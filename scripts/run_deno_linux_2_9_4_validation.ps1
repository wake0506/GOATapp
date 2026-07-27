[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $repoRoot 'artifacts\backend_contract_alignment\logs\deno_linux_2_9_4_test.log'
$log = [System.Collections.Generic.List[string]]::new()
$image = 'denoland/deno:2.9.4'
$mount = "$repoRoot`:/workspace:ro"

function Add-Log {
  param([string]$Line)
  [void]$script:log.Add($Line)
  Write-Host $Line
}

function Invoke-Container {
  param(
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string[]]$Arguments
  )
  Add-Log "--- $Label ---"
  Add-Log "Command: docker run --rm --volume $mount --workdir /workspace --env DENO_DIR=/tmp/deno --env DENO_NO_UPDATE_CHECK=1 --env DENO_NO_PROMPT=1 $image deno $($Arguments -join ' ')"
  $started = [DateTimeOffset]::Now
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = @(& docker run --rm --volume $mount --workdir /workspace --env DENO_DIR=/tmp/deno --env DENO_NO_UPDATE_CHECK=1 --env DENO_NO_PROMPT=1 $image deno @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
  }
  $duration = [DateTimeOffset]::Now - $started
  Add-Log "ExitCode: $exitCode"
  Add-Log "Duration: $([Math]::Round($duration.TotalSeconds, 3))s"
  foreach ($line in $output) {
    Add-Log ([string]$line)
  }
  $summary = ($output -join "`n")
  $passed = [regex]::Match($summary, '(?i)(\d+)\s+passed').Groups[1].Value
  $failed = [regex]::Match($summary, '(?i)(\d+)\s+failed').Groups[1].Value
  $ignored = [regex]::Match($summary, '(?i)(\d+)\s+ignored').Groups[1].Value
  Add-Log "TestsPassed: $(if ($passed) { $passed } else { 'not reported' })"
  Add-Log "TestsFailed: $(if ($failed) { $failed } else { 'not reported' })"
  Add-Log "Ignored: $(if ($ignored) { $ignored } else { 'not reported' })"
  $leakLines = $output | Where-Object { [string]$_ -match '(?i)sanitizer|resource leak|leak detected' }
  Add-Log "SanitizerOrResourceLeak: $(if ($leakLines) { ($leakLines -join ' | ') } else { 'not reported' })"
  if ($exitCode -ne 0) {
    throw "$Label failed with exit code $exitCode"
  }
}

Push-Location $repoRoot
try {
  Add-Log "Image: $image"
  $digest = (& docker image inspect $image --format '{{index .RepoDigests 0}}' 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or -not $digest) { throw 'Unable to read the official Deno image digest.' }
  Add-Log "ImageDigest: $digest"
  $beforeStatus = @(git status --short)
  $beforeDiff = @(git diff --binary)
  Add-Log "HostBeforeStatusEntries: $($beforeStatus.Count)"
  Add-Log "HostBeforeDiffBytes: $([Text.Encoding]::UTF8.GetByteCount(($beforeDiff -join "`n")))"
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $version = @(& docker run --rm --volume $mount --workdir /workspace --env DENO_DIR=/tmp/deno --env DENO_NO_UPDATE_CHECK=1 --env DENO_NO_PROMPT=1 $image deno --version 2>&1)
  $versionExit = $LASTEXITCODE
  $ErrorActionPreference = $previousPreference
  Add-Log '--- container version ---'
  Add-Log "ExitCode: $versionExit"
  foreach ($line in $version) { Add-Log ([string]$line) }
  if ($versionExit -ne 0 -or -not (($version -join "`n") -match 'deno 2\.9\.4')) {
    throw 'Official Linux container did not report Deno 2.9.4.'
  }
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $uname = @(& docker run --rm --volume $mount --workdir /workspace --env DENO_DIR=/tmp/deno --env DENO_NO_UPDATE_CHECK=1 --env DENO_NO_PROMPT=1 $image uname -a 2>&1)
  $ErrorActionPreference = $previousPreference
  Add-Log 'ContainerOS:'
  foreach ($line in $uname) { Add-Log ([string]$line) }

  Invoke-Container -Label 'single test file' -Arguments @('test', 'supabase/functions/nutrition-ai/index.test.ts')
  Invoke-Container -Label 'full test suite first run' -Arguments @('test', 'supabase/functions/nutrition-ai/index.test.ts', 'supabase/functions/coach-ai/index.test.ts', 'supabase/functions/delete-account/index.test.ts')
  Invoke-Container -Label 'full test suite second run' -Arguments @('test', 'supabase/functions/nutrition-ai/index.test.ts', 'supabase/functions/coach-ai/index.test.ts', 'supabase/functions/delete-account/index.test.ts')

  $afterStatus = @(git status --short)
  $afterDiff = @(git diff --binary)
  Add-Log "HostAfterStatusEntries: $($afterStatus.Count)"
  Add-Log "HostAfterDiffBytes: $([Text.Encoding]::UTF8.GetByteCount(($afterDiff -join "`n")))"
  if (($beforeStatus -join "`n") -cne ($afterStatus -join "`n") -or ($beforeDiff -join "`n") -cne ($afterDiff -join "`n")) {
    throw 'Repository changed during read-only container execution.'
  }
  Add-Log 'HostSourceWorktreeUnchanged: PASS'
} finally {
  $logDirectory = Split-Path -Parent $logPath
  New-Item -ItemType Directory -Force $logDirectory | Out-Null
  [System.IO.File]::WriteAllLines($logPath, $log, [Text.UTF8Encoding]::new($false))
  Pop-Location
}
