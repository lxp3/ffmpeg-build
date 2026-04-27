# FFmpeg Build

FFmpeg 音频编解码库的跨平台构建工具集

## 功能特性

本项目专注于音频处理，支持：

| 功能 | 支持 |
|------|------|
| 从视频提取音频 | 支持 (MP4/MKV/AVI/FLV 等) |
| 麦克风录制 (dshow) | 支持 |
| 流式音频 (HTTP/RTMP/RTSP) | 支持 |
| 音频格式转换 | 支持 |
| AAC/MP3/FLAC/WAV/OGG/Opus | 支持编解码 |
| PCM 各种格式 | 支持编解码 |
| 视频编码 | 不支持 |

## 发布包

| 平台 | 类型 | 编译器 | 包名 |
|------|------|--------|------|
| Linux | 静态库 | GCC | `ffmpeg-7.1-static-x86_64-linux-gnu.tar.gz` |
| Linux | 动态库 | GCC | `ffmpeg-7.1-shared-x86_64-linux-gnu.tar.gz` |
| Linux | 静态库 | GCC | `ffmpeg-7.1-static-aarch64-linux-gnu.tar.gz` |
| Linux | 动态库 | GCC | `ffmpeg-7.1-shared-aarch64-linux-gnu.tar.gz` |
| macOS | 静态库 | Clang | `ffmpeg-7.1-static-x86_64-macos.tar.gz` |
| macOS | 动态库 | Clang | `ffmpeg-7.1-shared-x86_64-macos.tar.gz` |
| macOS | 静态库 | Clang | `ffmpeg-7.1-static-aarch64-macos.tar.gz` |
| macOS | 动态库 | Clang | `ffmpeg-7.1-shared-aarch64-macos.tar.gz` |
| Windows | 静态库 | MSVC | `ffmpeg-7.1-static-x86_64-msvc.tar.gz` |
| Windows | 静态库 | MinGW | `ffmpeg-7.1-static-x86_64-w64-mingw32.tar.gz` |
| Windows | 动态库 | MinGW | `ffmpeg-7.1-shared-x86_64-w64-mingw32.tar.gz` |
| WebAssembly | 静态库 | Emscripten | `ffmpeg-7.1-wasm.tar.gz` |

## 构建命令

### 快速开始

推荐优先使用统一入口 `build.sh`。

```bash
# Linux 当前机器，构建静态库
ENABLE_SHARED=0 ./build.sh

# Linux 当前机器，构建动态库
ENABLE_SHARED=1 ./build.sh

# 显式指定 Linux arm64
TARGET_OS=linux ARCH=aarch64 ENABLE_SHARED=0 ./build.sh

# 显式指定 macOS arm64
TARGET_OS=macos ARCH=aarch64 ENABLE_SHARED=0 ./build.sh

# 在 MSYS2 里构建 Windows MinGW 静态库
TARGET_OS=windows TOOLCHAIN=mingw ENABLE_SHARED=0 ./build.sh

# 没有 sudo、跳过外部依赖
ENABLE_EXTERNAL_CODECS=0 ENABLE_SHARED=0 ./build.sh
```

产物默认输出到 `outputs/` 目录，打包文件也会生成在仓库根目录，例如：

- `outputs/ffmpeg-7.1-static-x86_64-linux-gnu`
- `ffmpeg-7.1-static-x86_64-linux-gnu.tar.gz`

### 统一入口 `build.sh`

```bash
# 自动按当前宿主平台检测目标平台与架构
ENABLE_SHARED=0 ./build.sh

# 显式指定平台 / 工具链 / 架构
TARGET_OS=linux ARCH=aarch64 ENABLE_SHARED=1 ./build.sh
TARGET_OS=macos ARCH=aarch64 ENABLE_SHARED=1 ./build.sh
TARGET_OS=windows TOOLCHAIN=mingw ENABLE_SHARED=0 ./build.sh
```

默认行为：

- 自动检测 `ARCH`
- `Linux` 宿主默认走 Linux 构建
- `macOS` 宿主默认走 macOS 构建
- `MSYS2 / GitHub Windows runner` 默认走 Windows 构建

可用环境变量：

- `ENABLE_SHARED=0|1`
  - `0` 表示静态库
  - `1` 表示动态库
- `ENABLE_EXTERNAL_CODECS=0|1`
  - 默认 `1`
  - `1` 表示启用 `libmp3lame`、`libopus`、`libvorbis`、`libspeex`、`openssl`
  - `0` 表示关闭这些外部依赖，适合没有 `sudo`、没有系统开发包的环境
- `ARCH`
  - 可省略，默认自动检测
  - 支持 `x86_64`、`aarch64`
  - 兼容别名：`amd64 -> x86_64`，`arm64 -> aarch64`
- `TARGET_OS`
  - 可省略，默认按宿主系统自动判断
  - 支持 `linux`、`macos`、`windows`
- `TOOLCHAIN`
  - 仅 Windows 使用
  - 支持 `mingw`、`msvc`

当前 `ARCH` 统一支持：

- `x86_64`
- `aarch64`

### Linux

```bash
# 静态库
ENABLE_SHARED=0 ./build.sh

# 动态库
ENABLE_SHARED=1 ./build.sh

# 指定 arm64
ARCH=aarch64 ENABLE_SHARED=0 ./build.sh

# 无 sudo 环境
ENABLE_EXTERNAL_CODECS=0 ENABLE_SHARED=0 ./build.sh
```

### macOS

```bash
# 静态库
ENABLE_SHARED=0 ./build.sh

# 动态库
ENABLE_SHARED=1 ./build.sh

# 指定 arm64
TARGET_OS=macos ARCH=aarch64 ENABLE_SHARED=0 ./build.sh
```

推荐通过 Homebrew 安装完整依赖：

```bash
brew install \
  autoconf \
  automake \
  libtool \
  pkg-config \
  nasm \
  yasm \
  make \
  bison \
  gnu-tar \
  xz \
  openssl@3 \
  lame \
  opus \
  libogg \
  libvorbis \
  speex
```

GitHub Actions 使用较新的 macOS 15 runner 构建，但显式设置
`MACOSX_DEPLOYMENT_TARGET=12.0`，发布包按 macOS 12+ 兼容性处理。

### Windows (MSVC)

1. 安装 Visual Studio (推荐 2022) 并勾选 "使用 C++ 的桌面开发" 工作负载。

2. 安装 MSYS2 (用于提供构建环境，如 `make`, `bash`, `tar` 等)。

3. 在 PowerShell 中运行：

```powershell
# 仅支持构建静态库
.\build-window.ps1 -EnableShared 0

# 如需显式覆盖架构
.\build-window.ps1 -Arch x86_64 -EnableShared 0
```

该脚本会自动查找 Visual Studio 环境，并启动 MSYS2 进行构建。输出的 `.lib` 文件将位于 `outputs/` 目录。

说明：

- `build-window.ps1` 是给 MSVC 准备环境的包装脚本
- 当前 `MSVC` 仅支持 `x86_64`
- `MSVC` 不支持 `EnableShared=1`

### Windows (MinGW - MSYS2)

在 MSYS2 MINGW64 终端运行：

```bash
# 静态库
TARGET_OS=windows TOOLCHAIN=mingw ENABLE_SHARED=0 ./build.sh

# 动态库
TARGET_OS=windows TOOLCHAIN=mingw ENABLE_SHARED=1 ./build.sh
```

如果你想直接调用底层脚本，也可以：

```bash
TOOLCHAIN=mingw ENABLE_SHARED=0 ./build-window.sh
TOOLCHAIN=mingw ENABLE_SHARED=1 ./build-window.sh
```

### WebAssembly

```bash
# Linux/macOS
./build-wasm.sh

# Windows (PowerShell)
.\build-wasm.ps1
```

WASM 构建脚本会自动安装 Emscripten SDK。

## 依赖

### Linux

```bash
# Ubuntu/Debian
sudo apt-get install \
  build-essential \
  nasm \
  patchelf \
  libmp3lame-dev \
  libopus-dev \
  libvorbis-dev \
  libspeex-dev \
  libssl-dev

# CentOS/RHEL
sudo yum install \
  gcc \
  make \
  nasm \
  patchelf \
  lame-devel \
  opus-devel \
  libvorbis-devel \
  speex-devel \
  openssl-devel
```

如果是 `aarch64/arm64` 机器，包名通常不变，只要软件源里有对应架构版本即可。

如果缺少某个开发包，FFmpeg `configure` 常见报错会类似：

- `ERROR: libmp3lame >= 3.98.3 not found`
- `fatal error: lame/lame.h: No such file or directory`

这类错误说明你启用了对应外部库，但系统没有安装它的 `-dev/-devel` 包。

如果当前机器没有 `sudo`，可以直接关闭外部依赖：

```bash
ENABLE_EXTERNAL_CODECS=0 ENABLE_SHARED=0 ./build.sh
```

关闭后会自动移除这些 configure 选项：

- `--enable-libmp3lame`
- `--enable-libopus`
- `--enable-libvorbis`
- `--enable-libspeex`
- `--enable-openssl`
- 对应的 `--enable-encoder=...`

### Windows (MSYS2)

1. 从 https://www.msys2.org/ 下载并安装 MSYS2

2. 打开 MSYS2 MINGW64 终端，更新系统：

```bash
pacman -Syu
```

3. 重新打开终端，安装构建工具：

```bash
pacman -S \
  mingw-w64-x86_64-toolchain \
  mingw-w64-x86_64-nasm \
  make \
  diffutils \
  tar
```

当前 GitHub Actions 和 Windows 预编译依赖仍以 `x86_64` 为主；脚本层已经支持 `aarch64` 参数归一化和 Linux flags 选择，但 Windows ARM 产物暂未在 CI 中发布。

## 配置

FFmpeg 编译选项配置在 `ffmpeg_configure_flags.txt` 文件中。

## GitHub Actions 自动发布

workflow 文件在 [.github/workflows/build.yml](/appsvc/repos/ffmpeg-build/.github/workflows/build.yml)。

推送 tag 后会自动构建并发布 release，规则如下：

- `v7.1.0`
  - 构建全部产物：Linux、macOS、WASM、Windows MSVC、Windows MinGW
- `v7.1.0-linux`
  - 构建 Linux + WASM
- `v7.1.0-macos`
  - 只构建全部 macOS 产物
- `v7.1.0-macos-x86_64`
  - 只构建 macOS x86_64 产物
- `v7.1.0-macos-aarch64`
  - 只构建 macOS aarch64 产物
- `v7.1.0-wasm`
  - 只构建 WASM
- `v7.1.0-window`
  - 构建全部 Windows 产物
- `v7.1.0-window-msvc-0`
  - 只构建 Windows MSVC 静态库
- `v7.1.0-window-mingw-0`
  - 只构建 Windows MinGW 静态库
- `v7.1.0-window-mingw-1`
  - 只构建 Windows MinGW 动态库

当前 GitHub Actions 中：

- Linux 使用 matrix 构建 `x86_64/aarch64` 和 `static/shared`
- macOS 使用 matrix 构建 `x86_64/aarch64` 和 `static/shared`
- Windows 使用 matrix 构建 `msvc static`、`mingw static`、`mingw shared`
- Linux `aarch64` 通过 QEMU + `manylinux2014_aarch64` 容器构建
- Windows 发布产物当前仍以 `x86_64` 为主

## 常见问题

### 1. 什么时候用 `build.sh`，什么时候用平台脚本？

- 日常使用优先 `build.sh`
- 只有在需要 MSVC 环境准备时，使用 `build-window.ps1`
- `build-linux.sh` / `build-window.sh` 主要保留给调试或兼容旧用法

### 2. `ARCH` 不传会怎样？

会自动检测当前机器架构：

- `amd64` / `x86_64` -> `x86_64`
- `arm64` / `aarch64` -> `aarch64`

### 3. 没有 sudo 时怎么编？

直接关闭外部依赖：

```bash
ENABLE_EXTERNAL_CODECS=0 ENABLE_SHARED=0 ./build.sh
```

这样不会再检查 `libmp3lame`、`libopus`、`libvorbis`、`libspeex`、`openssl`。

### 4. Windows arm64 现在能直接出包吗？

还不能。当前只是把脚本的架构处理统一了，Linux 已经能正确区分 flags，Windows ARM 产物和 CI 发布暂未完整接通。

## License

MIT
