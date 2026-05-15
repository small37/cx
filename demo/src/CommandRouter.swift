import Foundation

enum TouchBarCommand {
    case msg(String)
    case done(String)
}

final class CommandRouter {
    private let store: CurrentMessageStore

    init(store: CurrentMessageStore) {
        self.store = store
    }

    func handle(rawLine: String) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, let command = parse(line) else { return }
        store.snapshot { _, _, isPaused in
            guard !isPaused else { return }
            self.apply(command)
        }
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
        }
    }

    private func parse(_ line: String) -> TouchBarCommand? {
        guard let spaceIndex = line.firstIndex(of: " ") else { return nil }
        let op = String(line[..<spaceIndex]).uppercased()
        let payload = String(line[line.index(after: spaceIndex)...]).trimmingCharacters(in: .whitespaces)

        switch op {
        case "MSG":
            return .msg(payload)
        case "DONE":
            return .done(payload)
        default:
            return nil
        }
    }
}
