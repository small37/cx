# 预编译版本安装

## 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/small37/cx/main/install_prebuilt.sh | bash
```

默认行为：
1. 自动识别系统和架构（`darwin/linux` + `arm64/amd64`）
2. 从最新 Release 下载对应压缩包
3. 安装到 `~/.local/bin/cx`

如果提示找不到文件，说明仓库还没有发布对应 Release 资产，请先执行“发布预编译包”。

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

## 发布预编译包

方式一：GitHub Actions（推荐）
1. 推送 tag（例如 `v1.0.0`）
2. Actions 会自动构建并上传上述四个压缩包到 Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

方式二：本地手动构建

```bash
chmod +x scripts/build_release_assets.sh
./scripts/build_release_assets.sh
```

生成目录：`dist/`，可手动上传到 GitHub Release。

## 验证

```bash
cx --help
```
