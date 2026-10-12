# Uses AuthSmoke's disposable API/PostgreSQL fixture and workflow helpers.
$editTrainer = New-WorkflowAccount 'Trainer' 'Program'
$editOtherTrainer = New-WorkflowAccount 'Trainer' 'Diğer'
$editUser = New-WorkflowAccount 'User' 'Düzenleme'
$editUserId = $editUser.Id
$editToday = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
$editRelations = @()
foreach ($staff in @($editTrainer, $editOtherTrainer)) {
    $created = Invoke-Api 'POST' '/api/user-advisors' @{ userId = $editUserId; advisorId = $staff.Id;
        advisorType = 'Trainer'; startDate = $editToday } $adminToken
    Assert-Check ($created.Status -eq 201) 'Edit fixture relation failed.'
    $editRelations += $created.Body.userAdvisorId
}
$editCatalogBody = @{ name = 'Edit Exercise'; description = $null; instructions = $null;
    videoUrl = $null; imageUrl = $null; isActive = $true }
$editCatalog = Invoke-Api 'POST' '/api/exercises' $editCatalogBody $adminToken
$editExerciseId = $editCatalog.Body.id
$editCreate = @{ name = 'Original'; description = 'Original description'; startDate = $editToday; endDate = $null;
    days = @(@{ name = 'First'; dayNumber = 1; weekday = 'Monday'; description = 'Day note'; exercises = @(
        @{ exerciseId = $editExerciseId; order = 1; sets = 3; reps = 10; durationSeconds = $null; restSeconds = 60; weightKg = 0; notes = $null },
        @{ exerciseId = $editExerciseId; order = 2; sets = $null; reps = $null; durationSeconds = 30; restSeconds = 0; weightKg = $null; notes = 'Timed' }
    ) }) }
$editCreated = Invoke-Api 'POST' ('/api/users/' + $editUserId + '/workout-plans') $editCreate $editTrainer.Token
Assert-Check ($editCreated.Status -eq 201) 'Edit fixture plan failed.'
$editPlanId = $editCreated.Body.id
$editPath = '/api/workout-plans/' + $editPlanId
function Get-EditRequest {
    $plan = (Invoke-Api 'GET' $editPath $null $editTrainer.Token).Body
    return @{ name = $plan.name; description = $plan.description; startDate = $plan.startDate; endDate = $plan.endDate;
        expectedUpdatedAt = $plan.updatedAt; days = @($plan.days | ForEach-Object {
            @{ id = $_.id; name = $_.name; dayNumber = $_.dayNumber; weekday = $_.weekday; description = $_.description;
                exercises = @($_.exercises | ForEach-Object {
                    @{ id = $_.id; exerciseId = $_.exerciseId; order = $_.order; sets = $_.sets; reps = $_.reps;
                        durationSeconds = $_.durationSeconds; restSeconds = $_.restSeconds; weightKg = $_.weightKg; notes = $_.notes }
                }) }
        }) }
}
$editRequest = Get-EditRequest
Assert-Check ((Invoke-Api 'PUT' $editPath $editRequest).Status -eq 401) 'Anonymous plan edit accepted.'
foreach ($token in @($editUser.Token, $dietitian.Token, $adminToken)) {
    Assert-Check ((Invoke-Api 'PUT' $editPath $editRequest $token).Status -eq 403) 'Non-Trainer plan edit accepted.'
}
Assert-Check ((Invoke-Api 'PUT' $editPath $editRequest $editOtherTrainer.Token).Status -eq 404) 'Assigned non-creator edited plan.'
Assert-Check ((Invoke-Api 'PUT' ('/api/workout-plans/' + [Guid]::NewGuid()) $editRequest $editTrainer.Token).Status -eq 404) 'Missing plan edit not hidden.'
$editBefore = ((Invoke-Api 'GET' $editPath $null $editUser.Token).Body | ConvertTo-Json -Depth 12 -Compress)
foreach ($case in @('missingRevision', 'spoofUser', 'unknownItemField', 'emptyDays', 'nullDay', 'nullExercise',
    'duplicateWeekday', 'duplicateNumber', 'duplicateOrder', 'missingTarget', 'mixedTarget', 'precision', 'dates',
    'foreignDay', 'foreignItem', 'duplicateItem', 'wrongExercise', 'emptyId', 'nullExerciseList', 'emptyName')) {
    $bad = Get-EditRequest
    switch ($case) {
        'missingRevision' { $bad.Remove('expectedUpdatedAt') }
        'spoofUser' { $bad.userId = [Guid]::NewGuid().ToString() }
        'unknownItemField' { $bad.days[0].exercises[0].trainerId = $editTrainer.Id }
        'emptyDays' { $bad.days = @() }
        'nullDay' { $bad.days = @($null) }
        'nullExercise' { $bad.days[0].exercises = @($null) }
        'duplicateWeekday' { $day = (Get-EditRequest).days[0]; $day.dayNumber = 2; $bad.days += $day }
        'duplicateNumber' { $day = (Get-EditRequest).days[0]; $day.weekday = 'Tuesday'; $bad.days += $day }
        'duplicateOrder' { $bad.days[0].exercises[1].order = 1 }
        'missingTarget' { $bad.days[0].exercises[0].sets = $null }
        'mixedTarget' { $bad.days[0].exercises[0].durationSeconds = 10 }
        'precision' { $bad.days[0].exercises[0].weightKg = 0.001 }
        'dates' { $bad.endDate = '2020-01-01' }
        'foreignDay' { $bad.days[0].id = [Guid]::NewGuid().ToString() }
        'foreignItem' { $bad.days[0].exercises[0].id = [Guid]::NewGuid().ToString() }
        'duplicateItem' { $bad.days[0].exercises[1].id = $bad.days[0].exercises[0].id }
        'wrongExercise' { $bad.days[0].exercises[0].exerciseId = [Guid]::NewGuid().ToString() }
        'emptyId' { $bad.days[0].id = [Guid]::Empty.ToString() }
        'nullExerciseList' { $bad.days[0].exercises = $null }
        'emptyName' { $bad.name = '   ' }
    }
    $badResponse = Invoke-Api 'PUT' $editPath $bad $editTrainer.Token
    Assert-Check ($badResponse.Status -eq 400 -and $null -ne $badResponse.Body.errors) "Invalid edit accepted: $case (status $($badResponse.Status))"
}
Assert-Check (((Invoke-Api 'GET' $editPath $null $editUser.Token).Body | ConvertTo-Json -Depth 12 -Compress) -eq $editBefore) 'Rejected edit changed persisted plan.'
$editRequest.name = '  Updated  '
$editRequest.days[0].exercises = @($editRequest.days[0].exercises[1], $editRequest.days[0].exercises[0])
$editRequest.days[0].exercises[0].order = 1; $editRequest.days[0].exercises[1].order = 2
$edited = Invoke-Api 'PUT' $editPath $editRequest $editTrainer.Token
Assert-Check ($edited.Status -eq 200 -and $edited.NoStore -and $edited.Body.name -ceq 'Updated' -and
    $null -ne $edited.Body.updatedAt -and $edited.Body.days[0].id -eq $editCreated.Body.days[0].id -and
    $edited.Body.days[0].exercises[0].id -eq $editCreated.Body.days[0].exercises[1].id) "Edit/reorder did not retain IDs or revision (status $($edited.Status))."
Assert-Check ((Invoke-Api 'PUT' $editPath $editRequest $editTrainer.Token).Status -eq 409) 'Stale edit overwrote newer plan.'

# Seven weekdays, then reverse all weekday/order assignments; no spare weekday slot exists.
$editWeekdays = @('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')
$seven = Get-EditRequest
for ($index = 1; $index -lt 7; $index++) {
    $day = (Get-EditRequest).days[0]; $day.id = $null; $day.dayNumber = $index + 1; $day.weekday = $editWeekdays[$index]
    foreach ($item in $day.exercises) { $item.id = $null }
    $seven.days += $day
}
Assert-Check ((Invoke-Api 'PUT' $editPath $seven $editTrainer.Token).Status -eq 200) 'Adding days failed.'
$swapped = Get-EditRequest
$retainedIds = ($swapped.days.id | Sort-Object) -join ','
for ($index = 0; $index -lt 7; $index++) { $swapped.days[$index].weekday = $editWeekdays[6-$index]; $swapped.days[$index].dayNumber = 7-$index }
$swapResponse = Invoke-Api 'PUT' $editPath $swapped $editTrainer.Token
Assert-Check ($swapResponse.Status -eq 200 -and (($swapResponse.Body.days.id | Sort-Object) -join ',') -eq $retainedIds) 'Weekday/number swap violated unique indexes or lost IDs.'
$removedIds = @($swapResponse.Body.days | Select-Object -Skip 1 | ForEach-Object { $_.id })
$shorter = Get-EditRequest; $shorter.days = @($shorter.days[0]); $shorter.days[0].dayNumber = 1
$shorter.days[0].exercises = @($shorter.days[0].exercises[0])
Assert-Check ((Invoke-Api 'PUT' $editPath $shorter $editTrainer.Token).Status -eq 200) 'Removing days/items failed.'
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM workout_days WHERE workout_plan_id = '$editPlanId';") -eq '1') 'Removed days remain in DB.'
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM workout_exercises e JOIN workout_days d ON d.id = e.workout_day_id WHERE d.workout_plan_id = '$editPlanId';") -eq '1') 'Removed exercises remain in DB.'
$resurrect = Get-EditRequest; $resurrect.days[0].id = $removedIds[0]
Assert-Check ((Invoke-Api 'PUT' $editPath $resurrect $editTrainer.Token).Status -eq 400) 'Deleted day ID resurrected.'

$editCatalogBody.isActive = $false
[void] (Invoke-Api 'PUT' ('/api/exercises/' + $editExerciseId) $editCatalogBody $adminToken)
$keepInactive = Get-EditRequest; $keepInactive.name = 'Keep existing exercise'
Assert-Check ((Invoke-Api 'PUT' $editPath $keepInactive $editTrainer.Token).Status -eq 200) 'Retained inactive exercise prevents unrelated edit.'
$newInactive = Get-EditRequest; $newInactive.days[0].exercises[0].id = $null
Assert-Check ((Invoke-Api 'PUT' $editPath $newInactive $editTrainer.Token).Status -eq 400) 'New inactive exercise assignment accepted.'
$editCatalogBody.isActive = $true
[void] (Invoke-Api 'PUT' ('/api/exercises/' + $editExerciseId) $editCatalogBody $adminToken)

function Send-Edit($Body) {
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Put, $baseUrl + $editPath)
    $request.Content = New-JsonContent $Body
    $request.Headers.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $editTrainer.Token)
    return @{ Request = $request; Task = $client.SendAsync($request) }
}
$raceRequest = Get-EditRequest
$raceA = Send-Edit $raceRequest; $raceB = Send-Edit $raceRequest
$raceResults = @((Complete-WorkflowPost $raceA), (Complete-WorkflowPost $raceB))
Assert-Check ((($raceResults.Status | Sort-Object) -join ',') -eq '200,409') 'Concurrent edits must have one winner.'
$mobileEdit = Invoke-Api 'GET' $editPath $null $editUser.Token
Assert-Check ($mobileEdit.Status -eq 200 -and $mobileEdit.Body.id -eq $editPlanId -and $mobileEdit.Body.name -eq 'Keep existing exercise') 'Mobile detail incompatible after edit.'
Assert-Check ((Invoke-Api 'GET' '/api/users/me/workout-plans' $null $editUser.Token).Body[0].id -eq $editPlanId) 'Edit created a duplicate plan.'
Assert-Check ((Invoke-Api 'GET' '/api/users/me/workout-plans' $null $editUser.Token).Body[0].name -eq 'Keep existing exercise') 'Mobile summary did not reflect edited name.'
$noAccess = Get-EditRequest
[void] (Invoke-CheckSql "UPDATE users SET is_active = false WHERE id = '$editUserId';")
Assert-Check ((Invoke-Api 'PUT' $editPath $noAccess $editTrainer.Token).Status -eq 403) 'Inactive client edited.'
[void] (Invoke-CheckSql "UPDATE users SET is_active = true WHERE id = '$editUserId';")
[void] (Invoke-Api 'PATCH' ('/api/user-advisors/' + $editRelations[0]) @{ status = 'Ended'; endDate = $editToday } $adminToken)
Assert-Check ((Invoke-Api 'PUT' $editPath $noAccess $editTrainer.Token).Status -eq 403) 'Ended creator relation retained edit access.'
# The second assigned Trainer may create a new plan, but cannot edit the old creator's plan.
$replacement = Invoke-Api 'POST' ('/api/users/' + $editUserId + '/workout-plans') $editCreate $editOtherTrainer.Token
$history = Invoke-Api 'GET' $editPath $null $editUser.Token
Assert-Check ($replacement.Status -eq 201 -and -not $history.Body.isActive -and $history.Body.name -eq 'Keep existing exercise') 'Replacement lost edited history.'
$restoreRelation = Invoke-Api 'POST' '/api/user-advisors' @{ userId = $editUserId; advisorId = $editTrainer.Id; advisorType = 'Trainer'; startDate = $editToday } $adminToken
Assert-Check ($restoreRelation.Status -eq 201 -and (Invoke-Api 'PUT' $editPath $noAccess $editTrainer.Token).Status -eq 409) 'Historical plan editable.'
Write-Output 'PASS: WorkoutPlan editing, stable IDs, seven-day/order swaps, validation/rollback, inactive catalog, creator/client authorization, stale/concurrent edits and mobile reads.'
