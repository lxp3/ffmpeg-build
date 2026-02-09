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

if ($Toolchain -eq "msvc" -and $EnableShared -ne 0) {
    Write-Error "Toolchain=msvc does not support shared builds. Please set EnableShared=0."
    exit 1
}


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
# $MsysRoot = "C:\msys64"
$MsysRoot = "E:\Repos\third_party\msys64"
$MsysShell = Join-Path $MsysRoot "msys2_shell.cmd"

# --- 关键修复：移�?MSYS2 自带�?link.exe 避免�?MSVC 冲突 ---
$MsysLink = Join-Path $MsysRoot "usr\bin\link.exe"
if (Test-Path $MsysLink) {
    Write-Host "Removing MSYS2 link.exe to avoid conflict with MSVC linker..."
    Remove-Item -Force $MsysLink
}

if (-not (Test-Path $MsysShell)) {
    Write-Error "MSYS2 not found at $MsysRoot"
    exit 1
}

# Convert ScriptDir to MSYS path
$Drive = $ScriptDir.Substring(0, 1).ToLower()
$PathPart = $ScriptDir.Substring(3).Replace('\', '/')
$MsysScriptDir = "/$Drive/$PathPart"

# Build command
# Append /mingw64/bin to PATH to find nasm, but keep it at the end to prefer MSVC tools
$BuildScript = "export PATH=`$PATH:/mingw64/bin && cd '$MsysScriptDir' && export TOOLCHAIN=$Toolchain && export ARCH=$Arch && export ENABLE_SHARED=$EnableShared && ./build-window.sh"

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

