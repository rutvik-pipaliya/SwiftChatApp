import SwiftUI
import SwiftChat

struct ChatViewWrapper: View {
    let currentUser: ProfileModel
    let otherUser: ProfileModel
    
    @StateObject private var viewModel: ChatViewModel
    
    init(currentUser: ProfileModel, otherUser: ProfileModel) {
        self.currentUser = currentUser
        self.otherUser = otherUser
        _viewModel = StateObject(wrappedValue: ChatViewModel(currentUser: currentUser, otherUser: otherUser))
    }
    
    var body: some View {
        ChatView(
            currentUser: currentUser,
            otherUser: otherUser,
            viewModel: viewModel
        )
        .navigationTitle(otherUser.full_name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.start()
        }
    }
}
