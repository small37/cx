import Foundation

@main
struct AssertionTester {
    static func main() {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            printUsage()
            exit(1)
        }

        let manager = SleepManager()
        let command = args[1]

        switch command {
        case "on":
            let duration: Int
            if args.count >= 3, let sec = Int(args[2]), sec > 0 {
                duration = sec
            } else {
                duration = 30
            }

            let ok = manager.enablePreventSleep(reason: "SleepGuardDemo assertion_tester")
            if !ok {
                fputs("Failed to create sleep assertion\n", stderr)
                exit(2)
            }

            print("Assertion enabled for \(duration)s. Check with: pmset -g assertions")
            sleep(UInt32(duration))
            manager.disablePreventSleep()
            print("Assertion released.")

        case "off":
            manager.disablePreventSleep()
            print("Assertion released (if existed in this process).")

        default:
            printUsage()
            exit(1)
        }
    }

    private static func printUsage() {
        print("Usage:")
        print("  assertion_tester on <seconds>")
        print("  assertion_tester off")
    }
}
