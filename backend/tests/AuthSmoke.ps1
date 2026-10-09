param(
    [ValidateRange(1024, 65535)] [int] $ApiPort = 5059,
    [ValidateRange(1024, 65535)] [int] $DatabasePort = 55432,
    [switch] $NoBuild
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$projectFile = Join-Path $repositoryRoot 'backend/SmartHealthFitness.Api.csproj'
$composeFile = Join-Path $repositoryRoot 'backend/docker-compose.yml'
$testName = 'shf-auth-check-' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) $testName
$baseUrl = "http://127.0.0.1:$ApiPort"
$apiProcess = $null
$client = $null
$databaseStarted = $false
$originalEnvironment = @{}
foreach ($name in @('POSTGRES_PASSWORD', 'POSTGRES_USER', 'POSTGRES_DB', 'POSTGRES_PORT',
    'DATABASE_CONNECTION_STRING', 'JWT_SECRET', 'JWT_ISSUER', 'JWT_AUDIENCE', 'ASPNETCORE_ENVIRONMENT', 'ASPNETCORE_URLS')) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function Assert-Check([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}

function New-JsonContent($Body) {
    return [System.Net.Http.StringContent]::new(($Body | ConvertTo-Json -Depth 8 -Compress),
        [Text.Encoding]::UTF8, 'application/json')
}

function Read-Response($Response) {
    $body = $Response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    return [PSCustomObject]@{
        Status = [int] $Response.StatusCode
        Body = if ($body) { $body | ConvertFrom-Json } else { $null }
        ContentType = $Response.Content.Headers.ContentType.MediaType
        HasBearerChallenge = $Response.Headers.Contains('WWW-Authenticate')
        NoStore = $Response.Headers.CacheControl.NoStore
    }
}

function Invoke-Api([string] $Method, [string] $Path, $Body = $null, [string] $Token = '') {
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), $baseUrl + $Path)
    if ($null -ne $Body) { $request.Content = New-JsonContent $Body }
    if ($Token) { $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token) }
    $response = $client.SendAsync($request).GetAwaiter().GetResult()
    try { return Read-Response $response } finally { $response.Dispose(); $request.Dispose() }
}

function Invoke-CheckSql([string] $Sql) {
    $result = & docker compose -f $composeFile -p $testName exec -T postgres psql -U auth_check -d auth_check -v ON_ERROR_STOP=1 -At -c $Sql
    if ($LASTEXITCODE -ne 0) { throw 'SQL check failed.' }
    return ($result -join "`n").Trim()
}

function Get-TokenHash([string] $Token) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Token))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function ConvertTo-Base64Url([byte[]] $Bytes) {
    return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function New-CheckJwt([string] $UserId, [long] $ExpiresAt, [string] $Issuer, [string] $Audience) {
    $header = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
    $payload = @{ sub = $UserId; role = 'User'; iss = $Issuer; aud = $Audience; exp = $ExpiresAt;
        nbf = [DateTimeOffset]::UtcNow.AddMinutes(-20).ToUnixTimeSeconds(); jti = [Guid]::NewGuid().ToString() } | ConvertTo-Json -Compress
    $data = $header + '.' + (ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($payload)))
    $hmac = [Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($env:JWT_SECRET))
    try { return $data + '.' + (ConvertTo-Base64Url ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($data)))) }
    finally { $hmac.Dispose() }
}

Push-Location $repositoryRoot
try {
    Add-Type -AssemblyName System.Net.Http
    if (-not $NoBuild) {
        dotnet tool restore
        if ($LASTEXITCODE -ne 0) { throw 'EF tool restore failed.' }
        dotnet restore $projectFile
        if ($LASTEXITCODE -ne 0) { throw 'Restore failed.' }
        dotnet build $projectFile --no-restore
        if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
    }

    $env:POSTGRES_DB = 'auth_check'
    $env:POSTGRES_USER = 'auth_check'
    $env:POSTGRES_PORT = $DatabasePort.ToString()
    $env:POSTGRES_PASSWORD = [Guid]::NewGuid().ToString('N')
    $env:DATABASE_CONNECTION_STRING = "Host=127.0.0.1;Port=$DatabasePort;Database=auth_check;Username=auth_check;Password=$env:POSTGRES_PASSWORD;Timeout=5"
    $randomBytes = New-Object byte[] 64
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $random.GetBytes($randomBytes) } finally { $random.Dispose() }
    $env:JWT_SECRET = [Convert]::ToBase64String($randomBytes)
    $env:JWT_ISSUER = 'SmartHealthFitness.Api'
    $env:JWT_AUDIENCE = 'SmartHealthFitness.Clients'
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $env:ASPNETCORE_URLS = $baseUrl

    $databaseStarted = $true
    docker compose -f $composeFile -p $testName up -d --wait --wait-timeout 60
    if ($LASTEXITCODE -ne 0) { throw 'Temporary PostgreSQL startup failed.' }
    dotnet tool run dotnet-ef database update --project $projectFile --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Migration could not be applied.' }
    dotnet tool run dotnet-ef migrations has-pending-model-changes --project $projectFile --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Migration and model differ.' }
    Write-Output 'PASS: migration applied to PostgreSQL; model has no pending changes.'

    [void] (New-Item -ItemType Directory -Path $testDirectory)
    $apiDll = Join-Path $repositoryRoot 'backend/bin/Debug/net10.0/SmartHealthFitness.Api.dll'
    $apiProcess = Start-Process -FilePath (Get-Command dotnet).Source -ArgumentList @('exec', ('"' + $apiDll + '"')) `
        -WorkingDirectory (Join-Path $repositoryRoot 'backend') -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $testDirectory 'api.stdout.log') -RedirectStandardError (Join-Path $testDirectory 'api.stderr.log')
    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromSeconds(10)
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        if ($apiProcess.HasExited) { throw 'API exited before becoming ready; check JWT/database configuration.' }
        try { $ready = (Invoke-Api 'GET' '/api/health').Status -eq 200 } catch { $ready = $false }
        if ($ready) { break }
        Start-Sleep -Milliseconds 500
    }
    Assert-Check $ready 'Health endpoint did not become ready.'

    $schema = Invoke-Api 'GET' '/swagger/v1/swagger.json'
    Assert-Check ($schema.Status -eq 200) 'OpenAPI is unavailable.'
    Assert-Check ($schema.Body.paths.'/api/users/me'.get.security.Bearer.Count -eq 0 -and
        $schema.Body.paths.'/api/users/me'.get.security.Count -eq 1) 'Swagger Bearer metadata missing.'
    Assert-Check (-not $schema.Body.paths.'/api/health'.get.security) 'Health must be public in Swagger.'
    Write-Output 'PASS: health remains public; Swagger documents Bearer authentication.'

    $email = [Guid]::NewGuid().ToString('N') + '@example.test'
    $password = 'Aa1!' + [Guid]::NewGuid().ToString('N')
    $registerBody = @{ firstName = 'Auth'; lastName = 'Check'; email = $email; password = $password }
    $invalid = Invoke-Api 'POST' '/api/auth/register' @{ firstName = ''; lastName = ''; email = 'invalid'; password = 'short' }
    Assert-Check ($invalid.Status -eq 400 -and $null -ne $invalid.Body.errors) 'Validation must return 400 + errors.'
    $errorFieldNames = @($invalid.Body.errors.PSObject.Properties.Name)
    Assert-Check ($errorFieldNames -ccontains 'email' -and $errorFieldNames -ccontains 'password') 'Validation error fields must match camelCase JSON names.'
    foreach ($role in @('Trainer', 'Dietitian', 'Admin')) {
        $roleBody = $registerBody.Clone(); $roleBody.roles = @($role)
        Assert-Check ((Invoke-Api 'POST' '/api/auth/register' $roleBody).Status -eq 400) 'Public role selection must be rejected.'
    }
    $registered = Invoke-Api 'POST' '/api/auth/register' $registerBody
    Assert-Check ($registered.Status -eq 201 -and ($registered.Body.roles -join ',') -eq 'User') 'Register must create only User role.'
    $userId = ([Guid]::Parse($registered.Body.id)).ToString()
    $duplicate = $registerBody.Clone(); $duplicate.email = $email.ToUpperInvariant()
    Assert-Check ((Invoke-Api 'POST' '/api/auth/register' $duplicate).Status -eq 409) 'Duplicate normalized email must return 409.'
    $raceBody = $registerBody.Clone(); $raceBody.email = [Guid]::NewGuid().ToString('N') + '@example.test'
    $raceA = $client.PostAsync($baseUrl + '/api/auth/register', (New-JsonContent $raceBody))
    $raceB = $client.PostAsync($baseUrl + '/api/auth/register', (New-JsonContent $raceBody))
    $raceStatuses = @([int] $raceA.GetAwaiter().GetResult().StatusCode, [int] $raceB.GetAwaiter().GetResult().StatusCode) | Sort-Object
    Assert-Check (($raceStatuses -join ',') -eq '201,409') 'Concurrent duplicate registration must have one winner.'
    Write-Output 'PASS: validation, public role rejection, register and duplicate/concurrent email protection.'

    $badLogin = Invoke-Api 'POST' '/api/auth/login' @{ email = $email; password = 'WrongPassword123!' }
    $unknownLogin = Invoke-Api 'POST' '/api/auth/login' @{ email = 'unknown@example.test'; password = 'WrongPassword123!' }
    Assert-Check ($badLogin.Status -eq 401 -and $unknownLogin.Status -eq 401 -and
        $badLogin.Body.title -eq $unknownLogin.Body.title) 'Login errors must be generic 401.'
    $login = Invoke-Api 'POST' '/api/auth/login' @{ email = $email.ToUpperInvariant(); password = $password }
    Assert-Check ($login.Status -eq 200 -and $login.NoStore) 'Login must succeed and prohibit caching.'
    $anonymous = Invoke-Api 'GET' '/api/users/me'
    Assert-Check ($anonymous.Status -eq 401 -and $anonymous.ContentType -eq 'application/problem+json' -and
        $anonymous.HasBearerChallenge) 'Anonymous me must return ProblemDetails 401 and Bearer challenge.'
    $me = Invoke-Api 'GET' '/api/users/me' $null $login.Body.accessToken
    Assert-Check ($me.Status -eq 200 -and $me.NoStore -and $me.Body.id -eq $userId -and $null -eq $me.Body.passwordHash) 'Authenticated me response is invalid or cacheable.'
    Assert-Check ((Invoke-Api 'GET' '/api/users/me' $null ($login.Body.accessToken + '!')).Status -eq 401) 'Tampered JWT must be rejected.'
    $expiredJwt = New-CheckJwt $userId ([DateTimeOffset]::UtcNow.AddMinutes(-5).ToUnixTimeSeconds()) $env:JWT_ISSUER $env:JWT_AUDIENCE
    $wrongIssuerJwt = New-CheckJwt $userId ([DateTimeOffset]::UtcNow.AddMinutes(5).ToUnixTimeSeconds()) 'wrong-issuer' $env:JWT_AUDIENCE
    $wrongAudienceJwt = New-CheckJwt $userId ([DateTimeOffset]::UtcNow.AddMinutes(5).ToUnixTimeSeconds()) $env:JWT_ISSUER 'wrong-audience'
    foreach ($invalidJwt in @($expiredJwt, $wrongIssuerJwt, $wrongAudienceJwt)) {
        Assert-Check ((Invoke-Api 'GET' '/api/users/me' $null $invalidJwt).Status -eq 401) 'Invalid JWT lifetime/issuer/audience was accepted.'
    }
    Write-Output 'PASS: login, authenticated me, anonymous rejection, JWT signature/lifetime/issuer/audience validation.'

    $storedPassword = Invoke-CheckSql "SELECT password_hash FROM users WHERE id = '$userId';"
    Assert-Check ($storedPassword -ne $password -and [Convert]::FromBase64String($storedPassword)[0] -eq 1) 'Password must be stored using Identity password hashing.'
    $refreshHash = Get-TokenHash $login.Body.refreshToken
    $storedRefresh = Invoke-CheckSql "SELECT token_hash FROM refresh_tokens WHERE user_id = '$userId';"
    Assert-Check ($storedRefresh -eq $refreshHash -and $storedRefresh.Length -eq 64) 'Only the refresh token SHA-256 hash should be stored.'
    Assert-Check ((Invoke-Api 'POST' '/api/auth/refresh' @{ refreshToken = 'invalid-token' }).Status -eq 401) 'Invalid refresh token must be rejected.'
    $expiryLogin = Invoke-Api 'POST' '/api/auth/login' @{ email = $email; password = $password }
    $expiryHash = Get-TokenHash $expiryLogin.Body.refreshToken
    [void] (Invoke-CheckSql "UPDATE refresh_tokens SET expires_at = created_at - interval '1 minute' WHERE token_hash = '$expiryHash';")
    Assert-Check ((Invoke-Api 'POST' '/api/auth/refresh' @{ refreshToken = $expiryLogin.Body.refreshToken }).Status -eq 401) 'Expired refresh token must be rejected.'
    $refreshed = Invoke-Api 'POST' '/api/auth/refresh' @{ refreshToken = $login.Body.refreshToken }
    Assert-Check ($refreshed.Status -eq 200 -and $refreshed.Body.refreshToken -ne $login.Body.refreshToken) 'Refresh rotation failed.'
    Assert-Check ((Invoke-Api 'POST' '/api/auth/refresh' @{ refreshToken = $login.Body.refreshToken }).Status -eq 401) 'Consumed token was reused.'
    Assert-Check ((Invoke-Api 'GET' '/api/users/me' $null $refreshed.Body.accessToken).Status -eq 200) 'Refreshed access token does not work.'
    $refreshBody = @{ refreshToken = $refreshed.Body.refreshToken }
    $refreshA = $client.PostAsync($baseUrl + '/api/auth/refresh', (New-JsonContent $refreshBody))
    $refreshB = $client.PostAsync($baseUrl + '/api/auth/refresh', (New-JsonContent $refreshBody))
    $refreshStatuses = @([int] $refreshA.GetAwaiter().GetResult().StatusCode, [int] $refreshB.GetAwaiter().GetResult().StatusCode) | Sort-Object
    Assert-Check (($refreshStatuses -join ',') -eq '200,401') 'Concurrent refresh must have only one winner.'
    Write-Output 'PASS: hashed credential storage; invalid/expired/reused and concurrent refresh protection.'

    [void] (Invoke-CheckSql "INSERT INTO user_roles (id, user_id, role_id) SELECT gen_random_uuid(), '$userId'::uuid, id FROM roles WHERE name IN ('Trainer', 'Dietitian', 'Admin');")
    $roleLogin = Invoke-Api 'POST' '/api/auth/login' @{ email = $email; password = $password }
    Assert-Check (($roleLogin.Body.user.roles -join ',') -eq 'Admin,Dietitian,Trainer,User') 'Multiple roles are not returned correctly.'
    $jwtPayload = $roleLogin.Body.accessToken.Split('.')[1].Replace('-', '+').Replace('_', '/')
    $jwtPayload = $jwtPayload.PadRight($jwtPayload.Length + ((4 - $jwtPayload.Length % 4) % 4), '=')
    $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($jwtPayload)) | ConvertFrom-Json
    Assert-Check (($claims.role | Sort-Object) -join ',' -eq 'Admin,Dietitian,Trainer,User') 'JWT role claims are missing.'

    $secondBody = $registerBody.Clone(); $secondBody.email = [Guid]::NewGuid().ToString('N') + '@example.test'
    $secondUser = Invoke-Api 'POST' '/api/auth/register' $secondBody
    $secondId = ([Guid]::Parse($secondUser.Body.id)).ToString()
    $secondHash = Invoke-CheckSql "SELECT password_hash FROM users WHERE id = '$secondId';"
    Assert-Check ($secondHash -ne $storedPassword) 'Password hashes must use independent salts.'
    $secondLogin = Invoke-Api 'POST' '/api/auth/login' @{ email = $secondBody.email; password = $password }
    $logoutBody = @{ refreshToken = $secondLogin.Body.refreshToken }
    $forbidden = Invoke-Api 'POST' '/api/auth/logout' $logoutBody $roleLogin.Body.accessToken
    Assert-Check ($forbidden.Status -eq 403 -and $forbidden.ContentType -eq 'application/problem+json') 'Cross-user logout must return 403 ProblemDetails.'
    Assert-Check ((Invoke-Api 'POST' '/api/auth/logout' $logoutBody $secondLogin.Body.accessToken).Status -eq 204) 'Logout failed.'
    Assert-Check ((Invoke-Api 'POST' '/api/auth/refresh' $logoutBody).Status -eq 401) 'Revoked refresh token was accepted.'
    Assert-Check ((Invoke-Api 'POST' '/api/auth/logout' $logoutBody $secondLogin.Body.accessToken).Status -eq 204) 'Logout should be idempotent.'
    Write-Output 'PASS: four roles in database/JWT, independent password salts, logout ownership and revocation.'

    [void] (Invoke-CheckSql "UPDATE users SET is_active = false WHERE id = '$userId';")
    Assert-Check ((Invoke-Api 'POST' '/api/auth/login' @{ email = $email; password = $password }).Status -eq 401) 'Inactive account login was accepted.'
    Assert-Check ((Invoke-Api 'POST' '/api/auth/refresh' @{ refreshToken = $roleLogin.Body.refreshToken }).Status -eq 401) 'Inactive account refresh was accepted.'
    Assert-Check ((Invoke-Api 'GET' '/api/users/me' $null $roleLogin.Body.accessToken).Status -eq 401) 'Inactive account access was accepted.'
    $tables = Invoke-CheckSql "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name NOT LIKE '\_\_%' ORDER BY table_name;"
    Assert-Check ($tables -eq "refresh_tokens`nroles`nuser_roles`nusers") 'Migration created unexpected domain tables.'
    Write-Output 'PASS: inactive accounts are blocked; only four auth tables exist.'
    docker compose -f $composeFile -p $testName stop postgres
    if ($LASTEXITCODE -ne 0) { throw 'Temporary PostgreSQL could not be stopped for health check.' }
    foreach ($healthToken in @('', $secondLogin.Body.accessToken)) {
        $unavailableHealth = Invoke-Api 'GET' '/api/health' $null $healthToken
        Assert-Check ($unavailableHealth.Status -eq 503 -and $unavailableHealth.Body.title -eq 'Database unavailable') 'Health must remain 503 when PostgreSQL stops, with or without a Bearer token.'
    }
    Write-Output 'PASS: health returns 503 when PostgreSQL stops, even with a valid Bearer token.'
    Write-Output 'AUTH SMOKE CHECKS PASSED.'
}
finally {
    if ($client) { $client.Dispose() }
    if ($apiProcess -and -not $apiProcess.HasExited) { $apiProcess.Kill(); [void] $apiProcess.WaitForExit(5000) }
    if ($databaseStarted) { docker compose -f $composeFile -p $testName down --volumes }
    foreach ($name in $originalEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], 'Process')
    }
    foreach ($logName in @('api.stdout.log', 'api.stderr.log')) {
        Remove-Item -LiteralPath (Join-Path $testDirectory $logName) -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $testDirectory -ErrorAction SilentlyContinue
    Pop-Location
}
