param([Parameter(Mandatory)][string] $AdbPath, [Parameter(Mandatory)][string] $Device)
$ErrorActionPreference = 'Stop'
if ($Device -notmatch '^emulator-\d+$') { throw 'GPS fixture is restricted to Android emulators.' }
$package = 'com.smarthealthfitness.smart_health_fitness_mobile'
# Test-only GPS input. Production Dart uses the real Android Geolocator plugin.
& $AdbPath -s $Device shell cmd location set-location-enabled true | Out-Null
$granted = $false
for ($step = 0; $step -lt 240; $step++) {
    # Retry grants until Flutter installs the new APK manifest.
    if (-not $granted) {
        & $AdbPath -s $Device shell pm grant $package android.permission.ACCESS_COARSE_LOCATION 2>$null
        & $AdbPath -s $Device shell pm grant $package android.permission.ACCESS_FINE_LOCATION 2>$null
        $granted = $LASTEXITCODE -eq 0
    }
    $latitude = (41 + $step * 0.00006).ToString('F6', [Globalization.CultureInfo]::InvariantCulture)
    & $AdbPath -s $Device emu geo fix 29.000000 $latitude 0 8 | Out-Null
    Write-Output "GPS fixture: $step, $latitude, exit=$LASTEXITCODE"
    Start-Sleep -Seconds 2
}
