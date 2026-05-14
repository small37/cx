import Foundation

enum SelectedTextReadMethod {
    case accessibility
    case clipboard
    case failed
}

struct SelectedTextResult {
    let text: String?
    let method: SelectedTextReadMethod
}

protocol SelectedTextReadable {
    func readSelectedText() -> SelectedTextResult
}

final class SelectedTextReader: SelectedTextReadable {
    private let axReader = AXSelectedTextReader()
    private let clipboardReader = ClipboardTextReader()

    func readSelectedText() -> SelectedTextResult {
        for _ in 0..<3 {
            if let text = axReader.readSelectedText(), !text.isEmpty {
                return SelectedTextResult(text: text, method: .accessibility)
            }
            Thread.sleep(forTimeInterval: 0.08)
        }

        if let text = clipboardReader.readSelectedText(retryCount: 2), !text.isEmpty {
            return SelectedTextResult(text: text, method: .clipboard)
        }

        return SelectedTextResult(text: nil, method: .failed)
    }
}
