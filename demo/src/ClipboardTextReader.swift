import AppKit
import Carbon
import Foundation

final class ClipboardTextReader {
    private lazy var eventSource: CGEventSource? = CGEventSource(stateID: .combinedSessionState)

    func readSelectedText(retryCount: Int = 0) -> String? {
        let pasteboard = NSPasteboard.general
        let backup = PasteboardBackup(pasteboard: pasteboard)
        defer { backup.restore(to: pasteboard) }

        for _ in 0...max(retryCount, 0) {
            pasteboard.clearContents()
            let changeCount = pasteboard.changeCount
            sendCommandC()
            if let text = waitForCopiedText(on: pasteboard, after: changeCount) {
                return text
            }
        }
        return nil
    }

    private func sendCommandC() {
        guard let source = eventSource else { return }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    private func waitForCopiedText(on pasteboard: NSPasteboard, after changeCount: Int) -> String? {
        let deadline = Date().addingTimeInterval(0.55)
        var interval: TimeInterval = 0.015
        while Date() < deadline {
            if pasteboard.changeCount != changeCount,
               let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return text
            }
            Thread.sleep(forTimeInterval: interval)
            interval = min(interval * 1.35, 0.05)
        }
        return nil
    }
}
