import Foundation

enum MessageType {
    case info
    case done
}

struct TouchBarMessage {
    let id: String
    let source: String
    let layout: String
    let type: MessageType
    let createdAt: Date
    let ttl: TimeInterval?
}
