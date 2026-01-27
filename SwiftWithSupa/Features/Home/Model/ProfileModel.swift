import Foundation
import SwiftChat

struct ProfileModel: Identifiable, Codable, Equatable, ProfileProtocol {
    let id: String
    var full_name: String
    var email: String
    var password: String?
    var avatar_url: String?
    var created_at: String?
    var updated_at: String?
    
    var uuidId: UUID {
        UUID(uuidString: id) ?? UUID()
    }
    
    enum CodingKeys: String, CodingKey {
        case id, full_name, email, password, avatar_url, created_at, updated_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let uuidId = try container.decode(UUID.self, forKey: .id)
        self.id = uuidId.uuidString
        
        self.full_name = try container.decode(String.self, forKey: .full_name)
        self.email = try container.decode(String.self, forKey: .email)
        self.password = try container.decodeIfPresent(String.self, forKey: .password)
        self.avatar_url = try container.decodeIfPresent(String.self, forKey: .avatar_url)
        self.created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        self.updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(UUID(uuidString: id) ?? UUID(), forKey: .id)
        try container.encode(full_name, forKey: .full_name)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(password, forKey: .password)
        try container.encodeIfPresent(avatar_url, forKey: .avatar_url)
        try container.encodeIfPresent(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
    }
}
