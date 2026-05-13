# SleepGuard PRD 可行性评估与易踩坑

## 结论

PRD 技术路线可行，且是 macOS 菜单栏工具的标准实现路线：`Swift + AppKit + NSStatusItem + IOKit Assertion`。

MVP 难度低，主要风险不在“能不能做出来”，而在“细节完整性”（退出释放、异常恢复、图标适配、登录项兼容）。

## 可行性评估

1. 菜单栏图标/菜单：`NSStatusItem + NSMenu` 成熟稳定。
2. 防休眠能力：`IOPMAssertionCreateWithName` 是官方能力，适配目标需求。
3. 低资源占用：无轮询、无子进程、无 WebView，可做到接近 0% CPU。
4. 隐藏 Dock：`LSUIElement=true` 可实现代理型后台应用体验。

## 易踩坑（按优先级）

1. 断言生命周期泄漏（高）
   - 坑点：开启后未在退出/崩溃路径释放，导致状态异常。
   - 规避：统一用单一 `assertionID` 管理；`deinit`、`quit`、`applicationWillTerminate` 都执行释放。

2. 断言类型选错（高）
   - 坑点：`kIOPMAssertionTypeNoIdleSleep` 只能防系统空闲休眠，不等于永不锁屏/永不熄屏。
   - 规避：文案明确“阻止系统空闲休眠”；第二版再加“显示器防休眠”并使用对应 assertion 类型。

3. UI 状态与真实状态不同步（高）
   - 坑点：创建 assertion 失败但 UI 先切换为“已开启”。
   - 规避：以 API 返回值为准，只在 `kIOReturnSuccess` 后更新状态/图标。

4. 菜单栏图标在深浅色不可见（中）
   - 坑点：非模板图标在某些主题下发灰/看不见。
   - 规避：默认 `isTemplate=true`；若用彩色激活图标，要在深浅色下分别验收。

5. 登录启动实现版本兼容（中）
   - 坑点：`SMAppService` 在不同 macOS 版本和签名状态下行为差异大。
   - 规避：MVP 不做；第二版单独做版本门槛和签名验证。

6. 定时模式状态竞争（中）
   - 坑点：重复点击定时菜单导致多个 timer 并发，提前或延后释放。
   - 规避：全局只保留一个 timer，每次设置前先 `invalidate`。

7. Xcode 不在当前环境（中）
   - 坑点：只写 Xcode 流程，CI/无 Xcode 环境无法快速验证。
   - 规避：提供 `swiftc` 可编译 demo + 命令行断言测试器。

8. 权限和产品预期偏差（中）
   - 坑点：用户以为它能阻止“手动睡眠/合盖睡眠”。
   - 规避：PRD 和 UI 都明确能力边界：仅阻止 idle sleep。

## 建议的 MVP 验收补充

在原 PRD 基础上增加以下硬性检查：

1. `pmset -g assertions` 中断言出现/消失与 UI 状态一致。
2. 连续快速点击 20 次切换后，无崩溃、无残留断言。
3. 菜单栏深色/浅色模式图标均可见。
4. 退出 App 后 3 秒内断言应消失。

