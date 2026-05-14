import Carbon
import Foundation

final class HotkeyManager {
    private var textHotKeyRef: EventHotKeyRef?
    private var screenshotHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    var onReadSelectedText: (() -> Void)?
    var onStartScreenshot: (() -> Void)?

    func registerHotkeys() {
        unregisterHotkeys()

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return noErr }
            manager.handleHotkey(id: hotKeyID.id)
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        let config = HotkeyConfig.load()
        registerHotKey(keyCode: config.text.keyCode, modifiers: config.text.modifiers, hotKeyID: 1, ref: &textHotKeyRef)
        registerHotKey(keyCode: config.screenshot.keyCode, modifiers: config.screenshot.modifiers, hotKeyID: 2, ref: &screenshotHotKeyRef)
    }

    func unregisterHotkeys() {
        if let ref = textHotKeyRef {
            UnregisterEventHotKey(ref)
            textHotKeyRef = nil
        }
        if let ref = screenshotHotKeyRef {
            UnregisterEventHotKey(ref)
            screenshotHotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, hotKeyID: UInt32, ref: inout EventHotKeyRef?) {
        let id = EventHotKeyID(signature: OSType(0x53475458), id: hotKeyID)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    private func handleHotkey(id: UInt32) {
        DispatchQueue.main.async {
            switch id {
            case 1:
                self.onReadSelectedText?()
            case 2:
                self.onStartScreenshot?()
            default:
                break
            }
        }
    }
}
