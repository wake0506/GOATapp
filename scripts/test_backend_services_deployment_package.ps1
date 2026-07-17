[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$results = [System.Collections.Generic.List[object]]::new()
$repoRoot = Split-Path -Parent $PSScriptRoot
$migrationPath = Join-Path $repoRoot 'supabase/migrations/20260715000000_backend_data_services.sql'
$schemaPath = Join-Path $repoRoot 'supabase/dashboard_backend_services/10_schema.sql'
$rlsPath = Join-Path $repoRoot 'supabase/dashboard_backend_services/11_rls_and_permissions.sql'
$verificationPath = Join-Path $repoRoot 'supabase/dashboard_backend_services/12_verification_readonly.sql'

function Add-Result {
  param([string]$Name, [bool]$Passed)
  $results.Add([pscustomobject]@{ Name = $Name; Passed = $Passed })
  if ($Passed) { Write-Output "PASS $Name" } else { Write-Output "FAIL $Name" }
}

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

$migration = Read-Utf8 $migrationPath
$schema = Read-Utf8 $schemaPath
$rls = Read-Utf8 $rlsPath
$verification = Read-Utf8 $verificationPath
$allSql = $migration + "`n" + $schema + "`n" + $rls + "`n" + $verification

$bannedTypePattern = 'pg_catalog\.(boolean|integer|bigint|smallint|varchar|timestamp|date|time|double|real)'
Add-Result 'standard boolean type is used' ($schema -match '\bsync_enabled\s+boolean\b')
Add-Result 'no invalid pg_catalog scalar types remain' (-not ($allSql -match $bannedTypePattern))
Add-Result '10 is transaction-wrapped for rollback' ($schema -match '(?im)^begin;' -and $schema -match '(?im)^commit;' -and $schema -match 'REQUIRED_OBJECT_MISSING')

$chatFkSafe = $schema -match 'CHAT_HISTORY_ORPHAN_USER_ID' -and
  $migration -match 'CHAT_HISTORY_ORPHAN_USER_ID' -and
  $schema -match 'foreign key \(user_id\) references auth\.users\(id\) on delete cascade' -and
  $migration -match 'foreign key \(user_id\) references auth\.users\(id\) on delete cascade' -and
  $schema -match 'on delete cascade not valid' -and
  $migration -match 'on delete cascade not valid' -and
  $schema -match 'validate constraint goat_chat_history_user_id_fkey' -and
  $migration -match 'validate constraint goat_chat_history_user_id_fkey' -and
  $schema -match "fk\.confdeltype = 'c'" -and
  $migration -match "fk\.confdeltype = 'c'"
Add-Result 'chat_history without orphans can be made cascade-safe' $chatFkSafe
Add-Result 'chat_history orphans stop without data deletion' ($schema -match 'CHAT_HISTORY_ORPHAN_USER_ID' -and -not ($schema -match '(?im)^\s*delete\s+from\s+public\.chat_history'))
Add-Result 'existing cascade FK is idempotently preserved' ($schema -match "fk\.confdeltype = 'c'" -and $schema -match 'if not has_cascade_fk then')

$legacyDeleteSafe = $schema -match "to_regprocedure\('public\.delete_user\(\)'\)" -and
  $migration -match "to_regprocedure\('public\.delete_user\(\)'\)" -and
  $schema -match "revoke all on function public\.delete_user\(\) from public" -and
  $migration -match "revoke all on function public\.delete_user\(\) from public" -and
  $schema -match "revoke all on function public\.delete_user\(\) from anon" -and
  $migration -match "revoke all on function public\.delete_user\(\) from anon" -and
  $schema -match "revoke all on function public\.delete_user\(\) from authenticated" -and
  $migration -match "revoke all on function public\.delete_user\(\) from authenticated"
Add-Result 'legacy delete_user absence is safe and client roles are revoked' $legacyDeleteSafe

$triggerSafe = $schema -match 'drop trigger if exists sync_diagnostics_updated_at on public\.sync_diagnostics' -and
  $schema -match 'drop trigger if exists app_feature_flags_updated_at on public\.app_feature_flags' -and
  $schema -match "to_regprocedure\('public\.goat_set_updated_at\(\)'\)" -and
  $verification -match "trigger:' \|\| table_name \|\| '_updated_at'"
Add-Result 'managed updated_at triggers are checked and recreated idempotently' $triggerSafe

Add-Result '11 is transaction-wrapped with no permissive client write policy' ($rls -match '(?im)^begin;' -and $rls -match '(?im)^commit;' -and -not ($rls -match 'using\s*\(\s*true\s*\)'))
Add-Result '12 reports missing objects as FAIL without invoking readiness checks' ($verification -match 'to_regclass' -and $verification -match "'FAIL', 'table is missing'" -and -not ($verification -match 'select\s+public\.assert_account_deletion_ready\('))

$passed = @($results | Where-Object { $_.Passed }).Count
$failed = @($results | Where-Object { -not $_.Passed }).Count
Write-Output "SUMMARY PASS=$passed FAIL=$failed"
if ($failed -gt 0) { exit 1 }
exit 0
