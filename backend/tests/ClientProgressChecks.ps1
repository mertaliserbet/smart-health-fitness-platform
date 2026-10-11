# Runs inside AdvisorWorkflowChecks / AuthSmoke's disposable PostgreSQL/API fixture.
$progressTrainer = New-WorkflowAccount 'Trainer' 'İlerleme antrenörü'
$progressDietitian = New-WorkflowAccount 'Dietitian' 'İlerleme diyetisyeni'
$progressUser = New-WorkflowAccount 'User' 'İlerleme danışanı'
$progressId = $progressUser.Id
$progressPaths = @(('/api/users/' + $progressId + '/weight-records'), ('/api/users/' + $progressId + '/body-measurements'))
foreach ($path in $progressPaths) {
    Assert-Check ((Invoke-Api 'GET' $path).Status -eq 401) 'Anonymous progress access accepted.'
    foreach ($token in @($progressUser.Token, $AdminToken)) {
        Assert-Check ((Invoke-Api 'GET' $path $null $token).Status -eq 403) 'User/Admin can read advisor progress.'
    }
    Assert-Check ((Invoke-Api 'GET' $path $null $progressTrainer.Token).Status -eq 403) 'Unassigned advisor can read progress.'
}
$progressRelations = @()
foreach ($staff in @(@{ Account = $progressTrainer; Type = 'Trainer' }, @{ Account = $progressDietitian; Type = 'Dietitian' })) {
    $relation = Invoke-Api 'POST' '/api/user-advisors' @{ userId = $progressId; advisorId = $staff.Account.Id; advisorType = $staff.Type; startDate = $today } $AdminToken
    Assert-Check ($relation.Status -eq 201) 'Progress relation setup failed.'
    $progressRelations += $relation.Body.userAdvisorId
    foreach ($path in $progressPaths) {
        $empty = Invoke-Api 'GET' $path $null $staff.Account.Token
        Assert-Check ($empty.Status -eq 200 -and @($empty.Body).Count -eq 0 -and $empty.NoStore) 'Empty advisor progress is invalid or cacheable.'
    }
}
$recent = [DateTimeOffset]::UtcNow.AddDays(-1).ToString('o')
$old = [DateTimeOffset]::UtcNow.AddDays(-120).ToString('o')
foreach ($record in @(@{ weightKg = 84.25; recordedAt = $old }, @{ weightKg = 82.5; recordedAt = $recent })) {
    Assert-Check ((Invoke-Api 'POST' '/api/users/me/weight-records' $record $progressUser.Token).Status -eq 201) 'Progress weight fixture failed.'
}
foreach ($record in @(@{ waistCm = 90.25; chestCm = 100; recordedAt = $old }, @{ waistCm = 88; bodyFatPercentage = 0; recordedAt = $recent })) {
    Assert-Check ((Invoke-Api 'POST' '/api/users/me/body-measurements' $record $progressUser.Token).Status -eq 201) 'Progress body fixture failed.'
}
foreach ($index in 0..1) {
    $path = $progressPaths[$index]
    $selfPath = if ($index -eq 0) { '/api/users/me/weight-records' } else { '/api/users/me/body-measurements' }
    $self = Invoke-Api 'GET' $selfPath $null $progressUser.Token
    foreach ($staff in @($progressTrainer, $progressDietitian)) {
        $history = Invoke-Api 'GET' $path $null $staff.Token
        Assert-Check ($history.Status -eq 200 -and $history.NoStore -and $history.Body.Count -eq 2) 'Advisor progress failed.'
        Assert-Check (($history.Body | ConvertTo-Json -Depth 8 -Compress) -eq ($self.Body | ConvertTo-Json -Depth 8 -Compress)) 'Advisor DTO/order differs from self tracking.'
        $spoof = Invoke-Api 'GET' ($path + '?userId=' + $OtherUserId + '&advisorId=' + $admin.Id + '&from=2099-01-01') $null $staff.Token
        Assert-Check ($spoof.Status -eq 200 -and $spoof.Body[0].id -eq $self.Body[0].id -and $spoof.Body.Count -eq 2) 'Query injection changed progress ownership or undocumented filtering.'
        Assert-Check ((Invoke-Api 'GET' ('/api/users/' + $OtherUserId + $(if ($index -eq 0) { '/weight-records' } else { '/body-measurements' })) $null $staff.Token).Status -eq 403) 'Other client progress exposed.'
    }
    foreach ($method in @('POST', 'PUT', 'DELETE')) {
        Assert-Check ((Invoke-Api $method $path @{ weightKg = 70; waistCm = 70; recordedAt = $recent } $progressTrainer.Token).Status -eq 405) 'Advisor tracking write route exists.'
    }
}
$partial = (Invoke-Api 'GET' $progressPaths[1] $null $progressTrainer.Token).Body[0]
Assert-Check ($partial.waistCm -eq 88 -and $partial.bodyFatPercentage -eq 0 -and $null -eq $partial.chestCm -and $null -eq $partial.armCm) 'Null and zero measurements were changed.'

# The token's role must match the active relationship; current database roles are also checked.
function New-ProgressJwt([string[]] $Roles) {
    $header = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
    $payload = @{ sub = $progressTrainer.Id; role = $Roles; iss = $env:JWT_ISSUER; aud = $env:JWT_AUDIENCE; exp = [DateTimeOffset]::UtcNow.AddMinutes(5).ToUnixTimeSeconds() } | ConvertTo-Json -Compress
    $data = $header + '.' + (ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($payload)))
    $hmac = [Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($env:JWT_SECRET))
    try { return $data + '.' + (ConvertTo-Base64Url ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($data)))) } finally { $hmac.Dispose() }
}
$wrongRoleToken = New-ProgressJwt @('Dietitian')
$multiRoleToken = New-ProgressJwt @('Trainer', 'Dietitian')
foreach ($path in $progressPaths) {
    Assert-Check ((Invoke-Api 'GET' $path $null $wrongRoleToken).Status -eq 403) 'Mismatched relationship role accepted.'
    Assert-Check ((Invoke-Api 'GET' $path $null $multiRoleToken).Status -eq 200) 'Multi-role advisor lost matching relationship access.'
    Assert-Check ((Invoke-Api 'GET' ($path.Replace($progressId, [Guid]::NewGuid().ToString())) $null $progressTrainer.Token).Status -eq 403) 'Unknown client reveals different access behavior.'
}
[void] (Invoke-CheckSql "UPDATE users SET is_active = false WHERE id = '$progressId';")
foreach ($path in $progressPaths) { Assert-Check ((Invoke-Api 'GET' $path $null $progressTrainer.Token).Status -eq 403) 'Inactive client exposed.' }
[void] (Invoke-CheckSql "UPDATE users SET is_active = true WHERE id = '$progressId'; DELETE FROM user_roles WHERE user_id = '$progressId';")
foreach ($path in $progressPaths) { Assert-Check ((Invoke-Api 'GET' $path $null $progressDietitian.Token).Status -eq 403) 'Client without User role exposed.' }
[void] (Invoke-CheckSql "INSERT INTO user_roles (id,user_id,role_id) SELECT gen_random_uuid(), '$progressId'::uuid, id FROM roles WHERE name = 'User'; DELETE FROM user_roles WHERE user_id = '$($progressTrainer.Id)';")
foreach ($path in $progressPaths) { Assert-Check ((Invoke-Api 'GET' $path $null $progressTrainer.Token).Status -eq 403) 'Removed advisor role retained access with old JWT.' }
[void] (Invoke-CheckSql "INSERT INTO user_roles (id,user_id,role_id) SELECT gen_random_uuid(), '$($progressTrainer.Id)'::uuid, id FROM roles WHERE name = 'Trainer';")
foreach ($index in 0..1) {
    $status = if ($index -eq 0) { 'Ended' } else { 'Cancelled' }
    $staff = if ($index -eq 0) { $progressTrainer } else { $progressDietitian }
    Assert-Check ((Invoke-Api 'PATCH' ('/api/user-advisors/' + $progressRelations[$index]) @{ status = $status; endDate = $today } $AdminToken).Status -eq 200) 'Progress relation termination failed.'
    foreach ($path in $progressPaths) { Assert-Check ((Invoke-Api 'GET' $path $null $staff.Token).Status -eq 403) 'Ended/cancelled advisor retained progress access.' }
}
Assert-Check ((Invoke-Api 'GET' '/api/users/me/weight-records' $null $progressUser.Token).Body.Count -eq 2) 'Advisor workflow changed self tracking history.'
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM body_measurements WHERE user_id = '$progressId';") -eq '2') 'Advisor workflow mutated body records.'
Write-Output 'PASS: advisor body/weight progress, existing DTO compatibility, null/zero/order, read-only routes, current role/client checks and relation termination.'
