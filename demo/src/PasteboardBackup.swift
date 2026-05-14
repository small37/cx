import AppKit

struct PasteboardBackup {
    private let items: [NSPasteboardItem]

    init(pasteboard: NSPasteboard = .general) {
        items = pasteboard.pasteboardItems?.compactMap { item in
            let clone = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    clone.setData(data, forType: type)
                }
            }
            return clone
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
