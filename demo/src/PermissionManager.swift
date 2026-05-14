import ApplicationServices
import CoreGraphics

final class PermissionManager {
    func ensureAccessibilityPermission() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestScreenRecordingPermissionIfNeeded() {
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
        }
    }
}
