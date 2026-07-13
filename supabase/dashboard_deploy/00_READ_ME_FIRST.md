# GOATapp Supabase Dashboard 部署包

本目录是网页 Dashboard SQL Editor 的执行版本。仓库中的
`supabase/migrations/` 和 `supabase/functions/nutrition-ai/` 仍是源码真相；本目录只为人工网页部署拆分脚本。

## 执行边界

- 本包不包含数据库密码、service-role key、access token 或 DeepSeek key。
- 不要使用 Table Editor 手工创建 11 张表。
- 不要在本轮运行 `99_emergency_rollback.sql`。
- 不要把 service-role key 放进 Flutter；publishable key 也不能替代服务端权限控制。
- Dashboard Edge Function Editor 没有可靠的仓库版本历史，部署前后都应以仓库源码为准。
- 每个 SQL 文件单独粘贴执行。某一步报错后立即停止，保存错误信息，不要继续后续脚本。

## 网页步骤

### A. 备份确认

1. 打开 Supabase Dashboard，确认项目名称、Project ID 和当前登录账号。
2. 进入 **Database → Backups**，确认最近备份状态并记录备份时间。
3. 确认有回滚负责人；没有备份确认时不要继续。

### B. SQL Editor

按以下顺序逐个执行，并在每一步保存结果截图或复制结果：

1. `01_preflight_readonly.sql`
2. `02_schema_extensions.sql`
3. `03_new_tables.sql`
4. `04_legacy_data_migration.sql`
5. `05_triggers_indexes_constraints.sql`
6. `06_rls_policies.sql`
7. `07_rpc_and_functions.sql`
8. `08_verification_readonly.sql`

`01` 和 `08` 只读。所有脚本都设计为可在失败原因排除后安全重试，但仍必须逐步确认，不要盲目重复执行。

### C. Edge Function

1. 进入 **Edge Functions → Deploy a new function → Via Editor**。
2. 函数名填写 `nutrition-ai`。
3. 粘贴 `nutrition-ai/index.ts` 的完整源码并部署。
4. 使用 Dashboard Test 功能验证：未登录请求应返回 401；合法请求应返回 `items`、`requestId`、`provider`。

### D. Edge Function Secret

在 **Edge Function Secrets** 中添加：

```text
DEEPSEEK_API_KEY=<由操作者安全输入，不要写入仓库>
```

不要在 SQL Editor、Flutter、Git、日志或 APK 中粘贴该值。

### E. 最后检查

再次运行 `08_verification_readonly.sql`，确认全部关键项为 `PASS`，`REVIEW` 项已人工确认，且没有执行任何回滚文件。

## 源码对应关系

- Schema 源码：`supabase/migrations/20260713000000_backend_production.sql`
- Function 源码：`supabase/functions/nutrition-ai/index.ts`
- Dashboard SQL：本目录 `01` 到 `08`
- 回滚参考：本目录 `99_emergency_rollback.sql`
