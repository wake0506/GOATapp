[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$TestProjectRef,

  [Parameter(Mandatory)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$ProductionProjectRef,

  [switch]$DeployEdgeFunctions,
  [switch]$RunDedicatedDeleteTest,
  [switch]$RunRollbackAndReapply
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($TestProjectRef -ceq $ProductionProjectRef) {
  throw 'Refusing to use the production project as the independent test project.'
}
if ([string]::IsNullOrWhiteSpace($env:GOAT_TEST_DATABASE_URL)) {
  throw 'GOAT_TEST_DATABASE_URL is required and will not be printed.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$migration = Join-Path $repoRoot 'supabase\migrations\20260725000000_backend_contract_alignment.sql'
$preflight = Join-Path $repoRoot 'supabase\contract_alignment\01_preflight_readonly.sql'
$verification = Join-Path $repoRoot 'supabase\contract_alignment\03_post_deploy_verification_readonly.sql'
$databaseTests = Join-Path $repoRoot 'supabase\tests\database\002_backend_contract_alignment.sql'
$rollback = Join-Path $repoRoot 'supabase\rollbacks\20260725000000_backend_contract_alignment_test_only.sql'
$staticTest = Join-Path $repoRoot 'scripts\test_backend_contract_alignment_static.ps1'
$exportTest = Join-Path $repoRoot 'scripts\test_export_user_data_remote.ps1'
$deleteTest = Join-Path $repoRoot 'scripts\test_delete_account_remote.ps1'
$runRoot = 'D:\CODEX\GOATapp-backend-contract-test-runs'
$runDirectory = Join-Path $runRoot (Get-Date -Format 'yyyyMMdd-HHmmss')

$requiredFiles = @(
  $migration,
  $preflight,
  $verification,
  $databaseTests,
  $rollback,
  $staticTest,
  $exportTest,
  $deleteTest
)
foreach ($requiredFile in $requiredFiles) {
  if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
    throw "Required file missing: $requiredFile"
  }
}

foreach ($tool in @('psql', 'deno')) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "$tool is required before independent test-project execution."
  }
}
if ($DeployEdgeFunctions -and -not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  throw 'Supabase CLI is required to deploy Edge Functions to the test project.'
}

New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
Copy-Item -LiteralPath $requiredFiles -Destination $runDirectory

function Set-PostgresEnvironment {
  $databaseUri = [Uri]$env:GOAT_TEST_DATABASE_URL
  if ($databaseUri.Scheme -notin @('postgres', 'postgresql')) {
    throw 'GOAT_TEST_DATABASE_URL must be a PostgreSQL connection URL.'
  }
  $credentials = $databaseUri.UserInfo.Split(':', 2)
  if ($credentials.Count -ne 2) {
    throw 'GOAT_TEST_DATABASE_URL must include user and password.'
  }
  $env:PGHOST = $databaseUri.Host
  $env:PGPORT = if ($databaseUri.Port -gt 0) { "$($databaseUri.Port)" } else { '5432' }
  $env:PGDATABASE = $databaseUri.AbsolutePath.TrimStart('/')
  $env:PGUSER = [Uri]::UnescapeDataString($credentials[0])
  $env:PGPASSWORD = [Uri]::UnescapeDataString($credentials[1])
  $env:PGSSLMODE = 'require'
  $env:PGCONNECT_TIMEOUT = '15'
}

function Invoke-PsqlFile {
  param(
    [Parameter(Mandatory)]
    [string]$Phase,
    [Parameter(Mandatory)]
    [string]$Path
  )
  Write-Host "PHASE $Phase"
  & psql -X --set ON_ERROR_STOP=1 --file $Path
  if ($LASTEXITCODE -ne 0) {
    throw "$Phase failed with exit code $LASTEXITCODE"
  }
}

function Assert-No-FailStatus {
  param([Parameter(Mandatory)][string]$Path)
  $output = & psql -X --csv --tuples-only --set ON_ERROR_STOP=1 --file $Path
  if ($LASTEXITCODE -ne 0) {
    throw "Read-only verification failed: $Path"
  }
  $output | Set-Content -LiteralPath (Join-Path $runDirectory ((Split-Path -Leaf $Path) + '.csv')) -Encoding utf8
  if ($output -match ',FAIL,' -or $output -match ',REVIEW,') {
    throw "Read-only verification returned FAIL or REVIEW: $Path"
  }
}

try {
  Set-PostgresEnvironment

  Write-Host 'PHASE local static checks'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $staticTest
  if ($LASTEXITCODE -ne 0) {
    throw 'Local static contract checks failed.'
  }

  Write-Host 'PHASE Deno checks'
  & deno check `
    (Join-Path $repoRoot 'supabase\functions\export-user-data\index.ts') `
    (Join-Path $repoRoot 'supabase\functions\delete-account\index.ts') `
    (Join-Path $repoRoot 'supabase\functions\coach-ai\index.ts')
  if ($LASTEXITCODE -ne 0) {
    throw 'Deno type checking failed.'
  }
  & deno test `
    (Join-Path $repoRoot 'supabase\functions\nutrition-ai\index.test.ts') `
    (Join-Path $repoRoot 'supabase\functions\delete-account\index.test.ts') `
    (Join-Path $repoRoot 'supabase\functions\coach-ai\index.test.ts')
  if ($LASTEXITCODE -ne 0) {
    throw 'Deno Edge Function tests failed.'
  }

  Write-Host 'PHASE schema preflight'
  Assert-No-FailStatus $preflight

  Invoke-PsqlFile -Phase 'migration first run' -Path $migration
  Assert-No-FailStatus $verification

  Invoke-PsqlFile -Phase 'migration idempotent re-run' -Path $migration
  Assert-No-FailStatus $verification

  Invoke-PsqlFile -Phase 'database contract and RLS tests' -Path $databaseTests

  if ($DeployEdgeFunctions) {
    Write-Host 'PHASE test-project Edge Function deployment'
    foreach ($functionName in @('export-user-data', 'delete-account', 'coach-ai')) {
      & supabase functions deploy $functionName --project-ref $TestProjectRef
      if ($LASTEXITCODE -ne 0) {
        throw "Test-project deployment failed: $functionName"
      }
    }

    Write-Host 'PHASE authenticated export smoke test'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $exportTest
    if ($LASTEXITCODE -ne 0) {
      throw 'Authenticated export smoke test failed.'
    }

    if ($RunDedicatedDeleteTest) {
      Write-Host 'PHASE dedicated account deletion smoke test'
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $deleteTest
      if ($LASTEXITCODE -ne 0) {
        throw 'Dedicated account deletion smoke test failed.'
      }
    } else {
      throw 'Full acceptance requires -RunDedicatedDeleteTest with a dedicated delete-test account.'
    }
  } else {
    throw 'Full acceptance requires -DeployEdgeFunctions after explicit independent-test-project approval.'
  }

  if ($RunRollbackAndReapply) {
    Write-Host 'PHASE guarded test rollback'
    $rollbackDriver = Join-Path $runDirectory 'rollback-driver.sql'
    @(
      "set goat.contract_test_rollback = 'on';"
      "\i '$($rollback.Replace('\', '/'))'"
    ) | Set-Content -LiteralPath $rollbackDriver -Encoding utf8
    Invoke-PsqlFile -Phase 'guarded rollback' -Path $rollbackDriver

    Invoke-PsqlFile -Phase 'migration reapply after rollback' -Path $migration
    Assert-No-FailStatus $verification
    Invoke-PsqlFile -Phase 'database tests after reapply' -Path $databaseTests
  } else {
    throw 'Full acceptance requires -RunRollbackAndReapply.'
  }

  Write-Host 'PASS BACKEND CONTRACT ALIGNMENT INDEPENDENT TEST PROJECT'
} finally {
  $env:PGPASSWORD = $null
  $env:GOAT_TEST_DATABASE_URL = $null
}
