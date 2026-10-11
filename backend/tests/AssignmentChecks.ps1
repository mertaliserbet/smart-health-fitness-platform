param([string] $FirstToken, [string] $SecondToken, [Guid] $FirstUserId, [Guid] $SecondUserId)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AssignmentFixture.ps1')
$fixturePassword = [Guid]::NewGuid().ToString('N') + '!Aa1'
$advisorIds = @{}
$advisorTokens = @{}
foreach ($role in @('Trainer', 'Dietitian', 'Admin')) {
    $email = [Guid]::NewGuid().ToString('N') + '@example.test'
    $registeredAdvisor = Invoke-Api 'POST' '/api/auth/register' @{
        firstName = if ($role -eq 'Trainer') { 'Çağrı' } else { 'İrem' }
        lastName = 'Şerbet'; email = $email; password = $fixturePassword
    }
    Assert-Check ($registeredAdvisor.Status -eq 201) 'Advisor test registration failed.'
    $advisorId = ([Guid]::Parse($registeredAdvisor.Body.id)).ToString()
    [void] (Invoke-CheckSql "DELETE FROM user_roles WHERE user_id = '$advisorId'; INSERT INTO user_roles (id, user_id, role_id) SELECT gen_random_uuid(), '$advisorId'::uuid, id FROM roles WHERE name = '$role';")
    $advisorLogin = Invoke-Api 'POST' '/api/auth/login' @{ email = $email; password = $fixturePassword }
    Assert-Check ($advisorLogin.Status -eq 200) 'Advisor fixture login failed.'
    $advisorIds[$role] = $advisorId
    $advisorTokens[$role] = $advisorLogin.Body.accessToken
}
$listPaths = @('/api/users/me/advisors', '/api/users/me/workout-plans', '/api/users/me/tasks', '/api/users/me/advisor-notes')
$goalPath = '/api/users/me/nutrition-goals/active'
foreach ($path in $listPaths) {
    $empty = Invoke-Api 'GET' $path $null $FirstToken
    Assert-Check ($empty.Status -eq 200 -and $empty.NoStore -and $empty.Body.Count -eq 0) 'Unassigned user list must be empty and no-store.'
}
$missingGoal = Invoke-Api 'GET' $goalPath $null $FirstToken
Assert-Check ($missingGoal.Status -eq 404 -and $missingGoal.Body.code -eq 'NutritionGoalNotFound') 'No-goal error code missing.'
foreach ($path in ($listPaths + @($goalPath))) {
    Assert-Check ((Invoke-Api 'GET' $path).Status -eq 401) 'Anonymous assignment access was accepted.'
    foreach ($role in @('Trainer', 'Dietitian', 'Admin')) {
        Assert-Check ((Invoke-Api 'GET' $path $null $advisorTokens[$role]).Status -eq 403) 'User role not enforced on own assignments.'
    }
}
Add-AssignmentFixture $FirstUserId $SecondUserId $advisorIds.Trainer $advisorIds.Dietitian
$planPath = '/api/workout-plans/10000000-0000-0000-0000-000000000005'
$otherPlanPath = '/api/workout-plans/10000000-0000-0000-0000-000000000006'
$plans = Invoke-Api 'GET' '/api/users/me/workout-plans' $null $FirstToken
Assert-Check ($plans.Status -eq 200 -and $plans.Body.Count -eq 2 -and $plans.Body[0].isActive -and $plans.Body[0].name -eq 'Atanmış kuvvet programı') 'Assigned/current and historical plan summaries invalid.'
$detail = Invoke-Api 'GET' $planPath $null $FirstToken
Assert-Check ($detail.Status -eq 200 -and $detail.NoStore -and $detail.Body.userId -eq $FirstUserId.ToString()) 'Owner plan detail failed.'
Assert-Check ($detail.Body.days.Count -eq 2 -and $detail.Body.days[0].weekday -ceq 'Monday' -and
    $detail.Body.days[0].exercises[0].order -eq 1 -and $detail.Body.days[0].exercises[0].exerciseName -eq 'Squat' -and
    $detail.Body.days[0].exercises[0].sets -eq 3 -and $detail.Body.days[0].exercises[0].restSeconds -eq 90) 'Plan/day/exercise DTO or sorting invalid.'
Assert-Check ((Invoke-Api 'GET' $planPath $null $SecondToken).Status -eq 404) 'Other User read protected plan.'
Assert-Check ((Invoke-Api 'GET' $otherPlanPath $null $FirstToken).Status -eq 404) 'Unassigned multirole user read another plan.'
Assert-Check ((Invoke-Api 'GET' $planPath $null $advisorTokens.Trainer).Status -eq 200) 'Assigned Trainer cannot read plan detail.'
Assert-Check ((Invoke-Api 'GET' $otherPlanPath $null $advisorTokens.Trainer).Status -eq 404) 'Unassigned Trainer can read plan detail.'
foreach ($role in @('Dietitian', 'Admin')) {
    Assert-Check ((Invoke-Api 'GET' $planPath $null $advisorTokens[$role]).Status -eq 403) 'Non-workout role can read plan.'
}
Assert-Check ((Invoke-Api 'GET' $planPath).Status -eq 401) 'Anonymous plan detail allowed.'
foreach ($path in @('/api/users/me/tasks', '/api/users/me/advisor-notes')) {
    $own = Invoke-Api 'GET' ($path + '?userId=' + $SecondUserId.ToString()) $null $FirstToken
    Assert-Check ($own.Status -eq 200 -and $own.Body.Count -eq 2 -and ($own.Body.userId | Select-Object -Unique) -eq $FirstUserId.ToString()) 'Query userId bypassed own-record isolation.'
    $other = Invoke-Api 'GET' $path $null $SecondToken
    Assert-Check ($other.Body.Count -eq 1 -and $other.Body[0].userId -eq $SecondUserId.ToString()) 'Other account sees first account content.'
}
$pending = Invoke-Api 'GET' '/api/users/me/tasks?status=Pending' $null $FirstToken
Assert-Check ($pending.Body.Count -eq 1 -and $pending.Body[0].status -ceq 'Pending') 'Task filter/status format failed.'
foreach ($status in @('unknown', '0', 'pending')) {
    $invalid = Invoke-Api 'GET' ('/api/users/me/tasks?status=' + $status) $null $FirstToken
    Assert-Check ($invalid.Status -eq 400 -and $null -ne $invalid.Body.errors.status) 'Invalid task status accepted.'
}
$notes = Invoke-Api 'GET' '/api/users/me/advisor-notes' $null $FirstToken
$noteTimestamp = $notes.Body[0].createdAt
# PowerShell 7 parses JSON dates; Windows PowerShell keeps ISO strings.
$noteIsUtc = ($noteTimestamp -is [DateTime] -and $noteTimestamp.Kind -eq [DateTimeKind]::Utc) -or
    ($noteTimestamp -is [string] -and $noteTimestamp.EndsWith('Z'))
Assert-Check ($notes.Body[0].title -eq 'Koç notu' -and $noteIsUtc) 'Note order/UTC format invalid.'
$advisors = Invoke-Api 'GET' '/api/users/me/advisors' $null $FirstToken
Assert-Check ($advisors.Status -eq 200 -and $advisors.Body.Count -eq 2 -and $advisors.Body[0].firstName -eq 'Çağrı' -and
    $advisors.Body[0].title -eq 'Kuvvet koçu' -and $advisors.Body[1].advisorType -eq 'Dietitian' -and $null -eq $advisors.Body[1].title) 'Advisor names/types/optional profile failed.'
Assert-Check ((Invoke-Api 'GET' '/api/users/me/advisors' $null $SecondToken).Body.Count -eq 0) 'Other User can read advisor assignments.'
[void] (Invoke-CheckSql "UPDATE user_advisors SET status = 'Ended', end_date = '2026-12-01' WHERE advisor_type = 'Trainer';")
Assert-Check ((Invoke-Api 'GET' '/api/users/me/advisors' $null $FirstToken).Body.Count -eq 1) 'Ended advisor remained visible.'
Assert-Check ((Invoke-Api 'GET' $planPath $null $advisorTokens.Trainer).Status -eq 404) 'Ended Trainer retains detail permission.'
[void] (Invoke-CheckSql "UPDATE user_advisors SET status = 'Active', end_date = NULL WHERE advisor_type = 'Trainer'; UPDATE user_advisors SET status = 'Cancelled', end_date = '2026-12-01' WHERE advisor_type = 'Dietitian';")
Assert-Check ((Invoke-Api 'GET' '/api/users/me/advisors' $null $FirstToken).Body.Count -eq 1) 'Cancelled advisor remained visible.'
[void] (Invoke-CheckSql "UPDATE user_advisors SET status = 'Active', end_date = NULL WHERE advisor_type = 'Dietitian';")
$goal = Invoke-Api 'GET' ($goalPath + '?date=2026-11-01') $null $FirstToken
Assert-Check ($goal.Status -eq 200 -and $goal.Body.dailyCalories -eq 2300 -and $goal.Body.proteinGrams -eq 150 -and $goal.Body.waterMl -eq 2500 -and $goal.NoStore) 'Active goal response invalid.'
Assert-Check ((Invoke-Api 'GET' ($goalPath + '?date=2026-11-01') $null $SecondToken).Body.dailyCalories -eq 1900) 'Goal isolation failed.'
[void] (Invoke-CheckSql "UPDATE nutrition_goals SET start_date = '2026-11-01', end_date = '2026-11-30' WHERE id = '10000000-0000-0000-0000-000000000012';")
foreach ($date in @('2026-11-01', '2026-11-30')) {
    Assert-Check ((Invoke-Api 'GET' ($goalPath + '?date=' + $date) $null $FirstToken).Status -eq 200) 'Target date boundary is not inclusive.'
}
foreach ($date in @('2026-10-31', '2026-12-01')) {
    $notFound = Invoke-Api 'GET' ($goalPath + '?date=' + $date) $null $FirstToken
    Assert-Check ($notFound.Status -eq 404 -and $notFound.Body.code -eq 'NutritionGoalNotFound') 'Out-of-range target or historical fallback shown.'
}
foreach ($date in @('bad-date', '2026-02-30', '2026-1-1')) {
    $invalid = Invoke-Api 'GET' ($goalPath + '?date=' + $date) $null $FirstToken
    Assert-Check ($invalid.Status -eq 400 -and $null -ne $invalid.Body.errors.date) 'Invalid target date accepted.'
}
[void] (Invoke-CheckSql "UPDATE nutrition_goals SET start_date = '2026-01-01', end_date = NULL WHERE id = '10000000-0000-0000-0000-000000000012';")
# Each DO block rolls back its rejected change in PostgreSQL's subtransaction.
foreach ($sql in @(
    "INSERT INTO nutrition_goals (id, user_id, dietitian_id, daily_calories, protein_grams, carbohydrate_grams, fat_grams, water_ml, start_date, end_date, is_active, created_at, updated_at) SELECT gen_random_uuid(), user_id, dietitian_id, daily_calories, protein_grams, carbohydrate_grams, fat_grams, water_ml, start_date, end_date, is_active, created_at, updated_at FROM nutrition_goals WHERE id = '10000000-0000-0000-0000-000000000012'",
    "UPDATE workout_plans SET is_active = true WHERE id = '10000000-0000-0000-0000-000000000007'",
    "UPDATE workout_days SET weekday = 'Monday' WHERE id = '10000000-0000-0000-0000-000000000009'",
    "INSERT INTO user_advisors (id, user_id, advisor_id, advisor_type, start_date, end_date, status, created_at) SELECT gen_random_uuid(), user_id, advisor_id, advisor_type, start_date, end_date, status, created_at FROM user_advisors WHERE id = '10000000-0000-0000-0000-000000000002'"
)) {
    [void] (Invoke-CheckSql ('DO $check$ BEGIN BEGIN ' + $sql + '; RAISE EXCEPTION ''Constraint did not reject duplicate''; EXCEPTION WHEN unique_violation THEN NULL; END; END $check$;'))
}
Write-Output 'PASS: real PostgreSQL assignment DTOs, owner/role isolation, Trainer access, task filters, active advisors, nutrition dates/error code and unique constraints.'
& (Join-Path $PSScriptRoot 'AssignmentWriteChecks.ps1') -UserId $FirstUserId -OtherId $SecondUserId `
    -UserToken $FirstToken -OtherToken $SecondToken -TrainerToken $advisorTokens.Trainer `
    -DietitianToken $advisorTokens.Dietitian -AdminToken $advisorTokens.Admin
