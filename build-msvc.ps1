# PowerShell script to build FFmpeg with MSVC (via MSYS2)
# This script acts as a wrapper to launch build-windows.sh in an MSYS2 bash environment.

param (
    [string]$Arch = "x86_64",
    [int]$EnableShared = 0
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
Set-Location $ScriptDir

Write-Host "Starting FFmpeg Build for Windows ($Arch, Shared=$EnableShared)..."

# Use MSYS2 MinGW64 shell directly
$Mingw64Bash = "C:\msys64\mingw64.exe"
if (-not (Test-Path $Mingw64Bash)) {
    # Fallback to msys2_shell with MINGW64
    $Mingw64Bash = "C:\msys64\msys2_shell.cmd"
    if (-not (Test-Path $Mingw64Bash)) {
        Write-Error "MSYS2 MinGW64 not found. Please ensure MSYS2 is installed at C:\msys64"
        exit 1
    }
}
Write-Host "Using MSYS2 MinGW64"

# Convert ScriptDir to MSYS path for passing to bash
# e.g. C:\Users -> /c/Users
$Drive = $ScriptDir.Substring(0, 1).ToLower()
$PathPart = $ScriptDir.Substring(3).Replace('\', '/')
$MsysScriptDir = "/$Drive/$PathPart"

# Build command to run build-windows.sh
$BuildScript = "cd '$MsysScriptDir' && export ARCH=$Arch && export ENABLE_SHARED=$EnableShared && ./build-windows.sh"

# Execute using msys2_shell.cmd with MINGW64 environment
& C:\msys64\msys2_shell.cmd -mingw64 -defterm -no-start -here -c $BuildScript

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed with exit code $LASTEXITCODE"
}

Write-Host "Build finished successfully."
