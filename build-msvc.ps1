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

# Find MSYS2 Bash
$Bash = Get-Command "bash" -ErrorAction SilentlyContinue
if ($null -eq $Bash) {
    # Common MSYS2 locations
    $PossiblePaths = @(
        "C:\msys64\usr\bin\bash.exe",
        "C:\Program Files\Git\bin\bash.exe"
    )
    foreach ($Path in $PossiblePaths) {
        if (Test-Path $Path) {
            $Bash = $Path
            break
        }
    }
}

if ($null -eq $Bash) {
    Write-Error "bash not found. Please ensure MSYS2 or Git Bash is installed and in PATH."
}
Write-Host "Using bash: $Bash"

# Convert ScriptDir to MSYS path for passing to bash
# e.g. C:\Users -> /c/Users
$Drive = $ScriptDir.Substring(0, 1).ToLower()
$PathPart = $ScriptDir.Substring(3).Replace('\', '/')
$MsysScriptDir = "/$Drive/$PathPart"

# Build command to run build-windows.sh
# We export environment variables ARCH and ENABLE_SHARED for the script to pick up
$Command = "cd ""$MsysScriptDir"" && export ARCH=$Arch && export ENABLE_SHARED=$EnableShared && ./build-windows.sh"

# Execute
& $Bash -c $Command

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed with exit code $LASTEXITCODE"
}

Write-Host "Build finished successfully."
