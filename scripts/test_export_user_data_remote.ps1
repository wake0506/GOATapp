[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$results = [System.Collections.Generic.List[object]]::new()
$accessToken = $null
$password = $null
$tempPath = $null

function Add-Result {
  param([string]$Name, [bool]$Passed)
  $results.Add([pscustomobject]@{ Name = $Name; Passed = $Passed })
  if ($Passed) { Write-Output "PASS $Name" } else { Write-Output "FAIL $Name" }
}

function Invoke-Http {
  param(
    [string]$Uri,
    [string]$Method,
    [hashtable]$Headers,
    [string]$Body = $null
  )
  try {
    $request = @{ Uri = $Uri; Method = $Method; Headers = $Headers; UseBasicParsing = $true }
    if ($null -ne $Body) {
      $request.Body = $Body
      $request.ContentType = 'application/json; charset=utf-8'
    }
    $response = Invoke-WebRequest @request
    return [pscustomobject]@{ Status = [int]$response.StatusCode; Body = [string]$response.Content }
  } catch {
    $webResponse = $_.Exception.Response
    if ($null -eq $webResponse) { return [pscustomobject]@{ Status = 0; Body = '' } }
    return [pscustomobject]@{ Status = [int]$webResponse.StatusCode; Body = '' }
  }
}

function Has-Property {
  param([object]$Object, [string]$Name)
  return $null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]
}

$supabaseUrl = $env:SUPABASE_URL
$anonKey = $env:SUPABASE_ANON_KEY
$email = $env:GOAT_TEST_EMAIL
$password = $env:GOAT_TEST_PASSWORD

try {
  $configOk = -not [string]::IsNullOrWhiteSpace($supabaseUrl) -and
    -not [string]::IsNullOrWhiteSpace($anonKey) -and
    -not [string]::IsNullOrWhiteSpace($email) -and
    -not [string]::IsNullOrWhiteSpace($password)
  Add-Result 'required environment variables' $configOk
  if ($configOk) {
    $supabaseUrl = $supabaseUrl.TrimEnd('/')
  $authHeaders = @{ apikey = $anonKey }
  $functionUrl = "$supabaseUrl/functions/v1/export-user-data"
  $requestBody = '{}'

  $anonymous = Invoke-Http -Uri $functionUrl -Method 'POST' -Headers $authHeaders -Body $requestBody
  Add-Result 'anonymous request returns 401' ($anonymous.Status -eq 401)

  $loginBody = @{ email = $email; password = $password } | ConvertTo-Json -Compress
  try {
    $login = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers $authHeaders -ContentType 'application/json' -Body $loginBody
    $accessToken = [string]$login.access_token
  } catch { $accessToken = $null }
  $loginOk = -not [string]::IsNullOrWhiteSpace($accessToken)
  Add-Result 'test account login' $loginOk

  if ($loginOk) {
    $functionHeaders = @{ apikey = $anonKey; Authorization = "Bearer $accessToken" }
    $response = Invoke-Http -Uri $functionUrl -Method 'POST' -Headers $functionHeaders -Body $requestBody
    Add-Result 'authenticated export returns HTTP 200' ($response.Status -eq 200)

    if ($response.Status -eq 200) {
      $tempPath = Join-Path ([IO.Path]::GetTempPath()) "goat-export-$([guid]::NewGuid()).json"
      [IO.File]::WriteAllText($tempPath, $response.Body, [Text.UTF8Encoding]::new($false))
      $raw = [IO.File]::ReadAllText($tempPath, [Text.Encoding]::UTF8)
      try { $export = $raw | ConvertFrom-Json } catch { $export = $null }
      Add-Result 'export body is valid JSON' ($null -ne $export)

      $requiredFields = @('exportedAt', 'profile', 'foodDictionary', 'dietLogs', 'exerciseLogs', 'dailyTracking', 'waterRecords', 'weightLogs', 'trainingSessions', 'chatHistory', 'settings')
      $fieldsOk = $true
      foreach ($field in $requiredFields) { if (-not (Has-Property $export $field)) { $fieldsOk = $false } }
      Add-Result 'export field allow-list is complete' $fieldsOk
      Add-Result 'export excludes sensitive and internal fields' (-not ($raw -match '(?i)access_token|refresh_token|service_role|claim_token|client_operation_id|DEEPSEEK_API_KEY'))
    } else {
      Add-Result 'export body is valid JSON' $false
      Add-Result 'export field allow-list is complete' $false
      Add-Result 'export excludes sensitive and internal fields' $false
    }
    } else {
      Add-Result 'authenticated export returns HTTP 200' $false
      Add-Result 'export body is valid JSON' $false
      Add-Result 'export field allow-list is complete' $false
      Add-Result 'export excludes sensitive and internal fields' $false
    }
  }
} finally {
  if ($tempPath -and (Test-Path -LiteralPath $tempPath)) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
  $accessToken = $null
  $password = $null
}

$passed = @($results | Where-Object { $_.Passed }).Count
$failed = @($results | Where-Object { -not $_.Passed }).Count
Write-Output "SUMMARY PASS=$passed FAIL=$failed"
if ($failed -gt 0) { exit 1 }
exit 0
