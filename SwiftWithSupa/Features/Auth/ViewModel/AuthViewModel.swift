import Combine
import UIKit
import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: ProfileModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let client = SupabaseConfig.shared.client
    
    private var currentUserId: String? {
        didSet {
            if let id = currentUserId {
                UserDefaults.standard.set(id, forKey: "currentUserId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentUserId")
            }
        }
    }
    
    init() {
        if let savedId = UserDefaults.standard.string(forKey: "currentUserId") {
            currentUserId = savedId
            Task { await loadCurrentUser() }
        }
    }
    
    func signUp(fullName: String, email: String, password: String, avatarPath: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let newProfile = UserModel(
                full_name: fullName,
                email: email,
                password: password,
                avatar_url: avatarPath ?? ""
            )
            
            let response = try await client
                .from("profiles")
                .insert(newProfile)
                .select()
                .single()
                .execute()
            
            let profile = try JSONDecoder().decode(ProfileModel.self, from: response.data)
            currentUser = profile
            currentUserId = profile.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response = try await client
                .from("profiles")
                .select()
                .eq("email", value: email)
                .eq("password", value: password)
                .single()
                .execute()
            
            let profile = try JSONDecoder().decode(ProfileModel.self, from: response.data)
            currentUser = profile
            currentUserId = profile.id
        } catch {
            errorMessage = "Invalid email or password"
        }
    }
    
    func logout() {
        currentUser = nil
        currentUserId = nil
    }
    
    func loadCurrentUser() async {
        guard let id = currentUserId,
              let uuidId = UUID(uuidString: id) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await client
                .from("profiles")
                .select()
                .eq("id", value: uuidId.uuidString)
                .single()
                .execute()
            
            let profile = try JSONDecoder().decode(ProfileModel.self, from: response.data)
            currentUser = profile
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func uploadAvatar(image: UIImage, fileName: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "AvatarUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }
        
        let path = "avatars/\(fileName).jpg"
        
        _ = try await client.storage
            .from("avatars")
            .upload(path, data: data)
        
        let url = try client.storage
            .from("avatars")
            .getPublicURL(path: path)
        
        return url.absoluteString
    }
}
