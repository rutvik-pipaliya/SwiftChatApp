import SwiftUI
import SwiftChat

struct HomeView: View {
    let currentUser: ProfileModel
    let onLogout: () -> Void
    
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var otherUsers: [ProfileModel] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: currentUser.avatar_url ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text(currentUser.full_name)
                            .font(.headline)
                        Text(currentUser.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Other Users")
                    .font(.title3)
                    .bold()
                
                if isLoading {
                    ProgressView()
                } else {
                    List(otherUsers) { profile in
                        NavigationLink {
                            ChatViewWrapper(currentUser: currentUser, otherUser: profile)
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: profile.avatar_url ?? "")) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    default:
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading) {
                                    Text(profile.full_name)
                                    Text(profile.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("Home")
            .toolbar {
                Button("Logout") {
                    onLogout()
                }
            }
            .task {
                await loadOtherUsers()
            }
        }
    }
    
    private func loadOtherUsers() async {
        isLoading = true
        defer { isLoading = false }
        otherUsers = await homeViewModel.fetchOtherUsers(excluding: currentUser.id)
    }
}
