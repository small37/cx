import AppKit
import ObjectiveC.runtime

final class TouchBarHostView: NSView {
    var hostedTouchBar: NSTouchBar?

    override var acceptsFirstResponder: Bool { true }

    override func makeTouchBar() -> NSTouchBar? {
        hostedTouchBar
    }
}

final class TouchBarHostPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class TouchBarController: NSObject, NSTouchBarDelegate {
    private let store: CurrentMessageStore
    private let parser = LayoutParser()
    private var observerID: UUID?
    private var currentTouchBar: NSTouchBar?
    private var hostWindow: TouchBarHostPanel?
    private var hostView: TouchBarHostView?
    private static let trayIdentifier = "com.sleepguard.touchbar.tray" as NSString
    private static let leadingIdentifier = NSTouchBarItem.Identifier("com.sleepguard.touchbar.leading")
    private static let trailingIdentifier = NSTouchBarItem.Identifier("com.sleepguard.touchbar.trailing")
    private var renderedNodes: [LayoutNode] = [.text(color: .white, value: "已启动")]
    private var hasTrailingButtons = false
    private var currentMessageType: MessageType?
    private var lastPlayedSoundMessageID: String?
    private var activeSound: NSSound?
    private let metricsProvider = SystemMetricsProvider()
    private var metricsTimer: Timer?
    private var latestMetrics = SystemMetrics(cpuPercent: 0, memoryPercent: 0)
    private weak var cpuLabel: NSTextField?
    private weak var memoryLabel: NSTextField?

    init(store: CurrentMessageStore) {
        self.store = store
        super.init()
        FontManager.shared.loadPixelFontIfNeeded()
    }

    func start() {
        setupResponderFallback()
        startMetricsUpdates()
        observerID = store.addObserver { [weak self] in
            self?.refresh()
        }
        refresh()
    }

    func stop() {
        if let observerID {
            store.removeObserver(observerID)
            self.observerID = nil
        }
        hostWindow?.orderOut(nil)
        hostWindow = nil
        hostView = nil
        currentTouchBar = nil
        metricsTimer?.invalidate()
        metricsTimer = nil
        dismissSystemModalTouchBar()
    }

    private func refresh() {
        store.snapshot { [weak self] currentMessage, defaultStatus, isPaused in
            guard let self else { return }
            if isPaused {
                self.renderedNodes = [.text(color: .gray, value: "已暂停显示")]
                self.currentMessageType = nil
            } else if let currentMessage {
                self.renderedNodes = self.parser.parse(currentMessage.layout)
                self.currentMessageType = currentMessage.type
                self.playSoundIfNeeded(messageID: currentMessage.id, nodes: self.renderedNodes)
            } else {
                self.renderedNodes = self.parser.parse("[text:white:\(defaultStatus)]")
                self.currentMessageType = nil
            }

            self.hasTrailingButtons = self.renderedNodes.contains {
                if case .button = $0 { return true }
                return false
            }

            let touchBar = NSTouchBar()
            touchBar.delegate = self
            touchBar.defaultItemIdentifiers = [Self.leadingIdentifier, .flexibleSpace, Self.trailingIdentifier]
            touchBar.principalItemIdentifier = Self.leadingIdentifier
            self.currentTouchBar = touchBar
            self.appendRenderLog("render current=\(currentMessage?.layout ?? defaultStatus) nodes=\(self.renderedNodes.count) buttons=\(self.hasTrailingButtons)")

            DispatchQueue.main.async {
                self.hostView?.hostedTouchBar = touchBar
                self.hostWindow?.makeFirstResponder(self.hostView)
                self.hostWindow?.orderFront(nil)
                self.presentSystemModalTouchBar(touchBar)
            }
        }
    }

    private func setupResponderFallback() {
        guard hostWindow == nil else { return }
        let hostView = TouchBarHostView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        let panel = TouchBarHostPanel(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.alphaValue = 0.01
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.contentView = hostView
        panel.makeFirstResponder(hostView)
        self.hostView = hostView
        hostWindow = panel
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        let normalized = normalizedNodes(renderedNodes)
        let leftNodes = normalized.filter {
            switch $0 {
            case .button: return false
            case .flex: return false
            case .sound: return false
            default: return true
            }
        }
        let rightNodes = normalized.filter {
            if case .button = $0 { return true }
            return false
        }

        if identifier == Self.leadingIdentifier {
            let item = NSCustomTouchBarItem(identifier: identifier)
            let leftRow = NSStackView()
            leftRow.orientation = .horizontal
            leftRow.spacing = 8
            leftRow.alignment = .centerY
            configureLeadingRow(leftRow, with: leftNodes)
            item.view = leftRow
            return item
        }

        if identifier == Self.trailingIdentifier {
            let item = NSCustomTouchBarItem(identifier: identifier)
            let rightRow = NSStackView()
            rightRow.orientation = .horizontal
            rightRow.spacing = 8
            rightRow.alignment = .centerY
            configureTrailingRow(rightRow, with: rightNodes)
            item.view = rightRow
            return item
        }

        return nil
    }

    @objc private func onButtonClick(_ sender: NSButton) {
        let action = sender.identifier?.rawValue ?? ""
        if action == "confirm" || action == "cancel" || action == "dismiss" {
            appendActionLog(action: action)
            store.clearMessage()
            NSSound.beep()
        }
    }

    private func appendActionLog(action: String) {
        let dir = NSHomeDirectory() + "/.touchbar-island"
        let path = dir + "/action.log"
        let timestamp = Int(Date().timeIntervalSince1970)
        let payload = "{\"action\":\"\(action)\",\"time\":\(timestamp)}\n"
        let data = Data(payload.utf8)

        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // 忽略日志写入错误，不影响主流程
        }
    }

    private func configureLeadingRow(_ left: NSStackView, with nodes: [LayoutNode]) {
        let textSize = currentMessageType == .info ? 17.0 : 13.0
        for node in nodes {
            switch node {
            case .text(let color, let value):
                let label = NSTextField(labelWithString: value)
                label.textColor = nsColor(from: color)
                label.lineBreakMode = .byTruncatingTail
                label.maximumNumberOfLines = 1
                label.font = FontManager.shared.regular(size: CGFloat(textSize))
                label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                left.addArrangedSubview(label)
            case .tag(let value):
                let label = NSTextField(labelWithString: value)
                label.textColor = .black
                label.backgroundColor = NSColor(calibratedRed: 0.96, green: 0.82, blue: 0.18, alpha: 1.0)
                label.isBezeled = false
                label.isBordered = false
                label.drawsBackground = true
                label.lineBreakMode = .byTruncatingTail
                label.maximumNumberOfLines = 1
                label.font = FontManager.shared.bold(size: CGFloat(textSize))
                label.alignment = .center
                label.translatesAutoresizingMaskIntoConstraints = false
                label.wantsLayer = true
                label.layer?.cornerRadius = 0
                label.layer?.borderWidth = 1
                label.layer?.borderColor = NSColor.black.withAlphaComponent(0.6).cgColor
                label.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
                left.addArrangedSubview(label)
            case .icon(let path, let size):
                let resolvedPath = resolveIconPath(path)
                guard let image = NSImage(contentsOfFile: resolvedPath) else { continue }
                let iconView = NSImageView()
                iconView.image = image
                iconView.imageScaling = .scaleProportionallyUpOrDown
                iconView.translatesAutoresizingMaskIntoConstraints = false
                let edge = max(12, size ?? 18)
                iconView.widthAnchor.constraint(equalToConstant: edge).isActive = true
                iconView.heightAnchor.constraint(equalToConstant: edge).isActive = true
                left.addArrangedSubview(iconView)
            case .button, .flex, .sound:
                continue
            case .space(let width):
                let spacer = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 1))
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.widthAnchor.constraint(equalToConstant: width).isActive = true
                left.addArrangedSubview(spacer)
            }
        }
    }

    private func configureTrailingRow(_ right: NSStackView, with nodes: [LayoutNode]) {
        right.setContentHuggingPriority(.required, for: .horizontal)
        right.setContentCompressionResistancePriority(.required, for: .horizontal)
        for node in nodes {
            guard case .button(let title, let action, let colorToken) = node else { continue }
            let button = NSButton(title: title, target: self, action: #selector(onButtonClick(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(action)
            button.controlSize = .small
            button.bezelStyle = .rounded
            button.lineBreakMode = .byTruncatingTail
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.setContentHuggingPriority(.required, for: .horizontal)
            if let color = nsButtonColor(from: colorToken) {
                button.bezelColor = color
            }
            right.addArrangedSubview(button)
        }

        right.addArrangedSubview(makeResourceMonitorView())

        let trailingPadding = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 1))
        trailingPadding.translatesAutoresizingMaskIntoConstraints = false
        trailingPadding.widthAnchor.constraint(equalToConstant: 0).isActive = true
        right.addArrangedSubview(trailingPadding)
    }

    private func makeResourceMonitorView() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.17, alpha: 0.95).cgColor
        container.layer?.cornerRadius = 6
        container.translatesAutoresizingMaskIntoConstraints = false

        let cpu = NSTextField(labelWithString: "")
        cpu.textColor = NSColor(calibratedWhite: 0.96, alpha: 1)
        cpu.font = FontManager.shared.departureBold(size: 9)
        cpu.alignment = .center

        let mem = NSTextField(labelWithString: "")
        mem.textColor = NSColor(calibratedWhite: 0.86, alpha: 1)
        mem.font = FontManager.shared.departureBold(size: 9)
        mem.alignment = .center

        let stack = NSStackView(views: [cpu, mem])
        stack.orientation = .vertical
        stack.spacing = 2
        stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 88),
            container.heightAnchor.constraint(equalToConstant: 28)
        ])

        cpuLabel = cpu
        memoryLabel = mem
        updateMetricsLabels()
        return container
    }

    private func normalizedNodes(_ nodes: [LayoutNode]) -> [LayoutNode] {
        let moved = moveIconsToFront(nodes)
        let firstButtonIndex = moved.firstIndex {
            if case .button = $0 { return true }
            return false
        }

        guard let firstButtonIndex else { return moved }
        let hasLeadingContent = moved[..<firstButtonIndex].contains {
            switch $0 {
            case .text, .tag, .space, .icon:
                return true
            case .flex, .button, .sound:
                return false
            }
        }
        let alreadyHasFlexBeforeButtons = moved[..<firstButtonIndex].contains {
            if case .flex = $0 { return true }
            return false
        }

        guard hasLeadingContent, !alreadyHasFlexBeforeButtons else { return moved }

        var normalized = moved
        normalized.insert(.flex, at: firstButtonIndex)
        return normalized
    }

    private func moveIconsToFront(_ nodes: [LayoutNode]) -> [LayoutNode] {
        let icons = nodes.filter {
            if case .icon = $0 { return true }
            return false
        }
        guard !icons.isEmpty else { return nodes }
        let others = nodes.filter {
            if case .icon = $0 { return false }
            return true
        }
        return icons + others
    }

    private func playSoundIfNeeded(messageID: String, nodes: [LayoutNode]) {
        guard lastPlayedSoundMessageID != messageID else { return }
        guard let soundToken = nodes.compactMap({
            if case .sound(let token) = $0 { return token }
            return nil
        }).first else { return }

        let resolvedPath = resolveSoundPath(soundToken)
        guard FileManager.default.fileExists(atPath: resolvedPath) else { return }
        guard let sound = NSSound(contentsOfFile: resolvedPath, byReference: true) else { return }

        activeSound = sound
        lastPlayedSoundMessageID = messageID
        sound.play()
    }

    private func startMetricsUpdates() {
        latestMetrics = metricsProvider.sample()
        metricsTimer?.invalidate()
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.latestMetrics = self.metricsProvider.sample()
            self.updateMetricsLabels()
        }
        if let metricsTimer {
            RunLoop.main.add(metricsTimer, forMode: .common)
        }
    }

    private func updateMetricsLabels() {
        cpuLabel?.stringValue = "CPU \(scaledPercentText(latestMetrics.cpuPercent))"
        memoryLabel?.stringValue = "MEM \(scaledPercentText(latestMetrics.memoryPercent))"
        cpuLabel?.textColor = color(for: latestMetrics.cpuPercent)
        memoryLabel?.textColor = color(for: latestMetrics.memoryPercent)
    }

    private func scaledPercentText(_ value: Double) -> String {
        let rounded = max(0, min(100, Int(value.rounded())))
        if rounded < 100 {
            return String(format: "%02d%%", rounded)
        }
        return "100%"
    }

    private func color(for percent: Double) -> NSColor {
        switch percent {
        case ..<60:
            return NSColor(calibratedWhite: 0.96, alpha: 1)
        case 60..<85:
            return .systemYellow
        default:
            return .systemRed
        }
    }

    private func nsColor(from color: LayoutColor) -> NSColor {
        switch color {
        case .white:
            return .labelColor
        case .yellow:
            return .systemYellow
        case .green:
            return .systemGreen
        case .red:
            return .systemRed
        case .gray:
            return .systemGray
        }
    }

    private func nsButtonColor(from token: String?) -> NSColor? {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return nil
        }

        switch token.lowercased() {
        case "blue": return .systemBlue
        case "green": return .systemGreen
        case "red": return .systemRed
        case "orange": return .systemOrange
        case "yellow": return .systemYellow
        case "pink": return .systemPink
        case "purple": return .systemPurple
        case "gray", "grey": return .systemGray
        case "black": return .black
        case "white": return .white
        default:
            return nsHexColor(token)
        }
    }

    private func nsHexColor(_ raw: String) -> NSColor? {
        let text = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        guard text.count == 6, let value = Int(text, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xff) / 255.0
        let g = CGFloat((value >> 8) & 0xff) / 255.0
        let b = CGFloat(value & 0xff) / 255.0
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
    }

    private func resolveIconPath(_ raw: String) -> String {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let iconDir = "/Users/one/Documents/项目/多功能bar|休眠/demo/ico"
        switch token {
        case "claude":
            return iconDir + "/claude.png"
        case "hermes":
            return iconDir + "/hermes.png"
        case "codex":
            return iconDir + "/codex.png"
        default:
            return raw
        }
    }

    private func resolveSoundPath(_ raw: String) -> String {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let soundDir = "/Users/one/Documents/项目/多功能bar|休眠/demo/wav"
        switch token {
        case "start":
            return soundDir + "/start.wav"
        case "end":
            return soundDir + "/end.wav"
        default:
            return raw
        }
    }

    private func appendRenderLog(_ text: String) {
        let dir = NSHomeDirectory() + "/.touchbar-island"
        let path = dir + "/touchbar_render.log"
        let payload = "\(Int(Date().timeIntervalSince1970)) \(text)\n"
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(payload.utf8))
        } catch {
            // Render diagnostics must not affect the Touch Bar path.
        }
    }

    private func presentSystemModalTouchBar(_ touchBar: NSTouchBar) {
        let cls: AnyClass = NSTouchBar.self
        let sel2 = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
        if let method = class_getClassMethod(cls, sel2) {
            typealias Fn = @convention(c) (AnyClass, Selector, NSTouchBar, NSString) -> Void
            let imp = method_getImplementation(method)
            let fn = unsafeBitCast(imp, to: Fn.self)
            fn(cls, sel2, touchBar, Self.trayIdentifier)
            return
        }

        let sel3 = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
        if let method = class_getClassMethod(cls, sel3) {
            typealias Fn = @convention(c) (AnyClass, Selector, NSTouchBar, Int, NSString) -> Void
            let imp = method_getImplementation(method)
            let fn = unsafeBitCast(imp, to: Fn.self)
            fn(cls, sel3, touchBar, 0, Self.trayIdentifier)
        }
    }

    private func dismissSystemModalTouchBar() {
        let cls: AnyClass = NSTouchBar.self
        let sel = NSSelectorFromString("dismissSystemModalTouchBar:")
        guard let method = class_getClassMethod(cls, sel) else { return }
        typealias Fn = @convention(c) (AnyClass, Selector, NSString) -> Void
        let imp = method_getImplementation(method)
        let fn = unsafeBitCast(imp, to: Fn.self)
        fn(cls, sel, Self.trayIdentifier)
    }
}
