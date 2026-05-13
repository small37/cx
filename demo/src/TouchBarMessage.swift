import Foundation

enum MessageType {
    case status
    case info
    case permission
    case done
    case error
}

struct TouchBarMessage {
    let id: String
    let source: String
    let layout: String
    let type: MessageType
    let createdAt: Date
    let ttl: TimeInterval?
}

