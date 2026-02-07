# build-wasm.ps1 - Build FFmpeg WASM on Windows using Emscripten
# Run in PowerShell

$ErrorActionPreference = "Stop"

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $BaseDir

# FFmpeg version
$FFMPEG_VERSION = "7.1"
$FFMPEG_TARBALL = "ffmpeg-$FFMPEG_VERSION.tar.gz"
$FFMPEG_TARBALL_URL = "http://ffmpeg.org/releases/$FFMPEG_TARBALL"

# Emscripten version
$EMSDK_VERSION = "3.1.51"
$EMSDK_DIR = "$BaseDir\emsdk"

Write-Host "=== Setting up Emscripten ===" -ForegroundColor Cyan

# Clone emsdk if not exists
if (-not (Test-Path $EMSDK_DIR)) {
    Write-Host "Cloning emsdk..."
    git clone https://github.com/emscripten-core/emsdk.git $EMSDK_DIR
}

# Install and activate emsdk
Set-Location $EMSDK_DIR
Write-Host "Installing Emscripten $EMSDK_VERSION..."
& .\emsdk.bat install $EMSDK_VERSION
if ($LASTEXITCODE -ne 0) { throw "emsdk install failed" }

Write-Host "Activating Emscripten $EMSDK_VERSION..."
& .\emsdk.bat activate $EMSDK_VERSION
if ($LASTEXITCODE -ne 0) { throw "emsdk activate failed" }

# Source environment - parse emsdk_env.bat output
Write-Host "Setting up environment variables..."
$envOutput = & cmd /c "emsdk_env.bat && set" 2>$null
foreach ($line in $envOutput) {
    if ($line -match "^([^=]+)=(.*)$") {
        $name = $matches[1]
        $value = $matches[2]
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

# Verify emcc is available
$emccPath = Get-Command emcc -ErrorAction SilentlyContinue
if (-not $emccPath) {
    # Try adding paths manually
    $env:PATH = "$EMSDK_DIR;$EMSDK_DIR\upstream\emscripten;$env:PATH"
    $env:EMSDK = $EMSDK_DIR
    $env:EMSDK_NODE = "$EMSDK_DIR\node\22.16.0_64bit\bin\node.exe"
}

# Verify again
$emccPath = Get-Command emcc -ErrorAction SilentlyContinue
if (-not $emccPath) {
    throw "emcc not found. Emscripten setup failed."
}
Write-Host "emcc found at: $($emccPath.Source)" -ForegroundColor Green

Set-Location $BaseDir

Write-Host "=== Downloading FFmpeg ===" -ForegroundColor Cyan

# Download FFmpeg tarball if missing
if (-not (Test-Path $FFMPEG_TARBALL)) {
    Write-Host "Downloading $FFMPEG_TARBALL..."
    Invoke-WebRequest -Uri $FFMPEG_TARBALL_URL -OutFile $FFMPEG_TARBALL
}

# Create build directory
$BUILD_DIR = "$BaseDir\build-static-wasm"
$OUTPUT_DIR = "$BaseDir\outputs\ffmpeg-$FFMPEG_VERSION-wasm"

if (Test-Path $BUILD_DIR) {
    Remove-Item -Recurse -Force $BUILD_DIR
}
New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null

Write-Host "Extracting FFmpeg..."
tar -xzf $FFMPEG_TARBALL -C $BUILD_DIR --strip-components=1

# Read configure flags from file
$configFlags = @()
if (Test-Path "ffmpeg_configure_flags.txt") {
    $configFlags = Get-Content "ffmpeg_configure_flags.txt" | Where-Object { $_.Trim() -ne "" }
}

# WASM specific configure flags
$wasmFlags = @(
    "--prefix=$OUTPUT_DIR"
    "--target-os=none"
    "--arch=x86_32"
    "--enable-cross-compile"
    "--cc=emcc"
    "--cxx=em++"
    "--ar=emar"
    "--nm=emnm"
    "--ranlib=emranlib"
    "--disable-autodetect"
    "--disable-stripping"
    "--disable-inline-asm"
    "--disable-x86asm"
    "--disable-asm"
    "--disable-runtime-cpudetect"
    "--disable-pthreads"
    "--disable-w32threads"
    "--disable-os2threads"
    "--enable-static"
    "--disable-shared"
    "--disable-programs"
    '--extra-cflags="-O3 -msimd128"'
    '--extra-ldflags="-O3 -msimd128 -sWASM=1"'
)

Write-Host "=== Configuring FFmpeg for WASM ===" -ForegroundColor Cyan

Set-Location $BUILD_DIR

# Run configure using bash (from Git for Windows or MSYS2)
$bashPath = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bashPath) {
    # Try common locations
    $possibleBash = @(
        "C:\Program Files\Git\bin\bash.exe"
        "C:\msys64\usr\bin\bash.exe"
    )
    foreach ($p in $possibleBash) {
        if (Test-Path $p) {
            $bashPath = @{Source = $p}
            break
        }
    }
}

if (-not $bashPath) {
    throw "bash not found. Please install Git for Windows or MSYS2."
}

Write-Host "Using bash: $($bashPath.Source)"

# Build configure command
$allFlags = $wasmFlags + $configFlags
$configCmd = "./configure " + ($allFlags -join " ")

Write-Host "Running: $configCmd"

# Execute configure
& $bashPath.Source -c "source '$EMSDK_DIR/emsdk_env.sh' && $configCmd"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Configure failed. Check ffbuild/config.log for details." -ForegroundColor Red
    if (Test-Path "ffbuild/config.log") {
        Get-Content "ffbuild/config.log" -Tail 50
    }
    throw "Configure failed"
}

Write-Host "=== Building FFmpeg ===" -ForegroundColor Cyan

# Get number of processors
$numProcs = [Environment]::ProcessorCount

& $bashPath.Source -c "source '$EMSDK_DIR/emsdk_env.sh' && make -j$numProcs"
if ($LASTEXITCODE -ne 0) { throw "Build failed" }

Write-Host "=== Installing FFmpeg ===" -ForegroundColor Cyan

& $bashPath.Source -c "source '$EMSDK_DIR/emsdk_env.sh' && make install"
if ($LASTEXITCODE -ne 0) { throw "Install failed" }

Set-Location $BaseDir

Write-Host "=== Packaging ===" -ForegroundColor Cyan

# Create output directory if needed
if (-not (Test-Path "outputs")) {
    New-Item -ItemType Directory -Path "outputs" | Out-Null
}

$tarName = "outputs\ffmpeg-$FFMPEG_VERSION-wasm.tar.gz"
tar -czf $tarName -C outputs "ffmpeg-$FFMPEG_VERSION-wasm"

Write-Host "=== Build Complete ===" -ForegroundColor Green
Write-Host "Output: $OUTPUT_DIR"
Write-Host "Archive: $tarName"
