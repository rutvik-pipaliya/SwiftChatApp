import SwiftUI
import SwiftChat

struct ChatViewWrapper: View {
    let currentUser: ProfileModel
    let otherUser: ProfileModel
    
    @StateObject private var viewModel: ChatViewModel
    @State private var showErrorAlert = false
    
    init(currentUser: ProfileModel, otherUser: ProfileModel) {
        self.currentUser = currentUser
        self.otherUser = otherUser
        _viewModel = StateObject(wrappedValue: ChatViewModel(currentUser: currentUser, otherUser: otherUser))
    }
    
    var body: some View {
        SwiftChat.ChatView(
            currentUser: currentUser,
            otherUser: otherUser,
            viewModel: viewModel,
            showLoadingMore: viewModel.isLoadingMore,
            hasMoreOlderMessages: viewModel.hasMoreOlderMessages
        )
        .navigationTitle(otherUser.full_name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.start()
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Error", isPresented: $showErrorAlert, actions: {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
    }
}
