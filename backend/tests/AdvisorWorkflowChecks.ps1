param([string] $OtherUserToken, [Guid] $OtherUserId)

# Runs only in AuthSmoke's disposable PostgreSQL/API fixture.
$workflowPassword = [Guid]::NewGuid().ToString('N') + '!Aa1'
function New-WorkflowAccount([string] $Role, [string] $Name) {
    $email = [Guid]::NewGuid().ToString('N') + '@example.test'
    $registered = Invoke-Api 'POST' '/api/auth/register' @{
        firstName = $Name; lastName = 'Danışman'; email = $email; password = $workflowPassword
    }
    Assert-Check ($registered.Status -eq 201) 'Workflow registration failed.'
    $id = ([Guid]::Parse($registered.Body.id)).ToString()
    if ($Role -ne 'User') {
        [void] (Invoke-CheckSql "DELETE FROM user_roles WHERE user_id = '$id'; INSERT INTO user_roles (id, user_id, role_id) SELECT gen_random_uuid(), '$id'::uuid, id FROM roles WHERE name = '$Role';")
    }
    $login = Invoke-Api 'POST' '/api/auth/login' @{ email = $email; password = $workflowPassword }
    Assert-Check ($login.Status -eq 200) 'Workflow login failed.'
    return @{ Id = $id; Token = $login.Body.accessToken }
}
$trainer = New-WorkflowAccount 'Trainer' 'Çağrı'
$dietitian = New-WorkflowAccount 'Dietitian' 'İrem'
$admin = New-WorkflowAccount 'Admin' 'Deniz'
$adminToken = $admin.Token
$clientUser = New-WorkflowAccount 'User' 'Uğur'
$clientId = $clientUser.Id
$trainerPath = '/api/trainers/me/clients'
$dietitianPath = '/api/dietitians/me/clients'
$profilePath = '/api/users/' + $clientId
$workoutPath = $profilePath + '/workout-plans'
$nutritionPath = $profilePath + '/nutrition-goals'
$today = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
foreach ($path in @($trainerPath, $dietitianPath, $profilePath, '/api/users', '/api/user-advisors', '/api/exercises')) {
    Assert-Check ((Invoke-Api 'GET' $path).Status -eq 401) 'Anonymous workflow access accepted.'
}
foreach ($path in @('/api/users', ('/api/user-advisors?userId=' + $clientId), $trainerPath, $dietitianPath)) {
    Assert-Check ((Invoke-Api 'GET' $path $null $clientUser.Token).Status -eq 403) 'User role can access staff management.'
}
Assert-Check ((Invoke-Api 'GET' ($profilePath + '?advisorId=' + $trainer.Id) $null $trainer.Token).Status -eq 403) 'Unassigned client profile exposed.'
$adminList = Invoke-Api 'GET' '/api/users?page=1&pageSize=2&role=Trainer' $null $AdminToken
Assert-Check ($adminList.Status -eq 200 -and $adminList.NoStore -and $adminList.Body.pageSize -eq 2 -and
    $adminList.Body.items.Count -le 2 -and $adminList.Body.totalCount -ge 1) 'Admin pagination or role filter failed.'
foreach ($item in $adminList.Body.items) {
    Assert-Check ($item.roles -contains 'Trainer' -and $null -eq $item.passwordHash -and $null -eq $item.heightCm) 'Admin summary exposes private fields or wrong role.'
}
foreach ($query in @('page=0', 'pageSize=101', 'role=trainer', 'page=1000001')) {
    Assert-Check ((Invoke-Api 'GET' ('/api/users?' + $query) $null $AdminToken).Status -eq 400) 'Invalid user-list query accepted.'
}
Assert-Check ((Invoke-Api 'GET' '/api/user-advisors' $null $AdminToken).Status -eq 400) 'Missing relation userId accepted.'
Assert-Check ((Invoke-Api 'GET' ('/api/users?search=' + [Uri]::EscapeDataString('Uğur')) $null $AdminToken).Body.items.Count -ge 1) 'Admin name search failed.'

$relationRequest = @{ userId = $clientId; advisorId = $trainer.Id; advisorType = 'Trainer'; startDate = $today }
Assert-Check ((Invoke-Api 'POST' '/api/user-advisors' $relationRequest $trainer.Token).Status -eq 403) 'Trainer assigned their own client.'
foreach ($invalid in @(
    @{ userId = $clientId; advisorId = $clientId; advisorType = 'Trainer'; startDate = $today },
    @{ userId = $trainer.Id; advisorId = $dietitian.Id; advisorType = 'Dietitian'; startDate = $today },
    @{ userId = $clientId; advisorId = $dietitian.Id; advisorType = 'Trainer'; startDate = $today },
    @{ userId = $clientId; advisorId = $trainer.Id; advisorType = 'trainer'; startDate = $today },
    @{ userId = $clientId; advisorId = $trainer.Id; advisorType = 'Trainer'; startDate = [DateTime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd') },
    @{ userId = $clientId; advisorId = $trainer.Id; advisorType = 'Trainer'; startDate = [DateTime]::UtcNow.AddDays(-1).ToString('yyyy-MM-dd') }
)) {
    Assert-Check ((Invoke-Api 'POST' '/api/user-advisors' $invalid $AdminToken).Status -eq 400) 'Invalid advisor relationship accepted.'
}
# Exercise the duplicate race through HTTP, not direct inserts.
function Send-WorkflowPost([string] $Path, $Body, [string] $Token) {
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, $baseUrl + $Path)
    $request.Content = New-JsonContent $Body
    $request.Headers.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token)
    return @{ Request = $request; Task = $client.SendAsync($request) }
}
function Complete-WorkflowPost($Pending) {
    $response = $Pending.Task.GetAwaiter().GetResult()
    try { return Read-Response $response } finally { $response.Dispose(); $Pending.Request.Dispose() }
}
$relationA = Send-WorkflowPost '/api/user-advisors' $relationRequest $AdminToken
$relationB = Send-WorkflowPost '/api/user-advisors' $relationRequest $AdminToken
$relationResults = @((Complete-WorkflowPost $relationA), (Complete-WorkflowPost $relationB))
Assert-Check ((($relationResults.Status | Sort-Object) -join ',') -eq '201,409') 'Concurrent relationship creates need one winner.'
$trainerRelation = ($relationResults | Where-Object { $_.Status -eq 201 }).Body
$dietitianRelation = Invoke-Api 'POST' '/api/user-advisors' @{
    userId = $clientId; advisorId = $dietitian.Id; advisorType = 'Dietitian'; startDate = $today
} $AdminToken
Assert-Check ($dietitianRelation.Status -eq 201 -and $dietitianRelation.Body.userId -eq $clientId) 'Dietitian relationship creation failed.'
$relations = Invoke-Api 'GET' ('/api/user-advisors?userId=' + $clientId) $null $AdminToken
Assert-Check ($relations.Status -eq 200 -and $relations.Body.Count -eq 2) 'Admin relation list mismatch.'
foreach ($entry in @(@{ Path = $trainerPath; Staff = $trainer }, @{ Path = $dietitianPath; Staff = $dietitian })) {
    $clients = Invoke-Api 'GET' ($entry.Path + '?advisorId=' + [Guid]::NewGuid()) $null $entry.Staff.Token
    Assert-Check ($clients.Status -eq 200 -and $clients.NoStore -and $clients.Body.Count -eq 1 -and
        $clients.Body[0].id -eq $clientId -and $clients.Body[0].relationshipStatus -ceq 'Active') 'Client list leaks another advisor or is incompatible.'
}
[void] (Invoke-CheckSql "UPDATE users SET birth_date = '2003-08-15', height_cm = 180, gender = 'Other' WHERE id = '$clientId';")
$advisorProfile = Invoke-Api 'GET' $profilePath $null $trainer.Token
Assert-Check ($advisorProfile.Status -eq 200 -and $advisorProfile.Body.heightCm -eq 180 -and $advisorProfile.NoStore) 'Assigned client profile failed.'
$adminProfile = Invoke-Api 'GET' $profilePath $null $AdminToken
Assert-Check ($adminProfile.Status -eq 200 -and $null -eq $adminProfile.Body.heightCm -and
    $null -eq $adminProfile.Body.birthDate -and $null -eq $adminProfile.Body.gender) 'Admin-only profile exposes health data.'
Assert-Check ((Invoke-Api 'GET' ('/api/users/' + $OtherUserId) $null $trainer.Token).Status -eq 403) 'Unassigned user profile leaked.'

$exerciseRequest = @{ name = 'Workflow Squat'; description = 'Kontrollü hareket'; instructions = 'Dizleri kontrollü bük.';
    videoUrl = $null; imageUrl = $null; isActive = $true }
Assert-Check ((Invoke-Api 'POST' '/api/exercises' $exerciseRequest $trainer.Token).Status -eq 403) 'Trainer can edit exercise catalog.'
$exercise = Invoke-Api 'POST' '/api/exercises' $exerciseRequest $AdminToken
Assert-Check ($exercise.Status -eq 201 -and $exercise.Body.instructions -eq $exerciseRequest.instructions) 'Admin exercise create failed.'
$exerciseId = $exercise.Body.id
$catalog = Invoke-Api 'GET' '/api/exercises?search=workflow' $null $trainer.Token
Assert-Check ($catalog.Status -eq 200 -and $catalog.NoStore -and $catalog.Body.Count -eq 1 -and $catalog.Body[0].id -eq $exerciseId) 'Real exercise catalog mismatch.'
Assert-Check ((Invoke-Api 'GET' ('/api/exercises?muscleGroupId=' + [Guid]::NewGuid()) $null $trainer.Token).Status -eq 400) 'Unsupported muscle-group filter ignored.'

function New-WorkflowPlan {
    return @{ name = 'Web üzerinden atanan plan'; description = 'Gerçek API'; startDate = $today; endDate = $null;
        days = @(@{ name = 'Kuvvet'; dayNumber = 1; weekday = 'Monday'; description = $null;
            exercises = @(@{ exerciseId = $exerciseId; order = 1; sets = 3; reps = 10;
                durationSeconds = $null; restSeconds = 0; weightKg = 20.25; notes = 'Kontrollü' }) }) }
}
$planRequest = New-WorkflowPlan
Assert-Check ((Invoke-Api 'POST' $workoutPath $planRequest $dietitian.Token).Status -eq 403) 'Dietitian can assign workout.'
Assert-Check ((Invoke-Api 'POST' ('/api/users/' + $OtherUserId + '/workout-plans') $planRequest $trainer.Token).Status -eq 403) 'Trainer assigned unlinked user.'
$planCreated = Invoke-Api 'POST' $workoutPath $planRequest $trainer.Token
Assert-Check ($planCreated.Status -eq 201 -and $planCreated.Body.days[0].exercises[0].weightKg -eq 20.25) 'Workout POST must return the persisted plan JSON.'
$plans = Invoke-Api 'GET' $workoutPath $null $trainer.Token
Assert-Check ($plans.Status -eq 200 -and $plans.Body.Count -eq 1 -and $plans.Body[0].isActive) 'Web plan list failed.'
$planId = $plans.Body[0].id
$mobilePlans = Invoke-Api 'GET' '/api/users/me/workout-plans' $null $clientUser.Token
Assert-Check ($mobilePlans.Body[0].id -eq $planId) 'Mobile cannot see real web assignment.'
$detail = Invoke-Api 'GET' ('/api/workout-plans/' + $planId) $null $clientUser.Token
Assert-Check ($detail.Status -eq 200 -and $detail.Body.trainerId -eq $trainer.Id -and
    $detail.Body.days[0].exercises[0].weightKg -eq 20.25) 'Assigned plan detail/persistence mismatch.'
Assert-Check ((Invoke-Api 'GET' ('/api/workout-plans/' + $planId) $null $OtherUserToken).Status -eq 404) 'Another user sees the assigned plan.'
foreach ($case in @('emptyDays', 'nullDay', 'nullExercise', 'duplicateWeekday', 'duplicateOrder', 'noTarget', 'mixedTarget', 'missingExercise', 'spoofTrainer', 'precision', 'dates', 'lowercaseWeekday')) {
    $invalidPlan = New-WorkflowPlan
    switch ($case) {
        'emptyDays' { $invalidPlan.days = @() }
        'nullDay' { $invalidPlan.days = @($null) }
        'nullExercise' { $invalidPlan.days[0].exercises = @($null) }
        'duplicateWeekday' { $day = (New-WorkflowPlan).days[0]; $day.dayNumber = 2; $invalidPlan.days += $day }
        'duplicateOrder' { $invalidPlan.days[0].exercises += (New-WorkflowPlan).days[0].exercises[0] }
        'noTarget' { $invalidPlan.days[0].exercises[0].sets = $null }
        'mixedTarget' { $invalidPlan.days[0].exercises[0].durationSeconds = 30 }
        'missingExercise' { $invalidPlan.days[0].exercises[0].exerciseId = [Guid]::NewGuid().ToString() }
        'spoofTrainer' { $invalidPlan.trainerId = [Guid]::NewGuid().ToString() }
        'precision' { $invalidPlan.days[0].exercises[0].weightKg = 20.123 }
        'dates' { $invalidPlan.endDate = '2025-01-01' }
        'lowercaseWeekday' { $invalidPlan.days[0].weekday = 'monday' }
    }
    $invalidResponse = Invoke-Api 'POST' $workoutPath $invalidPlan $trainer.Token
    Assert-Check ($invalidResponse.Status -eq 400 -and $null -ne $invalidResponse.Body.errors) "Invalid plan accepted: $case"
}
Assert-Check ((Invoke-Api 'GET' $workoutPath $null $trainer.Token).Body[0].id -eq $planId) 'Rejected plan replaced active plan.'
$exerciseRequest.isActive = $false
Assert-Check ((Invoke-Api 'PUT' ('/api/exercises/' + $exerciseId) $exerciseRequest $AdminToken).Status -eq 200) 'Exercise deactivation failed.'
Assert-Check ((Invoke-Api 'POST' $workoutPath $planRequest $trainer.Token).Status -eq 400) 'Inactive exercise assigned.'
Assert-Check ((Invoke-Api 'GET' ('/api/exercises/' + $exerciseId) $null $trainer.Token).Status -eq 404) 'Inactive exercise exposed to trainer catalog.'
Assert-Check ((Invoke-Api 'GET' ('/api/workout-plans/' + $planId) $null $clientUser.Token).Status -eq 200) 'Exercise deactivation destroyed historical plan.'
$exerciseRequest.isActive = $true
[void] (Invoke-Api 'PUT' ('/api/exercises/' + $exerciseId) $exerciseRequest $AdminToken)
$timedPlan = New-WorkflowPlan
$timedPlan.days[0].exercises[0].sets = $null; $timedPlan.days[0].exercises[0].reps = $null
$timedPlan.days[0].exercises[0].durationSeconds = 60
$planA = Send-WorkflowPost $workoutPath $planRequest $trainer.Token
$planB = Send-WorkflowPost $workoutPath $timedPlan $trainer.Token
Assert-Check ((Complete-WorkflowPost $planA).Status -eq 201 -and (Complete-WorkflowPost $planB).Status -eq 201) 'Concurrent program replacement failed.'
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM workout_plans WHERE user_id = '$clientId' AND is_active;") -eq '1') 'Multiple active plans survived concurrent replacement.'
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM workout_plans WHERE user_id = '$clientId';") -eq '3') 'Plan history lost in replacement.'

$goalRequest = @{ dailyCalories = 2300.25; proteinGrams = 150; carbohydrateGrams = 260; fatGrams = 0;
    waterMl = 2500; startDate = $today; endDate = $null }
Assert-Check ((Invoke-Api 'POST' $nutritionPath $goalRequest $trainer.Token).Status -eq 403) 'Trainer assigned dietitian goal.'
Assert-Check ((Invoke-Api 'GET' $nutritionPath $null $AdminToken).Status -eq 403) 'Admin can read private nutrition goals.'
$goalCreated = Invoke-Api 'POST' $nutritionPath $goalRequest $dietitian.Token
Assert-Check ($goalCreated.Status -eq 201 -and $goalCreated.Body.isActive -and $goalCreated.Body.dailyCalories -eq 2300.25) 'Goal JSON response incompatible.'
$activeGoal = Invoke-Api 'GET' ('/api/users/me/nutrition-goals/active?date=' + $today) $null $clientUser.Token
Assert-Check ($activeGoal.Status -eq 200 -and $activeGoal.Body.id -eq $goalCreated.Body.id) 'Mobile cannot read web nutrition target.'
foreach ($field in @('dailyCalories', 'proteinGrams', 'carbohydrateGrams', 'fatGrams', 'waterMl')) {
    foreach ($value in @($null, -1, 20.123, 10000000000)) {
        $invalidGoal = $goalRequest.Clone(); $invalidGoal[$field] = $value
        Assert-Check ((Invoke-Api 'POST' $nutritionPath $invalidGoal $dietitian.Token).Status -eq 400) 'Invalid nutrition target accepted.'
    }
}
$spoofGoal = $goalRequest.Clone(); $spoofGoal.dietitianId = $trainer.Id
Assert-Check ((Invoke-Api 'POST' $nutritionPath $spoofGoal $dietitian.Token).Status -eq 400) 'Spoofed dietitian ID accepted.'
$goalA = Send-WorkflowPost $nutritionPath $goalRequest $dietitian.Token
$goalB = Send-WorkflowPost $nutritionPath $goalRequest $dietitian.Token
Assert-Check ((Complete-WorkflowPost $goalA).Status -eq 201 -and (Complete-WorkflowPost $goalB).Status -eq 201) 'Concurrent nutrition replacement failed.'
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM nutrition_goals WHERE user_id = '$clientId' AND is_active;") -eq '1') 'Multiple active goals survived.'
$goals = Invoke-Api 'GET' $nutritionPath $null $dietitian.Token
Assert-Check ($goals.Status -eq 200 -and $goals.Body.Count -eq 3 -and $goals.Body[0].isActive) 'Nutrition history/list failed.'
$scheduledGoal = $goalRequest.Clone(); $scheduledGoal.startDate = [DateTime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
Assert-Check ((Invoke-Api 'POST' $nutritionPath $scheduledGoal $dietitian.Token).Status -eq 201) 'Future target assignment failed.'
$noGoalToday = Invoke-Api 'GET' ('/api/users/me/nutrition-goals/active?date=' + $today) $null $clientUser.Token
Assert-Check ($noGoalToday.Status -eq 404 -and $noGoalToday.Body.code -eq 'NutritionGoalNotFound') 'Old goal resurfaced before new target starts.'

foreach ($relationEntry in @(@{ Id = $trainerRelation.userAdvisorId; Staff = $trainer; Path = $workoutPath; Body = $planRequest },
    @{ Id = $dietitianRelation.Body.userAdvisorId; Staff = $dietitian; Path = $nutritionPath; Body = $goalRequest })) {
    $endPath = '/api/user-advisors/' + $relationEntry.Id
    $endBody = @{ status = 'Ended'; endDate = $today }
    Assert-Check ((Invoke-Api 'PATCH' $endPath $endBody $AdminToken).Status -eq 200) 'Admin relation termination failed.'
    Assert-Check ((Invoke-Api 'PATCH' $endPath $endBody $AdminToken).Status -eq 200) 'Termination not idempotent.'
    Assert-Check ((Invoke-Api 'POST' $relationEntry.Path $relationEntry.Body $relationEntry.Staff.Token).Status -eq 403) 'Ended advisor retained write access.'
    Assert-Check ((Invoke-Api 'GET' $relationEntry.Path $null $relationEntry.Staff.Token).Status -eq 403) 'Ended advisor retained history access.'
    Assert-Check ((Invoke-Api 'PATCH' $endPath @{ status = 'Active'; endDate = $today } $AdminToken).Status -eq 400) 'Ended relation reactivated.'
}
Assert-Check ((Invoke-Api 'GET' '/api/users/me/advisors' $null $clientUser.Token).Body.Count -eq 0) 'Ended advisors visible to mobile.'
Assert-Check ((Invoke-Api 'GET' '/api/users/me/workout-plans' $null $clientUser.Token).Body.Count -eq 3) 'Relationship termination erased user history.'
Write-Output 'PASS: real advisor management, client/profile access, catalog, web-to-mobile plan/goal assignment, validation, concurrent replacements and relationship termination.'
