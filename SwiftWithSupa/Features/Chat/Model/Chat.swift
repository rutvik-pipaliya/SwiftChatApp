import Foundation

struct Chat: Identifiable, Codable {
    let id: UUID
    let user_a: UUID
    let user_b: UUID
    let last_message_at: String?
    let created_at: String
}

extension Chat {
    struct InsertPayload: Encodable {
        let user_a: UUID
        let user_b: UUID
    }
}

enum ChatMessageType: String, Codable {
    case text
    case image
    case link
}
