# Uses AuthSmoke's disposable API/PostgreSQL fixture and workflow helpers.
$sessionTrainer = New-WorkflowAccount 'Trainer' 'Oturum'
$sessionStranger = New-WorkflowAccount 'Trainer' 'Yetkisiz'
$sessionUser = New-WorkflowAccount 'User' 'Antrenman'
$sessionOtherUser = New-WorkflowAccount 'User' 'Başka'
$sessionToday = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
$sessionRelation = Invoke-Api 'POST' '/api/user-advisors' @{ userId = $sessionUser.Id; advisorId = $sessionTrainer.Id;
    advisorType = 'Trainer'; startDate = $sessionToday } $adminToken
Assert-Check ($sessionRelation.Status -eq 201) 'Session fixture relation failed.'
$sessionCatalog = Invoke-Api 'POST' '/api/exercises' @{ name = 'Session Press'; isActive = $true } $adminToken
Assert-Check ($sessionCatalog.Status -eq 201) 'Session fixture exercise failed.'
$sessionCatalogId = $sessionCatalog.Body.id
function New-SessionPlan {
    return @{ name = 'Session Plan'; description = $null; startDate = $sessionToday; endDate = $null; days = @(
        @{ name = 'Kuvvet'; dayNumber = 1; weekday = 'Monday'; exercises = @(
            @{ exerciseId = $sessionCatalogId; order = 1; sets = 3; reps = 10; weightKg = 0 },
            @{ exerciseId = $sessionCatalogId; order = 2; durationSeconds = 30 }) },
        @{ name = 'Diğer gün'; dayNumber = 2; weekday = 'Wednesday'; exercises = @(
            @{ exerciseId = $sessionCatalogId; order = 1; durationSeconds = 60 }) }) }
}
function Send-SessionRequest([string] $Method, [string] $Path, $Body, [string] $Token) {
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($Method), $baseUrl + $Path)
    if ($null -ne $Body) { $request.Content = New-JsonContent $Body }
    $request.Headers.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token)
    return @{ Request = $request; Task = $client.SendAsync($request) }
}
$sessionPlansPath = '/api/users/' + $sessionUser.Id + '/workout-plans'
$sessionPlan = Invoke-Api 'POST' $sessionPlansPath (New-SessionPlan) $sessionTrainer.Token
Assert-Check ($sessionPlan.Status -eq 201 -and !$sessionPlan.Body.hasSessions) 'Session fixture plan failed.'
$sessionStart = @{ workoutPlanId = $sessionPlan.Body.id; workoutDayId = $sessionPlan.Body.days[0].id }
$sessionHistory = '/api/users/' + $sessionUser.Id + '/workout-sessions'
Assert-Check ((Invoke-Api 'GET' $sessionHistory $null $sessionTrainer.Token).Body.totalCount -eq 0) 'New client history is not empty.'
foreach ($invalid in @(@{}, @{ workoutPlanId = [Guid]::Empty; workoutDayId = [Guid]::Empty },
    @{ workoutPlanId = 'bad'; workoutDayId = $sessionStart.workoutDayId },
    @{ workoutPlanId = $sessionStart.workoutPlanId; workoutDayId = $sessionStart.workoutDayId; userId = $sessionOtherUser.Id })) {
    $bad = Invoke-Api 'POST' '/api/workout-sessions' $invalid $sessionUser.Token
    Assert-Check ($bad.Status -eq 400 -and $null -ne $bad.Body.errors) 'Invalid/spoofed session start accepted.'
}
Assert-Check ((Invoke-Api 'POST' '/api/workout-sessions' $sessionStart $sessionOtherUser.Token).Status -eq 404) 'Foreign plan session accepted.'
$unknownStart = $sessionStart.Clone(); $unknownStart.workoutDayId = [Guid]::NewGuid()
Assert-Check ((Invoke-Api 'POST' '/api/workout-sessions' $unknownStart $sessionUser.Token).Status -eq 404) 'Missing day session accepted.'

$startA = Send-SessionRequest 'POST' '/api/workout-sessions' $sessionStart $sessionUser.Token
$startB = Send-SessionRequest 'POST' '/api/workout-sessions' $sessionStart $sessionUser.Token
$startedA = Complete-WorkflowPost $startA; $startedB = Complete-WorkflowPost $startB
Assert-Check ((@($startedA.Status, $startedB.Status) | Sort-Object) -join ',' -eq '200,201') 'Concurrent start must create one session.'
Assert-Check ($startedA.Body.id -eq $startedB.Body.id -and $startedA.Body.startedAt -ceq $startedB.Body.startedAt -and $startedA.NoStore) 'Start retry changed ID/time or lacks no-store.'
$sessionId = $startedA.Body.id; $sessionPath = '/api/workout-sessions/' + $sessionId
$setsId = $sessionPlan.Body.days[0].exercises[0].id; $timedId = $sessionPlan.Body.days[0].exercises[1].id
$otherDayId = $sessionPlan.Body.days[1].exercises[0].id
$logPath = $sessionPath + '/exercises/' + $setsId
$logBody = @{ completedSets = 2; completedReps = 8; weightKg = 0; durationSeconds = $null; isCompleted = $true; notes = '  İyi geçti  ' }
foreach ($path in @('/api/users/me/workout-sessions', $sessionPath, $sessionHistory)) {
    Assert-Check ((Invoke-Api 'GET' $path).Status -eq 401) 'Anonymous history/detail accepted.'
}
foreach ($write in @(@{ Method = 'POST'; Path = '/api/workout-sessions'; Body = $sessionStart },
    @{ Method = 'PUT'; Path = $logPath; Body = $logBody }, @{ Method = 'POST'; Path = $sessionPath + '/complete'; Body = $null },
    @{ Method = 'POST'; Path = $sessionPath + '/cancel'; Body = $null })) {
    Assert-Check ((Invoke-Api $write.Method $write.Path $write.Body).Status -eq 401) 'Anonymous session write accepted.'
    foreach ($token in @($sessionTrainer.Token, $dietitian.Token, $adminToken)) {
        Assert-Check ((Invoke-Api $write.Method $write.Path $write.Body $token).Status -eq 403) 'Staff can write User workout.'
    }
}
foreach ($token in @($dietitian.Token, $adminToken)) {
    Assert-Check ((Invoke-Api 'GET' $sessionPath $null $token).Status -eq 403) 'Dietitian/Admin can read session.'
    Assert-Check ((Invoke-Api 'GET' $sessionHistory $null $token).Status -eq 403) 'Dietitian/Admin can read history.'
}
Assert-Check ((Invoke-Api 'GET' $sessionPath $null $sessionOtherUser.Token).Status -eq 404) 'Foreign User session exposed.'
Assert-Check ((Invoke-Api 'GET' $sessionPath $null $sessionStranger.Token).Status -eq 404) 'Unassigned Trainer session exposed.'
Assert-Check ((Invoke-Api 'GET' $sessionHistory $null $sessionStranger.Token).Status -eq 403) 'Unassigned Trainer history exposed.'
foreach ($suffix in @('/complete', '/cancel')) {
    Assert-Check ((Invoke-Api 'POST' ($sessionPath + $suffix) $null $sessionOtherUser.Token).Status -eq 404) 'Foreign terminal write accepted.'
}
Assert-Check ((Invoke-Api 'PUT' $logPath $logBody $sessionOtherUser.Token).Status -eq 404) 'Foreign log accepted.'
foreach ($wrongItem in @($otherDayId, $sessionCatalogId, [Guid]::NewGuid().ToString())) {
    Assert-Check ((Invoke-Api 'PUT' ($sessionPath + '/exercises/' + $wrongItem) $logBody $sessionUser.Token).Status -eq 404) 'Non-session exercise log accepted.'
}
foreach ($case in @('missingFlag','negative','precision','tooLarge','wrongMode','zeroCompleted','spoof','notes')) {
    $bad = $logBody.Clone()
    switch ($case) {
        'missingFlag' { $bad.Remove('isCompleted') }
        'negative' { $bad.completedReps = -1 }
        'precision' { $bad.weightKg = 0.001 }
        'tooLarge' { $bad.weightKg = 100000000 }
        'wrongMode' { $bad.durationSeconds = 30 }
        'zeroCompleted' { $bad.completedSets = 0 }
        'spoof' { $bad.workoutExerciseId = $otherDayId }
        'notes' { $bad.notes = 'x' * 10001 }
    }
    $invalid = Invoke-Api 'PUT' $logPath $bad $sessionUser.Token
    Assert-Check ($invalid.Status -eq 400 -and $null -ne $invalid.Body.errors) "Invalid log accepted: $case."
}
$logA = Send-SessionRequest 'PUT' $logPath $logBody $sessionUser.Token
$logB = Send-SessionRequest 'PUT' $logPath $logBody $sessionUser.Token
$savedA = Complete-WorkflowPost $logA; $savedB = Complete-WorkflowPost $logB
Assert-Check ($savedA.Status -eq 200 -and $savedB.Status -eq 200 -and $savedA.Body.id -eq $savedB.Body.id -and
    $savedA.Body.createdAt -ceq $savedB.Body.createdAt -and $savedA.Body.weightKg -eq 0 -and $savedA.Body.notes -ceq 'İyi geçti') "Concurrent log upsert lost ID/time/zero/note (statuses $($savedA.Status), $($savedB.Status))."
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM workout_logs WHERE workout_session_id = '$sessionId';") -eq '1') 'Log duplicate persisted.'
$otherStart = $sessionStart.Clone(); $otherStart.workoutDayId = $sessionPlan.Body.days[1].id
Assert-Check ((Invoke-Api 'POST' '/api/workout-sessions' $otherStart $sessionUser.Token).Status -eq 409) 'Second active day started.'
$frozenPlan = (Invoke-Api 'GET' ('/api/workout-plans/' + $sessionPlan.Body.id) $null $sessionTrainer.Token).Body
$frozenEdit = New-SessionPlan; $frozenEdit.expectedUpdatedAt = $frozenPlan.updatedAt
Assert-Check ($frozenPlan.hasSessions -and (Invoke-Api 'PUT' ('/api/workout-plans/' + $sessionPlan.Body.id) $frozenEdit $sessionTrainer.Token).Status -eq 409) 'Plan with sessions was edited.'
$finished = Invoke-Api 'POST' ($sessionPath + '/complete') $null $sessionUser.Token
$retryFinish = Invoke-Api 'POST' ($sessionPath + '/complete') $null $sessionUser.Token
Assert-Check ($finished.Status -eq 200 -and $finished.Body.status -ceq 'Completed' -and $finished.Body.logs.Count -eq 1 -and
    $finished.Body.completedAt -ceq $retryFinish.Body.completedAt) 'Partial session completion/retry failed.'
Assert-Check ((Invoke-Api 'PUT' $logPath $logBody $sessionUser.Token).Status -eq 409) 'Completed log changed.'
Assert-Check ((Invoke-Api 'POST' ($sessionPath + '/cancel') $null $sessionUser.Token).Status -eq 409) 'Completed session cancelled.'
$trainerDetail = Invoke-Api 'GET' $sessionPath $null $sessionTrainer.Token
Assert-Check ($trainerDetail.Status -eq 200 -and $trainerDetail.Body.day.exercises.Count -eq 2 -and $trainerDetail.Body.logs[0].completedSets -eq 2) 'Trainer detail lost prescriptions/actuals.'
$history = Invoke-Api 'GET' ($sessionHistory + '?pageSize=1&status=Completed') $null $sessionTrainer.Token
Assert-Check ($history.Status -eq 200 -and $history.NoStore -and $history.Body.items[0].completedExerciseCount -eq 1 -and $history.Body.items[0].totalExerciseCount -eq 2) 'Trainer summary falsely completes all exercises.'
foreach ($query in @('page=0','pageSize=101','page=1000001','status=completed','status=Planned','page=bad')) {
    Assert-Check ((Invoke-Api 'GET' ($sessionHistory + '?' + $query) $null $sessionTrainer.Token).Status -eq 400) 'Invalid history query accepted.'
}
$ownHistory = Invoke-Api 'GET' ('/api/users/me/workout-sessions?userId=' + $sessionOtherUser.Id) $null $sessionUser.Token
Assert-Check ($ownHistory.Body.totalCount -eq 1 -and $ownHistory.Body.items[0].userId -eq $sessionUser.Id) 'History query spoofing leaked another user.'

# Replacing a program must preserve, and allow finishing, its already-open session.
$oldOpen = Invoke-Api 'POST' '/api/workout-sessions' $sessionStart $sessionUser.Token
$replacement = Invoke-Api 'POST' $sessionPlansPath (New-SessionPlan) $sessionTrainer.Token
Assert-Check ($oldOpen.Status -eq 201 -and $replacement.Status -eq 201) 'Replacement fixture failed.'
Assert-Check ((Invoke-Api 'POST' '/api/workout-sessions' $sessionStart $sessionUser.Token).Body.id -eq $oldOpen.Body.id) 'Replacement broke resume.'
$timeBody = @{ durationSeconds = 20; isCompleted = $true; notes = 'Süre' }
Assert-Check ((Invoke-Api 'PUT' ('/api/workout-sessions/' + $oldOpen.Body.id + '/exercises/' + $timedId) $logBody $sessionUser.Token).Status -eq 400) 'Timed exercise accepts set/reps.'
Assert-Check ((Invoke-Api 'PUT' ('/api/workout-sessions/' + $oldOpen.Body.id + '/exercises/' + $timedId) $timeBody $sessionUser.Token).Status -eq 200) 'Inactive plan open log failed.'
Assert-Check ((Invoke-Api 'POST' ('/api/workout-sessions/' + $oldOpen.Body.id + '/complete') $null $sessionUser.Token).Status -eq 200) 'Old open session could not finish.'
Assert-Check ((Invoke-Api 'POST' '/api/workout-sessions' $sessionStart $sessionUser.Token).Status -eq 409) 'Historical plan started again.'
$newStart = @{ workoutPlanId = $replacement.Body.id; workoutDayId = $replacement.Body.days[0].id }
$cancelOpen = Invoke-Api 'POST' '/api/workout-sessions' $newStart $sessionUser.Token
$cancelPath = '/api/workout-sessions/' + $cancelOpen.Body.id
$incompleteBody = @{ completedSets = 0; completedReps = $null; isCompleted = $false }
Assert-Check ((Invoke-Api 'PUT' ($cancelPath + '/exercises/' + $replacement.Body.days[0].exercises[0].id) $incompleteBody $sessionUser.Token).Status -eq 200) 'Incomplete log rejected.'
$cancel = Invoke-Api 'POST' ($cancelPath + '/cancel') $null $sessionUser.Token
Assert-Check ($cancel.Status -eq 200 -and $cancel.Body.status -ceq 'Cancelled' -and $null -eq $cancel.Body.completedAt -and $cancel.Body.logs.Count -eq 1) 'Cancel erased log.'
Assert-Check ((Invoke-Api 'POST' ($cancelPath + '/cancel') $null $sessionUser.Token).Status -eq 200) 'Cancel retry failed.'
Assert-Check ((Invoke-Api 'POST' ($cancelPath + '/complete') $null $sessionUser.Token).Status -eq 409) 'Cancelled session completed.'
Assert-Check ((Invoke-Api 'PUT' ($cancelPath + '/exercises/' + $replacement.Body.days[0].exercises[0].id) $logBody $sessionUser.Token).Status -eq 409) 'Cancelled log changed.'
$paged = Invoke-Api 'GET' ($sessionHistory + '?page=2&pageSize=1') $null $sessionTrainer.Token
Assert-Check ($paged.Body.totalPages -eq 3 -and $paged.Body.items.Count -eq 1 -and $paged.Body.items[0].id -eq $oldOpen.Body.id) 'History paging/order failed.'
foreach ($boundary in @('future','expired')) {
    $datedPlan = New-SessionPlan
    if ($boundary -eq 'future') { $datedPlan.startDate = [DateTime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd') }
    else { $datedPlan.startDate = [DateTime]::UtcNow.AddDays(-2).ToString('yyyy-MM-dd'); $datedPlan.endDate = [DateTime]::UtcNow.AddDays(-1).ToString('yyyy-MM-dd') }
    $dated = Invoke-Api 'POST' $sessionPlansPath $datedPlan $sessionTrainer.Token
    Assert-Check ((Invoke-Api 'POST' '/api/workout-sessions' @{ workoutPlanId = $dated.Body.id; workoutDayId = $dated.Body.days[0].id } $sessionUser.Token).Status -eq 409) 'Out-of-date plan session started.'
}

# Start and edit race: the user lock permits either complete edit-before-start or edit rejection.
$racePlan = Invoke-Api 'POST' $sessionPlansPath (New-SessionPlan) $sessionTrainer.Token
$raceEdit = New-SessionPlan; $raceEdit.expectedUpdatedAt = $null
for ($i = 0; $i -lt $raceEdit.days.Count; $i++) {
    $raceEdit.days[$i].id = $racePlan.Body.days[$i].id
    for ($j = 0; $j -lt $raceEdit.days[$i].exercises.Count; $j++) { $raceEdit.days[$i].exercises[$j].id = $racePlan.Body.days[$i].exercises[$j].id }
}
$raceEdit.days[0].exercises[0].reps = 12
$editPending = Send-SessionRequest 'PUT' ('/api/workout-plans/' + $racePlan.Body.id) $raceEdit $sessionTrainer.Token
$startPending = Send-SessionRequest 'POST' '/api/workout-sessions' @{ workoutPlanId = $racePlan.Body.id; workoutDayId = $racePlan.Body.days[0].id } $sessionUser.Token
$raceEdited = Complete-WorkflowPost $editPending; $raceStarted = Complete-WorkflowPost $startPending
Assert-Check ($raceStarted.Status -eq 201 -and $raceEdited.Status -in @(200,409)) 'Concurrent start/edit failed or erased history.'
$expectedReps = if ($raceEdited.Status -eq 200) { 12 } else { 10 }
Assert-Check ($raceStarted.Body.day.exercises[0].reps -eq $expectedReps) 'Start used a partially edited prescription.'
$raceFinish = '/api/workout-sessions/' + $raceStarted.Body.id
$logPending = Send-SessionRequest 'PUT' ($raceFinish + '/exercises/' + $racePlan.Body.days[0].exercises[0].id) $logBody $sessionUser.Token
$finishPending = Send-SessionRequest 'POST' ($raceFinish + '/complete') $null $sessionUser.Token
$raceLog = Complete-WorkflowPost $logPending; $raceCompleted = Complete-WorkflowPost $finishPending
Assert-Check ($raceCompleted.Status -eq 200 -and $raceLog.Status -in @(200,409)) 'Concurrent log/complete failed.'
$raceRead = Invoke-Api 'GET' $raceFinish $null $sessionUser.Token
Assert-Check ($raceRead.Body.logs.Count -eq $(if ($raceLog.Status -eq 200) { 1 } else { 0 })) 'Late log mutated terminal session.'

# Ended/inactive relationships lose Trainer access while the user's own history survives.
Assert-Check ((Invoke-Api 'PATCH' ('/api/user-advisors/' + $sessionRelation.Body.userAdvisorId) @{ status = 'Ended'; endDate = $sessionToday } $adminToken).Status -eq 200) 'Session relation ending failed.'
Assert-Check ((Invoke-Api 'GET' $sessionHistory $null $sessionTrainer.Token).Status -eq 403 -and
    (Invoke-Api 'GET' $sessionPath $null $sessionTrainer.Token).Status -eq 404 -and
    (Invoke-Api 'GET' $sessionPath $null $sessionUser.Token).Status -eq 200) 'Ended relationship access/history incorrect.'
$nextRelation = Invoke-Api 'POST' '/api/user-advisors' @{ userId = $sessionUser.Id; advisorId = $sessionStranger.Id; advisorType = 'Trainer'; startDate = $sessionToday } $adminToken
Assert-Check ($nextRelation.Status -eq 201 -and (Invoke-Api 'GET' $sessionPath $null $sessionStranger.Token).Status -eq 200) 'New assigned Trainer cannot read past sessions.'
[void](Invoke-CheckSql "UPDATE users SET is_active = false WHERE id = '$($sessionUser.Id)';")
Assert-Check ((Invoke-Api 'GET' $sessionHistory $null $sessionStranger.Token).Status -eq 403 -and
    (Invoke-Api 'GET' $sessionPath $null $sessionStranger.Token).Status -eq 404 -and
    (Invoke-Api 'GET' '/api/users/me/workout-sessions' $null $sessionUser.Token).Status -eq 401) 'Inactive client workout access accepted.'
Write-Output 'PASS: workout sessions/logs, User/Trainer isolation, real persistence, retry/concurrent start/log/complete/edit, partial progress, frozen history, replacement, paging and ended/inactive relationships.'
