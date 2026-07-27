[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$results = [System.Collections.Generic.List[object]]::new()
$accessToken = $null
$userId = $null
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

function Find-ById {
  param([object[]]$Rows, [string]$Id)
  return @($Rows | Where-Object { [string]$_.id -eq $Id } | Select-Object -First 1)[0]
}

function Upsert-TestRow {
  param(
    [string]$Table,
    [string]$ConflictColumns,
    [hashtable]$Headers,
    [object]$Row
  )
  $encodedConflict = [uri]::EscapeDataString($ConflictColumns)
  $body = @($Row) | ConvertTo-Json -Depth 20 -Compress
  $response = Invoke-Http `
    -Uri "$supabaseUrl/rest/v1/$Table`?on_conflict=$encodedConflict" `
    -Method 'POST' `
    -Headers ($Headers + @{ Prefer = 'resolution=merge-duplicates,return=minimal' }) `
    -Body $body
  return $response.Status -in @(200, 201, 204)
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
    $dedicatedAccount = $email -match '(?i)test'
    Add-Result 'dedicated test account naming' $dedicatedAccount
    if ($dedicatedAccount) {
      $authHeaders = @{ apikey = $anonKey }
      $functionUrl = "$supabaseUrl/functions/v1/export-user-data"
      $requestBody = '{}'

      $anonymous = Invoke-Http -Uri $functionUrl -Method 'POST' -Headers $authHeaders -Body $requestBody
      Add-Result 'anonymous request returns 401' ($anonymous.Status -eq 401)

      $loginBody = @{ email = $email; password = $password } | ConvertTo-Json -Compress
      try {
        $login = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers $authHeaders -ContentType 'application/json' -Body $loginBody
        $accessToken = [string]$login.access_token
        $userId = [string]$login.user.id
      } catch {
        $accessToken = $null
        $userId = $null
      }
      $loginOk = -not [string]::IsNullOrWhiteSpace($accessToken) -and
        -not [string]::IsNullOrWhiteSpace($userId)
      Add-Result 'test account login' $loginOk

      if ($loginOk) {
        $functionHeaders = @{ apikey = $anonKey; Authorization = "Bearer $accessToken" }
        $rowPrefix = "contract-export-$userId"
        $sessionId = "$rowPrefix-session"
        $templateId = "$rowPrefix-template"
        $memoryId = "$rowPrefix-memory"
        $suggestionId = "$rowPrefix-suggestion"
        $feedbackId = '7c9b84f0-7e76-4e2c-9794-b97da75ae5ad'

        $seedChecks = @(
          Upsert-TestRow -Table 'training_sessions' -ConflictColumns 'id' -Headers $functionHeaders -Row @{
            id = $sessionId
            user_id = $userId
            name = 'Contract export session'
            date = '2026-07-25'
            exercises = @(
              @{
                exerciseId = 'bench-press'
                exerciseName = 'Bench Press'
                bodyPart = 'chest'
                orderIndex = 0
                supersetGroupId = 'group-a'
                unknownOptional = @{ preserved = $true }
                sets = @(
                  @{
                    id = 'set-1'
                    weight = 80
                    reps = 8
                    type = 'working'
                    restPolicyVersion = 2
                    replacementPlaceholder = $false
                  }
                )
              }
            )
            client_operation_id = "$rowPrefix-session-op"
          }
          Upsert-TestRow -Table 'training_templates' -ConflictColumns 'user_id,id' -Headers $functionHeaders -Row @{
            user_id = $userId
            id = $templateId
            name = 'Contract export template'
            exercise_ids = @('bench-press', 'barbell-row')
            progression_targets = @{
              'bench-press' = @{ targetSets = 3; targetRepMin = 6; targetRepMax = 10; weightStepKg = 2.5 }
            }
            rest_prescriptions = @{
              'bench-press' = @{ mode = 'fixed'; fixedSeconds = 120 }
            }
            superset_groups = @{ 'group-a' = @('bench-press', 'barbell-row') }
            client_operation_id = "$rowPrefix-template-op"
          }
          Upsert-TestRow -Table 'ai_memories' -ConflictColumns 'user_id,id' -Headers $functionHeaders -Row @{
            user_id = $userId
            id = $memoryId
            stable_key = 'preference.training_goal'
            category = 'trainingGoal'
            value = 'Strength'
            structured_value = @{ goal = 'strength'; unknownOptional = 'preserved' }
            source_type = 'userProvided'
            status = 'active'
            source_refs = @('profile')
            confidence_level = 'high'
            user_confirmed = $true
            client_operation_id = "$rowPrefix-memory-op"
          }
          Upsert-TestRow -Table 'ai_suggestions' -ConflictColumns 'user_id,id' -Headers $functionHeaders -Row @{
            user_id = $userId
            id = $suggestionId
            type = 'restAdjustment'
            title = 'Contract export suggestion'
            summary = 'Use a longer rest interval.'
            reason_codes = @('recentPerformance')
            evidence_refs = @('training-session')
            knowledge_refs = @('rest-guideline')
            proposed_action = @{ kind = 'updateRest'; seconds = 150; unknownOptional = $true }
            data_quality = 'high'
            status = 'proposed'
            client_operation_id = "$rowPrefix-suggestion-op"
          }
          Upsert-TestRow -Table 'ai_suggestion_feedback' -ConflictColumns 'user_id,id' -Headers $functionHeaders -Row @{
            user_id = $userId
            id = $feedbackId
            suggestion_id = $suggestionId
            decision = 'accepted'
            modified_action = @{ kind = 'updateRest'; seconds = 150 }
            feedback_type = 'helpful'
            client_operation_id = "$rowPrefix-feedback-op"
          }
        )
        Add-Result 'contract export fixtures upsert through user RLS' (-not ($seedChecks -contains $false))

        $response = Invoke-Http -Uri $functionUrl -Method 'POST' -Headers $functionHeaders -Body $requestBody
        Add-Result 'authenticated export returns HTTP 200' ($response.Status -eq 200)

        if ($response.Status -eq 200) {
          $tempPath = Join-Path ([IO.Path]::GetTempPath()) "goat-export-$([guid]::NewGuid()).json"
          [IO.File]::WriteAllText($tempPath, $response.Body, [Text.UTF8Encoding]::new($false))
          $raw = [IO.File]::ReadAllText($tempPath, [Text.Encoding]::UTF8)
          try { $export = $raw | ConvertFrom-Json } catch { $export = $null }
          Add-Result 'export body is valid JSON' ($null -ne $export)

          $requiredFields = @(
            'exportedAt',
            'profile',
            'foodDictionary',
            'dietLogs',
            'exerciseLogs',
            'dailyTracking',
            'waterRecords',
            'weightLogs',
            'trainingSessions',
            'trainingTemplates',
            'aiProfile',
            'aiMemories',
            'aiSuggestions',
            'aiFeedback',
            'chatHistory',
            'settings'
          )
          $fieldsOk = $true
          foreach ($field in $requiredFields) { if (-not (Has-Property $export $field)) { $fieldsOk = $false } }
          Add-Result 'export field allow-list is complete' $fieldsOk
          Add-Result 'export excludes sensitive and internal fields' (-not ($raw -match '(?i)access_token|refresh_token|service_role|claim_token|client_operation_id|DEEPSEEK_API_KEY'))

          $session = Find-ById -Rows @($export.trainingSessions) -Id $sessionId
          $template = Find-ById -Rows @($export.trainingTemplates) -Id $templateId
          $memory = Find-ById -Rows @($export.aiMemories) -Id $memoryId
          $profileMemory = Find-ById -Rows @($export.aiProfile) -Id $memoryId
          $suggestion = Find-ById -Rows @($export.aiSuggestions) -Id $suggestionId
          $feedback = Find-ById -Rows @($export.aiFeedback) -Id $feedbackId

          Add-Result 'training session rich JSON round-trips' (
            $null -ne $session -and
            $session.exercises[0].unknownOptional.preserved -eq $true -and
            [int]$session.exercises[0].sets[0].restPolicyVersion -eq 2
          )
          Add-Result 'training template order and maps round-trip' (
            $null -ne $template -and
            [string]$template.exercise_ids[0] -eq 'bench-press' -and
            [string]$template.exercise_ids[1] -eq 'barbell-row' -and
            [int]$template.progression_targets.'bench-press'.targetSets -eq 3 -and
            [int]$template.rest_prescriptions.'bench-press'.fixedSeconds -eq 120
          )
          Add-Result 'AI memory and profile projection round-trip' (
            $null -ne $memory -and
            $null -ne $profileMemory -and
            [string]$memory.structured_value.goal -eq 'strength' -and
            [string]$profileMemory.source_type -eq 'userProvided'
          )
          Add-Result 'AI suggestion and feedback round-trip' (
            $null -ne $suggestion -and
            $null -ne $feedback -and
            [string]$suggestion.proposed_action.kind -eq 'updateRest' -and
            [string]$feedback.feedback_type -eq 'helpful'
          )
        } else {
          Add-Result 'export body is valid JSON' $false
          Add-Result 'export field allow-list is complete' $false
          Add-Result 'export excludes sensitive and internal fields' $false
          Add-Result 'training session rich JSON round-trips' $false
          Add-Result 'training template order and maps round-trip' $false
          Add-Result 'AI memory and profile projection round-trip' $false
          Add-Result 'AI suggestion and feedback round-trip' $false
        }
      } else {
        Add-Result 'contract export fixtures upsert through user RLS' $false
        Add-Result 'authenticated export returns HTTP 200' $false
        Add-Result 'export body is valid JSON' $false
        Add-Result 'export field allow-list is complete' $false
        Add-Result 'export excludes sensitive and internal fields' $false
        Add-Result 'training session rich JSON round-trips' $false
        Add-Result 'training template order and maps round-trip' $false
        Add-Result 'AI memory and profile projection round-trip' $false
        Add-Result 'AI suggestion and feedback round-trip' $false
      }
    } else {
      Add-Result 'anonymous request returns 401' $false
      Add-Result 'test account login' $false
    }
  }
} finally {
  if ($tempPath -and (Test-Path -LiteralPath $tempPath)) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
  $accessToken = $null
  $userId = $null
  $password = $null
}

$passed = @($results | Where-Object { $_.Passed }).Count
$failed = @($results | Where-Object { -not $_.Passed }).Count
Write-Output "SUMMARY PASS=$passed FAIL=$failed"
if ($failed -gt 0) { exit 1 }
exit 0
