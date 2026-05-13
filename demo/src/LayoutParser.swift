import Foundation

final class LayoutParser {
    func parse(_ layout: String) -> [LayoutNode] {
        var result: [LayoutNode] = []
        var index = layout.startIndex

        while index < layout.endIndex {
            guard let start = layout[index...].firstIndex(of: "[") else {
                appendPlainText(String(layout[index...]), to: &result)
                break
            }

            if start > index {
                appendPlainText(String(layout[index..<start]), to: &result)
            }

            guard let end = findTokenEnd(in: layout, from: layout.index(after: start)) else {
                appendPlainText(String(layout[start...]), to: &result)
                break
            }

            let token = String(layout[layout.index(after: start)..<end])
            appendToken(token, to: &result)
            index = layout.index(after: end)
        }

        return compact(result)
    }

    private func appendPlainText(_ text: String, to result: inout [LayoutNode]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        result.append(.text(color: .white, value: trimmed))
    }

    private func appendToken(_ token: String, to result: inout [LayoutNode]) {
        if token == "flex" {
            result.append(.flex)
            return
        }

        if token.hasPrefix("space:") {
            let value = String(token.dropFirst("space:".count))
            if let number = Double(value), number >= 0 {
                result.append(.space(CGFloat(number)))
            }
            return
        }

        if token.hasPrefix("tag:") {
            let value = unescape(String(token.dropFirst("tag:".count)))
            if !value.isEmpty {
                result.append(.tag(value))
            }
            return
        }

        if token.hasPrefix("button:") {
            let parts = splitEscaped(token, maxSplits: 3)
            if parts.count >= 3 {
                let title = unescape(parts[1])
                let action = unescape(parts[2])
                let color = parts.count >= 4 ? unescape(parts[3]) : nil
                if !title.isEmpty, !action.isEmpty {
                    result.append(.button(title: title, action: action, color: color?.isEmpty == true ? nil : color))
                }
            }
            return
        }

        if token.hasPrefix("icon:") {
            let parts = splitEscaped(token, maxSplits: 2)
            if parts.count >= 2 {
                let path = unescape(parts[1])
                let size: CGFloat?
                if parts.count == 3, let number = Double(unescape(parts[2])), number > 0 {
                    size = CGFloat(number)
                } else {
                    size = nil
                }
                if !path.isEmpty {
                    result.append(.icon(path: path, size: size))
                }
            }
            return
        }

        if token.hasPrefix("text:") {
            let parts = splitEscaped(token, maxSplits: 2)
            if parts.count == 3 {
                let color = LayoutColor(rawValue: parts[1]) ?? .white
                let value = unescape(parts[2])
                if !value.isEmpty {
                    result.append(.text(color: color, value: value))
                }
            }
            return
        }

        if !token.isEmpty {
            result.append(.text(color: .white, value: unescape(token)))
        }
    }

    private func compact(_ nodes: [LayoutNode]) -> [LayoutNode] {
        var merged: [LayoutNode] = []
        for node in nodes {
            switch node {
            case .text(let color, let value):
                if case .text(let lastColor, let lastValue)? = merged.last, lastColor == color {
                    merged.removeLast()
                    merged.append(.text(color: color, value: "\(lastValue) \(value)"))
                } else {
                    merged.append(.text(color: color, value: value))
                }
            default:
                merged.append(node)
            }
        }
        return merged
    }

    private func findTokenEnd(in layout: String, from start: String.Index) -> String.Index? {
        var i = start
        var escaped = false
        while i < layout.endIndex {
            let ch = layout[i]
            if escaped {
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == "]" {
                return i
            }
            i = layout.index(after: i)
        }
        return nil
    }

    private func splitEscaped(_ text: String, maxSplits: Int) -> [String] {
        var out: [String] = []
        var current = ""
        var escaped = false
        var splits = 0

        for ch in text {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }

            if ch == "\\" {
                escaped = true
                current.append(ch)
                continue
            }

            if ch == ":" && splits < maxSplits {
                out.append(current)
                current = ""
                splits += 1
                continue
            }

            current.append(ch)
        }

        out.append(current)
        return out
    }

    private func unescape(_ text: String) -> String {
        var out = ""
        var escaped = false
        for ch in text {
            if escaped {
                out.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" {
                escaped = true
                continue
            }
            out.append(ch)
        }
        if escaped {
            out.append("\\")
        }
        return out
    }
}
