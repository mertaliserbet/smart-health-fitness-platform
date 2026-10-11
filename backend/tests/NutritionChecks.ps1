param([string] $FirstToken, [string] $SecondToken, [string] $FirstUserId, [string] $SecondUserId)

# Uses AuthSmoke's actual, disposable PostgreSQL and API fixture.
$path = '/api/users/me/nutrition-records'
$date = [DateTime]::UtcNow.AddDays(-2).ToString('yyyy-MM-dd')
$nextDate = ([DateTime]::ParseExact($date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)).AddDays(1).ToString('yyyy-MM-dd')
$from = [Uri]::EscapeDataString("${date}T00:00:00+03:00")
$to = [Uri]::EscapeDataString("${nextDate}T00:00:00+03:00")
$dayQuery = "date=$date&from=$from&to=$to"
foreach ($route in @($path, "$path/daily-summary")) {
    Assert-Check ((Invoke-Api 'GET' $route).Status -eq 401) 'Anonymous nutrition access was accepted.'
}
Assert-Check ((Invoke-Api 'POST' $path).Status -eq 401) 'Anonymous nutrition write was accepted.'
$empty = Invoke-Api 'GET' $path $null $FirstToken
Assert-Check ($empty.Status -eq 200 -and $empty.Body.Count -eq 0 -and $empty.NoStore) 'Nutrition empty history is invalid.'
$emptySummary = Invoke-Api 'GET' "$path/daily-summary?$dayQuery" $null $FirstToken
Assert-Check ($emptySummary.Status -eq 200 -and $emptySummary.Body.recordCount -eq 0 -and $emptySummary.Body.consumedCalories -eq 0) 'Empty day aggregation failed.'
$payload = @{ mealType='Breakfast'; name='  Yulaf ve süt  '; calories=450.25; proteinGrams=20.5;
    carbohydrateGrams=60.25; fatGrams=12.5; portionDescription='1 kase'; sourceType='Manual';
    foodRecognitionLogId=$null; consumedAt="${date}T00:00:00+03:00" }
$first = Invoke-Api 'POST' $path $payload $FirstToken
Assert-Check ($first.Status -eq 201 -and $first.Body.userId -eq $FirstUserId -and $first.Body.name -eq 'Yulaf ve süt' -and $first.NoStore) 'Nutrition creation or ownership failed.'
Assert-Check ($first.Body.sourceType -eq 'Manual' -and $null -eq $first.Body.foodRecognitionLogId) 'Manual source invalid.'
$payload.mealType='Lunch'; $payload.name='Tavuk ve pilav'; $payload.calories=650.75
$payload.proteinGrams=48; $payload.carbohydrateGrams=72.75; $payload.fatGrams=16
$payload.consumedAt="${date}T12:00:00+03:00"
$lunch = Invoke-Api 'POST' $path $payload $FirstToken
Assert-Check ($lunch.Status -eq 201) 'Second meal failed.'
$payload.calories=99; $payload.consumedAt="${nextDate}T00:00:00+03:00"
Assert-Check ((Invoke-Api 'POST' $path $payload $FirstToken).Status -eq 201) 'Day boundary fixture failed.'
$summary = Invoke-Api 'GET' "$path/daily-summary?$dayQuery" $null $FirstToken
Assert-Check ($summary.Status -eq 200 -and $summary.NoStore -and $summary.Body.recordCount -eq 2 -and $summary.Body.consumedCalories -eq 1101 -and $summary.Body.consumedProteinGrams -eq 68.5 -and $summary.Body.consumedCarbohydrateGrams -eq 133 -and $summary.Body.consumedFatGrams -eq 28.5) 'Local day totals/inclusive start/exclusive end failed.'
$history = Invoke-Api 'GET' "$path`?$dayQuery" $null $FirstToken
Assert-Check ($history.Body.Count -eq 2 -and $history.Body[0].id -eq $lunch.Body.id) 'Nutrition date filter/order failed.'
Assert-Check ((Invoke-Api 'GET' "$path`?$dayQuery&mealType=Breakfast" $null $FirstToken).Body.Count -eq 1) 'Meal filter failed.'
Assert-Check ((Invoke-Api 'GET' "$path`?date=$date" $null $FirstToken).Body.Count -eq 2) 'UTC-only calendar day failed.'
$other = Invoke-Api 'GET' "$path`?userId=$FirstUserId" $null $SecondToken
Assert-Check ($other.Body.Count -eq 0) 'Nutrition list leaked another user data.'
$otherSummary = Invoke-Api 'GET' "$path/daily-summary?$dayQuery&userId=$FirstUserId" $null $SecondToken
Assert-Check ($otherSummary.Body.recordCount -eq 0 -and $otherSummary.Body.consumedCalories -eq 0) 'Nutrition summary leaked another user data.'
$spoof = $payload.Clone(); $spoof.userId=$FirstUserId
Assert-Check ((Invoke-Api 'POST' $path $spoof $SecondToken).Status -eq 400) 'Nutrition owner injection accepted.'
$zero = $payload.Clone(); $zero.calories=0; $zero.proteinGrams=0; $zero.carbohydrateGrams=0; $zero.fatGrams=0
Assert-Check ((Invoke-Api 'POST' $path $zero $SecondToken).Status -eq 201) 'Zero nutrition values must be supported.'
Assert-Check ((Invoke-CheckSql "SELECT count(*) FROM nutrition_records WHERE user_id='$SecondUserId';") -eq '1') 'Nutrition record not persisted for own user.'
foreach ($field in @('calories','proteinGrams','carbohydrateGrams','fatGrams')) {
    foreach ($value in @($null, -1, 12.345, 10000000000, 'abc')) {
        $invalid = $payload.Clone(); $invalid[$field]=$value
        $response = Invoke-Api 'POST' $path $invalid $FirstToken
        Assert-Check ($response.Status -eq 400 -and $null -ne $response.Body.errors) "Invalid $field accepted."
    }
}
foreach ($invalidFields in @(@{name=' '}, @{name=('a'*201)}, @{mealType='Other'}, @{mealType=1},
    @{sourceType='AI'}, @{foodRecognitionLogId=[Guid]::NewGuid().ToString()}, @{consumedAt=$null},
    @{consumedAt='invalid'}, @{consumedAt=[DateTimeOffset]::UtcNow.AddDays(1).ToString('o')})) {
    $invalid=$payload.Clone(); foreach ($key in $invalidFields.Keys) { $invalid[$key]=$invalidFields[$key] }
    Assert-Check ((Invoke-Api 'POST' $path $invalid $FirstToken).Status -eq 400) 'Invalid nutrition request accepted.'
}
foreach ($query in @('date=invalid','date=9999-12-31',"date=$date&from=$from", "date=$date&from=$to&to=$from",
    "date=$date&from=2020-01-01T12%3A00%3A00Z&to=2020-01-02T00%3A00%3A00Z",'from=invalid','mealType=1')) {
    Assert-Check ((Invoke-Api 'GET' "$path`?$query" $null $FirstToken).Status -eq 400) 'Invalid nutrition query accepted.'
}
# Exercise goal date boundaries with the existing active NutritionGoal; never create a duplicate goal model.
[void] (Invoke-CheckSql "UPDATE nutrition_goals SET start_date='$date', end_date='$date' WHERE user_id='$FirstUserId' AND is_active;")
$withGoal=Invoke-Api 'GET' "$path/daily-summary?$dayQuery" $null $FirstToken
$activeGoalId=Invoke-CheckSql "SELECT id FROM nutrition_goals WHERE user_id='$FirstUserId' AND is_active;"
Assert-Check ($withGoal.Body.goal.id -eq $activeGoalId) 'Daily summary did not reuse active NutritionGoal at inclusive date bounds.'
Assert-Check ($null -eq (Invoke-Api 'GET' "$path/daily-summary?date=$nextDate" $null $FirstToken).Body.goal) 'Out-of-period target leaked into daily summary.'
[void] (Invoke-CheckSql "UPDATE nutrition_goals SET is_active=false WHERE user_id='$FirstUserId' AND is_active;")
Assert-Check ($null -eq (Invoke-Api 'GET' "$path/daily-summary?$dayQuery" $null $FirstToken).Body.goal) 'Inactive goal selected for daily nutrition summary.'
# Trainer-only JWT (signed by test fixture) cannot use personal nutrition endpoints.
$header=ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
$claims=@{sub=$FirstUserId;role='Trainer';iss=$env:JWT_ISSUER;aud=$env:JWT_AUDIENCE;exp=[DateTimeOffset]::UtcNow.AddMinutes(5).ToUnixTimeSeconds()} | ConvertTo-Json -Compress
$data=$header+'.'+(ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($claims)))
$hmac=[Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($env:JWT_SECRET))
try { $trainer=$data+'.'+(ConvertTo-Base64Url ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($data)))) } finally { $hmac.Dispose() }
foreach ($route in @($path,"$path/daily-summary")) {
    Assert-Check ((Invoke-Api 'GET' $route $null $trainer).Status -eq 403) 'Nutrition reads accepted Trainer-only role.'
}
Assert-Check ((Invoke-Api 'POST' $path $payload $trainer).Status -eq 403) 'Nutrition write accepted Trainer-only role.'
Write-Output 'PASS: real PostgreSQL nutrition create/history, decimal validation, local-day totals, active goal periods, JWT role and user isolation.'
