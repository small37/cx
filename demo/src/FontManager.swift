import AppKit
import CoreText

final class FontManager {
    static let shared = FontManager()

    private var loadedPostScriptName: String?
    private let preferredFontName = "FusionPixel"

    private init() {}

    func loadPixelFontIfNeeded() {
        if loadedPostScriptName != nil {
            return
        }

        let candidates = fontCandidateURLs()
        for url in candidates {
            if registerFont(at: url) {
                break
            }
        }
    }

    func regular(size: CGFloat) -> NSFont {
        if let name = loadedPostScriptName, let font = NSFont(name: name, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func bold(size: CGFloat) -> NSFont {
        if let name = loadedPostScriptName, let font = NSFont(name: name, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .semibold)
    }

    private func fontCandidateURLs() -> [URL] {
        var urls: [URL] = []
        let fm = FileManager.default

        if let bundleURL = Bundle.main.resourceURL {
            let bundleFonts = bundleURL.appendingPathComponent("Fonts/FusionPixel.ttf")
            urls.append(bundleFonts)
        }

        let home = NSHomeDirectory()
        urls.append(URL(fileURLWithPath: home + "/.touchbar-island/fonts/FusionPixel.ttf"))

        if let userFonts = fm.urls(for: .libraryDirectory, in: .userDomainMask).first {
            urls.append(userFonts.appendingPathComponent("Fonts/FusionPixel.ttf"))
        }

        return urls
    }

    private func registerFont(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !ok && error == nil {
            return false
        }

        if let descriptor = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
           let first = descriptor.first {
            let name = CTFontDescriptorCopyAttribute(first, kCTFontNameAttribute) as? String
            loadedPostScriptName = name ?? preferredFontName
            return true
        }

        loadedPostScriptName = preferredFontName
        return true
    }
}

