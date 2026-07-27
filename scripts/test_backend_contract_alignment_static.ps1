[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$migrationPath = Join-Path $repoRoot 'supabase\migrations\20260725000000_backend_contract_alignment.sql'
$rollbackPath = Join-Path $repoRoot 'supabase\rollbacks\20260725000000_backend_contract_alignment_test_only.sql'
$exportPath = Join-Path $repoRoot 'supabase\functions\export-user-data\index.ts'
$dashboardExportPath = Join-Path $repoRoot 'supabase\dashboard_backend_services\export-user-data\index.ts'
$deletePath = Join-Path $repoRoot 'supabase\functions\delete-account\index.ts'
$dashboardDeletePath = Join-Path $repoRoot 'supabase\dashboard_backend_services\delete-account\index.ts'
$coachPath = Join-Path $repoRoot 'supabase\functions\coach-ai\index.ts'
$databaseTestPath = Join-Path $repoRoot 'supabase\tests\database\002_backend_contract_alignment.sql'
$remoteExportTestPath = Join-Path $repoRoot 'scripts\test_export_user_data_remote.ps1'
$preflightPath = Join-Path $repoRoot 'supabase\contract_alignment\01_preflight_readonly.sql'
$verificationPath = Join-Path $repoRoot 'supabase\contract_alignment\03_post_deploy_verification_readonly.sql'

$requiredFiles = @(
  $migrationPath,
  $rollbackPath,
  $exportPath,
  $dashboardExportPath,
  $deletePath,
  $dashboardDeletePath,
  $coachPath,
  $databaseTestPath,
  $remoteExportTestPath,
  $preflightPath,
  $verificationPath
)

Write-Host 'PHASE prerequisites'
foreach ($requiredFile in $requiredFiles) {
  if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
    throw "Required file missing: $requiredFile"
  }
}

function Read-Utf8([string]$Path) {
  return [System.IO.File]::ReadAllText(
    $Path,
    [System.Text.Encoding]::UTF8
  )
}

$migration = Read-Utf8 $migrationPath
$rollback = Read-Utf8 $rollbackPath
$export = Read-Utf8 $exportPath
$dashboardExport = Read-Utf8 $dashboardExportPath
$delete = Read-Utf8 $deletePath
$dashboardDelete = Read-Utf8 $dashboardDeletePath
$coach = Read-Utf8 $coachPath
$databaseTest = Read-Utf8 $databaseTestPath
$remoteExportTest = Read-Utf8 $remoteExportTestPath
$preflight = Read-Utf8 $preflightPath
$verification = Read-Utf8 $verificationPath

$passCount = 0
$failCount = 0

function Assert-Contract {
  param(
    [Parameter(Mandatory)]
    [bool]$Condition,
    [Parameter(Mandatory)]
    [string]$Name
  )
  if ($Condition) {
    $script:passCount++
    Write-Host "PASS $Name"
  } else {
    $script:failCount++
    Write-Host "FAIL $Name"
  }
}

Write-Host 'PHASE migration contract'
Assert-Contract ($migration -match '(?is)\bbegin\s*;.*commit\s*;\s*$') 'migration is transaction wrapped'
Assert-Contract ($migration -match 'training_sessions_exercises_array') 'training JSON array contract is validated'
Assert-Contract ($migration -match "jsonb_typeof\(exercises\)\s*=\s*'array'") 'training sessions remain JSON arrays'
Assert-Contract (-not ($migration -match '(?i)progressionTarget.+default.+targetSets')) 'no synthetic progression defaults'
Assert-Contract (-not ($migration -match "(?i)versioned_sync.+true")) 'versioned_sync is never enabled'

foreach ($table in @(
  'training_templates',
  'ai_memories',
  'ai_suggestions',
  'ai_suggestion_feedback'
)) {
  Assert-Contract ($migration -match "create table if not exists public\.$table") "$table is additive"
  Assert-Contract ($migration -match "alter table public\.$table enable row level security") "$table enables RLS"
  Assert-Contract ($migration -match "'$table'") "$table participates in shared policy/trigger/deletion checks"
}

Assert-Contract ($migration -match "source_type in \('userProvided', 'behaviorDerived', 'aiInferred'\)") 'AI memory source values match Dart enums'
Assert-Contract ($migration -match "status in \('active', 'pendingConfirmation', 'rejected', 'incorrect', 'archived'\)") 'AI memory status values match Dart enums'
Assert-Contract ($migration -match "status in \('proposed', 'accepted', 'modified', 'rejected', 'dismissed', 'applied', 'applyFailed'\)") 'AI suggestion status values match Dart enums'
Assert-Contract ($migration -match 'USER_PROVIDED_MEMORY_IDENTITY_IMMUTABLE') 'USER_PROVIDED identity cannot be reclassified'
Assert-Contract ($migration -match 'set search_path = ''''') 'security-definer deletion check uses empty search_path'
Assert-Contract ($migration -match 'grant execute on function public\.assert_account_deletion_ready\(\)\s+to service_role') 'deletion readiness remains service-role only'
Assert-Contract ($migration -match 'client_operations') 'existing idempotency ledger is a migration precondition'
Assert-Contract ($migration -match 'client_operation_id') 'new writes use existing client operation identifiers'

Write-Host 'PHASE export and delete'
foreach ($section in @(
  'trainingTemplates',
  'aiProfile',
  'aiMemories',
  'aiSuggestions',
  'aiFeedback'
)) {
  Assert-Contract ($export -match [regex]::Escape($section)) "export contains $section"
}
Assert-Contract (-not ($export -match "\.select\(\s*['""]\*['""]\s*\)")) 'export never selects wildcard fields'
Assert-Contract (-not ($export -match '(?i)select\([^)]*(access_token|refresh_token|claim_token|service_role|api_key)')) 'export whitelist excludes credentials and claim tokens'
Assert-Contract ($export -ceq $dashboardExport) 'Dashboard export copy is byte identical'
Assert-Contract ($delete -match 'confirmPhrase\s*!==\s*["'']DELETE MY ACCOUNT["'']') 'delete-account keeps fixed confirmation phrase'
Assert-Contract ($delete -match 'rpc\(["'']assert_account_deletion_ready["'']\)') 'delete-account checks cascade readiness'
Assert-Contract ($delete -ceq $dashboardDelete) 'Dashboard delete copy is byte identical'
Assert-Contract ($remoteExportTest -match 'unknownOptional') 'remote export test covers unknown JSON preservation'
Assert-Contract ($remoteExportTest -match 'restPolicyVersion') 'remote export test covers Rest V2 history'
Assert-Contract ($remoteExportTest -match 'training template order and maps round-trip') 'remote export test covers template order and maps'
Assert-Contract ($remoteExportTest -match 'AI suggestion and feedback round-trip') 'remote export test covers AI entities'

Write-Host 'PHASE coach endpoint'
foreach ($taskType in @(
  'nutrition_explanation',
  'progression_explanation',
  'rest_explanation',
  'coverage_explanation',
  'weekly_review',
  'memory_inference'
)) {
  Assert-Contract ($coach -match [regex]::Escape($taskType)) "coach-ai supports $taskType"
}
foreach ($deterministicFact in @(
  'effective sets',
  'trend weight',
  'progression recommendations',
  'coverage level',
  'exercise recommendations',
  'rest prescriptions'
)) {
  Assert-Contract ($coach -match [regex]::Escape($deterministicFact)) "coach-ai does not recalculate $deterministicFact"
}
Assert-Contract (-not ($coach -match '(?i)console\.(log|info|error)\([^)]*(token|email|password|providerKey)')) 'coach logs exclude credentials and personal identifiers'
Assert-Contract (-not ($coach -match '(?s)console\.(info|error).*?clientRequestId')) 'coach logs omit client-supplied request identifiers'

Write-Host 'PHASE test and rollback assets'
Assert-Contract ($databaseTest -match 'unknownOptional') 'database test covers unknown JSON preservation'
Assert-Contract ($databaseTest -match 'supersetGroupId') 'database test covers superset round-trip'
Assert-Contract ($databaseTest -match 'user B cannot read user A') 'database test covers cross-user isolation'
Assert-Contract ($databaseTest -match 'user A can update an owned template') 'database test covers own-row update'
Assert-Contract ($databaseTest -match 'user A can delete an owned template') 'database test covers own-row delete'
Assert-Contract ($databaseTest -match 'anonymous user cannot read') 'database test covers anonymous isolation'
Assert-Contract ($databaseTest -match 'service role can read user-owned rows') 'database test covers service-role behavior'
Assert-Contract ($databaseTest -match 'account deletion leaves no new-entity orphan rows') 'database test covers cascade cleanup'
Assert-Contract ($rollback -match 'TEST_ROLLBACK_GUARD_NOT_ENABLED') 'rollback is protected by an explicit test-project guard'
Assert-Contract (-not ($preflight -match '(?i)\b(insert|update|delete|truncate|drop|alter|create)\b\s+(table|into|from|public\.)')) 'preflight is read-only'
Assert-Contract (-not ($verification -match '(?i)\b(insert|update|delete|truncate|drop|alter|create)\b\s+(table|into|from|public\.)')) 'post-deploy verification is read-only'

Write-Host 'PHASE dangerous-pattern scan'
$combinedSql = "$migration`n$rollback`n$preflight`n$verification"
Assert-Contract (-not ($combinedSql -match '(?i)disable\s+row\s+level\s+security')) 'RLS is never disabled'
Assert-Contract (-not ($combinedSql -match '(?i)using\s*\(\s*true\s*\)')) 'no permissive USING true policy'
Assert-Contract (-not ($migration -match '(?i)\btruncate\b')) 'migration never truncates data'
Assert-Contract (-not ($migration -match '(?i)delete\s+from\s+')) 'migration never deletes user data'

Push-Location $repoRoot
try {
  git diff --check
  if ($LASTEXITCODE -ne 0) {
    throw "git diff --check failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

Write-Host "SUMMARY PASS=$passCount FAIL=$failCount"
if ($failCount -ne 0) {
  exit 1
}
