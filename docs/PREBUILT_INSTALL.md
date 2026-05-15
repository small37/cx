# 预编译版本安装

## 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/small37/cx/main/install_prebuilt.sh | bash
```

默认行为：
1. 自动识别系统和架构（`darwin/linux` + `arm64/amd64`）
2. 从最新 Release 下载对应压缩包
3. 安装到 `~/.local/bin/cx`

## 指定仓库或版本

```bash
# 指定仓库
curl -fsSL https://raw.githubusercontent.com/small37/cx/main/install_prebuilt.sh | bash -s -- small37/cx

# 指定版本（例如 v1.0.0）
curl -fsSL https://raw.githubusercontent.com/small37/cx/main/install_prebuilt.sh | bash -s -- small37/cx v1.0.0
```

## Release 包命名要求

安装脚本默认下载以下命名格式：

```text
cx_<os>_<arch>.tar.gz
```

示例：
- `cx_darwin_arm64.tar.gz`
- `cx_darwin_amd64.tar.gz`
- `cx_linux_arm64.tar.gz`
- `cx_linux_amd64.tar.gz`

## 验证

```bash
cx --help
```
