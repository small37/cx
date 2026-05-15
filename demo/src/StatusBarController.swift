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
    private let countdownItem = NSMenuItem(title: "休眠剩余时间：--:--:--", action: nil, keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem()
    private let runtimeItem = NSMenuItem(title: "状态：运行中", action: nil, keyEquivalent: "")
    private let currentMessageItem = NSMenuItem(title: "当前消息：Claude Ready", action: nil, keyEquivalent: "")
    private let clearMessageItem = NSMenuItem()
    private let pauseDisplayItem = NSMenuItem()
    private let resumeDisplayItem = NSMenuItem()
    private let featureSwitchItem = NSMenuItem()
    private let titleItem = NSMenuItem(title: "☕ SleepGuard", action: nil, keyEquivalent: "")
    private var disableTimer: Timer?
    private var countdownTimer: Timer?
    private var selectedDuration: TimeInterval?
    private var timedPreventSleepEndAt: Date?
    private var observerID: UUID?
    private(set) var isCaptureAndTextFeatureEnabled = true
    private var lastRuntimeTitle = "状态：运行中"
    private var lastMessageTitle = "当前消息：Claude Ready"
    private var lastCountdownTitle = "休眠剩余时间：--:--:--"

    var onCaptureAndTextFeatureToggled: ((Bool) -> Void)?

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
        stopCountdownTimer()
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

        featureSwitchItem.title = "截图与获取文本功能"
        featureSwitchItem.action = #selector(toggleCaptureAndTextFeature)
        featureSwitchItem.target = self
        featureSwitchItem.state = .on
        menu.addItem(featureSwitchItem)

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
        countdownItem.isEnabled = false
        countdownItem.isHidden = true
        menu.addItem(countdownItem)

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
        toggleItem.title = isActive ? "允许系统休眠(含合盖)" : "阻止系统休眠(含合盖)"
        toggleItem.state = selectedDuration == nil && isActive ? .on : .off
        prevent30Item.state = selectedDuration == 30 * 60 ? .on : .off
        prevent60Item.state = selectedDuration == 60 * 60 ? .on : .off
        prevent120Item.state = selectedDuration == 120 * 60 ? .on : .off

        button.image = isActive ? Self.activeImage : Self.inactiveImage

        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        updateCountdownItem()
        updateRuntimeItems()
    }

    private func updateRuntimeItems() {
        messageStore.snapshot { [weak self] currentMessage, defaultStatus, isPaused in
            guard let self else { return }
            let text = (currentMessage?.layout.isEmpty == false) ? (currentMessage?.layout ?? defaultStatus) : defaultStatus
            DispatchQueue.main.async {
                let runtimeTitle = isPaused ? "状态：已暂停" : "状态：运行中"
                if self.lastRuntimeTitle != runtimeTitle {
                    self.runtimeItem.title = runtimeTitle
                    self.lastRuntimeTitle = runtimeTitle
                }

                let messageTitle = "当前消息：\(text)"
                if self.lastMessageTitle != messageTitle {
                    self.currentMessageItem.title = messageTitle
                    self.lastMessageTitle = messageTitle
                }

                let shouldHidePause = isPaused
                if self.pauseDisplayItem.isHidden != shouldHidePause {
                    self.pauseDisplayItem.isHidden = shouldHidePause
                }
                let shouldHideResume = !isPaused
                if self.resumeDisplayItem.isHidden != shouldHideResume {
                    self.resumeDisplayItem.isHidden = shouldHideResume
                }
            }
        }
    }

    @objc private func togglePreventSleep() {
        disableTimer?.invalidate()
        disableTimer = nil
        stopCountdownTimer()
        selectedDuration = nil
        timedPreventSleepEndAt = nil
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
        stopCountdownTimer()
        selectedDuration = duration
        timedPreventSleepEndAt = Date().addingTimeInterval(duration)

        let enabled = sleepManager.enablePreventSleep(reason: "SleepGuardDemo timed full sleep prevention")
        guard enabled else {
            selectedDuration = nil
            timedPreventSleepEndAt = nil
            updateUI()
            NSSound.beep()
            return
        }

        disableTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.sleepManager.disablePreventSleep()
            self.selectedDuration = nil
            self.disableTimer = nil
            self.timedPreventSleepEndAt = nil
            self.stopCountdownTimer()
            self.updateUI()
            NSSound.beep()
        }

        startCountdownTimer()
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

    @objc private func toggleCaptureAndTextFeature() {
        isCaptureAndTextFeatureEnabled.toggle()
        featureSwitchItem.state = isCaptureAndTextFeatureEnabled ? .on : .off
        onCaptureAndTextFeatureToggled?(isCaptureAndTextFeatureEnabled)
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
        stopCountdownTimer()
        selectedDuration = nil
        timedPreventSleepEndAt = nil
        sleepManager.disablePreventSleep()
        NSApp.terminate(nil)
    }

    private func startCountdownTimer() {
        stopCountdownTimer()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateCountdownItem()
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownItem.isHidden = true
        if countdownItem.title != lastCountdownTitle {
            countdownItem.title = lastCountdownTitle
        }
    }

    private func updateCountdownItem() {
        guard sleepManager.isPreventingSleep,
              selectedDuration != nil,
              let endAt = timedPreventSleepEndAt else {
            countdownItem.isHidden = true
            return
        }

        let remaining = max(0, Int(endAt.timeIntervalSinceNow))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        let title = String(format: "休眠剩余时间：%02d:%02d:%02d", hours, minutes, seconds)

        countdownItem.isHidden = false
        if countdownItem.title != title {
            countdownItem.title = title
        }

        if remaining <= 0 {
            countdownItem.isHidden = true
            stopCountdownTimer()
        }
    }
}

private extension StatusBarController {
    static let activeImage: NSImage? = {
        let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "SleepGuard status")
        image?.isTemplate = true
        return image
    }()

    static let inactiveImage: NSImage? = {
        let image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "SleepGuard status")
        image?.isTemplate = true
        return image
    }()
}
