-- Run this after 00_READ_ME_FIRST.md. This is intentionally standalone: the
-- Dashboard SQL Editor does not support psql includes. Keep it in sync with
-- the matching migration's schema/function section.
create table if not exists public.sync_diagnostics (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null check (char_length(trim(device_id)) between 8 and 128), app_version text not null check (char_length(trim(app_version)) between 1 and 64),
  sync_enabled boolean not null, pending_operations integer not null default 0 check (pending_operations >= 0),
  last_success_at timestamptz, last_error_code text check (last_error_code is null or last_error_code ~ '^[A-Z0-9_]{1,64}$'), last_error_at timestamptz,
  updated_at timestamptz not null default now(), unique (user_id, device_id)
);
create table if not exists public.app_feature_flags (
  key text primary key check (key ~ '^[a-z][a-z0-9_]{1,63}$'), enabled boolean not null default false,
  config jsonb not null default '{}'::jsonb check (jsonb_typeof(config) = 'object'), minimum_app_version text, updated_at timestamptz not null default now()
);
drop trigger if exists sync_diagnostics_updated_at on public.sync_diagnostics;
create trigger sync_diagnostics_updated_at before update on public.sync_diagnostics for each row execute function public.goat_set_updated_at();
drop trigger if exists app_feature_flags_updated_at on public.app_feature_flags;
create trigger app_feature_flags_updated_at before update on public.app_feature_flags for each row execute function public.goat_set_updated_at();
insert into public.app_feature_flags (key, enabled) values ('versioned_sync', false), ('nutrition_ai', true), ('training_ai_insights', false), ('voice_entry', true) on conflict (key) do nothing;

create or replace function public.get_daily_summary(p_date date)
returns table (date date, calories_in numeric, calories_burned numeric, net_calories numeric, protein_g numeric, carbs_g numeric, fat_g numeric, water_ml bigint, weight_kg numeric, exercise_count bigint, training_count bigint, training_volume_kg numeric, completed_sets bigint)
language sql security invoker set search_path = public stable as $$
  with u as (select auth.uid() id), d as (select coalesce(sum(kcal),0) ci,coalesce(sum(p),0) p,coalesce(sum(c),0) c,coalesce(sum(f),0) f from public.diet_logs x,u where x.user_id=u.id and x.date=p_date and x.deleted_at is null),
  e as (select coalesce(sum(kcal),0) cb,count(*) ec from public.exercise_logs x,u where x.user_id=u.id and x.date=p_date and x.deleted_at is null),
  w as (select coalesce(sum(amount_ml),0)::bigint ml from public.water_intake_records x,u where x.user_id=u.id and x.date=p_date and x.deleted_at is null),
  b as (select coalesce(max(weight_kg),0) kg from public.body_weight_logs x,u where x.user_id=u.id and x.date=p_date and x.deleted_at is null),
  t as (select count(*)::bigint tc,coalesce(sum(q.volume),0) vol,coalesce(sum(q.sets),0)::bigint sets from public.training_sessions x join u on x.user_id=u.id cross join lateral (select coalesce(sum(coalesce((s.value->>'weight')::numeric,0)*coalesce((s.value->>'reps')::numeric,0)),0) volume,count(s.value) filter(where coalesce((s.value->>'reps')::integer,0)>0) sets from jsonb_array_elements(coalesce(x.exercises,'[]'::jsonb)) z(value) cross join lateral jsonb_array_elements(coalesce(z.value->'sets','[]'::jsonb)) s(value)) q where x.date=p_date and x.deleted_at is null)
  select p_date,d.ci,e.cb,d.ci-e.cb,d.p,d.c,d.f,w.ml,b.kg,e.ec,t.tc,t.vol,t.sets from d,e,w,b,t;
$$;
create or replace function public.get_weekly_summary(p_start_date date)
returns table (start_date date,end_date date,days jsonb,average_calories_in numeric,average_calories_burned numeric,average_water_ml numeric,average_training_volume_kg numeric,training_count bigint,weight_start_kg numeric,weight_end_kg numeric,weight_change_kg numeric,average_macro_goal_completion_pct numeric)
language sql security invoker set search_path = public stable as $$
  with u as (select auth.uid() id), d as (select s.* from generate_series(p_start_date,p_start_date+6,interval '1 day') g(day) cross join lateral public.get_daily_summary(g.day::date) s), p as(select target_p,target_c,target_f from public.user_profiles x,u where x.id=u.id),w as(select * from d where weight_kg>0 order by date)
  select p_start_date,p_start_date+6,jsonb_agg(jsonb_build_object('date',date,'calories_in',calories_in,'calories_burned',calories_burned,'water_ml',water_ml,'weight_kg',nullif(weight_kg,0),'training_volume_kg',training_volume_kg) order by date),avg(calories_in),avg(calories_burned),avg(water_ml),avg(training_volume_kg),sum(training_count),(select weight_kg from w limit 1),(select weight_kg from w offset greatest((select count(*) from w)-1,0) limit 1),(select weight_kg from w offset greatest((select count(*) from w)-1,0) limit 1)-(select weight_kg from w limit 1),coalesce(((avg(case when p.target_p>0 then d.protein_g/p.target_p end)+avg(case when p.target_c>0 then d.carbs_g/p.target_c end)+avg(case when p.target_f>0 then d.fat_g/p.target_f end))*100/3),0) from d cross join p;
$$;
revoke all on function public.get_daily_summary(date), public.get_weekly_summary(date) from public, anon;
grant execute on function public.get_daily_summary(date), public.get_weekly_summary(date) to authenticated;

create or replace function public.assert_account_deletion_ready() returns boolean language plpgsql security definer set search_path = pg_catalog, public, auth as $$
declare t text; c text;
begin
  foreach t in array array['user_profiles','food_dictionary','diet_logs','exercise_logs','daily_tracking','water_intake_records','body_weight_logs','training_sessions','sync_tombstones','client_operations','ai_usage_daily','sync_diagnostics'] loop
    c := case when t='user_profiles' then 'id' else 'user_id' end;
    if not exists(select 1 from pg_constraint k join pg_class r on r.oid=k.conrelid join pg_namespace n on n.oid=r.relnamespace join pg_attribute a on a.attrelid=r.oid and a.attnum=any(k.conkey) where k.contype='f' and k.confrelid='auth.users'::regclass and k.confdeltype='c' and n.nspname='public' and r.relname=t and a.attname=c) then raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:%',t using errcode='check_violation'; end if;
  end loop;
  if to_regclass('public.chat_history') is not null and not exists(select 1 from pg_constraint k join pg_class r on r.oid=k.conrelid join pg_namespace n on n.oid=r.relnamespace join pg_attribute a on a.attrelid=r.oid and a.attnum=any(k.conkey) where k.contype='f' and k.confrelid='auth.users'::regclass and k.confdeltype='c' and n.nspname='public' and r.relname='chat_history' and a.attname='user_id') then raise exception 'ACCOUNT_DELETION_FK_NOT_CASCADE:chat_history' using errcode='check_violation'; end if;
  return true;
end;
$$;
revoke all on function public.assert_account_deletion_ready() from public, anon, authenticated;
grant execute on function public.assert_account_deletion_ready() to service_role;
revoke all on function public.delete_user() from public, anon, authenticated;
