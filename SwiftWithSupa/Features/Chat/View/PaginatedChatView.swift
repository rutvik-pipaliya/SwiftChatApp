import SwiftUI
import SwiftChat

/// Chat view that supports pagination correctly: scroll-to-bottom only when the last message
/// changes (new message at bottom), not when older messages are prepended. Shows a loading
/// indicator at the top when loading older messages and uses a larger trigger area so
/// loadMoreMessages fires reliably when scrolling to top.
struct PaginatedChatView<ViewModel: ObservableObject & ChatViewModelProtocol>: View {
    let currentUser: any ProfileProtocol
    let otherUser: any ProfileProtocol
    @ObservedObject var viewModel: ViewModel
    var showLoadingMore: Bool
    var hasMoreOlderMessages: Bool

    @State private var messageText = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var lastMessageId: String = ""
    @State private var initialScrollDone = false

    var body: some View {
        let canSend = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil

        VStack(spacing: 0) {
            if !viewModel.messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            loadMoreTrigger()
                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { _, message in
                                MessageBubble(
                                    message: message,
                                    isCurrentUser: message.sender_id == currentUser.id
                                )
                                .id(message.id)
                                .contextMenu {
                                    if message.sender_id == currentUser.id {
                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.deleteMessage(message)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top)
                    }
                    .onAppear {
                        if let lastMessage = viewModel.messages.last {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                                initialScrollDone = true
                            }
                        } else {
                            initialScrollDone = true
                        }
                    }
                    .onChange(of: lastMessageId) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("No messages yet. Start a conversation!")
                    Spacer()
                }
            }

            Divider()

            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                        .cornerRadius(8)
                    Spacer()
                    Button("Remove") {
                        selectedImage = nil
                    }
                }
                .padding(.horizontal)
            }

            ChatInputBar(
                messageText: $messageText,
                onSend: {
                    Task {
                        if let image = selectedImage {
                            await viewModel.sendImageMessage(image: image)
                            selectedImage = nil
                        } else {
                            let text = messageText
                            messageText = ""
                            await viewModel.sendTextMessage(text)
                        }
                    }
                },
                onImageTap: {
                    showImagePicker = true
                },
                isSendEnabled: canSend
            )
        }
        .navigationTitle(otherUser.full_name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: viewModel.messages.count) { _, count in
            if let lastMessage = viewModel.messages.last, lastMessage.id != lastMessageId {
                lastMessageId = lastMessage.id
            }
        }
    }

    @ViewBuilder
    private func loadMoreTrigger() -> some View {
        Group {
            if showLoadingMore {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading older messages…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.vertical, 12)
            } else if hasMoreOlderMessages {
                Button {
                    Task {
                        await viewModel.loadMoreMessages()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                        Text("Load older messages")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.vertical, 12)
            } else {
                Color.clear
                    .frame(height: 20)
            }
        }
        .onAppear {
            guard initialScrollDone else { return }
            Task {
                await viewModel.loadMoreMessages()
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.messages.last else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}
