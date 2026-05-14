import ApplicationServices
import Foundation

final class AXSelectedTextReader {
    func readSelectedText() -> String? {
        guard let focusedElement = focusedElement() else { return nil }
        if let text = selectedText(from: focusedElement), !text.isEmpty {
            return text
        }
        return selectedTextByRange(from: focusedElement)
    }

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )
        guard focusedStatus == .success, let focusedObject else { return nil }
        guard CFGetTypeID(focusedObject) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(focusedObject, to: AXUIElement.self)
    }

    private func selectedText(from element: AXUIElement) -> String? {
        var selectedTextObject: CFTypeRef?
        let textStatus = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextObject
        )
        guard textStatus == .success, let selectedTextObject else { return nil }

        if let text = selectedTextObject as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let attributed = selectedTextObject as? NSAttributedString {
            return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func selectedTextByRange(from element: AXUIElement) -> String? {
        var rangeObject: CFTypeRef?
        let rangeStatus = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeObject
        )
        guard rangeStatus == .success, let rangeObject else { return nil }
        guard CFGetTypeID(rangeObject) == AXValueGetTypeID() else { return nil }

        let axValue = unsafeBitCast(rangeObject, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else { return nil }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }

        var textObject: CFTypeRef?
        let textStatus = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            axValue,
            &textObject
        )
        guard textStatus == .success, let textObject else { return nil }
        guard let text = textObject as? String else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
