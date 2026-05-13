import Foundation
import IOKit.pwr_mgt

final class SleepManager {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isPreventingSleep = false

    @discardableResult
    func enablePreventSleep(reason: String = "SleepGuardDemo is preventing idle sleep") -> Bool {
        guard !isPreventingSleep else { return true }

        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )

        guard result == kIOReturnSuccess else { return false }
        assertionID = id
        isPreventingSleep = true
        return true
    }

    func disablePreventSleep() {
        guard isPreventingSleep else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isPreventingSleep = false
    }

    func toggle() {
        if isPreventingSleep {
            disablePreventSleep()
        } else {
            _ = enablePreventSleep()
        }
    }

    deinit {
        disablePreventSleep()
    }
}

