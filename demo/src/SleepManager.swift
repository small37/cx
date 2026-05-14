import Foundation
import IOKit.pwr_mgt

final class SleepManager {
    private var assertionIDs: [IOPMAssertionID] = []
    private(set) var isPreventingSleep = false

    @discardableResult
    func enablePreventSleep(reason: String = "SleepGuardDemo is preventing sleep") -> Bool {
        guard !isPreventingSleep else { return true }

        let systemSleepAssertion = createAssertion(type: kIOPMAssertionTypePreventSystemSleep as CFString, reason: reason)
        let disablesleepEnabled = setDisableSleep(true)

        assertionIDs = [systemSleepAssertion].compactMap { $0 }
        guard !assertionIDs.isEmpty || disablesleepEnabled else {
            disablePreventSleep()
            return false
        }

        isPreventingSleep = true
        return true
    }

    func disablePreventSleep() {
        guard isPreventingSleep else { return }
        assertionIDs.forEach { IOPMAssertionRelease($0) }
        assertionIDs.removeAll()
        _ = setDisableSleep(false)
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

    private func createAssertion(type: CFString, reason: String) -> IOPMAssertionID? {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        return result == kIOReturnSuccess ? id : nil
    }

    private func setDisableSleep(_ enabled: Bool) -> Bool {
        let target = enabled ? "1" : "0"
        let command = "/usr/bin/pmset -a disablesleep \(target)"
        let script = "do shell script \"\(command)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
