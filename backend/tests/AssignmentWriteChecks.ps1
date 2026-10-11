param([Guid] $UserId, [Guid] $OtherId, [string] $UserToken, [string] $OtherToken,
    [string] $TrainerToken, [string] $DietitianToken, [string] $AdminToken)
$ErrorActionPreference = 'Stop'
$planRoute = "/api/users/$UserId/workout-plans"
$goalRoute = "/api/users/$UserId/nutrition-goals"
$taskRoute = "/api/users/$UserId/tasks"
$noteRoute = "/api/users/$UserId/advisor-notes"
$today = [DateTime]::Today.ToString('yyyy-MM-dd')
$plan = @{ name='Gerçek program'; description='Atama testi'; startDate=$today; endDate=$null; days=@(
    @{ name='Kuvvet'; dayNumber=1; weekday='Monday'; description=$null; exercises=@(
        @{ exerciseId='10000000-0000-0000-0000-000000000004'; order=1; sets=3; reps=10;
            durationSeconds=$null; restSeconds=90; weightKg=20.5; notes='Kontrollü' }) }) }
$goal = @{ dailyCalories=2200; proteinGrams=140; carbohydrateGrams=250; fatGrams=70;
    waterMl=2500; startDate=$today; endDate=$null }
$task = @{ title='Gerçek görev'; description='Esneme yap'; dueDate=$today }
$note = @{ title='Gerçek not'; content='İlerlemeyi birlikte kontrol edelim.' }
foreach ($case in @(@{route=$planRoute;body=$plan;token=$TrainerToken}, @{route=$goalRoute;body=$goal;token=$DietitianToken},
    @{route=$taskRoute;body=$task;token=$TrainerToken}, @{route=$noteRoute;body=$note;token=$DietitianToken})) {
    Assert-Check ((Invoke-Api 'POST' $case.route $case.body).Status -eq 401) 'Anonymous assignment allowed.'
    Assert-Check ((Invoke-Api 'POST' $case.route $case.body $AdminToken).Status -eq 403) 'Admin bypassed advisor relationship.'
    $foreignRoute = $case.route.Replace($UserId.ToString(), $OtherId.ToString())
    Assert-Check ((Invoke-Api 'POST' $foreignRoute $case.body $case.token).Status -eq 403) 'Unassigned client write allowed.'
    Assert-Check ((Invoke-Api 'GET' $foreignRoute $null $case.token).Status -eq 403) 'Unassigned client read allowed.'
}
Assert-Check ((Invoke-Api 'POST' $planRoute $plan $DietitianToken).Status -eq 403) 'Dietitian created workout.'
Assert-Check ((Invoke-Api 'POST' $goalRoute $goal $TrainerToken).Status -eq 403) 'Trainer created nutrition goal.'
Assert-Check ((Invoke-Api 'GET' '/api/trainers/me/clients' $null $TrainerToken).Body[0].id -eq $UserId) 'Trainer client list failed.'
Assert-Check ((Invoke-Api 'GET' '/api/dietitians/me/clients' $null $DietitianToken).Body[0].id -eq $UserId) 'Dietitian client list failed.'
Assert-Check ((Invoke-Api 'GET' "/api/users/$UserId" $null $TrainerToken).Status -eq 200) 'Assigned profile read failed.'
Assert-Check ((Invoke-Api 'GET' "/api/users/$OtherId" $null $TrainerToken).Status -eq 403) 'Foreign profile readable.'
Assert-Check ((Invoke-Api 'GET' '/api/exercises?search=Squat' $null $TrainerToken).Body.Count -eq 1) 'Active exercise catalog failed.'

# Invalid nested values must leave the existing active plan intact.
$invalidBodies = @()
$copy = $plan | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable; $copy.days += $copy.days[0]; $invalidBodies += ,$copy
$copy = $plan | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable; $copy.days[0].weekday='0'; $invalidBodies += ,$copy
$copy = $plan | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable; $copy.days[0].exercises[0].sets=0; $invalidBodies += ,$copy
$copy = $plan | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable; $copy.days[0].exercises[0].exerciseId=[Guid]::NewGuid().ToString(); $invalidBodies += ,$copy
$copy = $plan | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable; $copy.days=@($null); $invalidBodies += ,$copy
$copy = $plan | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable; $copy.trainerId=[Guid]::NewGuid().ToString(); $invalidBodies += ,$copy
$copy = $plan | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable; $copy.endDate='2000-01-01'; $invalidBodies += ,$copy
foreach ($body in $invalidBodies) {
    $result = Invoke-Api 'POST' $planRoute $body $TrainerToken
    Assert-Check ($result.Status -eq 400 -and $result.ContentType -eq 'application/problem+json') 'Invalid nested plan was accepted or wrong error format.'
}
Assert-Check ((Invoke-Api 'GET' '/api/users/me/workout-plans' $null $UserToken).Body[0].name -eq 'Atanmış kuvvet programı') 'Rejected assignment deactivated current plan.'
$createdPlan = Invoke-Api 'POST' $planRoute $plan $TrainerToken
Assert-Check ($createdPlan.Status -eq 201 -and $createdPlan.Body.days[0].exercises[0].exerciseName -eq 'Squat') 'Nested plan write failed.'
$plan.name='Yeni aktif program'; $replacement = Invoke-Api 'POST' $planRoute $plan $TrainerToken
$plans = Invoke-Api 'GET' $planRoute $null $TrainerToken
Assert-Check ($replacement.Status -eq 201 -and @($plans.Body | Where-Object isActive).Count -eq 1 -and $plans.Body[0].name -eq 'Yeni aktif program') 'Active plan replacement failed.'
Assert-Check ((Invoke-Api 'GET' ("/api/workout-plans/" + $replacement.Body.id) $null $UserToken).Body.days.Count -eq 1) 'Mobile cannot read created plan.'
foreach ($body in @(@{dailyCalories=-1;proteinGrams=10;carbohydrateGrams=10;fatGrams=10;waterMl=100;startDate=$today},
    @{dailyCalories=100.001;proteinGrams=10;carbohydrateGrams=10;fatGrams=10;waterMl=100;startDate=$today},
    @{dailyCalories=100;startDate=$today})) {
    Assert-Check ((Invoke-Api 'POST' $goalRoute $body $DietitianToken).Status -eq 400) 'Invalid/missing goal value accepted.'
}
$createdGoal = Invoke-Api 'POST' $goalRoute $goal $DietitianToken
Assert-Check ($createdGoal.Status -eq 201 -and $createdGoal.Body.isActive) 'Nutrition goal write failed.'

# Concurrent assignments must both succeed while retaining exactly one active target.
$requests = @(); $pending = @()
try {
    foreach ($calories in @(2100, 2400)) {
        $goal.dailyCalories=$calories
        $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, $baseUrl + $goalRoute)
        $request.Content = New-JsonContent $goal
        $request.Headers.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $DietitianToken)
        $requests += $request; $pending += $client.SendAsync($request)
    }
    foreach ($operation in $pending) {
        $response = $operation.GetAwaiter().GetResult()
        try { Assert-Check ([int]$response.StatusCode -eq 201) 'Concurrent goal assignment failed.' } finally { $response.Dispose() }
    }
} finally { foreach ($request in $requests) { $request.Dispose() } }
$goals = Invoke-Api 'GET' $goalRoute $null $DietitianToken
Assert-Check (@($goals.Body | Where-Object isActive).Count -eq 1 -and $goals.Body.Count -eq 5) 'Concurrent replacement lost history or kept multiple active targets.'
Assert-Check ((Invoke-Api 'GET' ('/api/users/me/nutrition-goals/active?date=' + $today) $null $UserToken).Body.id -eq $goals.Body[0].id) 'Mobile sees a different active target.'
$createdTask = Invoke-Api 'POST' $taskRoute $task $TrainerToken
$createdNote = Invoke-Api 'POST' $noteRoute $note $DietitianToken
Assert-Check ($createdTask.Status -eq 201 -and $createdTask.Body.status -eq 'Pending' -and $null -eq $createdTask.Body.completedAt) 'Task creation failed.'
Assert-Check ($createdNote.Status -eq 201 -and $createdNote.Body.content -eq $note.content) 'Note creation failed.'
Assert-Check ((Invoke-Api 'GET' $taskRoute $null $DietitianToken).Body.Count -eq 3) 'Assigned advisors cannot read client tasks.'
$patchRoute='/api/tasks/' + $createdTask.Body.id
Assert-Check ((Invoke-Api 'PATCH' $patchRoute @{status='Completed'} $OtherToken).Status -eq 404) 'Other user completed task.'
Assert-Check ((Invoke-Api 'PATCH' $patchRoute @{status='Completed'} $DietitianToken).Status -eq 404) 'Non-creator advisor changed task.'
foreach ($status in @('unknown','0','completed')) {
    Assert-Check ((Invoke-Api 'PATCH' $patchRoute @{status=$status} $UserToken).Status -eq 400) 'Invalid task status accepted.'
}
Assert-Check ((Invoke-Api 'PATCH' $patchRoute @{status='Cancelled'} $UserToken).Status -eq 403) 'User changed task to non-completion status.'
$completed = Invoke-Api 'PATCH' $patchRoute @{status='Completed'} $UserToken
$again = Invoke-Api 'PATCH' $patchRoute @{status='Completed'} $UserToken
Assert-Check ($completed.Status -eq 200 -and $completed.Body.status -eq 'Completed' -and
    $null -ne $completed.Body.completedAt -and $again.Body.completedAt -eq $completed.Body.completedAt) 'Completion not persisted/idempotent.'
Assert-Check ((Invoke-Api 'PATCH' $patchRoute @{status='Pending'} $TrainerToken).Status -eq 409) 'Terminal task reopened.'
$cancelled = Invoke-Api 'POST' $taskRoute $task $TrainerToken
$cancelRoute='/api/tasks/' + $cancelled.Body.id
Assert-Check ((Invoke-Api 'PATCH' $cancelRoute @{status='Cancelled'} $TrainerToken).Status -eq 200) 'Creator cannot cancel pending task.'
Assert-Check ((Invoke-Api 'PATCH' $cancelRoute @{status='Completed'} $UserToken).Status -eq 409) 'Cancelled task completed.'
foreach ($type in @('Trainer', 'Dietitian')) {
    [void] (Invoke-CheckSql "UPDATE user_advisors SET status='Ended', end_date='$today' WHERE user_id='$UserId' AND advisor_type='$type';")
    $route = if ($type -eq 'Trainer') { $planRoute } else { $goalRoute }
    $body = if ($type -eq 'Trainer') { $plan } else { $goal }
    $token = if ($type -eq 'Trainer') { $TrainerToken } else { $DietitianToken }
    Assert-Check ((Invoke-Api 'POST' $route $body $token).Status -eq 403) 'Ended advisor wrote assignment.'
    Assert-Check ((Invoke-Api 'POST' $noteRoute $note $token).Status -eq 403) 'Ended advisor wrote note.'
    [void] (Invoke-CheckSql "UPDATE user_advisors SET status='Active', end_date=NULL WHERE user_id='$UserId' AND advisor_type='$type';")
}
Write-Output 'PASS: real assignment writes, nested validation, role/client isolation, transactional replacement/concurrency, mobile reads and idempotent task completion.'
