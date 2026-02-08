# PowerShell script to build FFmpeg with MSVC (via MSYS2)
# This script acts as a wrapper to launch build-windows.sh in an MSYS2 bash environment with MSVC toolchain.

param (
    [string]$Arch = "x86_64",
    [int]$EnableShared = 0,
    [string]$Toolchain = "msvc"
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
Set-Location $ScriptDir

if ($Toolchain -eq "msvc") {
    Write-Host "Searching for Visual Studio..."
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        Write-Error "vswhere.exe not found. Please ensure Visual Studio is installed."
        exit 1
    }

    $installPath = &$vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $installPath) {
        Write-Error "Visual Studio installation with C++ tools not found."
        exit 1
    }

    Write-Host "Using Visual Studio at: $installPath"

    # Get MSVC environment variables (PATH, INCLUDE, LIB, etc.)
    $vcvars = Join-Path $installPath "VC\Auxiliary\Build\vcvarsall.bat"
    $tempFile = [System.IO.Path]::GetTempFileName() + ".bat"
    "@echo off
    call `"$vcvars`" x64 > nul
    set
    " | Out-File -FilePath $tempFile -Encoding ascii

    $vars = cmd /c $tempFile
    Remove-Item $tempFile

    Write-Host "Applying MSVC environment variables..."
    foreach ($line in $vars) {
        if ($line -match "^(.*?)=(.*)$") {
            $name = $matches[1]
            $value = $matches[2]
            [System.Environment]::SetEnvironmentVariable($name, $value, [System.EnvironmentVariableTarget]::Process)
        }
    }
}

Write-Host "Starting FFmpeg Build for Windows ($Toolchain, $Arch, Shared=$EnableShared)..."

# MSYS2 path
$MsysShell = "C:\msys64\msys2_shell.cmd"
if (-not (Test-Path $MsysShell)) {
    Write-Error "MSYS2 not found at C:\msys64"
    exit 1
}

# Convert ScriptDir to MSYS path
$Drive = $ScriptDir.Substring(0, 1).ToLower()
$PathPart = $ScriptDir.Substring(3).Replace('\', '/')
$MsysScriptDir = "/$Drive/$PathPart"

# Build command
$BuildScript = "cd '$MsysScriptDir' && export TOOLCHAIN=$Toolchain && export ARCH=$Arch && export ENABLE_SHARED=$EnableShared && ./build-windows.sh"

# Execute using msys2_shell.cmd
# For MSVC, we use -msys to avoid MinGW tools (like ar, ld) polluting the PATH.
# -use-full-path inherits the MSVC environment variables we set above.
$MsysMode = if ($Toolchain -eq "msvc") { "-msys" } else { "-mingw64" }
$UseFullPath = if ($Toolchain -eq "msvc") { "-use-full-path" } else { "" }

& $MsysShell $MsysMode $UseFullPath -defterm -no-start -here -c $BuildScript

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed with exit code $LASTEXITCODE"
}

Write-Host "Build finished successfully."
