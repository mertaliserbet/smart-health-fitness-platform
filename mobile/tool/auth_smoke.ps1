param(
    [string] $Device = 'emulator-5554',
    [ValidateRange(1024, 65535)] [int] $ApiPort = 5061,
    [ValidateRange(1024, 65535)] [int] $DatabasePort = 55433,
    [switch] $AssignmentTest,
    [switch] $AssignmentWriteTest,
    [switch] $NutritionTest
)

$ErrorActionPreference = 'Stop'
# Fetch blocks SIP ports 5060/5061; use a browser-compatible test port for real web forms.
if ($AssignmentWriteTest -and -not $PSBoundParameters.ContainsKey('ApiPort')) { $ApiPort = 5064 }
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$projectFile = Join-Path $repositoryRoot 'backend/SmartHealthFitness.Api.csproj'
$composeFile = Join-Path $repositoryRoot 'backend/docker-compose.yml'
$fixtureName = 'shf-mobile-auth-' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
$logDirectory = Join-Path ([IO.Path]::GetTempPath()) $fixtureName
$apiProcess = $null
$databaseStarted = $false
$originalEnvironment = @{}
foreach ($name in @('POSTGRES_PASSWORD', 'POSTGRES_USER', 'POSTGRES_DB', 'POSTGRES_PORT',
    'DATABASE_CONNECTION_STRING', 'JWT_SECRET', 'JWT_ISSUER', 'JWT_AUDIENCE', 'ASPNETCORE_ENVIRONMENT', 'ASPNETCORE_URLS')) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

Push-Location $repositoryRoot
try {
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw 'EF tool restore failed.' }
    dotnet restore $projectFile
    if ($LASTEXITCODE -ne 0) { throw 'Backend restore failed.' }
    dotnet build $projectFile --no-restore
    if ($LASTEXITCODE -ne 0) { throw 'Backend build failed.' }

    $env:POSTGRES_DB = 'mobile_auth_check'
    $env:POSTGRES_USER = 'mobile_auth_check'
    $env:POSTGRES_PORT = $DatabasePort.ToString()
    $env:POSTGRES_PASSWORD = [Guid]::NewGuid().ToString('N')
    $env:DATABASE_CONNECTION_STRING = "Host=127.0.0.1;Port=$DatabasePort;Database=mobile_auth_check;Username=mobile_auth_check;Password=$env:POSTGRES_PASSWORD;Timeout=5"
    $randomBytes = New-Object byte[] 64
    [Security.Cryptography.RandomNumberGenerator]::Fill($randomBytes)
    $env:JWT_SECRET = [Convert]::ToBase64String($randomBytes)
    $env:JWT_ISSUER = 'SmartHealthFitness.Api'
    $env:JWT_AUDIENCE = 'SmartHealthFitness.Clients'
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $env:ASPNETCORE_URLS = "http://127.0.0.1:$ApiPort"

    $databaseStarted = $true
    docker compose -f $composeFile -p $fixtureName up -d --wait --wait-timeout 60
    if ($LASTEXITCODE -ne 0) { throw 'Temporary PostgreSQL startup failed.' }
    dotnet tool run dotnet-ef database update --project $projectFile --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Migration could not be applied to the test database.' }

    [void] (New-Item -ItemType Directory -Path $logDirectory)
    $apiDll = Join-Path $repositoryRoot 'backend/bin/Debug/net10.0/SmartHealthFitness.Api.dll'
    $apiProcess = Start-Process -FilePath (Get-Command dotnet).Source -ArgumentList @('exec', ('"' + $apiDll + '"')) `
        -WorkingDirectory (Join-Path $repositoryRoot 'backend') -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $logDirectory 'api.stdout.log') -RedirectStandardError (Join-Path $logDirectory 'api.stderr.log')
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        if ($apiProcess.HasExited) { throw 'Test API exited before startup.' }
        try { $ready = (Invoke-WebRequest "http://127.0.0.1:$ApiPort/api/health" -TimeoutSec 2).StatusCode -eq 200 }
        catch { $ready = $false }
        if ($ready) { break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) { throw 'Test API health check failed.' }

    if ($NutritionTest) {
        # The user creates every NutritionRecord through Flutter; only advisor prerequisites are seeded.
        $nutritionIds = @{}
        foreach ($account in @('user', 'other', 'dietitian')) {
            $body = @{ firstName='İrem'; lastName='Şerbet'; email="nutrition-$account@example.test"; password='Nutrition-Test-Password123!' }
            $registered = Invoke-RestMethod "http://127.0.0.1:$ApiPort/api/auth/register" -Method Post `
                -ContentType 'application/json; charset=utf-8' -Body ($body | ConvertTo-Json -Compress)
            $nutritionIds[$account] = ([Guid]::Parse($registered.id)).ToString()
        }
        $dietitianId=$nutritionIds.dietitian; $nutritionUserId=$nutritionIds.user
        $fixtureSql = "DELETE FROM user_roles WHERE user_id='$dietitianId'; INSERT INTO user_roles (id,user_id,role_id) SELECT gen_random_uuid(),'$dietitianId'::uuid,id FROM roles WHERE name='Dietitian'; INSERT INTO user_advisors (id,user_id,advisor_id,advisor_type,start_date,status,created_at) VALUES (gen_random_uuid(),'$nutritionUserId','$dietitianId','Dietitian','2026-01-01','Active',now());"
        & docker compose -f $composeFile -p $fixtureName exec -T postgres psql -U mobile_auth_check -d mobile_auth_check -v ON_ERROR_STOP=1 -c $fixtureSql
        if ($LASTEXITCODE -ne 0) { throw 'Nutrition advisor fixture failed.' }
        $loginBody=@{email='nutrition-dietitian@example.test';password='Nutrition-Test-Password123!'} | ConvertTo-Json -Compress
        $dietitianLogin=Invoke-RestMethod "http://127.0.0.1:$ApiPort/api/auth/login" -Method Post -ContentType 'application/json' -Body $loginBody
        $goalBody=@{dailyCalories=2000;proteinGrams=100;carbohydrateGrams=250;fatGrams=70;waterMl=2500;startDate='2026-01-01';endDate=$null} | ConvertTo-Json -Compress
        [void] (Invoke-RestMethod "http://127.0.0.1:$ApiPort/api/users/$nutritionUserId/nutrition-goals" -Method Post `
            -Headers @{Authorization="Bearer $($dietitianLogin.accessToken)"} -ContentType 'application/json' -Body $goalBody)
        Set-Location (Join-Path $repositoryRoot 'mobile')
        flutter test integration_test/nutrition_flow_test.dart -d $Device `
            "--dart-define=API_BASE_URL=http://10.0.2.2:$ApiPort" --dart-define=NUTRITION_TEST_FIXTURE=true
        if ($LASTEXITCODE -ne 0) { throw 'Android nutrition integration test failed.' }
        $stored = & docker compose -f $composeFile -p $fixtureName exec -T postgres psql -U mobile_auth_check -d mobile_auth_check -At -c `
            "SELECT count(*)::text || ':' || sum(calories)::text || ':' || sum(protein_grams)::text FROM nutrition_records WHERE user_id='$nutritionUserId';"
        if ($LASTEXITCODE -ne 0 -or ($stored -join '').Trim() -ne '2:1100.50:68.50') { throw 'Android meal totals were not persisted in PostgreSQL.' }
        Write-Output 'PASS: real Android manual meals -> API -> PostgreSQL -> daily totals/active goal/history; second user isolation.'
    }
    elseif ($AssignmentTest -or $AssignmentWriteTest) {
        # Register disposable accounts via the API; seed assignments only in this test database.
        . (Join-Path $repositoryRoot 'backend/tests/AssignmentFixture.ps1')
        function Invoke-CheckSql([string] $Sql) {
            $result = & docker compose -f $composeFile -p $fixtureName exec -T postgres psql `
                -U mobile_auth_check -d mobile_auth_check -v ON_ERROR_STOP=1 -At -c $Sql
            if ($LASTEXITCODE -ne 0) { throw 'Assignment fixture SQL failed.' }
            return ($result -join "`n").Trim()
        }
        $ids = @{}
        foreach ($account in @('user', 'other', 'trainer', 'dietitian')) {
            $body = @{ firstName = if ($account -eq 'trainer') { 'Çağrı' } else { 'İrem' }
                lastName = 'Şerbet'; email = "assignment-$account@example.test"; password = 'Assignment-Test-Password123!' }
            $registered = Invoke-RestMethod "http://127.0.0.1:$ApiPort/api/auth/register" -Method Post `
                -ContentType 'application/json; charset=utf-8' -Body ($body | ConvertTo-Json -Compress)
            $ids[$account] = ([Guid]::Parse($registered.id)).ToString()
        }
        foreach ($entry in @(@{account='trainer';role='Trainer'}, @{account='dietitian';role='Dietitian'})) {
            $id = $ids[$entry.account]; $role = $entry.role
            [void] (Invoke-CheckSql "DELETE FROM user_roles WHERE user_id = '$id'; INSERT INTO user_roles (id, user_id, role_id) SELECT gen_random_uuid(), '$id'::uuid, id FROM roles WHERE name = '$role';")
        }
        Add-AssignmentFixture $ids.user $ids.other $ids.trainer $ids.dietitian
        if ($AssignmentWriteTest) {
            # Keep advisor relationships, catalog and history; current assignments must come from web forms.
            $id = $ids.user
            [void] (Invoke-CheckSql "DELETE FROM workout_plans WHERE user_id='$id' AND is_active; DELETE FROM nutrition_goals WHERE user_id='$id'; DELETE FROM user_tasks WHERE user_id='$id'; DELETE FROM advisor_notes WHERE user_id='$id';")
            $oldApiUrl = $env:VITE_API_BASE_URL; $oldLiveUser = $env:ASSIGNMENT_LIVE_USER_ID
            try {
                $env:VITE_API_BASE_URL = "http://127.0.0.1:$ApiPort"
                $env:ASSIGNMENT_LIVE_USER_ID = $ids.user
                Set-Location (Join-Path $repositoryRoot 'web')
                $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
                $nodePath = if ($nodeCommand) { $nodeCommand.Source } else {
                    Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe'
                }
                & $nodePath node_modules/vitest/vitest.mjs run src/AssignmentLive.test.tsx
                if ($LASTEXITCODE -ne 0) { throw 'Real web assignment forms failed.' }
            } finally {
                $env:VITE_API_BASE_URL = $oldApiUrl; $env:ASSIGNMENT_LIVE_USER_ID = $oldLiveUser
            }
        }
        Set-Location (Join-Path $repositoryRoot 'mobile')
        flutter test integration_test/assignment_flow_test.dart -d $Device `
            "--dart-define=API_BASE_URL=http://10.0.2.2:$ApiPort" --dart-define=ASSIGNMENT_TEST_FIXTURE=true `
            "--dart-define=ASSIGNMENT_WRITE_TEST_FIXTURE=$($AssignmentWriteTest.IsPresent.ToString().ToLowerInvariant())"
        if ($LASTEXITCODE -ne 0) { throw 'Android assignment integration test failed.' }
        if ($AssignmentWriteTest) {
            $completedCount = Invoke-CheckSql "SELECT count(*) FROM user_tasks WHERE user_id='$($ids.user)' AND title='Esneme yap' AND status='Completed' AND completed_at IS NOT NULL;"
            if ($completedCount -ne '1') { throw 'Mobile completion was not persisted in PostgreSQL.' }
            Write-Output 'PASS: real React forms -> API -> PostgreSQL -> Android Planım -> task completion persisted.'
        }
        Write-Output 'PASS: real Flutter Planım/Rehberim reads, own-user isolation and logout against PostgreSQL.'
    }
    else {
        Set-Location (Join-Path $repositoryRoot 'mobile')
        flutter test integration_test/auth_flow_test.dart -d $Device `
            "--dart-define=API_BASE_URL=http://10.0.2.2:$ApiPort" --dart-define=AUTH_TEST_FIXTURE=true
        if ($LASTEXITCODE -ne 0) { throw 'Android auth integration test failed.' }
        Write-Output 'PASS: mobile auth/session, weight and body measurement creation/history, and logout against PostgreSQL.'
    }
}
finally {
    Set-Location $repositoryRoot
    if ($null -ne $apiProcess -and -not $apiProcess.HasExited) {
        Stop-Process -Id $apiProcess.Id -ErrorAction SilentlyContinue
        $apiProcess.WaitForExit()
    }
    if ($databaseStarted) { docker compose -f $composeFile -p $fixtureName down --volumes --remove-orphans }
    if (Test-Path -LiteralPath $logDirectory) {
        $resolvedLogDirectory = (Resolve-Path -LiteralPath $logDirectory).Path
        $expectedLogDirectory = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) $fixtureName))
        if ($resolvedLogDirectory -eq $expectedLogDirectory -and $fixtureName.StartsWith('shf-mobile-auth-')) {
            Remove-Item -LiteralPath $resolvedLogDirectory -Recurse -Force
        }
    }
    foreach ($name in $originalEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], 'Process')
    }
    Pop-Location
}
