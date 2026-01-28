import Foundation
import UIKit
import Supabase
import Combine
import SwiftChat

@MainActor
final class ChatViewModel: ObservableObject, ChatViewModelProtocol {
    
    @Published var messages: [any ChatMessageProtocol] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let client = SupabaseConfig.shared.client
    
    private(set) var chatId: UUID?
    private let currentUser: ProfileModel
    private let otherUser: ProfileModel
    
    private var channel: RealtimeChannelV2?
    
    init(currentUser: ProfileModel, otherUser: ProfileModel) {
        self.currentUser = currentUser
        self.otherUser = otherUser
    }
    
    func start() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let chat = try await loadOrCreateChat()
            chatId = chat.id
            
            try await loadMessages(chatId: chat.id)
            subscribeToRealtime(chatId: chat.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadOrCreateChat() async throws -> Chat {
        let myId = currentUser.uuidId
        let otherId = otherUser.uuidId
        
        do {
            let response = try await client
                .from("chats")
                .select()
                .or("and(user_a.eq.\(myId.uuidString),user_b.eq.\(otherId.uuidString)),and(user_a.eq.\(otherId.uuidString),user_b.eq.\(myId.uuidString))")
                .limit(1)
                .execute()
            
            if !response.data.isEmpty {
                let existing = try JSONDecoder().decode([Chat].self, from: response.data)
                if let chat = existing.first {
                    return chat
                }
            } else {
                print("No existing chat found, will create")
            }
        } catch {
            print("Error querying chats:", error)
        }
        
        let payload = Chat.InsertPayload(user_a: myId, user_b: otherId)
        
        let createResponse = try await client
            .from("chats")
            .insert(payload)
            .select()
            .single()
            .execute()
        
        let chat = try JSONDecoder().decode(Chat.self, from: createResponse.data)
        return chat
    }
    
    private func loadMessages(chatId: UUID) async throws {
        let response = try await client
            .from("messages")
            .select()
            .eq("chat_id", value: chatId.uuidString)
            .order("created_at", ascending: true)
            .execute()
        
        let decoded = try JSONDecoder().decode([ChatMessage].self, from: response.data)
        messages = decoded
    }
    
    func sendTextMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        
        if chatId == nil {
            await start()
        }
        
        guard let chatId = chatId else {
            return
        }
        
        let messageType: ChatMessageType
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            messageType = .link
        } else {
            messageType = .text
        }
        
        let payload = ChatMessage.InsertPayload(
            chat_id: chatId,
            sender_id: currentUser.uuidId,
            content: trimmed,
            type: messageType
        )
        
        do {
            let response = try await client
                .from("messages")
                .insert(payload)
                .select()
                .single()
                .execute()
            
            let message = try JSONDecoder().decode(ChatMessage.self, from: response.data)
            
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func sendImageMessage(image: UIImage) async {
        if chatId == nil {
            await start()
        }
        
        guard let chatId = chatId else {
            return
        }
        
        do {
            let url = try await uploadImage(image: image)
            
            let payload = ChatMessage.InsertPayload(
                chat_id: chatId,
                sender_id: currentUser.uuidId,
                content: url,
                type: .image
            )
            
            let response = try await client
                .from("messages")
                .insert(payload)
                .select()
                .single()
                .execute()
            
            let message = try JSONDecoder().decode(ChatMessage.self, from: response.data)
            
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func deleteMessage(_ message: any ChatMessageProtocol) async {
        do {
            if message.type == .image,
               let path = storagePath(from: message.content, bucket: "avatars") {
                do {
                    _ = try await client.storage
                        .from("avatars")
                        .remove(paths: [path])
                } catch {
                    print("Failed to delete image from storage:", error)
                }
            }
            
            guard let messageId = UUID(uuidString: message.id) else {
                return
            }
            
            _ = try await client
                .from("messages")
                .delete()
                .eq("id", value: messageId.uuidString)
                .execute()
            
            messages.removeAll { $0.id == message.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteChat() async {
        guard let chatId = chatId else { return }
        
        do {
            _ = try await client
                .from("chats")
                .delete()
                .eq("id", value: chatId.uuidString)
                .execute()
            
            messages.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func subscribeToRealtime(chatId: UUID) {
        let channel = client.channel("chat_\(chatId.uuidString)")
        
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "messages"
        )
        
        Task { [weak self] in
            guard let self = self else { return }
            
            for await change in changes {
                await MainActor.run {
                    switch change {
                    case .insert(let insertAction):
                        do {
                            let message = try insertAction.decodeRecord(
                                as: ChatMessage.self,
                                decoder: JSONDecoder()
                            )
                            guard message.chat_id == chatId else { return }
                            
                            if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                                self.messages[index] = message
                            } else {
                                self.messages.append(message)
                            }
                        } catch {
                            self.errorMessage = error.localizedDescription
                        }
                        
                    case .update(let updateAction):
                        do {
                            let message = try updateAction.decodeRecord(
                                as: ChatMessage.self,
                                decoder: JSONDecoder()
                            )
                            guard message.chat_id == chatId else { return }
                            
                            if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                                self.messages[index] = message
                            } else {
                                self.messages.append(message)
                            }
                        } catch {
                            self.errorMessage = error.localizedDescription
                        }
                        
                    case .delete(let deleteAction):
                        if let idValue = deleteAction.oldRecord["id"]?.value as? String {
                            self.messages.removeAll { $0.id == idValue }
                        }
                    }
                }
            }
        }
        
        Task {
            try await channel.subscribeWithError()
        }
        
        self.channel = channel
    }
    
    private func storagePath(from publicURLString: String, bucket: String = "avatars") -> String? {
        guard let url = URL(string: publicURLString) else {
            return nil
        }
        
        let components = url.pathComponents
        
        guard let bucketIndex = components.firstIndex(of: bucket),
              bucketIndex < components.count - 1 else {
            return nil
        }
        
        let pathComponents = components[(bucketIndex + 1)...]
        return pathComponents.joined(separator: "/")
    }

    private func resizedImage(from image: UIImage, scale: CGFloat) -> UIImage? {
        guard scale > 0, scale < 1 else { return image }
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func compressedJPEGData(from image: UIImage, maxBytes: Int) -> Data? {
        var currentImage: UIImage? = image
        var bestData: Data?

        for _ in 0..<4 {
            guard let img = currentImage else { break }

            var minQuality: CGFloat = 0.3
            var maxQuality: CGFloat = 0.9
            var bestForThisScale: Data?

            for _ in 0..<6 {
                let q = (minQuality + maxQuality) / 2
                guard let data = img.jpegData(compressionQuality: q) else { break }

                if bestData == nil || data.count < bestData!.count {
                    bestData = data
                }

                if data.count > maxBytes {
                    maxQuality = q
                } else {
                    bestForThisScale = data
                    minQuality = q
                }
            }

            if let bestForThisScale {
                return bestForThisScale
            }

            currentImage = resizedImage(from: img, scale: 0.7)
        }

        return bestData
    }
    
    private func uploadImage(image: UIImage) async throws -> String {

        let maxBytes = 800 * 1024
        guard let data = compressedJPEGData(from: image, maxBytes: maxBytes) else {
            throw NSError(
                domain: "ChatImageUpload",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Image is too large. Maximum allowed size is 800 KB. Please choose a smaller image."]
            )
        }
        
        let fileName = UUID().uuidString + ".jpg"
        let path = "chat-images/\(fileName)"
        
        try await client.storage
            .from("avatars")
            .upload(
                path,
                data: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )
        
        return try client.storage
            .from("avatars")
            .getPublicURL(path: path)
            .absoluteString
    }
}
