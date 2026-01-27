import Foundation
import Supabase
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var errorMessage: String?
    
    private let client = SupabaseConfig.shared.client
    
    func fetchOtherUsers(excluding userId: String?) async -> [ProfileModel] {
        guard let id = userId else { return [] }
        
        guard let uuidId = UUID(uuidString: id) else { return [] }
        
        do {
            let response = try await client
                .from("profiles")
                .select("id, full_name, email, avatar_url, created_at, updated_at")
                .neq("id", value: uuidId.uuidString)
                .execute()
            
            let users = try JSONDecoder().decode([ProfileModel].self, from: response.data)
            return users
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
}

