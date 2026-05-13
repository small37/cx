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

    init(store: CurrentMessageStore) {
        self.store = store
        super.init()
        FontManager.shared.loadPixelFontIfNeeded()
    }

    func start() {
        setupResponderFallback()
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
        dismissSystemModalTouchBar()
    }

    private func refresh() {
        store.snapshot { [weak self] currentMessage, defaultStatus, isPaused in
            guard let self else { return }
            if isPaused {
                self.renderedNodes = [.text(color: .gray, value: "已暂停显示")]
            } else if let currentMessage {
                self.renderedNodes = self.parser.parse(currentMessage.layout)
            } else {
                self.renderedNodes = self.parser.parse("[text:white:\(defaultStatus)]")
            }

            self.hasTrailingButtons = self.renderedNodes.contains {
                if case .button = $0 { return true }
                return false
            }

            let touchBar = NSTouchBar()
            touchBar.delegate = self
            if self.hasTrailingButtons {
                touchBar.defaultItemIdentifiers = [Self.leadingIdentifier, .flexibleSpace, Self.trailingIdentifier]
            } else {
                touchBar.defaultItemIdentifiers = [Self.leadingIdentifier]
            }
            touchBar.principalItemIdentifier = Self.leadingIdentifier
            self.currentTouchBar = touchBar
            self.appendRenderLog("render current=\(currentMessage?.layout ?? defaultStatus) nodes=\(self.renderedNodes.count) buttons=\(self.hasTrailingButtons)")

            DispatchQueue.main.async {
                self.hostView?.hostedTouchBar = touchBar
                self.hostWindow?.makeFirstResponder(self.hostView)
                self.hostWindow?.orderFrontRegardless()
                self.hostWindow?.makeKey()
                NSApp.activate(ignoringOtherApps: true)
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
        for node in nodes {
            switch node {
            case .text(let color, let value):
                let label = NSTextField(labelWithString: value)
                label.textColor = nsColor(from: color)
                label.lineBreakMode = .byTruncatingTail
                label.maximumNumberOfLines = 1
                label.font = FontManager.shared.regular(size: 13)
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
                label.font = FontManager.shared.bold(size: 13)
                label.alignment = .center
                label.translatesAutoresizingMaskIntoConstraints = false
                label.wantsLayer = true
                label.layer?.cornerRadius = 0
                label.layer?.borderWidth = 1
                label.layer?.borderColor = NSColor.black.withAlphaComponent(0.6).cgColor
                label.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
                left.addArrangedSubview(label)
            case .icon(let path, let size):
                guard let image = NSImage(contentsOfFile: path) else { continue }
                let iconView = NSImageView()
                iconView.image = image
                iconView.imageScaling = .scaleProportionallyUpOrDown
                iconView.translatesAutoresizingMaskIntoConstraints = false
                let edge = max(12, size ?? 18)
                iconView.widthAnchor.constraint(equalToConstant: edge).isActive = true
                iconView.heightAnchor.constraint(equalToConstant: edge).isActive = true
                left.addArrangedSubview(iconView)
            case .button, .flex:
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
        for node in nodes {
            guard case .button(let title, let action, let colorToken) = node else { continue }
            let button = NSButton(title: title, target: self, action: #selector(onButtonClick(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(action)
            if let color = nsButtonColor(from: colorToken) {
                button.bezelColor = color
            }
            right.addArrangedSubview(button)
        }
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
            case .flex, .button:
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
