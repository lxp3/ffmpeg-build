# FFmpeg Build

FFmpeg Build 是一个面向 C/C++ 项目的跨平台 FFmpeg 预编译库构建工程，重点关注音频编解码和常见媒体处理能力。

本项目发布静态库和动态库包，覆盖 Linux、macOS、Windows 和 WebAssembly，适合在播放器、录音、转码、流媒体、音频分析等项目中直接集成。静态发布包会携带外部音频编码依赖和 `FFmpegConfig.cmake`，让下游项目通过 CMake 更稳定地消费 FFmpeg，减少手动对齐系统依赖的成本。

## 功能特性

- 专注音频编解码：支持 AAC、MP3、FLAC、WAV、OGG、Opus、Speex、PCM 等常见音频格式。
- 支持常见媒体处理：可用于音频提取、格式转换、流式音频读取、麦克风采集等场景。
- 跨平台发布：覆盖 Linux、macOS、Windows、WebAssembly，并支持 x86_64 和 aarch64。
- C/C++ 友好集成：静态包提供 `FFmpegConfig.cmake`，下游 CMake 项目可直接 `find_package(FFmpeg CONFIG REQUIRED)`。
- 兼容性优先：构建脚本统一控制 FFmpeg 配置、外部 codecs、汇编优化和平台工具链，减少不同项目重复处理环境依赖的问题。
- 音频能力优先：默认不启用视频编码能力，减少包体和依赖复杂度。

## 发布包

| 平台 | 编译器 | 类型 | 汇编优化 | 外部codecs | 包名 |
|------|--------|------|----------|------------|------|
| Linux | GCC | static | ✓ | ✓ | `ffmpeg-7.1-static-x86_64-linux-gnu.tar.gz` |
| Linux | GCC | shared | ✓ | ✓ | `ffmpeg-7.1-shared-x86_64-linux-gnu.tar.gz` |
| Linux | GCC | static | ✓ | ✓ | `ffmpeg-7.1-static-aarch64-linux-gnu.tar.gz` |
| Linux | GCC | shared | ✓ | ✓ | `ffmpeg-7.1-shared-aarch64-linux-gnu.tar.gz` |
| macOS | Clang | static | ✓ | ✓ | `ffmpeg-7.1-static-x86_64-macos.tar.gz` |
| macOS | Clang | shared | ✓ | ✓ | `ffmpeg-7.1-shared-x86_64-macos.tar.gz` |
| macOS | Clang | static | ✓ | ✓ | `ffmpeg-7.1-static-aarch64-macos.tar.gz` |
| macOS | Clang | shared | ✓ | ✓ | `ffmpeg-7.1-shared-aarch64-macos.tar.gz` |
| Windows | MSVC | static | ✓ | ✓ | `ffmpeg-7.1-static-x86_64-msvc.tar.gz` |
| Windows | MSVC | static | ✗ | ✓ | `ffmpeg-7.1-static-aarch64-msvc.tar.gz` |
| Windows | MinGW | static | ✓ | ✓ | `ffmpeg-7.1-static-x86_64-w64-mingw32.tar.gz` |
| Windows | MinGW | static | ✓ | ✓ | `ffmpeg-7.1-static-aarch64-w64-mingw32.tar.gz` |
| Windows | MinGW | shared | ✓ | ✓ | `ffmpeg-7.1-shared-x86_64-w64-mingw32.tar.gz` |
| Windows | MinGW | shared | ✓ | ✓ | `ffmpeg-7.1-shared-aarch64-w64-mingw32.tar.gz` |
| WebAssembly | Emscripten | static | ✓ | ✓ | `ffmpeg-7.1-wasm.tar.gz` |

`外部codecs` 表示构建时是否启用 FFmpeg 外部音频编码依赖：

- `✓`：启用 `libmp3lame`、`libopus`、`libvorbis`、`libspeex` 等外部 codec。静态包会把相关第三方静态库一起放入 `lib/`，并通过 `FFmpegConfig.cmake` 暴露给 CMake 消费方。
- `✗`：不启用外部 codec，仅使用 FFmpeg 内建能力，适合依赖受限或只需要基础格式处理的环境。

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
.\build-window.ps1 -Arch aarch64 -EnableShared 0
```

该脚本会自动查找 Visual Studio 环境，并启动 MSYS2 进行构建。输出的 `.lib` 文件将位于 `outputs/` 目录。

说明：

- `build-window.ps1` 是给 MSVC 准备环境的包装脚本
- 当前 `MSVC` 支持 `x86_64` 和 `aarch64` 静态库
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

## CMake 集成

发布包内置 `FFmpegConfig.cmake`，CMake 项目解压 tar.gz 后可以直接使用
`find_package(FFmpeg CONFIG REQUIRED)`。

包内 CMake 配置位置：

```text
<ffmpeg-root>/lib/cmake/FFmpeg/FFmpegConfig.cmake
```

最小用法：

```cmake
set(FFmpeg_DIR "/path/to/ffmpeg-7.1-static-x86_64-linux-gnu/lib/cmake/FFmpeg")
find_package(FFmpeg CONFIG REQUIRED)

target_link_libraries(my_app PRIVATE ffmpeg::ffmpeg)
```

`ffmpeg::ffmpeg` 是聚合目标，会按正确顺序链接 FFmpeg 组件和静态包内置的第三方库。静态包会随包携带 `libmp3lame`、`libopus`、`libvorbis`、`libspeex`、`openssl` 等依赖库，下游项目不需要重新安装和对齐这些 codec 依赖。

如果项目用 `FetchContent` 下载发布包，可以在解压后设置 `FFmpeg_DIR`：

```cmake
include(FetchContent)

FetchContent_Declare(
    ffmpeg_bin
    URL "https://github.com/lxp3/ffmpeg-build/releases/download/v0.3.4/ffmpeg-7.1-static-x86_64-linux-gnu.tar.gz"
)
FetchContent_MakeAvailable(ffmpeg_bin)
FetchContent_GetProperties(ffmpeg_bin SOURCE_DIR FFMPEG_EXTRACT_DIR)

file(GLOB FFMPEG_CANDIDATES "${FFMPEG_EXTRACT_DIR}/ffmpeg-*")
list(GET FFMPEG_CANDIDATES 0 FFMPEG_ROOT)

set(FFmpeg_DIR "${FFMPEG_ROOT}/lib/cmake/FFmpeg")
find_package(FFmpeg CONFIG REQUIRED)

target_link_libraries(my_app PRIVATE ffmpeg::ffmpeg)
```

## 配置

FFmpeg 编译选项配置在 `ffmpeg_configure_flags.txt` 文件中。

各平台构建脚本显式启用 `--enable-pic`；Linux、macOS、MinGW 和 WASM 同时使用 `-fPIC`。Linux/macOS CI 会检查生成的 `CONFIG_PIC` 是否启用。更新已有本地构建时，请使用新的 `BUILD_DIR` 或先执行 `make clean` 后重新编译，避免复用旧的非 PIC 对象文件；已有发布包需要重新构建。

## License

MIT
