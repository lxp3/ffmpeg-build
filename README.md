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
| Windows | 静态库 | MSVC | `ffmpeg-7.1-static-x86_64-msvc.tar.gz` |
| Windows | 静态库 | MinGW | `ffmpeg-7.1-static-x86_64-w64-mingw32.tar.gz` |
| Windows | 动态库 | MinGW | `ffmpeg-7.1-shared-x86_64-w64-mingw32.tar.gz` |
| WebAssembly | 静态库 | Emscripten | `ffmpeg-7.1-wasm.tar.gz` |

## 构建命令

### Linux

```bash
# 静态库
ENABLE_SHARED=0 ./build-linux.sh

# 动态库
ENABLE_SHARED=1 ./build-linux.sh
```

### Windows (MSVC)

1. 安装 Visual Studio (推荐 2022) 并勾选 "使用 C++ 的桌面开发" 工作负载。

2. 安装 MSYS2 (用于提供构建环境，如 `make`, `bash`, `tar` 等)。

3. 在 PowerShell 中运行：

```powershell
# 仅支持构建静态库
.\build-window.ps1 -EnableShared 0
```

该脚本会自动查找 Visual Studio 环境，并启动 MSYS2 进行构建。输出的 `.lib` 文件将位于 `outputs/` 目录。

### Windows (MinGW - MSYS2)

在 MSYS2 MINGW64 终端运行：

```bash
# 静态库
ENABLE_SHARED=0 ./build-window.sh

# 动态库
ENABLE_SHARED=1 ./build-window.sh
```

### WebAssembly

```bash
# Linux/macOS
./build-wasm.sh

# Windows (PowerShell)
.\build-wasm.ps1
```

WASM 构建脚本会自动安装 Emscripten SDK。

## 触发构建

推送 tag 触发 GitHub Actions：

```bash
# 构建所有平台
git tag v0.1.0 && git push origin v0.1.0

# 仅构建 Linux + WASM
git tag v0.1.0-linux && git push origin v0.1.0-linux

# 仅构建 Windows
git tag v0.1.0-window && git push origin v0.1.0-window
```

## 依赖

### Linux

```bash
# Ubuntu/Debian
sudo apt-get install build-essential nasm patchelf

# CentOS/RHEL
sudo yum install gcc make nasm patchelf
```

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

## 配置

FFmpeg 编译选项配置在 `ffmpeg_configure_flags.txt` 文件中。

## License

MIT
