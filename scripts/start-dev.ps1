param(
    [ValidateSet('All', 'Backend', 'Mobile', 'Web')]
    [string] $Service = 'All',
    [switch] $Configure
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$repositoryRoot = Split-Path $PSScriptRoot -Parent
$settingsFile = Join-Path $repositoryRoot '.local/development.xml'
$backendUrl = 'http://localhost:5000'

function Invoke-Native([string] $Executable, [string[]] $Arguments) {
    # Windows PowerShell 5.1 must not treat normal native stderr as a crash.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($exitCode -ne 0) { throw "Komut basarisiz: $Executable (kod: $exitCode)" }
}

function Get-AndroidProperty([string] $Name) {
    $file = Join-Path $repositoryRoot 'mobile/android/local.properties'
    if (Test-Path -LiteralPath $file) {
        $line = Get-Content -LiteralPath $file | Where-Object { $_.StartsWith("$Name=") } | Select-Object -First 1
        if ($line) { return $line.Split('=', 2)[1].Replace('\\', '\') }
    }
}

function Get-Flutter {
    $command = Get-Command flutter.bat -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $sdk = Get-AndroidProperty 'flutter.sdk'
    if ($sdk -and (Test-Path -LiteralPath "$sdk/bin/flutter.bat")) { return "$sdk/bin/flutter.bat" }
    throw 'Flutter bulunamadi. Flutter SDK bin klasorunu PATH ayarina ekleyin.'
}

function Initialize-WebTools {
    $script:npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if ($script:npm) { return }
    # The existing local Codex runtime can supply Node/pnpm when npm is not on PATH.
    $runtime = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies'
    $node = Join-Path $runtime 'node/bin/node.exe'
    $script:pnpm = Join-Path $runtime 'bin/fallback/pnpm.cmd'
    if ((Test-Path -LiteralPath $node) -and (Test-Path -LiteralPath $script:pnpm)) {
        $env:PATH = (Split-Path $node -Parent) + ';' + $env:PATH
        return
    }
    throw 'Node.js/npm bulunamadi. Node.js 22.12 veya ustunu kurup baslaticiyi tekrar acin.'
}

function Invoke-Npm([string[]] $Arguments) {
    if ($script:npm) { Invoke-Native $script:npm.Source $Arguments }
    else { Invoke-Native $script:pnpm (@('dlx', 'npm@11') + $Arguments) }
}

function Write-WorkerOutput($Worker) {
    foreach ($output in $Worker.Outputs) {
        $count = 0
        while ($output.Pending -and $output.Pending.IsCompleted -and $count -lt 100) {
            $line = $output.Pending.GetAwaiter().GetResult()
            if ($null -eq $line) { $output.Pending = $null; break }
            Write-Host "[$($Worker.Name)] $line"
            $output.Pending = $output.Reader.ReadLineAsync()
            $count++
        }
    }
}

function Get-Settings {
    if ((Test-Path -LiteralPath $settingsFile) -and -not $Configure) {
        try {
            $settings = Import-Clixml -LiteralPath $settingsFile
            if ($settings.Password -isnot [Security.SecureString] -or $settings.Jwt -isnot [Security.SecureString]) {
                throw 'Invalid settings'
            }
            return $settings
        } catch { throw 'Yerel ayarlar okunamadi. Ayni Windows kullanicisini kullanin veya -Configure ile yeniden ayarlayin.' }
    }
    Write-Host 'Ilk kurulum: mevcut PostgreSQL parolanizi girin. Veritabani silinmez.' -ForegroundColor Cyan
    $password = Read-Host 'PostgreSQL parolasi' -AsSecureString
    if ($password.Length -eq 0) { throw 'PostgreSQL parolasi bos olamaz.' }
    $portText = Read-Host 'PostgreSQL portu (genellikle 5432; Enter ile varsayilan)'
    $port = 5432
    if ($portText -and (-not [int]::TryParse($portText, [ref] $port) -or $port -lt 1024 -or $port -gt 65535)) {
        throw 'PostgreSQL portu 1024-65535 arasinda olmali.'
    }
    $jwt = $env:JWT_SECRET
    if ([string]::IsNullOrWhiteSpace($jwt)) {
        $bytes = New-Object byte[] 64
        $random = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $random.GetBytes($bytes) } finally { $random.Dispose() }
        $jwt = [Convert]::ToBase64String($bytes)
    }
    $settings = [pscustomobject]@{
        Password = $password
        Jwt = ConvertTo-SecureString $jwt -AsPlainText -Force
        Port = $port
        Database = $(if ($env:POSTGRES_DB) { $env:POSTGRES_DB } else { 'smart_health_fitness' })
        Username = $(if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { 'smart_health_fitness' })
    }
    New-Item -ItemType Directory -Path (Split-Path $settingsFile -Parent) -Force | Out-Null
    # Windows DPAPI binds these SecureStrings to this user and computer.
    $settings | Export-Clixml -LiteralPath $settingsFile
    Write-Host 'Ayarlar sifreli kaydedildi. Sonraki acilislarda tekrar sorulmayacak.' -ForegroundColor Green
    return $settings
}

function Test-Docker {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & docker.exe info --format '{{.ServerVersion}}' *> $null
        return $LASTEXITCODE -eq 0
    } finally { $ErrorActionPreference = $previousPreference }
}

function Start-Docker {
    if (Test-Docker) { return }
    $desktop = Join-Path $env:ProgramFiles 'Docker/Docker/Docker Desktop.exe'
    if (-not (Test-Path -LiteralPath $desktop)) { throw 'Docker Desktop bulunamadi.' }
    Write-Host 'Docker Desktop baslatiliyor...'
    Start-Process -FilePath $desktop -WindowStyle Hidden | Out-Null
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    do {
        Start-Sleep -Seconds 2
        if (Test-Docker) { return }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Docker hazir olmadi. Docker Desktop hata mesajini kontrol edip tekrar baslatin.'
}

function Wait-Backend {
    Write-Host 'Backend hazir olana kadar bekleniyor...'
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    do {
        try {
            $health = Invoke-RestMethod "$backendUrl/api/health" -TimeoutSec 2
            if ($health.status -eq 'Healthy' -and $health.database -eq 'Connected') { return }
        } catch { }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Backend hazir olmadi. Backend terminalindeki hatayi kontrol edin.'
}

function Start-Mobile {
    $flutter = Get-Flutter
    $sdk = Get-AndroidProperty 'sdk.dir'
    if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android/sdk' }
    $adb = Join-Path $sdk 'platform-tools/adb.exe'
    if (-not (Test-Path -LiteralPath $adb)) { throw 'Android SDK/adb bulunamadi.' }
    $device = $null
    $devices = & $adb devices
    foreach ($line in $devices) {
        if ($line -match '^(emulator-\d+)\s+device\s*$') { $device = $Matches[1]; break }
    }
    if (-not $device) {
        $emulator = Join-Path $sdk 'emulator/emulator.exe'
        $names = @(& $emulator -list-avds)
        if ($names.Count -eq 0) { throw 'Emulator yok. Android Studio Device Manager ile bir cihaz olusturun.' }
        $name = if ($names -contains 'deneme_cihazi') { 'deneme_cihazi' } else { $names[0] }
        Invoke-Native $flutter @('emulators', '--launch', $name)
    }
    Write-Host 'Android acilisi bekleniyor...'
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    do {
        $devices = & $adb devices
        foreach ($line in $devices) {
            if ($line -match '^(emulator-\d+)\s+device\s*$') { $device = $Matches[1]; break }
        }
        if ($device) {
            $boot = & $adb -s $device shell getprop sys.boot_completed 2>$null
            if ($LASTEXITCODE -eq 0 -and "$boot".Trim() -eq '1') { break }
        }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $deadline)
    if (-not $device -or "$boot".Trim() -ne '1') { throw 'Emulator hazir olmadi. Emulator penceresini kontrol edin.' }
    Wait-Backend
    Set-Location (Join-Path $repositoryRoot 'mobile')
    Invoke-Native $flutter @('run', '-d', $device, '--dart-define=API_BASE_URL=http://10.0.2.2:5000')
}

# Dot-sourcing exposes helpers for checks without launching any applications.
if ($MyInvocation.InvocationName -eq '.') { return }

try {
    if ($env:OS -ne 'Windows_NT') { throw 'Bu baslatici Windows icindir.' }
    Set-Location $repositoryRoot
    switch ($Service) {
        'All' {
            foreach ($tool in @('docker.exe', 'dotnet.exe')) {
                if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool bulunamadi." }
            }
            Get-Flutter | Out-Null
            Initialize-WebTools
            Get-Settings | Out-Null
            $powershell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
            $workers = @()
            try {
                foreach ($part in @('Backend', 'Web', 'Mobile')) {
                    $start = [Diagnostics.ProcessStartInfo]::new()
                    $start.FileName = $powershell
                    $start.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Service $part"
                    $start.WorkingDirectory = $repositoryRoot
                    $start.UseShellExecute = $false
                    $start.CreateNoWindow = $true
                    $start.RedirectStandardOutput = $true
                    $start.RedirectStandardError = $true
                    $start.RedirectStandardInput = $true
                    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
                    $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
                    $process = [Diagnostics.Process]::Start($start)
                    $outputs = @($process.StandardOutput, $process.StandardError) | ForEach-Object {
                        [pscustomobject]@{ Reader = $_; Pending = $_.ReadLineAsync() }
                    }
                    $workers += [pscustomobject]@{ Name = $part; Process = $process; Outputs = $outputs }
                }
                Write-Host 'Backend, Web ve Mobile bu terminalde calisiyor. Kapatmak icin Ctrl+C.' -ForegroundColor Green
                while ($true) {
                    foreach ($worker in $workers) { Write-WorkerOutput $worker }
                    $finished = $workers | Where-Object { $_.Process.HasExited } | Select-Object -First 1
                    if ($finished) {
                        if ($finished.Process.ExitCode -ne 0) {
                            throw "$($finished.Name) basarisiz oldu (kod: $($finished.Process.ExitCode)). Yukaridaki hata mesajini kontrol edin."
                        }
                        Write-Host "$($finished.Name) kapatildi; diger uygulamalar da durduruluyor."
                        break
                    }
                    Start-Sleep -Milliseconds 100
                }
            } finally {
                foreach ($worker in $workers) {
                    if (-not $worker.Process.HasExited) {
                        # Stop only this launcher's worker and its child processes.
                        $stop = [Diagnostics.ProcessStartInfo]::new()
                        $stop.FileName = "$env:SystemRoot/System32/taskkill.exe"
                        $stop.Arguments = "/PID $($worker.Process.Id) /T /F"
                        $stop.UseShellExecute = $false
                        $stop.CreateNoWindow = $true
                        $stop.RedirectStandardOutput = $true
                        $stop.RedirectStandardError = $true
                        $killer = [Diagnostics.Process]::Start($stop)
                        $killer.WaitForExit()
                        $killer.Dispose()
                    }
                    $worker.Process.Dispose()
                }
            }
        }
        'Backend' {
            Write-Host 'PostgreSQL ve API baslatiliyor...' -ForegroundColor Cyan
            $settings = Get-Settings
            $env:POSTGRES_PASSWORD = [Net.NetworkCredential]::new('', $settings.Password).Password
            $env:JWT_SECRET = [Net.NetworkCredential]::new('', $settings.Jwt).Password
            $env:POSTGRES_PORT = "$($settings.Port)"
            $env:POSTGRES_DB = $settings.Database
            $env:POSTGRES_USER = $settings.Username
            $passwordQuoted = $env:POSTGRES_PASSWORD.Replace('"', '""')
            $userQuoted = $settings.Username.Replace('"', '""')
            $databaseQuoted = $settings.Database.Replace('"', '""')
            $env:DATABASE_CONNECTION_STRING = "Host=localhost;Port=$env:POSTGRES_PORT;Database=`"$databaseQuoted`";Username=`"$userQuoted`";Password=`"$passwordQuoted`";Timeout=5;Command Timeout=5"
            Start-Docker
            $previousPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                & docker.exe image inspect postgres:17 *> $null
                $imageExists = $LASTEXITCODE -eq 0
            } finally { $ErrorActionPreference = $previousPreference }
            # A cached image needs no Docker Hub request during daily startup.
            $pullPolicy = if ($imageExists) { 'never' } else { 'missing' }
            Invoke-Native 'docker.exe' @('compose', '-f', 'backend/docker-compose.yml', 'up', '-d', '--wait', '--pull', $pullPolicy)
            Invoke-Native 'dotnet.exe' @('tool', 'restore')
            Invoke-Native 'dotnet.exe' @('tool', 'run', 'dotnet-ef', 'database', 'update', '--project', 'backend/SmartHealthFitness.Api.csproj')
            Invoke-Native 'dotnet.exe' @('run', '--project', 'backend/SmartHealthFitness.Api.csproj', '--launch-profile', 'http', '--no-build')
        }
        'Web' {
            Write-Host 'http://localhost:5173 baslatiliyor...' -ForegroundColor Cyan
            Initialize-WebTools
            Set-Location (Join-Path $repositoryRoot 'web')
            # Hash with .NET so nested Windows PowerShell sessions do not depend
            # on Get-FileHash being available through module auto-loading.
            $lockStream = [IO.File]::OpenRead((Join-Path $PWD 'package-lock.json'))
            $hasher = [Security.Cryptography.SHA256]::Create()
            try {
                $lockHash = [BitConverter]::ToString($hasher.ComputeHash($lockStream)).Replace('-', '')
            } finally {
                $lockStream.Dispose()
                $hasher.Dispose()
            }
            $stamp = Join-Path $repositoryRoot '.local/web-lock-hash.txt'
            if (-not (Test-Path 'node_modules') -or -not (Test-Path $stamp) -or (Get-Content $stamp -Raw).Trim() -ne $lockHash) {
                Invoke-Npm @('ci')
                New-Item -ItemType Directory -Path (Split-Path $stamp -Parent) -Force | Out-Null
                Set-Content -LiteralPath $stamp -Value $lockHash
            }
            Invoke-Npm @('run', 'dev')
        }
        'Mobile' {
            Write-Host 'Android ve Flutter baslatiliyor...' -ForegroundColor Cyan
            Start-Mobile
        }
    }
} catch {
    Write-Host "HATA: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
