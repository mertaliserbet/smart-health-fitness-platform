param([string] $AdminToken, [Guid] $OtherUserId)
# Uses only AuthSmoke's disposable PostgreSQL/API fixture and existing HTTP/SQL helpers.
$nutritionPassword = [Guid]::NewGuid().ToString('N') + '!Aa1'
function New-NutritionAccount([string] $Role) {
    $email = [Guid]::NewGuid().ToString('N') + '@example.test'
    $registered = Invoke-Api 'POST' '/api/auth/register' @{ firstName = 'Beslenme'; lastName = 'Test'; email = $email; password = $nutritionPassword }
    Assert-Check ($registered.Status -eq 201) 'Nutrition progress registration failed.'
    $id = ([Guid]::Parse($registered.Body.id)).ToString()
    if ($Role -ne 'User') { [void](Invoke-CheckSql "DELETE FROM user_roles WHERE user_id = '$id'; INSERT INTO user_roles (id,user_id,role_id) SELECT gen_random_uuid(), '$id'::uuid, id FROM roles WHERE name = '$Role';") }
    $login = Invoke-Api 'POST' '/api/auth/login' @{ email = $email; password = $nutritionPassword }
    Assert-Check ($login.Status -eq 200) 'Nutrition progress login failed.'
    return @{ Id = $id; Token = $login.Body.accessToken }
}
function New-NutritionJwt([string] $Id, [string[]] $Roles) {
    $header = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
    $payload = @{ sub = $Id; role = $Roles; iss = $env:JWT_ISSUER; aud = $env:JWT_AUDIENCE; exp = [DateTimeOffset]::UtcNow.AddMinutes(5).ToUnixTimeSeconds() } | ConvertTo-Json -Compress
    $data = $header + '.' + (ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($payload)))
    $hmac = [Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($env:JWT_SECRET))
    try { return $data + '.' + (ConvertTo-Base64Url ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($data)))) } finally { $hmac.Dispose() }
}
$nutritionUser = New-NutritionAccount 'User'
$dietitian = New-NutritionAccount 'Dietitian'
$otherDietitian = New-NutritionAccount 'Dietitian'
$trainer = New-NutritionAccount 'Trainer'
$clientId = $nutritionUser.Id
$path = '/api/users/' + $clientId + '/nutrition-records'
$day = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
Assert-Check ((Invoke-Api 'GET' $path).Status -eq 401) 'Anonymous advisor nutrition access accepted.'
Assert-Check ((Invoke-Api 'GET' $path $null $dietitian.Token).Status -eq 403) 'Unassigned Dietitian can read nutrition.'
$relations = @()
foreach ($staff in @(@{ Account = $dietitian; Type = 'Dietitian' }, @{ Account = $trainer; Type = 'Trainer' })) {
    $relation = Invoke-Api 'POST' '/api/user-advisors' @{ userId = $clientId; advisorId = $staff.Account.Id; advisorType = $staff.Type; startDate = $day } $AdminToken
    Assert-Check ($relation.Status -eq 201) 'Nutrition relation fixture failed.'
    $relations += $relation.Body.userAdvisorId
}
foreach ($token in @($nutritionUser.Token, $trainer.Token, (New-NutritionJwt $dietitian.Id @('Admin')), (New-NutritionJwt $dietitian.Id @('Trainer')))) {
    Assert-Check ((Invoke-Api 'GET' $path $null $token).Status -eq 403) 'Non-Dietitian nutrition access accepted.'
}
$empty = Invoke-Api 'GET' $path $null $dietitian.Token
Assert-Check ($empty.Status -eq 200 -and @($empty.Body).Count -eq 0 -and $empty.NoStore) 'Empty nutrition history invalid/cacheable.'
$at = [DateTimeOffset]::UtcNow.AddHours(-1).ToString('o')
foreach ($entry in @(@{ mealType = 'Lunch'; name = 'Öğün'; calories = 650.25; proteinGrams = 48.75; carbohydrateGrams = 72.1; fatGrams = 16; portionDescription = 'Bir porsiyon'; consumedAt = $at }, @{ mealType = 'Snack'; name = 'Sıfır kayıt'; calories = 0; proteinGrams = 0; carbohydrateGrams = 0; fatGrams = 0; consumedAt = $at })) {
    Assert-Check ((Invoke-Api 'POST' '/api/users/me/nutrition-records' $entry $nutritionUser.Token).Status -eq 201) 'Nutrition record fixture failed.'
}
$self = Invoke-Api 'GET' '/api/users/me/nutrition-records' $null $nutritionUser.Token
$advisor = Invoke-Api 'GET' $path $null $dietitian.Token
Assert-Check ($advisor.Status -eq 200 -and $advisor.NoStore -and $advisor.Body.Count -eq 2) 'Advisor history failed.'
Assert-Check (($advisor.Body | ConvertTo-Json -Depth 8 -Compress) -eq ($self.Body | ConvertTo-Json -Depth 8 -Compress)) 'Advisor nutrition DTO/order differs from existing self API.'
Assert-Check ($advisor.Body[0].calories -eq 0 -and $null -eq $advisor.Body[0].portionDescription -and $advisor.Body[1].calories -eq 650.25) 'Nutrition zero/decimal/null values changed.'
$query = Invoke-Api 'GET' ($path + '?userId=' + $OtherUserId + '&advisorId=' + $trainer.Id + '&date=2099-01-01&mealType=Breakfast&from=2099-01-01') $null $dietitian.Token
Assert-Check (($query.Body | ConvertTo-Json -Depth 8 -Compress) -eq ($self.Body | ConvertTo-Json -Depth 8 -Compress)) 'Query changed ownership or applied undocumented filtering.'
foreach ($id in @($OtherUserId.ToString(), [Guid]::NewGuid().ToString())) { Assert-Check ((Invoke-Api 'GET' ('/api/users/' + $id + '/nutrition-records') $null $dietitian.Token).Status -eq 403) 'Unassigned/missing client nutrition exposed.' }
Assert-Check ((Invoke-Api 'GET' $path $null $otherDietitian.Token).Status -eq 403) 'Other Dietitian can read client.'
foreach ($method in @('POST', 'PUT', 'PATCH', 'DELETE')) { Assert-Check ((Invoke-Api $method $path @{} $dietitian.Token).Status -eq 405) 'Advisor nutrition write route exists.' }
$multi = New-NutritionJwt $dietitian.Id @('Trainer','Dietitian')
Assert-Check ((Invoke-Api 'GET' $path $null $multi).Status -eq 200) 'Multi-role matching Dietitian lost access.'
[void](Invoke-CheckSql "INSERT INTO user_roles (id,user_id,role_id) SELECT gen_random_uuid(), '$($trainer.Id)'::uuid, id FROM roles WHERE name = 'Dietitian';")
Assert-Check ((Invoke-Api 'GET' $path $null (New-NutritionJwt $trainer.Id @('Trainer','Dietitian'))).Status -eq 403) 'Multi-role Trainer relation grants nutrition access.'
[void](Invoke-CheckSql "UPDATE users SET is_active=false WHERE id='$clientId';")
Assert-Check ((Invoke-Api 'GET' $path $null $dietitian.Token).Status -eq 403) 'Inactive nutrition client exposed.'
[void](Invoke-CheckSql "UPDATE users SET is_active=true WHERE id='$clientId'; DELETE FROM user_roles WHERE user_id='$clientId';")
Assert-Check ((Invoke-Api 'GET' $path $null $dietitian.Token).Status -eq 403) 'Client without current User role exposed.'
[void](Invoke-CheckSql "INSERT INTO user_roles (id,user_id,role_id) SELECT gen_random_uuid(), '$clientId'::uuid, id FROM roles WHERE name='User'; DELETE FROM user_roles WHERE user_id='$($dietitian.Id)';")
Assert-Check ((Invoke-Api 'GET' $path $null $dietitian.Token).Status -eq 403) 'Removed Dietitian role retains access with old JWT.'
[void](Invoke-CheckSql "INSERT INTO user_roles (id,user_id,role_id) SELECT gen_random_uuid(), '$($dietitian.Id)'::uuid, id FROM roles WHERE name='Dietitian';")
Assert-Check ((Invoke-Api 'PATCH' ('/api/user-advisors/' + $relations[0]) @{ status='Ended'; endDate=$day } $AdminToken).Status -eq 200) 'Nutrition relation termination failed.'
Assert-Check ((Invoke-Api 'GET' $path $null $dietitian.Token).Status -eq 403) 'Ended Dietitian can read nutrition.'
$replacement = Invoke-Api 'POST' '/api/user-advisors' @{ userId=$clientId; advisorId=$otherDietitian.Id; advisorType='Dietitian'; startDate=$day } $AdminToken
Assert-Check ($replacement.Status -eq 201) 'Replacement relation failed.'
Assert-Check ((Invoke-Api 'PATCH' ('/api/user-advisors/' + $replacement.Body.userAdvisorId) @{ status='Cancelled'; endDate=$day } $AdminToken).Status -eq 200) 'Cancellation failed.'
Assert-Check ((Invoke-Api 'GET' $path $null $otherDietitian.Token).Status -eq 403) 'Cancelled Dietitian retains access.'
Assert-Check ((Invoke-Api 'GET' '/api/users/me/nutrition-records' $null $nutritionUser.Token).Body.Count -eq 2) 'Advisor workflow changed self history.'
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM nutrition_records WHERE user_id='$clientId';") -eq '2') 'Read-only advisor workflow mutated records.'
Write-Output 'PASS: Dietitian nutrition history, existing DTO/order/null/zero/decimal compatibility, read-only routes, current roles, client isolation and ended/cancelled relations.'
