import AppKit

final class ScreenshotOverlayWindow: NSWindow {
    private let onCancel: () -> Void

    init(screen: NSScreen, onSelected: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = ScreenshotSelectionView(frame: screen.frame, onSelected: onSelected, onCancel: onCancel)
        contentView = view
        makeKeyAndOrderFront(nil)
        makeFirstResponder(view)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}

final class ScreenshotSelectionView: NSView {
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private let onSelected: (CGRect) -> Void
    private let onCancel: () -> Void

    init(frame: CGRect, onSelected: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.onSelected = onSelected
        self.onCancel = onCancel
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = event.locationInWindow
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = event.locationInWindow
        defer {
            startPoint = nil
            currentPoint = nil
            needsDisplay = true
        }

        guard let start = startPoint, let end = currentPoint else {
            onCancel()
            return
        }

        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        if rect.width < 2 || rect.height < 2 {
            onCancel()
            return
        }

        DispatchQueue.main.async { [onSelected] in
            onSelected(rect)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let start = startPoint, let current = currentPoint else { return }

        let rect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )

        NSColor.clear.setFill()
        rect.fill(using: .copy)

        NSColor.white.withAlphaComponent(0.95).setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()
    }
}
