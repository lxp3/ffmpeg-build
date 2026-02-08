# FFmpeg Build

FFPEMG音频编解码包的编译

## 支持的平台

| 包名 | 平台 | 类型 |
|------|------|------|
| `ffmpeg-7.1-linux-x86_64-static.tar.gz` | Linux | 静态库 |
| `ffmpeg-7.1-linux-x86_64-shared.tar.gz` | Linux | 动态库 |
| `ffmpeg-7.1-wasm.tar.gz` | WebAssembly | 静态库 |
| `ffmpeg-7.1-windows-x86_64-static.tar.gz` | Windows | 静态库 |
| `ffmpeg-7.1-windows-x86_64-shared.tar.gz` | Windows | 动态库 |

## 构建命令

### Linux

```bash
# 静态库
ARCH=x86_64 ENABLE_SHARED=0 ./build-linux.sh

# 动态库
ARCH=x86_64 ENABLE_SHARED=1 ./build-linux.sh
```

### Windows (MSYS2/MINGW64)

```bash
# 静态库
ARCH=x86_64 ENABLE_SHARED=0 ./build-windows.sh

# 动态库
ARCH=x86_64 ENABLE_SHARED=1 ./build-windows.sh
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
- gcc, make, nasm, patchelf

### Windows (MSYS2)
- mingw-w64-x86_64-toolchain, mingw-w64-x86_64-nasm, make

### WebAssembly
- 自动安装 Emscripten SDK 5.0.0
- 需要 git, curl, bash

## 配置

FFmpeg 编译选项配置在 `ffmpeg_configure_flags.txt` 文件中。

## License

MIT
