import AppKit

final class ScreenshotManager {
    private let saveDirectory: URL

    init(saveDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures")
        .appendingPathComponent("SelectedTextDemo")) {
        self.saveDirectory = saveDirectory
    }

    func capture(rect: CGRect) throws -> URL {
        let normalized = CGRect(
            x: rect.origin.x.rounded(),
            y: rect.origin.y.rounded(),
            width: rect.width.rounded(),
            height: rect.height.rounded()
        )

        guard normalized.width > 1, normalized.height > 1 else {
            throw NSError(domain: "ScreenshotManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "截图区域无效"])
        }

        try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)

        let url = saveDirectory.appendingPathComponent(DateFileName.screenshotName())
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-R\(Int(normalized.origin.x)),\(Int(normalized.origin.y)),\(Int(normalized.width)),\(Int(normalized.height))", url.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ScreenshotManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "系统截图命令执行失败"])
        }

        return url
    }

    func captureInteractively() throws -> URL {
        try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
        let url = saveDirectory.appendingPathComponent(DateFileName.screenshotName())

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", url.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 1 {
            try? FileManager.default.removeItem(at: url)
            throw NSError(domain: "ScreenshotManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "已取消截图"])
        }
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ScreenshotManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "系统截图命令执行失败"])
        }
        guard FileManager.default.fileExists(atPath: url.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? NSNumber,
              fileSize.intValue > 0 else {
            try? FileManager.default.removeItem(at: url)
            throw NSError(domain: "ScreenshotManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "已取消截图"])
        }
        return url
    }
}
