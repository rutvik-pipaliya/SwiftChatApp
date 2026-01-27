import Foundation
import Supabase

final class SupabaseConfig {
    static let shared = SupabaseConfig()
    
    private let supabaseUrl = URL(string: Constants.SupabaseClient.projectURL)!
    private let supabaseKey = Constants.SupabaseClient.anonKey
    
    let client: SupabaseClient
    
    private init() {
        let authOptions = SupabaseClientOptions.AuthOptions(
            emitLocalSessionAsInitialSession: true
        )
        let options = SupabaseClientOptions(auth: authOptions)
        client = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseKey, options: options)
    }
}
