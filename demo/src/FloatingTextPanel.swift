import AppKit

final class FloatingTextPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }

    override func resignMain() {
        super.resignMain()
        orderOut(nil)
    }
}

final class FloatingTextPanelController {
    private var panel: FloatingTextPanel?
    private var sourceTextView: NSTextView?
    private var translatedTextView: NSTextView?

    func show(sourceText: String, translatedText: String, title: String = "划词翻译") {
        let panel = ensurePanel()
        panel.title = title
        sourceTextView?.string = sourceText
        translatedTextView?.string = translatedText
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func updateTranslation(_ translatedText: String) {
        translatedTextView?.string = translatedText
    }

    private func ensurePanel() -> FloatingTextPanel {
        if let panel {
            return panel
        }

        let size = NSSize(width: 520, height: 320)
        let panel = FloatingTextPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.title = "选中文本"
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1).cgColor

        let sourceTitle = makeTitle("原文")
        sourceTitle.frame = NSRect(x: 14, y: size.height - 34, width: size.width - 28, height: 18)
        sourceTitle.autoresizingMask = [.width, .minYMargin]
        content.addSubview(sourceTitle)

        let sourceSection = makeTextSection(frame: NSRect(x: 14, y: size.height / 2 + 6, width: size.width - 28, height: size.height / 2 - 44))
        sourceSection.scrollView.autoresizingMask = [.width, .height, .minYMargin]
        content.addSubview(sourceSection.scrollView)

        let translatedTitle = makeTitle("翻译")
        translatedTitle.frame = NSRect(x: 14, y: size.height / 2 - 18, width: size.width - 28, height: 18)
        translatedTitle.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        content.addSubview(translatedTitle)

        let translatedSection = makeTextSection(frame: NSRect(x: 14, y: 14, width: size.width - 28, height: size.height / 2 - 34))
        translatedSection.scrollView.autoresizingMask = [.width, .height, .maxYMargin]
        content.addSubview(translatedSection.scrollView)
        panel.contentView = content

        self.sourceTextView = sourceSection.textView
        self.translatedTextView = translatedSection.textView
        self.panel = panel
        return panel
    }

    private func makeTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.textColor = NSColor(calibratedWhite: 0.86, alpha: 1)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func makeTextSection(frame: NSRect) -> (scrollView: NSScrollView, textView: NSTextView) {
        let scrollView = NSScrollView(frame: frame)
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 10
        scrollView.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1).cgColor

        let textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        textView.textColor = NSColor(calibratedWhite: 0.94, alpha: 1)
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 10, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView
        return (scrollView, textView)
    }
}
