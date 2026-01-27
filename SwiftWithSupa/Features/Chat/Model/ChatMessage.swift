import Foundation
import SwiftChat

struct ChatMessage: Identifiable, Codable, Hashable, ChatMessageProtocol {
    let id: String
    let chat_id: UUID
    let sender_id: String
    let content: String
    let type: MessageType
    let is_read: Bool
    let created_at: String
    let updated_at: String?
    
    var uuidId: UUID {
        UUID(uuidString: id) ?? UUID()
    }
    
    var uuidSenderId: UUID {
        UUID(uuidString: sender_id) ?? UUID()
    }
    
    var chatMessageType: ChatMessageType {
        switch type {
        case .text:
            return .text
        case .image:
            return .image
        case .link:
            return .link
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, chat_id, sender_id, content, type, is_read, created_at, updated_at
    }

    struct InsertPayload: Encodable {
        let chat_id: UUID
        let sender_id: UUID
        let content: String
        let type: ChatMessageType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let uuidId = try container.decode(UUID.self, forKey: .id)
        self.id = uuidId.uuidString
        
        self.chat_id = try container.decode(UUID.self, forKey: .chat_id)
        
        let uuidSenderId = try container.decode(UUID.self, forKey: .sender_id)
        self.sender_id = uuidSenderId.uuidString
        
        self.content = try container.decode(String.self, forKey: .content)
        
        let chatType = try container.decode(ChatMessageType.self, forKey: .type)
        switch chatType {
        case .text:
            self.type = .text
        case .image:
            self.type = .image
        case .link:
            self.type = .link
        }
        
        self.is_read = try container.decode(Bool.self, forKey: .is_read)
        self.created_at = try container.decode(String.self, forKey: .created_at)
        self.updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(UUID(uuidString: id) ?? UUID(), forKey: .id)
        try container.encode(chat_id, forKey: .chat_id)
        try container.encode(UUID(uuidString: sender_id) ?? UUID(), forKey: .sender_id)
        try container.encode(content, forKey: .content)
        try container.encode(chatMessageType, forKey: .type)
        try container.encode(is_read, forKey: .is_read)
        try container.encode(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
    }
}
