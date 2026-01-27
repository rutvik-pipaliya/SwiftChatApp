import SwiftUI

@main
struct SwiftChatApp: App {
    @StateObject private var authManager = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let user = authManager.currentUser {
                    HomeView(
                        currentUser: user,
                        onLogout: authManager.logout
                    )
                } else {
                    AuthView()
                        .environmentObject(authManager)
                }
            }
        }
    }
}
