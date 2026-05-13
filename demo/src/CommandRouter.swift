import Foundation

enum TouchBarCommand {
    case msg(String)
    case permission(String)
    case done(String)
    case error(String)
    case status(String)
    case clear
}

final class CommandRouter {
    private let store: CurrentMessageStore

    init(store: CurrentMessageStore) {
        self.store = store
    }

    func handle(rawLine: String) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, let command = parse(line) else { return }

        if case .status = command {
            // STATUS 即使暂停也允许更新默认文案。
        } else {
            store.snapshot { _, _, isPaused in
                guard !isPaused else { return }
                self.apply(command)
            }
            return
        }

        apply(command)
    }

    private func apply(_ command: TouchBarCommand) {
        switch command {
        case .msg(let layout):
            store.setMessage(
                TouchBarMessage(
                    id: UUID().uuidString,
                    source: "socket",
                    layout: layout,
                    type: .info,
                    createdAt: Date(),
                    ttl: nil
                )
            )
        case .permission(let text):
            store.setMessage(
                TouchBarMessage(
                    id: UUID().uuidString,
                    source: "socket",
                    layout: "[tag:权限] [text:yellow:\(text)] [flex] [button:确认:confirm] [button:取消:cancel]",
                    type: .permission,
                    createdAt: Date(),
                    ttl: nil
                )
            )
        case .done(let text):
            store.setMessage(
                TouchBarMessage(
                    id: UUID().uuidString,
                    source: "socket",
                    layout: "[tag:完成] [text:green:\(text)] [flex] [button:关闭:dismiss]",
                    type: .done,
                    createdAt: Date(),
                    ttl: 8
                )
            )
        case .error(let text):
            store.setMessage(
                TouchBarMessage(
                    id: UUID().uuidString,
                    source: "socket",
                    layout: "[tag:错误] [text:red:\(text)] [flex] [button:关闭:dismiss]",
                    type: .error,
                    createdAt: Date(),
                    ttl: nil
                )
            )
        case .status(let text):
            store.setDefaultStatus(text)
        case .clear:
            store.clearMessage()
        }
    }

    private func parse(_ line: String) -> TouchBarCommand? {
        if line == "CLEAR" {
            return .clear
        }

        guard let spaceIndex = line.firstIndex(of: " ") else { return nil }
        let op = String(line[..<spaceIndex]).uppercased()
        let payload = String(line[line.index(after: spaceIndex)...]).trimmingCharacters(in: .whitespaces)

        switch op {
        case "MSG":
            return .msg(payload)
        case "PERMISSION":
            return .permission(payload)
        case "DONE":
            return .done(payload)
        case "ERROR":
            return .error(payload)
        case "STATUS":
            return .status(payload)
        default:
            return nil
        }
    }
}

