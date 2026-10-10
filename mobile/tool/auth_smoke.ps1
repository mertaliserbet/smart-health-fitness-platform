param(
    [string] $Device = 'emulator-5554',
    [ValidateRange(1024, 65535)] [int] $ApiPort = 5061,
    [ValidateRange(1024, 65535)] [int] $DatabasePort = 55433
)

$ErrorActionPreference = 'Stop'
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

    Set-Location (Join-Path $repositoryRoot 'mobile')
    flutter test integration_test/auth_flow_test.dart -d $Device `
        "--dart-define=API_BASE_URL=http://10.0.2.2:$ApiPort" --dart-define=AUTH_TEST_FIXTURE=true
    if ($LASTEXITCODE -ne 0) { throw 'Android auth integration test failed.' }
    Write-Output 'PASS: mobile auth/session, weight and body measurement creation/history, and logout against PostgreSQL.'
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
