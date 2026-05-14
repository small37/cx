# CX (Go)

Go 版终端命令选择器，功能与 Python 版一致。

## 安装

```bash
cd "/Users/one/Documents/项目/测试2/cx-go"
go install ./cmd/cx
```

产物：`$(go env GOPATH)/bin/cx`（一般是 `~/go/bin/cx`）。

## 跟 Python 版共存

Python 版二进制装在 `~/.local/bin/cx`，Go 版在 `~/go/bin/cx`。如果两个都在 PATH 里，先出现的赢。

切换方式：

- 想用 Go 版：把 `~/go/bin` 放在 `~/.local/bin` 之前；或者干脆 `uv tool uninstall cx` 把 Python 版卸了
- 临时显式调用：`~/go/bin/cx`

## 用法

| 命令 | 说明 |
|---|---|
| `cx` / `cx history` / `cx h` | 打开历史命令选择器 |
| `cx fav` / `cx f` | 打开收藏命令选择器 |
| `cx add <命令>` | 添加收藏 |
| `cx list` | 列出收藏 |
| `cx edit <id> --command ...` | 编辑收藏 |
| `cx del <id>` | 删除收藏 |

TUI 内：`↑↓` 选择，`Enter` 确认，`Esc` / `Ctrl+C` 退出，`Ctrl+U` 清空搜索，`PgUp/PgDn`、`Home/End` 翻页，空格分词搜索。

## zsh 集成

在 `~/.zshrc` 追加：

```bash
source "/Users/one/Documents/项目/测试2/cx-go/integrations/cx.zsh"
```

然后 `source ~/.zshrc`。在提示符里直接 `cx` / `cx fav`，选完命令落到下一行光标位置。

集成同时把 `Ctrl+R` 绑到 `cx history`，覆盖 zsh 默认的反向搜索；选完的命令会填到当前命令行。

## 数据位置

- 收藏数据库：`~/.cx/cx.db`（跟 Python 版**共用**同一个文件，schema 兼容）
- 历史来源：`~/.zsh_history`
