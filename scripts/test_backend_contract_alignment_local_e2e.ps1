[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$resultPath = Join-Path $repoRoot 'artifacts\backend_contract_alignment\results\phase5_9_local_jwt_e2e.log'
$results = [System.Collections.Generic.List[string]]::new()
$createdUsers = [System.Collections.Generic.List[string]]::new()

function Add-Check {
  param([string]$Name, [bool]$Passed)
  $status = if ($Passed) { 'PASS' } else { 'FAIL' }
  [void]$script:results.Add("$status`t$Name")
  Write-Host "$status - $Name"
  if (-not $Passed) {
    throw "Local E2E check failed: $Name"
  }
}

function Invoke-SafeHttp {
  param(
    [Parameter(Mandatory)][string]$Uri,
    [Parameter(Mandatory)][string]$Method,
    [hashtable]$Headers = @{},
    [string]$Body,
    [string]$ContentType = 'application/json'
  )
  try {
    $arguments = @{
      Uri = $Uri
      Method = $Method
      Headers = $Headers
      UseBasicParsing = $true
    }
    if ($PSBoundParameters.ContainsKey('Body')) {
      $arguments.Body = $Body
      $arguments.ContentType = $ContentType
    }
    $response = Invoke-WebRequest @arguments
    return [pscustomobject]@{
      Status = [int]$response.StatusCode
      Body = [string]$response.Content
      Headers = $response.Headers
    }
  } catch {
    $status = 0
    $bodyText = ''
    if ($_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
      try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
          $reader = [System.IO.StreamReader]::new($stream)
          $bodyText = $reader.ReadToEnd()
          $reader.Dispose()
        }
      } catch {
        $bodyText = ''
      }
    }
    return [pscustomobject]@{
      Status = $status
      Body = $bodyText
      Headers = @{}
    }
  }
}

function Convert-StatusEnv {
  if (-not [string]::IsNullOrWhiteSpace($env:GOAT_REMOTE_API_URL)) {
    return @{
      API_URL = $env:GOAT_REMOTE_API_URL
      ANON_KEY = $env:GOAT_REMOTE_ANON_KEY
      SERVICE_ROLE_KEY = $env:GOAT_REMOTE_SERVICE_ROLE_KEY
    }
  }
  $values = @{}
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $lines = & supabase status -o env 2>$null
  $ErrorActionPreference = $previousPreference
  if ($LASTEXITCODE -ne 0) {
    throw 'Local Supabase status is unavailable.'
  }
  foreach ($line in $lines) {
    if ($line -match '^([A-Z0-9_]+)=(.*)$') {
      $value = $Matches[2].Trim()
      if ($value.Length -ge 2 -and $value[0] -eq '"' -and $value[$value.Length - 1] -eq '"') {
        $value = $value.Substring(1, $value.Length - 2)
      }
      $values[$Matches[1]] = $value
    }
  }
  return $values
}

function New-TestUser {
  param(
    [Parameter(Mandatory)][string]$Email,
    [Parameter(Mandatory)][string]$Password
  )
  $body = @{
    email = $Email
    password = $Password
    email_confirm = $true
  } | ConvertTo-Json -Compress
  $created = Invoke-SafeHttp `
    -Uri "$script:apiUrl/auth/v1/admin/users" `
    -Method 'POST' `
    -Headers $script:adminHeaders `
    -Body $body
  Add-Check "create isolated local test account" ($created.Status -in @(200, 201))
  $user = $created.Body | ConvertFrom-Json
  [void]$script:createdUsers.Add([string]$user.id)
  return [string]$user.id
}

function Get-UserToken {
  param(
    [Parameter(Mandatory)][string]$Email,
    [Parameter(Mandatory)][string]$Password
  )
  $body = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
  $response = Invoke-SafeHttp `
    -Uri "$script:apiUrl/auth/v1/token?grant_type=password" `
    -Method 'POST' `
    -Headers @{ apikey = $script:anonKey } `
    -Body $body
  if ($response.Status -ne 200) {
    throw 'Local test account login failed.'
  }
  return [string](($response.Body | ConvertFrom-Json).access_token)
}

function Get-UserHeaders {
  param([Parameter(Mandatory)][string]$Token)
  return @{
    apikey = $script:anonKey
    Authorization = "Bearer $Token"
    Prefer = 'return=representation'
  }
}

function Get-JwtSubject {
  param([Parameter(Mandatory)][string]$Token)
  $parts = $Token.Split('.')
  if ($parts.Count -lt 2) { throw 'Invalid local JWT structure.' }
  $payload = $parts[1].Replace('-', '+').Replace('_', '/')
  switch ($payload.Length % 4) {
    2 { $payload += '==' }
    3 { $payload += '=' }
  }
  $json = [System.Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($payload)
  )
  return [string](($json | ConvertFrom-Json).sub)
}

function Invoke-Rest {
  param(
    [Parameter(Mandatory)][string]$TableAndQuery,
    [Parameter(Mandatory)][string]$Method,
    [Parameter(Mandatory)][hashtable]$Headers,
    [object]$Payload
  )
  $arguments = @{
    Uri = "$script:apiUrl/rest/v1/$TableAndQuery"
    Method = $Method
    Headers = $Headers
  }
  if ($PSBoundParameters.ContainsKey('Payload')) {
    $arguments.Body = $Payload | ConvertTo-Json -Depth 20 -Compress
  }
  return Invoke-SafeHttp @arguments
}

function Remove-TestUser {
  param([string]$UserId)
  if (-not $UserId) { return }
  [void](Invoke-SafeHttp `
    -Uri "$script:apiUrl/auth/v1/admin/users/$UserId" `
    -Method 'DELETE' `
    -Headers $script:adminHeaders)
}

Push-Location $repoRoot
try {
  $environment = Convert-StatusEnv
  $apiUrl = [string]$environment['API_URL']
  $anonKey = [string]$environment['ANON_KEY']
  $serviceKey = [string]$environment['SERVICE_ROLE_KEY']
  if (-not $apiUrl -or -not $anonKey -or -not $serviceKey) {
    throw 'Required local Supabase environment values are missing.'
  }
  $adminHeaders = @{
    apikey = $serviceKey
    Authorization = "Bearer $serviceKey"
    Prefer = 'return=representation'
  }

  $suffix = [Guid]::NewGuid().ToString('N')
  $password1 = "Local-Aa9!-$([Guid]::NewGuid().ToString('N'))"
  $password2 = "Local-Bb8!-$([Guid]::NewGuid().ToString('N'))"
  $passwordDelete = "Local-Cc7!-$([Guid]::NewGuid().ToString('N'))"
  $email1 = "contract-test-${suffix}-user1@example.test"
  $email2 = "contract-test-${suffix}-user2@example.test"
  $emailDelete = "contract-delete-test-${suffix}@example.test"

  $user1 = New-TestUser -Email $email1 -Password $password1
  $user2 = New-TestUser -Email $email2 -Password $password2
  $deleteUser = New-TestUser -Email $emailDelete -Password $passwordDelete
  $token1 = Get-UserToken -Email $email1 -Password $password1
  $token2 = Get-UserToken -Email $email2 -Password $password2
  $deleteToken = Get-UserToken -Email $emailDelete -Password $passwordDelete
  $subject1 = Get-JwtSubject -Token $token1
  $subject2 = Get-JwtSubject -Token $token2
  $deleteSubject = Get-JwtSubject -Token $deleteToken
  Add-Check 'JWT subjects match their isolated local accounts' (
    $subject1 -eq $user1 -and
    $subject2 -eq $user2 -and
    $deleteSubject -eq $deleteUser
  )
  Add-Check 'test users have distinct JWT subjects' (
    $subject1 -ne $subject2 -and
    $subject1 -ne $deleteSubject -and
    $subject2 -ne $deleteSubject
  )
  $headers1 = Get-UserHeaders -Token $token1
  $headers2 = Get-UserHeaders -Token $token2
  $deleteHeaders = Get-UserHeaders -Token $deleteToken

  $templateId = "template-$suffix"
  $suggestionId = "suggestion-$suffix"
  $feedbackId = [Guid]::NewGuid().ToString()
  $operationId = "operation-$suffix"
  $sessionId = "session-$suffix"

  $profile = Invoke-Rest -TableAndQuery 'user_profiles' -Method 'POST' -Headers $headers1 -Payload @{
    id = $user1
    gender = 'male'
    birth_year = 2000
    birth_month = 1
    birth_day = 2
    height = 178
    current_weight = 72
    target_kcal = 2200
    target_p = 160
    target_c = 240
    target_f = 65
    training_data = @()
    client_operation_id = "profile-$suffix"
  }
  Add-Check 'user can create own profile through JWT RLS' ($profile.Status -eq 201)

  $template = Invoke-Rest -TableAndQuery 'training_templates' -Method 'POST' -Headers $headers1 -Payload @{
    user_id = $user1
    id = $templateId
    name = 'Contract E2E Template'
    exercise_ids = @('bench', 'row')
    progression_targets = [ordered]@{ bench = @{ load = 82.5; reps = 6 }; optional = $null }
    rest_prescriptions = [ordered]@{ bench = 120; row = 90 }
    superset_groups = [ordered]@{ order = @(@('bench', 'row')) }
    client_operation_id = "template-op-$suffix"
  }
  Add-Check 'user can create own training template' ($template.Status -eq 201)

  $memory = Invoke-Rest -TableAndQuery 'ai_memories' -Method 'POST' -Headers $headers1 -Payload @{
    user_id = $user1
    id = "memory-$suffix"
    stable_key = "goal-$suffix"
    category = 'goal'
    value = 'Improve strength'
    structured_value = @{ target = 'strength'; optional = $null }
    source_type = 'userProvided'
    status = 'active'
    source_refs = @()
    confidence_level = 'high'
    user_confirmed = $true
    client_operation_id = "memory-op-$suffix"
  }
  Add-Check 'user can create own AI memory' ($memory.Status -eq 201)

  $suggestion = Invoke-Rest -TableAndQuery 'ai_suggestions' -Method 'POST' -Headers $headers1 -Payload @{
    user_id = $user1
    id = $suggestionId
    type = 'training'
    title = 'Progress carefully'
    summary = 'Evidence-bound local suggestion'
    reason_codes = @('recent_training')
    evidence_refs = @("session:$sessionId")
    knowledge_refs = @('local:test')
    proposed_action = [ordered]@{ kind = 'adjustRest'; seconds = 120; optional = $null }
    data_quality = 'high'
    status = 'proposed'
    client_operation_id = "suggestion-op-$suffix"
  }
  Add-Check 'user can create own AI suggestion' ($suggestion.Status -eq 201)

  $feedback = Invoke-Rest -TableAndQuery 'ai_suggestion_feedback' -Method 'POST' -Headers $headers1 -Payload @{
    user_id = $user1
    id = $feedbackId
    suggestion_id = $suggestionId
    decision = 'accepted'
    modified_action = @{ seconds = 105 }
    feedback_type = 'helpful'
    client_operation_id = "feedback-op-$suffix"
  }
  Add-Check 'user can create own AI feedback' ($feedback.Status -eq 201)

  $session = Invoke-Rest -TableAndQuery 'training_sessions' -Method 'POST' -Headers $headers1 -Payload @{
    user_id = $user1
    id = $sessionId
    name = 'Complex JSON E2E'
    date = (Get-Date).ToString('yyyy-MM-dd')
    exercises = @(
      [ordered]@{
        id = 'bench'
        sets = @(
          [ordered]@{ weight = '82.5'; reps = '6'; completed = $true; rpe = 8; optional = $null },
          [ordered]@{ weight = 'bad-history'; reps = ''; completed = $false }
        )
        superset = [ordered]@{ group = 'A'; order = 1 }
      }
    )
    client_operation_id = "session-op-$suffix"
  }
  Add-Check 'complex training JSON is persisted unchanged by RLS API' ($session.Status -eq 201)

  $operation = Invoke-Rest -TableAndQuery 'client_operations' -Method 'POST' -Headers $headers1 -Payload @{
    user_id = $user1
    operation_id = $operationId
    entity_type = 'training_template'
    entity_id = $templateId
    action = 'upsert'
    payload = @{ source = 'local-e2e' }
  }
  Add-Check 'user can create own idempotency operation' ($operation.Status -eq 201)
  $duplicate = Invoke-Rest -TableAndQuery 'client_operations' -Method 'POST' -Headers $headers1 -Payload @{
    user_id = $user1
    operation_id = $operationId
    entity_type = 'training_template'
    entity_id = $templateId
    action = 'upsert'
  }
  Add-Check 'same user duplicate operation is rejected' ($duplicate.Status -eq 409)
  $otherOperation = Invoke-Rest -TableAndQuery 'client_operations' -Method 'POST' -Headers $headers2 -Payload @{
    user_id = $user2
    operation_id = $operationId
    entity_type = 'training_template'
    entity_id = 'other'
    action = 'upsert'
  }
  Add-Check 'same operation id remains isolated per user' ($otherOperation.Status -eq 201)

  $ownRead = Invoke-Rest -TableAndQuery "training_templates?user_id=eq.$user1&id=eq.$templateId" -Method 'GET' -Headers $headers1
  Add-Check 'user reads own training template' ($ownRead.Status -eq 200 -and @($ownRead.Body | ConvertFrom-Json).Count -eq 1)
  $crossRead = Invoke-Rest -TableAndQuery "training_templates?user_id=eq.$user1&id=eq.$templateId" -Method 'GET' -Headers $headers2
  $crossReadIsEmpty = $crossRead.Body.Trim() -eq '[]'
  Add-Check "cross-user read returns no rows (HTTP $($crossRead.Status), empty JSON $crossReadIsEmpty)" (
    $crossRead.Status -eq 200 -and $crossReadIsEmpty
  )
  $crossUpdate = Invoke-Rest -TableAndQuery "training_templates?user_id=eq.$user1&id=eq.$templateId" -Method 'PATCH' -Headers $headers2 -Payload @{ name = 'forbidden' }
  Add-Check 'cross-user update changes no rows' ($crossUpdate.Status -eq 200 -and $crossUpdate.Body.Trim() -eq '[]')
  $spoof = Invoke-Rest -TableAndQuery 'ai_memories' -Method 'POST' -Headers $headers2 -Payload @{
    user_id = $user1
    id = "spoof-$suffix"
    category = 'goal'
    value = 'forbidden'
    structured_value = @{}
    source_type = 'userProvided'
    status = 'active'
    source_refs = @()
    user_confirmed = $true
  }
  Add-Check 'cross-user insert spoof is rejected' ($spoof.Status -in @(401, 403))
  $anonymous = Invoke-Rest -TableAndQuery 'training_templates?select=id' -Method 'GET' -Headers @{ apikey = $anonKey }
  Add-Check 'anonymous table access is denied' ($anonymous.Status -in @(401, 403))
  $serviceRead = Invoke-Rest -TableAndQuery "ai_suggestions?user_id=eq.$user1&id=eq.$suggestionId" -Method 'GET' -Headers $adminHeaders
  Add-Check 'service role can read user-owned contract data' ($serviceRead.Status -eq 200 -and @($serviceRead.Body | ConvertFrom-Json).Count -eq 1)

  $exportNoAuth = Invoke-SafeHttp -Uri "$apiUrl/functions/v1/export-user-data" -Method 'POST' -Headers @{ apikey = $anonKey } -Body '{}'
  Add-Check 'export rejects missing JWT' ($exportNoAuth.Status -eq 401)
  $export = Invoke-SafeHttp `
    -Uri "$apiUrl/functions/v1/export-user-data" `
    -Method 'POST' `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $token1" } `
    -Body '{}'
  Add-Check 'authenticated export succeeds' ($export.Status -eq 200)
  $exportData = $export.Body | ConvertFrom-Json
  Add-Check 'export contains current user contract entities' (
    @($exportData.trainingTemplates).Count -eq 1 -and
    @($exportData.aiMemories).Count -eq 1 -and
    @($exportData.aiSuggestions).Count -eq 1 -and
    @($exportData.aiFeedback).Count -eq 1 -and
    @($exportData.trainingSessions).Count -eq 1
  )
  Add-Check 'export preserves ordered arrays and optional JSON values' (
    $exportData.trainingTemplates[0].exercise_ids[0] -eq 'bench' -and
    $null -eq $exportData.trainingTemplates[0].progression_targets.optional -and
    $exportData.trainingSessions[0].exercises[0].sets[0].weight -eq '82.5'
  )
  $forbiddenPattern = '(?i)(access[_-]?token|refresh[_-]?token|service[_-]?role|claim[_-]?token|client_operation_id|secret|api[_-]?key|version)'
  Add-Check 'export omits tokens, keys and internal sync fields' ($export.Body -notmatch $forbiddenPattern)
  Add-Check 'export is marked no-store' ([string]$export.Headers['Cache-Control'] -match 'no-store')
  Add-Check 'export excludes the other test user' ($export.Body -notmatch [regex]::Escape($user2))

  $coachInvalid = Invoke-SafeHttp `
    -Uri "$apiUrl/functions/v1/coach-ai" `
    -Method 'POST' `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $token1" } `
    -Body (@{ requestId = "invalid-$suffix"; taskType = 'unsupported_task' } | ConvertTo-Json -Compress)
  Add-Check 'authenticated coach-ai rejects unsupported task without provider call' ($coachInvalid.Status -eq 400)
  $nutritionInvalid = Invoke-SafeHttp `
    -Uri "$apiUrl/functions/v1/nutrition-ai" `
    -Method 'POST' `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $token1" } `
    -Body '{not-json'
  Add-Check 'authenticated nutrition-ai rejects malformed JSON without provider call' ($nutritionInvalid.Status -eq 400)
  $nutritionOptions = Invoke-SafeHttp `
    -Uri "$apiUrl/functions/v1/nutrition-ai" `
    -Method 'OPTIONS' `
    -Headers @{ apikey = $anonKey }
  Add-Check 'nutrition-ai OPTIONS returns 204' ($nutritionOptions.Status -eq 204)

  $nutritionRequestId = "nutrition-$suffix"
  $nutritionValid = Invoke-SafeHttp `
    -Uri "$apiUrl/functions/v1/nutrition-ai" `
    -Method 'POST' `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $token1" } `
    -Body (@{
      text = 'rice and eggs'
      defaultMealType = 'breakfast'
      clientRequestId = $nutritionRequestId
    } | ConvertTo-Json -Compress)
  $nutritionJson = $null
  if ($nutritionValid.Status -eq 200) {
    try { $nutritionJson = $nutritionValid.Body | ConvertFrom-Json } catch { $nutritionJson = $null }
  }
  Add-Check 'nutrition-ai valid request returns a structured result' (
    $nutritionValid.Status -eq 200 -and $null -ne $nutritionJson -and
    $null -ne $nutritionJson.items
  )
  $nutritionDuplicate = Invoke-SafeHttp `
    -Uri "$apiUrl/functions/v1/nutrition-ai" `
    -Method 'POST' `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $token1" } `
    -Body (@{
      text = 'rice and eggs'
      defaultMealType = 'breakfast'
      clientRequestId = $nutritionRequestId
    } | ConvertTo-Json -Compress)
  Add-Check 'nutrition-ai duplicate request returns the same result' (
    $nutritionDuplicate.Status -eq 200 -and
    $nutritionDuplicate.Body -eq $nutritionValid.Body
  )
  $coachValid = Invoke-SafeHttp `
    -Uri "$apiUrl/functions/v1/coach-ai" `
    -Method 'POST' `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $token1" } `
    -Body (@{
      requestId = "coach-$suffix"
      taskType = 'nutrition_explanation'
      structuredContext = [ordered]@{ deterministic = @{ kcal = 520; protein = 30 } }
      activeProfile = [ordered]@{ goal = 'strength' }
      activeMemories = @([ordered]@{ category = 'goal'; value = 'strength' })
      evidenceRefs = @('daily_tracking:test')
      knowledgeRefs = @('local:contract')
    } | ConvertTo-Json -Depth 20 -Compress)
  $coachJson = $null
  if ($coachValid.Status -eq 200) {
    try { $coachJson = $coachValid.Body | ConvertFrom-Json } catch { $coachJson = $null }
  }
  Add-Check 'coach-ai valid task returns a structured result' (
    $coachValid.Status -eq 200 -and $null -ne $coachJson -and
    $null -ne $coachJson.answer -and $null -ne $coachJson.evidenceRefs
  )

  $deleteTemplate = Invoke-Rest -TableAndQuery 'training_templates' -Method 'POST' -Headers $deleteHeaders -Payload @{
    user_id = $deleteUser
    id = "delete-template-$suffix"
    name = 'Delete cascade fixture'
    exercise_ids = @()
    progression_targets = @{}
    rest_prescriptions = @{}
    superset_groups = @{}
  }
  Add-Check 'delete test account fixture is created' ($deleteTemplate.Status -eq 201)
  $wrongPhrase = Invoke-SafeHttp `
    -Uri "$apiUrl/functions/v1/delete-account" `
    -Method 'POST' `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $deleteToken" } `
    -Body (@{ confirmPhrase = 'NO' } | ConvertTo-Json -Compress)
  Add-Check 'delete rejects incorrect confirmation phrase' ($wrongPhrase.Status -eq 400)
  $wrongContent = Invoke-SafeHttp `
    -Uri "$apiUrl/functions/v1/delete-account" `
    -Method 'POST' `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $deleteToken" } `
    -Body '{}' `
    -ContentType 'text/plain'
  Add-Check 'delete rejects non-JSON content type' ($wrongContent.Status -eq 415)
  $deleted = Invoke-SafeHttp `
    -Uri "$apiUrl/functions/v1/delete-account" `
    -Method 'POST' `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $deleteToken" } `
    -Body (@{ confirmPhrase = 'DELETE MY ACCOUNT' } | ConvertTo-Json -Compress)
  Add-Check 'delete-account removes dedicated local test account' ($deleted.Status -eq 204)
  $createdUsers.Remove($deleteUser) | Out-Null
  $deletedLogin = Invoke-SafeHttp `
    -Uri "$apiUrl/auth/v1/token?grant_type=password" `
    -Method 'POST' `
    -Headers @{ apikey = $anonKey } `
    -Body (@{ email = $emailDelete; password = $passwordDelete } | ConvertTo-Json -Compress)
  Add-Check 'deleted account cannot log in' ($deletedLogin.Status -in @(400, 401))
  $oldToken = Invoke-SafeHttp `
    -Uri "$apiUrl/functions/v1/delete-account" `
    -Method 'POST' `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $deleteToken" } `
    -Body (@{ confirmPhrase = 'DELETE MY ACCOUNT' } | ConvertTo-Json -Compress)
  Add-Check 'deleted account old JWT cannot delete again' ($oldToken.Status -eq 401)
  $cascade = Invoke-Rest -TableAndQuery "training_templates?user_id=eq.$deleteUser" -Method 'GET' -Headers $adminHeaders
  Add-Check 'new contract rows cascade after account deletion' ($cascade.Status -eq 200 -and $cascade.Body.Trim() -eq '[]')
  [void](Get-UserToken -Email $email1 -Password $password1)
  [void](Get-UserToken -Email $email2 -Password $password2)
  Add-Check 'unrelated users remain valid after deletion' $true

  foreach ($functionName in @('coach-ai', 'nutrition-ai')) {
    $unauthorized = Invoke-SafeHttp `
      -Uri "$apiUrl/functions/v1/$functionName" `
      -Method 'POST' `
      -Headers @{ apikey = $anonKey } `
      -Body '{}'
    Add-Check "$functionName rejects missing JWT at the local gateway" ($unauthorized.Status -eq 401)
  }
} finally {
  foreach ($createdUser in @($createdUsers)) {
    Remove-TestUser -UserId $createdUser
  }
  $resultDirectory = Split-Path -Parent $resultPath
  New-Item -ItemType Directory -Force $resultDirectory | Out-Null
  [System.IO.File]::WriteAllLines(
    $resultPath,
    @(
      "GOATapp Backend Contract Alignment local JWT E2E"
      "CompletedAt=$([DateTimeOffset]::Now.ToString('o'))"
      "ResultCount=$($results.Count)"
    ) + $results,
    [System.Text.UTF8Encoding]::new($false)
  )
  Pop-Location
}

Write-Host "Local JWT E2E completed: $($results.Count) checks passed."
