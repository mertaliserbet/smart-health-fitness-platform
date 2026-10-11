param([string] $FirstToken, [string] $SecondToken, [string] $FirstUserId, [string] $SecondUserId)

# Disposable AuthSmoke API/PostgreSQL fixture only; coordinates are test inputs.
$path = '/api/users/me/running-activities'
function New-RunningPayload {
    $start = [DateTimeOffset]::UtcNow.AddMinutes(-2)
    return @{
        id=[Guid]::NewGuid().ToString(); startedAt=$start.ToString('o')
        endedAt=$start.AddSeconds(30).ToString('o'); durationSeconds=20
        routeData=@{type='gps-segments'; segments=@(
            ,@(
                @{latitude=41.0;longitude=29.0;accuracyMeters=5;recordedAt=$start.ToString('o')}
                @{latitude=41.0001;longitude=29.0;accuracyMeters=5;recordedAt=$start.AddSeconds(10).ToString('o')}
            )
        )}
    }
}
Assert-Check ((Invoke-Api 'GET' $path).Status -eq 401) 'Anonymous running read accepted.'
Assert-Check ((Invoke-Api 'POST' $path (New-RunningPayload)).Status -eq 401) 'Anonymous running write accepted.'
$empty = Invoke-Api 'GET' $path $null $FirstToken
Assert-Check ($empty.Status -eq 200 -and $empty.Body.Count -eq 0 -and $empty.NoStore) 'Running empty history invalid.'
$payload = New-RunningPayload
$created = Invoke-Api 'POST' $path $payload $FirstToken
Assert-Check ($created.Status -eq 201 -and $created.Body.id -eq $payload.id -and $created.NoStore) 'Running creation failed.'
Assert-Check ([Math]::Abs($created.Body.distanceMeters - 11.13) -lt 0.02 -and $created.Body.averageSpeedKmh -eq 2.00 -and $created.Body.averagePaceSecondsPerKm -eq [Math]::Round(20000 / 11.13, 2)) 'Derived running metrics invalid.'
Assert-Check ($null -eq $created.Body.estimatedCalories) 'Running calories must not be fabricated.'
$detail = Invoke-Api 'GET' "/api/running-activities/$($payload.id)" $null $FirstToken
Assert-Check ($detail.Status -eq 200 -and $detail.Body.routeData.segments[0].Count -eq 2 -and $detail.NoStore) 'Owned running detail missing.'
Assert-Check ((Invoke-Api 'GET' "/api/running-activities/$($payload.id)" $null $SecondToken).Status -eq 404) 'Running detail leaked across users.'
Assert-Check ((Invoke-Api 'GET' "/api/running-activities/$([Guid]::NewGuid())" $null $FirstToken).Status -eq 404) 'Missing running detail must return 404.'
Assert-Check ((Invoke-Api 'GET' "$path`?userId=$FirstUserId" $null $SecondToken).Body.Count -eq 0) 'Running list leaked across users.'
$history = Invoke-Api 'GET' $path $null $FirstToken
Assert-Check ($history.Body.Count -eq 1 -and $null -eq $history.Body[0].routeData) 'Running history should return route-free summaries.'
$replay = Invoke-Api 'POST' $path $payload $FirstToken
Assert-Check ($replay.Status -eq 200 -and $replay.Body.id -eq $payload.id) 'Same running retry duplicated a record.'
Assert-Check ((Invoke-Api 'POST' $path $payload $SecondToken).Status -eq 409) 'Running key ownership not checked.'
$conflict = $payload.Clone(); $conflict.durationSeconds=19
Assert-Check ((Invoke-Api 'POST' $path $conflict $FirstToken).Status -eq 409) 'Changed retry must conflict.'

$concurrent = New-RunningPayload
$requestA = New-Object Net.Http.HttpRequestMessage([Net.Http.HttpMethod]::Post, "$baseUrl$path")
$requestB = New-Object Net.Http.HttpRequestMessage([Net.Http.HttpMethod]::Post, "$baseUrl$path")
foreach ($request in @($requestA,$requestB)) {
    $request.Headers.Authorization = New-Object Net.Http.Headers.AuthenticationHeaderValue('Bearer',$FirstToken)
    $request.Content = New-JsonContent $concurrent
}
try {
    $taskA=$client.SendAsync($requestA); $taskB=$client.SendAsync($requestB)
    $responseA=$taskA.GetAwaiter().GetResult(); $responseB=$taskB.GetAwaiter().GetResult()
    Assert-Check ((@([int]$responseA.StatusCode,[int]$responseB.StatusCode) | Sort-Object) -join ',' -eq '200,201') 'Concurrent retry must create exactly one run.'
    $responseA.Dispose(); $responseB.Dispose()
} finally { $requestA.Dispose(); $requestB.Dispose() }

$segmented = New-RunningPayload
$newPoint = $segmented.routeData.segments[0][1].Clone()
$newPoint.latitude=42.0; $newPoint.recordedAt=([DateTimeOffset]::Parse($segmented.startedAt)).AddSeconds(20).ToString('o')
$segmented.routeData.segments += ,@($newPoint)
$segments = Invoke-Api 'POST' $path $segmented $FirstToken
Assert-Check ($segments.Status -eq 201 -and $segments.Body.distanceMeters -eq $created.Body.distanceMeters) 'Paused route segments must not connect.'
$stationary = New-RunningPayload
$stationary.routeData.segments = @(,@($stationary.routeData.segments[0][0]))
$zero = Invoke-Api 'POST' $path $stationary $SecondToken
Assert-Check ($zero.Status -eq 201 -and $zero.Body.distanceMeters -eq 0 -and $zero.Body.averageSpeedKmh -eq 0 -and $null -eq $zero.Body.averagePaceSecondsPerKm) 'Stationary GPS run must have zero distance and undefined pace.'
foreach ($fieldSet in @(@{id=$null},@{id=[Guid]::Empty.ToString()},@{startedAt=$null},@{endedAt=$null},
    @{endedAt='2020-01-01T00:00:00Z'},@{endedAt=[DateTimeOffset]::UtcNow.AddDays(1).ToString('o')},
    @{durationSeconds=$null},@{durationSeconds=0},@{durationSeconds=31},@{durationSeconds=86401},
    @{routeData=$null},@{userId=$SecondUserId},@{distanceMeters=999},@{averageSpeedKmh=999})) {
    $invalid=New-RunningPayload
    foreach ($key in $fieldSet.Keys) { $invalid[$key]=$fieldSet[$key] }
    $response=Invoke-Api 'POST' $path $invalid $FirstToken
    Assert-Check ($response.Status -eq 400 -and $null -ne $response.Body.errors) 'Invalid running request accepted.'
}
foreach ($pointSet in @(@{latitude=91},@{longitude=-181},@{accuracyMeters=36},@{accuracyMeters=-1},
    @{latitude=$null},@{recordedAt=$null},@{recordedAt='2020-01-01T00:00:00Z'},@{latitude=42})) {
    $invalid=New-RunningPayload
    foreach ($key in $pointSet.Keys) { $invalid.routeData.segments[0][1][$key]=$pointSet[$key] }
    Assert-Check ((Invoke-Api 'POST' $path $invalid $FirstToken).Status -eq 400) 'Invalid running GPS point accepted.'
}
foreach ($route in @(@{type='polyline';segments=@()},@{type='gps-segments';segments=@()},
    @{type='gps-segments';segments=@($null)},@{type='gps-segments';segments=@(,@())},
    @{type='gps-segments';segments=@(,@($null))})) {
    $invalid=New-RunningPayload; $invalid.routeData=$route
    Assert-Check ((Invoke-Api 'POST' $path $invalid $FirstToken).Status -eq 400) 'Invalid running segment accepted.'
}
$gap=New-RunningPayload
$gap.routeData.segments[0][1].recordedAt=([DateTimeOffset]::Parse($gap.startedAt)).AddSeconds(16).ToString('o')
Assert-Check ((Invoke-Api 'POST' $path $gap $FirstToken).Status -eq 400) 'Unsegmented GPS gap accepted.'
$outOfOrder=New-RunningPayload
$outOfOrder.routeData.segments[0][1].recordedAt=$outOfOrder.startedAt
Assert-Check ((Invoke-Api 'POST' $path $outOfOrder $FirstToken).Status -eq 400) 'Duplicate GPS timestamp accepted.'
$tooMany=New-RunningPayload
$points = @($tooMany.routeData.segments[0][0]) * 20001
$tooMany.routeData.segments=@(,$points)
Assert-Check ((Invoke-Api 'POST' $path $tooMany $FirstToken).Status -eq 400) 'Too many GPS points accepted.'

$staffId = [Guid]::NewGuid().ToString()
$staffEmail = "$staffId@example.test"
Assert-Check ((Invoke-Api 'POST' '/api/auth/register' @{firstName='Koşu';lastName='Test';email=$staffEmail;password='Running-Test-123!'}).Status -eq 201) 'Running role fixture registration failed.'
$staffId = Invoke-CheckSql "SELECT id FROM users WHERE email='$staffEmail';"
[void](Invoke-CheckSql "DELETE FROM user_roles WHERE user_id='$staffId'; INSERT INTO user_roles (id,user_id,role_id) SELECT gen_random_uuid(),'$staffId'::uuid,id FROM roles WHERE name='Trainer';")
$staff = Invoke-Api 'POST' '/api/auth/login' @{email=$staffEmail;password='Running-Test-123!'}
Assert-Check ((Invoke-Api 'POST' $path (New-RunningPayload) $staff.Body.accessToken).Status -eq 403) 'Trainer without User role may not create personal running records.'
Assert-Check ((Invoke-Api 'GET' $path $null $staff.Body.accessToken).Status -eq 403) 'Trainer without User role may not read personal running history.'
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM running_activities WHERE user_id='$FirstUserId';") -eq '3') 'Running retries created duplicate rows.'
Assert-Check ((Invoke-CheckSql "SELECT jsonb_typeof(route_data) FROM running_activities WHERE id='$($payload.id)';") -eq 'object') 'Route must be persisted as JSONB.'
Write-Output 'PASS: running GPS metrics/segments, validation, JWT/role/ownership, idempotent/concurrent writes and PostgreSQL JSONB persistence.'
