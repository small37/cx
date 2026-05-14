import AppKit

final class ToastWindow {
    private var window: NSWindow?
    private var generation = 0

    func show(message: String, duration: TimeInterval = 2.5) {
        generation += 1
        let currentGeneration = generation

        let label = NSTextField(labelWithString: message)
        label.alignment = .center
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.lineBreakMode = .byTruncatingMiddle

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 56))
        content.wantsLayer = true
        content.layer?.cornerRadius = 10
        content.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.82).cgColor
        label.frame = NSRect(x: 12, y: 18, width: 496, height: 20)
        content.addSubview(label)

        let window = NSWindow(
            contentRect: content.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.contentView = content
        window.center()
        window.orderFrontRegardless()

        self.window?.orderOut(nil)
        self.window = window

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.generation == currentGeneration else { return }
            window.orderOut(nil)
            if self.window === window {
                self.window = nil
            }
        }
    }
}
