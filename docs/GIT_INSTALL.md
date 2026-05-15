# Git URL 安装

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/small37/cx/main/install.sh | bash
```

## 指定仓库地址安装

```bash
curl -fsSL https://raw.githubusercontent.com/small37/cx/main/install.sh | bash -s -- https://github.com/small37/cx.git
```

## 安装内容

1. 拉取/更新源码到 `~/.cx/src/cx`
2. 执行 `go install ./cmd/cx`
3. 输出 `cx` 二进制路径

## 验证

```bash
cx --help
```

## 可选：zsh 集成

```bash
source "$HOME/.cx/src/cx/integrations/cx.zsh"
```
