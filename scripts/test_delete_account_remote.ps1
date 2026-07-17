[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$results = [System.Collections.Generic.List[object]]::new()
$accessToken = $null
$password = $null

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
    return [pscustomobject]@{ Status = [int]$response.StatusCode; Body = '' }
  } catch {
    $webResponse = $_.Exception.Response
    if ($null -eq $webResponse) { return [pscustomobject]@{ Status = 0; Body = '' } }
    return [pscustomobject]@{ Status = [int]$webResponse.StatusCode; Body = '' }
  }
}

$supabaseUrl = $env:SUPABASE_URL
$anonKey = $env:SUPABASE_ANON_KEY
$email = $env:GOAT_DELETE_TEST_EMAIL
$password = $env:GOAT_DELETE_TEST_PASSWORD

try {
  $configOk = -not [string]::IsNullOrWhiteSpace($supabaseUrl) -and
    -not [string]::IsNullOrWhiteSpace($anonKey) -and
    -not [string]::IsNullOrWhiteSpace($email) -and
    -not [string]::IsNullOrWhiteSpace($password)
  Add-Result 'required environment variables' $configOk
  $nameOk = $configOk -and $email -match '(?i)delete-test'
  Add-Result 'dedicated delete-test account naming rule' $nameOk
  if ($nameOk) {
    $confirmation = Read-Host 'Type DELETE MY ACCOUNT to continue'
    $phraseOk = $confirmation -ceq 'DELETE MY ACCOUNT'
    Add-Result 'explicit confirmation phrase' $phraseOk
  } else {
    $phraseOk = $false
  }

  if ($phraseOk) {
    $supabaseUrl = $supabaseUrl.TrimEnd('/')
  $authHeaders = @{ apikey = $anonKey }
  $functionUrl = "$supabaseUrl/functions/v1/delete-account"
  $loginBody = @{ email = $email; password = $password } | ConvertTo-Json -Compress
  try {
    $login = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers $authHeaders -ContentType 'application/json' -Body $loginBody
    $accessToken = [string]$login.access_token
  } catch { $accessToken = $null }
  $loginOk = -not [string]::IsNullOrWhiteSpace($accessToken)
  Add-Result 'dedicated test account login' $loginOk

  if ($loginOk) {
    $functionHeaders = @{ apikey = $anonKey; Authorization = "Bearer $accessToken" }
    $body = @{ confirmPhrase = 'DELETE MY ACCOUNT' } | ConvertTo-Json -Compress
    $deleted = Invoke-Http -Uri $functionUrl -Method 'POST' -Headers $functionHeaders -Body $body
    $deleteOk = $deleted.Status -eq 204
    Add-Result 'delete-account returns HTTP 204' $deleteOk

    if ($deleteOk) {
      $accessToken = $null
      try {
        $secondLogin = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers $authHeaders -ContentType 'application/json' -Body $loginBody
        $secondToken = [string]$secondLogin.access_token
      } catch { $secondToken = $null }
      Add-Result 'deleted account can no longer log in' ([string]::IsNullOrWhiteSpace($secondToken))
      $secondToken = $null
    } else { Add-Result 'deleted account can no longer log in' $false }
    } else {
      Add-Result 'delete-account returns HTTP 204' $false
      Add-Result 'deleted account can no longer log in' $false
    }
  }
} finally {
  $accessToken = $null
  $password = $null
  $confirmation = $null
}

$passed = @($results | Where-Object { $_.Passed }).Count
$failed = @($results | Where-Object { -not $_.Passed }).Count
Write-Output "SUMMARY PASS=$passed FAIL=$failed"
if ($failed -gt 0) { exit 1 }
exit 0
