[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet(
    '10_schema.sql',
    '11_rls_and_permissions.sql',
    '12_verification_readonly.sql',
    'export-user-data/index.ts',
    'delete-account/index.ts'
  )]
  [string]$File
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot (Join-Path 'supabase/dashboard_backend_services' $File)

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
  throw "Source file not found: $File"
}

# Read as UTF-8 explicitly so Chinese SQL and Function source remain intact when
# pasted into the Supabase Dashboard editor.
$content = [System.IO.File]::ReadAllText(
  $sourcePath,
  [System.Text.Encoding]::UTF8
)

$clipboardStatus = 'unavailable'
try {
  Set-Clipboard -Value $content
  $clipboardStatus = 'ready'
} catch {
  # Headless PowerShell sessions may not expose a clipboard provider. Keep the
  # metadata check useful without printing the source content.
}
$hash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
Write-Output "file=$File"
Write-Output "characters=$($content.Length)"
Write-Output "sha256=$hash"
Write-Output "clipboard=$clipboardStatus"

$content = $null
