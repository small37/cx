# SleepGuard Demo

这个目录包含两部分：

1. `docs/feasibility_and_pitfalls.md`：对 PRD 的可行性评估和易踩坑清单
2. `demo/`：可运行的最小程序
   - 菜单栏 App（MVP 核心闭环）
   - 命令行断言测试器（便于配合 `pmset` 验证）
   - TouchBar Island 基础能力（Unix Socket + 命令路由 + 单消息覆盖）

## 环境前提

- macOS
- Xcode Command Line Tools（已安装）

## 快速开始

```bash
cd /Users/one/Documents/项目/阻止休眠小程序/demo
./build.sh
```

编译成功后会生成：

- `build/SleepGuardDemo.app`：菜单栏 demo
- `build/assertion_tester`：命令行测试器

## 运行菜单栏 Demo

```bash
open build/SleepGuardDemo.app
```

菜单结构：

- 阻止系统休眠(含合盖) / 允许系统休眠(含合盖)（状态切换）
- 阻止 30 分钟 / 1 小时 / 2 小时（定时防休眠）
- 开机启动（SMAppService）
- TouchBar 消息状态（运行/暂停、当前消息、清空消息）
- 退出（退出前释放 assertion）

## TouchBar Island 基础能力

已实现（低占用事件驱动）：

- Unix Domain Socket：`~/.touchbar-island/touchbar.sock`
- 支持命令：`MSG / PERMISSION / DONE / ERROR / STATUS / CLEAR`
- 单消息覆盖策略：新消息替换旧消息
- `DONE` 自动 TTL 8 秒清理（一次性定时器）
- 暂停显示（暂停时忽略除 STATUS 外的命令）

脚本目录：

- `/Users/one/Documents/项目/阻止休眠小程序/demo/scripts`

安装命令：

```bash
cd /Users/one/Documents/项目/阻止休眠小程序/demo/scripts
./install_commands.sh
```

发送测试：

```bash
tbmsg "Claude 正在执行任务"
tbpermission "Claude 需要你确认权限"
tbdone "任务完成：已修改 3 个文件"
tberror "命令执行失败"
tbstatus "Claude Ready"
tbclear
```

DSL 转义规则：

- `\]` 表示字面 `]`
- `\:` 表示字面 `:`
- `\\` 表示字面反斜杠

示例：

```bash
tbmsg "[text:white:路径 C\\:\\\\work\\]ok] [flex] [button:关闭:dismiss]"
```

发送兜底：

- `tbsend` 优先使用 `nc -U`
- 若 `nc` 不可用或发送失败，自动回退到 `~/.touchbar-island/bin/tbsend_swift`

像素字体：

- 优先加载 `FusionPixel.ttf`
- 探测路径：
  - `SleepGuardDemo.app/Contents/Resources/Fonts/FusionPixel.ttf`
  - `~/.touchbar-island/fonts/FusionPixel.ttf`
  - `~/Library/Fonts/FusionPixel.ttf`
- 未命中时自动 fallback 到等宽系统字体

## Claude Hooks 联调

安装 hooks 模板：

```bash
cd /Users/one/Documents/项目/阻止休眠小程序/demo/scripts
./install_claude_hooks.sh
```

模板路径：

- `~/.touchbar-island/claude_hooks.json`
- 源文件：[claude_hooks.touchbar.example.json](/Users/one/Documents/项目/阻止休眠小程序/docs/claude_hooks.touchbar.example.json)

把模板合并到你自己的 Claude hooks 配置后，可用以下命令快速冒烟：

```bash
tbpermission "Claude 需要你确认权限"
tbdone "任务完成：已修改 3 个文件"
tberror "命令执行失败"
```

## 资源占用基准

运行脚本：

```bash
cd /Users/one/Documents/项目/阻止休眠小程序/demo/scripts
./benchmark_resources.sh
```

输出报告：

- `~/.touchbar-island/resource_benchmark_YYYYMMDD_HHMMSS.txt`

报告包含：

- 每秒采样的 `%CPU / RSS / VSZ`
- `avg_cpu_percent / max_cpu_percent`
- `avg_rss_mb / max_rss_mb`

## Release 验收脚本

运行：

```bash
cd /Users/one/Documents/项目/阻止休眠小程序/demo/scripts
./release_check.sh
```

默认阈值：

- `CPU_THRESHOLD=1.0`
- `RSS_MB_THRESHOLD=60.0`

可覆盖：

```bash
CPU_THRESHOLD=0.5 RSS_MB_THRESHOLD=50 ./release_check.sh
```

## Claude Hooks 安全合并

脚本：

```bash
cd /Users/one/Documents/项目/阻止休眠小程序/demo/scripts
./merge_claude_hooks.sh /path/to/your/hooks.json
```

行为：

- 自动备份目标配置
- 将模板中的 `hooks` 追加合并到目标文件（同 matcher+command 自动去重）
- 不删除你原有的其他顶层配置

## 打包分发

生成分发包：

```bash
cd /Users/one/Documents/项目/阻止休眠小程序/demo/scripts
./package_release.sh
```

输出：

- `demo/dist/SleepGuard_release_时间戳/`
- `demo/dist/SleepGuard_release_时间戳.tar.gz`

## Hook 端到端回归

运行：

```bash
cd /Users/one/Documents/项目/阻止休眠小程序/demo/scripts
./smoke_hooks.sh
```

输出：

- `~/.touchbar-island/smoke_hooks_YYYYMMDD_HHMMSS.txt`

## 测试必要功能

终端 A 观察断言与系统禁睡：

```bash
pmset -g assertions | rg "PreventSystemSleep"
pmset -g | rg disablesleep
```

终端 B 用命令行测试器快速验证：

```bash
./build/assertion_tester on 20
```

预期：20 秒内能看到断言，之后自动释放。

## 新增功能验收

1. 选择 `阻止 30 分钟 / 1 小时 / 2 小时` 后，菜单对应项出现勾选。
2. 定时到期后，状态自动回到“允许休眠”，并播放提示音。
3. 点击 `开机启动` 后，菜单项勾选状态切换（macOS 13+）。
