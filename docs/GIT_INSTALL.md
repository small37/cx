# Git 地址安装说明

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/small37/codex/main/install.sh | bash
```

## 指定仓库地址安装

```bash
curl -fsSL https://raw.githubusercontent.com/small37/codex/main/install.sh | bash -s -- https://github.com/small37/codex.git
```

## 安装流程

1. 拉取或更新源码到 `~/.touchbar-island/src/touchbar-island`
2. 执行 `demo/build.sh` 编译并安装到 `/Applications/SleepGuardDemo.app`
3. 执行 `demo/scripts/install_commands.sh` 安装 `tbmsg/tbdone/tbsend`

## 验证

```bash
tbmsg "hermes 任务开始"
tbdone "任务结束"
```
