import AppKit
import ServiceManagement

final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let sleepManager = SleepManager()
    private let messageStore: CurrentMessageStore
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem()
    private let prevent30Item = NSMenuItem()
    private let prevent60Item = NSMenuItem()
    private let prevent120Item = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()
    private let runtimeItem = NSMenuItem(title: "状态：运行中", action: nil, keyEquivalent: "")
    private let currentMessageItem = NSMenuItem(title: "当前消息：Claude Ready", action: nil, keyEquivalent: "")
    private let clearMessageItem = NSMenuItem()
    private let pauseDisplayItem = NSMenuItem()
    private let resumeDisplayItem = NSMenuItem()
    private let titleItem = NSMenuItem(title: "☕ SleepGuard", action: nil, keyEquivalent: "")
    private var disableTimer: Timer?
    private var selectedDuration: TimeInterval?
    private var observerID: UUID?

    init(messageStore: CurrentMessageStore) {
        self.messageStore = messageStore
        super.init()
        setupStatusItem()
        setupMenu()
        self.observerID = self.messageStore.addObserver { [weak self] in
            self?.updateRuntimeItems()
        }
        updateUI()
    }

    deinit {
        if let observerID {
            messageStore.removeObserver(observerID)
        }
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
    }

    private func setupMenu() {
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        runtimeItem.isEnabled = false
        currentMessageItem.isEnabled = false
        menu.addItem(runtimeItem)
        menu.addItem(currentMessageItem)
        menu.addItem(.separator())

        clearMessageItem.title = "清空当前消息"
        clearMessageItem.action = #selector(clearCurrentMessage)
        clearMessageItem.target = self
        menu.addItem(clearMessageItem)

        pauseDisplayItem.title = "暂停显示"
        pauseDisplayItem.action = #selector(pauseDisplay)
        pauseDisplayItem.target = self
        menu.addItem(pauseDisplayItem)

        resumeDisplayItem.title = "恢复显示"
        resumeDisplayItem.action = #selector(resumeDisplay)
        resumeDisplayItem.target = self
        menu.addItem(resumeDisplayItem)

        menu.addItem(.separator())

        toggleItem.action = #selector(togglePreventSleep)
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        prevent30Item.title = "阻止 30 分钟"
        prevent30Item.action = #selector(prevent30Minutes)
        prevent30Item.target = self
        menu.addItem(prevent30Item)

        prevent60Item.title = "阻止 1 小时"
        prevent60Item.action = #selector(prevent60Minutes)
        prevent60Item.target = self
        menu.addItem(prevent60Item)

        prevent120Item.title = "阻止 2 小时"
        prevent120Item.action = #selector(prevent120Minutes)
        prevent120Item.target = self
        menu.addItem(prevent120Item)

        menu.addItem(.separator())

        launchAtLoginItem.title = "开机启动"
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateUI() {
        guard let button = statusItem.button else { return }
        let isActive = sleepManager.isPreventingSleep
        toggleItem.title = isActive ? "允许系统休眠" : "阻止系统休眠"
        toggleItem.state = selectedDuration == nil && isActive ? .on : .off
        prevent30Item.state = selectedDuration == 30 * 60 ? .on : .off
        prevent60Item.state = selectedDuration == 60 * 60 ? .on : .off
        prevent120Item.state = selectedDuration == 120 * 60 ? .on : .off

        let symbolName = isActive ? "sun.max.fill" : "moon.zzz"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "SleepGuard status")
        image?.isTemplate = true
        button.image = image

        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        updateRuntimeItems()
    }

    private func updateRuntimeItems() {
        messageStore.snapshot { [weak self] currentMessage, defaultStatus, isPaused in
            guard let self else { return }
            let text = (currentMessage?.layout.isEmpty == false) ? (currentMessage?.layout ?? defaultStatus) : defaultStatus
            DispatchQueue.main.async {
                self.currentMessageItem.title = "当前消息：\(text)"
                self.pauseDisplayItem.isHidden = isPaused
                self.resumeDisplayItem.isHidden = !isPaused
                self.runtimeItem.title = isPaused ? "状态：已暂停" : "状态：运行中"
            }
        }
    }

    @objc private func togglePreventSleep() {
        disableTimer?.invalidate()
        disableTimer = nil
        selectedDuration = nil
        sleepManager.toggle()
        updateUI()
        NSSound.beep()
    }

    @objc private func prevent30Minutes() {
        startTimedPreventSleep(duration: 30 * 60)
    }

    @objc private func prevent60Minutes() {
        startTimedPreventSleep(duration: 60 * 60)
    }

    @objc private func prevent120Minutes() {
        startTimedPreventSleep(duration: 120 * 60)
    }

    private func startTimedPreventSleep(duration: TimeInterval) {
        disableTimer?.invalidate()
        disableTimer = nil
        selectedDuration = duration

        let enabled = sleepManager.enablePreventSleep(reason: "SleepGuardDemo timed sleep prevention")
        guard enabled else {
            selectedDuration = nil
            updateUI()
            NSSound.beep()
            return
        }

        disableTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.sleepManager.disablePreventSleep()
            self.selectedDuration = nil
            self.disableTimer = nil
            self.updateUI()
            NSSound.beep()
        }

        updateUI()
        NSSound.beep()
    }

    @objc private func toggleLaunchAtLogin() {
        let currentlyEnabled = isLaunchAtLoginEnabled()
        setLaunchAtLogin(enabled: !currentlyEnabled)
        updateUI()
        NSSound.beep()
    }

    @objc private func clearCurrentMessage() {
        messageStore.clearMessage()
        NSSound.beep()
    }

    @objc private func pauseDisplay() {
        messageStore.setPaused(true)
        NSSound.beep()
    }

    @objc private func resumeDisplay() {
        messageStore.setPaused(false)
        NSSound.beep()
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setLaunchAtLogin(enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 保持静默，避免菜单栏应用弹窗打断使用
        }
    }

    @objc private func quit() {
        disableTimer?.invalidate()
        disableTimer = nil
        selectedDuration = nil
        sleepManager.disablePreventSleep()
        NSApp.terminate(nil)
    }
}
