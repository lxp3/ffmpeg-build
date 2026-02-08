# CLAUDE.md

本文件为 Claude Code 提供项目规则和约定。

## Git 提交规则

- commit 消息中不要包含 "Claude" 或 "Co-Authored-By" 等 AI 相关署名
- 使用简洁的中文或英文描述变更内容
- 遵循常规 commit 格式：`<类型>: <描述>`

## 项目结构

- `build-linux.sh` - Linux 构建脚本
- `build-windows.sh` - Windows 构建脚本 (MSYS2)
- `build-wasm.sh` - WebAssembly 构建脚本 (Linux/macOS)
- `build-wasm.ps1` - WebAssembly 构建脚本 (Windows PowerShell)
- `ffmpeg_configure_flags.txt` - FFmpeg 编译选项配置
- `.github/workflows/build.yml` - GitHub Actions CI 配置

## 构建说明

- WASM 构建脚本已包含完整的 Emscripten SDK 安装步骤，无需预装
- Linux/Windows 构建通过环境变量 `ENABLE_SHARED` 控制静态/动态库
- 输出目录为 `outputs/`

## 发布流程

- 推送 tag 触发 GitHub Actions 构建
- `-linux` 后缀仅构建 Linux + WASM
- `-window` 后缀仅构建 Windows
- 无后缀构建全部平台
