[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$TestProjectRef
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-ProjectKey {
  param([string]$Type, [string]$Name)
  $raw = (& supabase projects api-keys --project-ref $TestProjectRef --reveal --output json 2>$null | Out-String)
  $keys = ConvertFrom-Json -InputObject $raw
  $match = @($keys | Where-Object { $_.type -eq $Type -and $_.name -eq $Name }) | Select-Object -First 1
  if ($null -eq $match -or [string]::IsNullOrWhiteSpace([string]$match.api_key)) {
    throw "Missing qasz API key metadata: $Type/$Name"
  }
  return [string]$match.api_key
}

function Invoke-Api {
  param(
    [string]$Uri,
    [string]$Method,
    [hashtable]$Headers,
    [object]$Body = $null
  )
  try {
    $params = @{ Uri = $Uri; Method = $Method; Headers = $Headers; UseBasicParsing = $true }
    if ($null -ne $Body) {
      $params.ContentType = 'application/json'
      $params.Body = ($Body | ConvertTo-Json -Compress -Depth 20)
    }
    $response = Invoke-WebRequest @params
    return [pscustomobject]@{ Status = [int]$response.StatusCode; Body = [string]$response.Content; Headers = $response.Headers }
  } catch {
    $response = $null
    $responseProperty = $_.Exception.PSObject.Properties['Response']
    if ($null -ne $responseProperty) { $response = $responseProperty.Value }
    if ($null -eq $response) { return [pscustomobject]@{ Status = 0; Body = ''; Headers = @{}; ErrorType = $_.Exception.GetType().Name } }
    $bodyText = ''
    try {
      $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
      $bodyText = $reader.ReadToEnd()
      $reader.Dispose()
    } catch { $bodyText = '' }
    return [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $bodyText; Headers = $response.Headers; ErrorType = $_.Exception.GetType().Name }
  }
}

function Get-Count {
  param([string]$Table, [hashtable]$Headers)
  $response = Invoke-Api -Uri "$base/rest/v1/${Table}?select=*&limit=1" -Method 'GET' -Headers ($Headers + @{ Prefer = 'count=exact' })
  if ($response.Status -lt 200 -or $response.Status -ge 300) { throw "Count query failed: $Table status=$($response.Status) error=$($response.ErrorType)" }
  $range = [string]$response.Headers['Content-Range']
  if ($range -notmatch '/(\d+)$') { throw "Count header missing: $Table" }
  return [int64]$matches[1]
}

$base = "https://$TestProjectRef.supabase.co"
$anonKey = Get-ProjectKey -Type 'legacy' -Name 'anon'
if ([string]::IsNullOrWhiteSpace($anonKey)) { $anonKey = Get-ProjectKey -Type 'publishable' -Name 'default' }
$serviceKey = Get-ProjectKey -Type 'legacy' -Name 'service_role'
$publicHeaders = @{ apikey = $anonKey }
$serviceHeaders = @{ apikey = $serviceKey; Authorization = "Bearer $serviceKey" }

$tables = @('user_profiles', 'daily_tracking', 'chat_history', 'client_operations')
$before = @{}
foreach ($table in $tables) { $before[$table] = Get-Count -Table $table -Headers $serviceHeaders }

$flagRead = Invoke-Api -Uri "$base/rest/v1/app_feature_flags?select=key,enabled&key=eq.nutrition_ai" -Method 'GET' -Headers $serviceHeaders
if ($flagRead.Status -ne 200) { throw 'Feature flag snapshot failed' }
Write-Output 'phase=flag_snapshot'
$flagRows = ConvertFrom-Json -InputObject $flagRead.Body
if (@($flagRows).Count -ne 1) { throw 'nutrition_ai feature flag missing' }
$originalEnabled = [bool]$flagRows[0].enabled

$flagOff = Invoke-Api -Uri "$base/rest/v1/app_feature_flags?key=eq.nutrition_ai" -Method 'PATCH' -Headers ($serviceHeaders + @{ Prefer = 'return=representation' }) -Body @{ enabled = $false }
if ($flagOff.Status -lt 200 -or $flagOff.Status -ge 300) { throw 'Containment flag update failed' }
$flagCheckResponse = Invoke-Api -Uri "$base/rest/v1/app_feature_flags?select=enabled&key=eq.nutrition_ai" -Method 'GET' -Headers $serviceHeaders
if ($flagCheckResponse.Status -ne 200) { throw "Containment flag read failed status=$($flagCheckResponse.Status)" }
Write-Output 'phase=containment_committed'
$flagCheck = ConvertFrom-Json -InputObject $flagCheckResponse.Body
$countsAfterContainment = @{}
foreach ($table in $tables) { $countsAfterContainment[$table] = Get-Count -Table $table -Headers $serviceHeaders }
$countsStableDuringContainment = $true
foreach ($table in $tables) { if ($before[$table] -ne $countsAfterContainment[$table]) { $countsStableDuringContainment = $false } }

$flagRestore = Invoke-Api -Uri "$base/rest/v1/app_feature_flags?key=eq.nutrition_ai" -Method 'PATCH' -Headers ($serviceHeaders + @{ Prefer = 'return=representation' }) -Body @{ enabled = $originalEnabled }
if ($flagRestore.Status -lt 200 -or $flagRestore.Status -ge 300) { throw 'Forward-fix flag restore failed' }
$flagRestoredResponse = Invoke-Api -Uri "$base/rest/v1/app_feature_flags?select=enabled&key=eq.nutrition_ai" -Method 'GET' -Headers $serviceHeaders
if ($flagRestoredResponse.Status -ne 200) { throw "Restored flag read failed status=$($flagRestoredResponse.Status)" }
Write-Output 'phase=forward_fix_committed'
$flagRestored = ConvertFrom-Json -InputObject $flagRestoredResponse.Body

$email = "goat-qasz-rollback-$([guid]::NewGuid().ToString('N'))@example.invalid"
$password = "T!$([guid]::NewGuid().ToString('N'))a9"
$created = Invoke-Api -Uri "$base/auth/v1/admin/users" -Method 'POST' -Headers $serviceHeaders -Body @{ email = $email; password = $password; email_confirm = $true }
if ($created.Status -lt 200 -or $created.Status -ge 300) { throw 'Disposable user creation failed' }
Write-Output 'phase=disposable_user_created'
if ([string]::IsNullOrWhiteSpace($created.Body)) { throw 'Disposable user response body missing' }
Write-Output 'phase=created_body_present'
$createdJson = ConvertFrom-Json -InputObject ([string]$created.Body)
Write-Output 'phase=created_json_parsed'
$userId = [string]$createdJson.id
$login = Invoke-Api -Uri "$base/auth/v1/token?grant_type=password" -Method 'POST' -Headers $publicHeaders -Body @{ email = $email; password = $password }
if ($login.Status -ne 200) { throw 'Disposable user login failed' }
if ([string]::IsNullOrWhiteSpace($login.Body)) { throw 'Disposable user login response body missing' }
Write-Output 'phase=login_body_present'
$loginJson = ConvertFrom-Json -InputObject ([string]$login.Body)
Write-Output 'phase=login_json_parsed'
$token = [string]$loginJson.access_token
Write-Output "phase=token_present=$(-not [string]::IsNullOrWhiteSpace($token))"
$operationId = [guid]::NewGuid().ToString()
Write-Output 'phase=operation_created'
$body = @{ text = '100g chicken breast'; clientRequestId = $operationId }
$functionHeaders = @{ apikey = $anonKey; Authorization = "Bearer $token" }
Write-Output 'phase=function_request_start'
$function = Invoke-Api -Uri "$base/functions/v1/nutrition-ai" -Method 'POST' -Headers $functionHeaders -Body $body
Write-Output "phase=function_request_done_status=$($function.Status)"
$functionJson = $null
try { $functionJson = ConvertFrom-Json -InputObject $function.Body } catch { }
$oldFunctionAvailable = $function.Status -eq 200 -and $null -ne $functionJson -and $null -ne $functionJson.items
$codeProperty = if ($null -ne $functionJson) { $functionJson.PSObject.Properties['code'] } else { $null }
$functionErrorCode = if ($null -ne $codeProperty -and $codeProperty.Value) { [string]$codeProperty.Value } else { 'NONE' }

$cleanup = Invoke-Api -Uri "$base/auth/v1/admin/users/$userId" -Method 'DELETE' -Headers $serviceHeaders
Write-Output 'phase=disposable_user_deleted'
$after = @{}
foreach ($table in $tables) { $after[$table] = Get-Count -Table $table -Headers $serviceHeaders }
$dataRestored = $true
foreach ($table in $tables) { if ($before[$table] -ne $after[$table]) { $dataRestored = $false } }
$versionedResponse = Invoke-Api -Uri "$base/rest/v1/app_feature_flags?select=enabled&key=eq.versioned_sync" -Method 'GET' -Headers $serviceHeaders
if ($versionedResponse.Status -ne 200) { throw "versioned_sync read failed status=$($versionedResponse.Status)" }
$versioned = ConvertFrom-Json -InputObject $versionedResponse.Body
$versionedOff = @($versioned).Count -eq 1 -and [bool]$versioned[0].enabled -eq $false

Write-Output "containment_flag_disabled=$([bool](@($flagCheck).Count -eq 1 -and $flagCheck[0].enabled -eq $false))"
Write-Output "data_counts_stable_during_containment=$countsStableDuringContainment"
Write-Output "forward_fix_flag_restored=$([bool](@($flagRestored).Count -eq 1 -and [bool]$flagRestored[0].enabled -eq $originalEnabled))"
Write-Output "old_function_after_forward_fix_http_status=$($function.Status)"
Write-Output "old_function_after_forward_fix_error_code=$functionErrorCode"
Write-Output "old_function_after_forward_fix_contract=$oldFunctionAvailable"
Write-Output "test_account_cleanup_http_status=$($cleanup.Status)"
Write-Output "data_counts_restored_after_cleanup=$dataRestored"
Write-Output "versioned_sync_false=$versionedOff"

if (-not ($cleanup.Status -ge 200 -and $cleanup.Status -lt 300 -and $oldFunctionAvailable -and $dataRestored -and $countsStableDuringContainment -and $versionedOff)) { exit 1 }
