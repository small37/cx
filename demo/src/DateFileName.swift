import Foundation

enum DateFileName {
    static func screenshotName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        return "screenshot_\(formatter.string(from: date)).png"
    }
}
