# GOATapp Supabase Dashboard 部署包 v2

本目录是供 Supabase Dashboard 网页执行的拆分版本。仓库中的
`supabase/migrations/` 和 `supabase/functions/nutrition-ai/` 仍是源码真相，
本目录不替代它们。本轮只生成和审查部署文件，不执行远程部署。

本 v3 包按生产预检结果处理：`pg_policies.permissive` 按文本比较，Policy
命令使用 `ALL`；`user_profiles.training_data` 可为 text 或 jsonb；
`client_operations` 使用 `claimed_at` 实现两分钟租约。07 不创建或替换
`delete_user()`，账号注销需单独安全审计。

本 v4 包进一步将 AI RPC 限制为 `service_role`，Edge Function 使用用户 client
验证 JWT、使用 admin client 调用 RPC；`SUPABASE_SECRET_KEYS` 优先，兼容
`SUPABASE_SERVICE_ROLE_KEY`。legacy 饮水记录的 `recorded_at` 为 NULL，不代表具体时间。

## 已确认的数据基线

部署后必须保留以下数据：

- `user_profiles`：1 行，且至少 1 行 `training_data` 非空
- `food_dictionary`：0 行
- `diet_logs`：0 行
- `exercise_logs`：0 行
- `daily_tracking`：2 行，旧饮水兼容总量 300 ml
- 旧饮水：1 条 legacy 汇总记录，总量 300 ml
- 旧体重：2 条记录
- `chat_history`：1 行

## 重要边界

- 不使用 Table Editor 手工创建 11 张表或修改 Policy。
- 不运行 `99_emergency_rollback.sql`，除非项目负责人已确认备份、项目和回滚范围。
- 任何步骤出现 `FAIL`，立即停止，不继续执行后续脚本。
- 不把 service-role key、secret key、访问令牌或 `DEEPSEEK_API_KEY` 写入仓库、Flutter 或 SQL。
- Dashboard Edge Function 编辑器没有可靠的仓库版本历史，部署前后都以仓库源码为准。
- 不关闭 RLS，不使用无条件放行策略。

## A. 备份确认

1. 打开 Supabase Dashboard，确认项目和登录账号正确。
2. 进入 **Database → Backups**，确认当前备份状态，并记录最近备份时间。
3. 未确认备份前不要继续。

## B. SQL Editor 执行顺序

逐个粘贴并执行以下脚本，每一步保存截图或复制 SQL Editor 输出：

1. `01_preflight_readonly.sql`
2. `02_schema_extensions.sql`
3. `03_new_tables.sql`
4. `04_legacy_data_migration.sql`
5. `05_triggers_indexes_constraints.sql`
6. 再运行 `01_preflight_readonly.sql`，确认表、字段和现有 Policy 没有异常
7. `06_rls_policies.sql`
8. `07_rpc_and_functions.sql`
9. `08_verification_readonly.sql`

重点：运行 `06` 前必须人工确认 `01` 的 Policy 输出。`06` 只保留已有实际表达式安全的 Policy，
不会按名称删除、覆盖或替换；发现冲突会停止并要求人工审查。`05` 在验证历史行无违规后才会
`VALIDATE CONSTRAINT`，发现不合法数据会回滚本次事务且不删除或修正用户数据。

## C. Edge Function

1. 进入 **Edge Functions → Deploy a new function → Via Editor**。
2. 函数名填写 `nutrition-ai`。
3. 粘贴 `nutrition-ai/index.ts` 的完整内容并部署。
4. 在 **Edge Function Secrets** 中添加 `DEEPSEEK_API_KEY`，只在 Dashboard Secret 中填写真实值。
5. 使用 Dashboard Test 验证未登录请求返回 401，合法请求返回严格 JSON。

Edge Function 使用服务端固定限额 RPC，不接受客户端 user id、日期或限额；nutrition-ai
幂等记录由服务端 RPC 原子声明、保存和释放，客户端不能直接写入这些行。

## D. 最后验证

再次运行 `08_verification_readonly.sql`。所有必要检查应为 `PASS`；`REVIEW` 必须在部署记录中
由人工确认。不要运行 rollback，不要通过 Table Editor 手工补对象。

## 源码对应关系

- Schema：`supabase/migrations/20260713000000_backend_production.sql`
- Edge Function：`supabase/functions/nutrition-ai/index.ts`
- Dashboard SQL：本目录 `01` 到 `09`
- 回滚参考：本目录 `99_emergency_rollback.sql`
