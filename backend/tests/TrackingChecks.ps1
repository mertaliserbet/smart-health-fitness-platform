param([string] $FirstToken, [string] $SecondToken, [string] $FirstUserId, [string] $SecondUserId)

# Executed inside AuthSmoke's disposable PostgreSQL/API fixture.
$weightPath = '/api/users/me/weight-records'
$bodyPath = '/api/users/me/body-measurements'
$earlier = [DateTimeOffset]::UtcNow.AddDays(-2).ToString('o')
$later = [DateTimeOffset]::UtcNow.AddDays(-1).ToString('o')
foreach ($path in @($weightPath, $bodyPath)) {
    foreach ($method in @('GET', 'POST')) {
        $anonymous = Invoke-Api $method $path
        Assert-Check ($anonymous.Status -eq 401) 'Tracking endpoint accepted an anonymous request.'
    }
    $empty = Invoke-Api 'GET' $path $null $FirstToken
    Assert-Check ($empty.Status -eq 200 -and @($empty.Body).Count -eq 0 -and $empty.NoStore) 'Empty tracking list is invalid or cacheable.'
}
$weight = Invoke-Api 'POST' $weightPath @{ weightKg = 82.45; recordedAt = $later } $FirstToken
Assert-Check ($weight.Status -eq 201 -and $weight.Body.weightKg -eq 82.45 -and $weight.NoStore) 'Weight creation failed.'
[void] (Invoke-Api 'POST' $weightPath @{ weightKg = 83; recordedAt = $earlier } $FirstToken)
$history = Invoke-Api 'GET' $weightPath $null $FirstToken
Assert-Check ($history.Body.Count -eq 2 -and $history.Body[0].id -eq $weight.Body.id) 'Weight history is not ordered by recorded time.'
$body = Invoke-Api 'POST' $bodyPath @{ waistCm = 88.25; recordedAt = $later } $FirstToken
Assert-Check ($body.Status -eq 201 -and $body.Body.waistCm -eq 88.25 -and $null -eq $body.Body.chestCm) 'Partial measurement failed.'
$allBody = Invoke-Api 'POST' $bodyPath @{ chestCm = 102; waistCm = 88; hipCm = 98; armCm = 36;
    thighCm = 58; bodyFatPercentage = 20.5; recordedAt = $earlier } $FirstToken
Assert-Check ($allBody.Status -eq 201) 'Complete measurement failed.'
$bodyHistory = Invoke-Api 'GET' $bodyPath $null $FirstToken
Assert-Check ($bodyHistory.Body.Count -eq 2 -and $bodyHistory.Body[0].id -eq $body.Body.id) 'Measurement history ordering failed.'
foreach ($invalidWeight in @(-1, 0, 1000.01, 82.451, [decimal]::Parse('82.400', [Globalization.CultureInfo]::InvariantCulture), $null, 'abc')) {
    $invalid = Invoke-Api 'POST' $weightPath @{ weightKg = $invalidWeight; recordedAt = $later } $FirstToken
    Assert-Check ($invalid.Status -eq 400 -and $null -ne $invalid.Body.errors) 'Invalid weight was accepted.'
}
foreach ($field in @('chestCm', 'waistCm', 'hipCm', 'armCm', 'thighCm', 'bodyFatPercentage')) {
    foreach ($value in @(-1, 1000.01, 20.123)) {
        $requestBody = @{ recordedAt = $later }; $requestBody[$field] = $value
        $invalid = Invoke-Api 'POST' $bodyPath $requestBody $FirstToken
        Assert-Check ($invalid.Status -eq 400 -and $null -ne $invalid.Body.errors.$field) 'Invalid measurement lacked field errors.'
    }
}
$missing = Invoke-Api 'POST' $bodyPath @{ recordedAt = $later } $FirstToken
Assert-Check ($missing.Status -eq 400 -and $null -ne $missing.Body.errors.measurements) 'All-null measurement was accepted.'
foreach ($date in @($null, 'invalid', [DateTimeOffset]::UtcNow.AddDays(1).ToString('o'))) {
    foreach ($path in @($weightPath, $bodyPath)) {
        $payload = if ($path -eq $weightPath) { @{ weightKg = 82; recordedAt = $date } } else { @{ waistCm = 88; recordedAt = $date } }
        Assert-Check ((Invoke-Api 'POST' $path $payload $FirstToken).Status -eq 400) 'Invalid/future timestamp was accepted.'
    }
}
foreach ($path in @($weightPath, $bodyPath)) {
    $otherList = Invoke-Api 'GET' "$path`?userId=$FirstUserId" $null $SecondToken
    Assert-Check (@($otherList.Body).Count -eq 0) 'Second user can read the first user records.'
    $spoof = if ($path -eq $weightPath) { @{ weightKg = 65; recordedAt = $later; userId = $FirstUserId } }
        else { @{ waistCm = 70; recordedAt = $later; userId = $FirstUserId } }
    Assert-Check ((Invoke-Api 'POST' $path $spoof $SecondToken).Status -eq 400) 'User ID injection was accepted.'
}
$secondWeight = Invoke-Api 'POST' $weightPath @{ weightKg = 65; recordedAt = $later } $SecondToken
$secondBody = Invoke-Api 'POST' $bodyPath @{ armCm = 30; recordedAt = $later } $SecondToken
Assert-Check ($secondWeight.Status -eq 201 -and $secondBody.Status -eq 201) 'Second user creation failed.'
Assert-Check ((Invoke-Api 'GET' $weightPath $null $FirstToken).Body.Count -eq 2) 'First user sees second user records.'
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM weight_records WHERE user_id = '$SecondUserId';") -eq '1') 'Weight ownership was not stored.'
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM body_measurements WHERE user_id = '$SecondUserId';") -eq '1') 'Body ownership was not stored.'
$roleOnlyToken = (New-CheckJwt $FirstUserId ([DateTimeOffset]::UtcNow.AddMinutes(5).ToUnixTimeSeconds()) $env:JWT_ISSUER $env:JWT_AUDIENCE)
# Replace the signed JWT's role by issuing a fresh, correctly signed test token.
$parts = $roleOnlyToken.Split('.')
$payloadJson = @{ sub = $FirstUserId; role = 'Trainer'; iss = $env:JWT_ISSUER; aud = $env:JWT_AUDIENCE;
    exp = [DateTimeOffset]::UtcNow.AddMinutes(5).ToUnixTimeSeconds() } | ConvertTo-Json -Compress
$data = $parts[0] + '.' + (ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($payloadJson)))
$hmac = [Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($env:JWT_SECRET))
try { $trainerToken = $data + '.' + (ConvertTo-Base64Url ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($data)))) }
finally { $hmac.Dispose() }
foreach ($path in @($weightPath, $bodyPath)) {
    foreach ($method in @('GET', 'POST')) {
        Assert-Check ((Invoke-Api $method $path $null $trainerToken).Status -eq 403) 'Tracking endpoint accepted Trainer-only token.'
    }
}
Write-Output 'PASS: tracking creation/history, partial measurements, ordering, validation, JWT roles and cross-user isolation.'
