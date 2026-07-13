$ErrorActionPreference = 'SilentlyContinue'

$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
  param(
    [string]$Name,
    [bool]$Passed
  )
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
    $request = @{
      Uri = $Uri
      Method = $Method
      Headers = $Headers
      UseBasicParsing = $true
    }
    if ($null -ne $Body) {
      $request.Body = $Body
      $request.ContentType = 'application/json'
    }
    $response = Invoke-WebRequest @request
    return [pscustomobject]@{ Status = [int]$response.StatusCode; Body = [string]$response.Content }
  } catch {
    $webResponse = $_.Exception.Response
    if ($null -eq $webResponse) { return [pscustomobject]@{ Status = 0; Body = '' } }
    $body = ''
    try {
      $reader = New-Object System.IO.StreamReader($webResponse.GetResponseStream())
      $body = $reader.ReadToEnd()
      $reader.Dispose()
    } catch { $body = '' }
    return [pscustomobject]@{ Status = [int]$webResponse.StatusCode; Body = $body }
  }
}

function Get-JsonObject {
  param([string]$Body)
  try { return $Body | ConvertFrom-Json } catch { return $null }
}

$supabaseUrl = $env:SUPABASE_URL
$anonKey = $env:SUPABASE_ANON_KEY
$email = $env:GOAT_TEST_EMAIL
$password = $env:GOAT_TEST_PASSWORD

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or
    [string]::IsNullOrWhiteSpace($anonKey) -or
    [string]::IsNullOrWhiteSpace($email) -or
    [string]::IsNullOrWhiteSpace($password)) {
  Write-Output 'FAIL configuration: required environment variables are missing'
  exit 1
}

$supabaseUrl = $supabaseUrl.TrimEnd('/')
$functionUrl = "$supabaseUrl/functions/v1/nutrition-ai"
$authHeaders = @{ apikey = $anonKey }
$functionHeaders = @{ apikey = $anonKey }

$anonymous = Invoke-Http -Uri $functionUrl -Method 'POST' -Headers $functionHeaders -Body '{}'
Add-Result 'anonymous request returns 401' ($anonymous.Status -eq 401)

$accessToken = $null
$loginBody = @{ email = $email; password = $password } | ConvertTo-Json -Compress
try {
  $login = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers $authHeaders -ContentType 'application/json' -Body $loginBody
  $accessToken = [string]$login.access_token
} catch { $accessToken = $null }

$loginOk = -not [string]::IsNullOrWhiteSpace($accessToken)
Add-Result 'test account login' $loginOk

if ($loginOk) {
  $functionHeaders.Authorization = "Bearer $accessToken"
  $clientRequestId = [guid]::NewGuid().ToString()
  $breakfast = [string]::Concat([char]0x65E9, [char]0x9910)
  $rice = [string]::Concat([char]0x4E00, [char]0x7897, [char]0x7C73, [char]0x996D)
  $normalBody = @{ text = $rice; defaultMealType = $breakfast; clientRequestId = $clientRequestId } | ConvertTo-Json -Compress

  $normal = Invoke-Http -Uri $functionUrl -Method 'POST' -Headers $functionHeaders -Body $normalBody
  $normalJson = Get-JsonObject $normal.Body
  $normalOk = $normal.Status -eq 200 -and $null -ne $normalJson -and $null -ne $normalJson.items
  Add-Result 'one normal AI request' $normalOk

  if ($normalOk) {
    $duplicate = Invoke-Http -Uri $functionUrl -Method 'POST' -Headers $functionHeaders -Body $normalBody
    $duplicateJson = Get-JsonObject $duplicate.Body
    $normalComparable = $normalJson | ConvertTo-Json -Compress -Depth 20
    $duplicateComparable = $duplicateJson | ConvertTo-Json -Compress -Depth 20
    Add-Result 'duplicate clientRequestId returns the same result' ($duplicate.Status -eq 200 -and $normalComparable -eq $duplicateComparable)
  } else { Add-Result 'duplicate clientRequestId returns the same result' $false }

  $invalidJson = Invoke-Http -Uri $functionUrl -Method 'POST' -Headers $functionHeaders -Body '{not-json'
  Add-Result 'invalid request JSON returns 400' ($invalidJson.Status -eq 400)

  $emptyBody = @{ text = ''; defaultMealType = $breakfast; clientRequestId = ([guid]::NewGuid().ToString()) } | ConvertTo-Json -Compress
  $emptyText = Invoke-Http -Uri $functionUrl -Method 'POST' -Headers $functionHeaders -Body $emptyBody
  Add-Result 'empty text returns 400' ($emptyText.Status -eq 400)

  $options = Invoke-Http -Uri $functionUrl -Method 'OPTIONS' -Headers $functionHeaders
  Add-Result 'CORS OPTIONS returns empty 204' ($options.Status -eq 204 -and [string]::IsNullOrEmpty($options.Body))
} else {
  Add-Result 'one normal AI request' $false
  Add-Result 'duplicate clientRequestId returns the same result' $false
  Add-Result 'invalid request JSON returns 400' $false
  Add-Result 'empty text returns 400' $false
  Add-Result 'CORS OPTIONS returns empty 204' $false
}

$passed = @($results | Where-Object { $_.Passed }).Count
$failed = @($results | Where-Object { -not $_.Passed }).Count
Write-Output "SUMMARY PASS=$passed FAIL=$failed"

$accessToken = $null
$password = $null
if ($failed -gt 0) { exit 1 }
exit 0
