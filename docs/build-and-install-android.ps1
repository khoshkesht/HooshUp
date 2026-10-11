param(
    [string]$Serial,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$projectPath = Join-Path $PSScriptRoot '..\SourceProject'
$apkPath = Join-Path $projectPath 'HooshUp-debug-install.apk'
$packageName = 'com.example.hooshup'

$adbCommand = Get-Command adb -ErrorAction SilentlyContinue | Select-Object -First 1
if ($adbCommand) {
    $adb = $adbCommand.Source
} else {
    $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (-not (Test-Path -LiteralPath $adb -PathType Leaf)) {
        throw 'adb was not found in PATH or the Android SDK platform-tools directory.'
    }
}

if ($SkipBuild) {
    if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
        throw 'The APK does not exist. Run without -SkipBuild first.'
    }
    Write-Host "Using existing APK: $apkPath"
} else {
    $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($godotCommand) {
        $godot = $godotCommand.Source
    } else {
        $godot = 'E:\Projects\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe'
        if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
            throw 'Godot was not found in PATH or at the project-documented fallback path.'
        }
    }
    Write-Host 'Building Android debug APK...'
    if (Test-Path -LiteralPath $apkPath -PathType Leaf) {
        Remove-Item -LiteralPath $apkPath
    }
    & $godot --headless --path $projectPath --export-debug 'Android' $apkPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
        throw 'APK export failed. The installed app was not changed.'
    }
}

function Invoke-Adb {
    param([string[]]$Arguments)

    # Windows PowerShell 5.1 reports native stderr as an error record even when adb succeeds.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $adb @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $lines = @($output | ForEach-Object { $_.ToString() })
    if ($exitCode -ne 0) {
        throw "adb $($Arguments -join ' ') failed (exit $exitCode): $($lines -join ' ')"
    }
    return $lines
}

$deviceLines = Invoke-Adb -Arguments @('devices')
$devices = @($deviceLines | ForEach-Object {
    if ($_ -match '^\s*(\S+)\s+device(?:\s|$)') { $Matches[1] }
})

if ($Serial) {
    if ($Serial -notin $devices) { throw "Device '$Serial' is not connected and authorized." }
    $selectedDevice = $Serial
} elseif ($devices.Count -eq 1) {
    $selectedDevice = $devices[0]
} else {
    throw "Expected one connected and authorized device; found $($devices.Count). Use -Serial to select one."
}

$installedPath = Invoke-Adb -Arguments @('-s', $selectedDevice, 'shell', 'pm', 'path', $packageName)
if ($installedPath -match '^package:') {
    Write-Host "Uninstalling $packageName from $selectedDevice..."
    Invoke-Adb -Arguments @('-s', $selectedDevice, 'uninstall', $packageName) | ForEach-Object { Write-Host $_ }
}

Write-Host "Installing APK on $selectedDevice..."
Invoke-Adb -Arguments @('-s', $selectedDevice, 'install', $apkPath) | ForEach-Object { Write-Host $_ }
Write-Host 'Done.'
