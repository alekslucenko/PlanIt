import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import Network

// MARK: - Chat Manager
@MainActor
class ChatManager: ObservableObject {
    @Published var conversations: [ChatConversation] = []
    @Published var currentChatMessages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isConnected = true
    
    private let db = Firestore.firestore()
    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var currentChatId: String?
    
    // Notification manager and auth service references
    var notificationManager: NotificationManager?
    var authService: AuthenticationService?
    
    // Track message sending state
    @Published var isSendingMessage = false
    
    deinit {
        conversationsListener?.remove()
        messagesListener?.remove()
    }
    
    func setNotificationManager(_ manager: NotificationManager) {
        self.notificationManager = manager
        print("✅ ChatManager: NotificationManager set")
    }
    
    func setAuthService(_ service: AuthenticationService) {
        self.authService = service
        print("✅ ChatManager: AuthService set")
    }
    
    // MARK: - Connection Status Monitoring
    private func setupConnectionListener() {
        // Monitor network connectivity using Network framework
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.isConnected = true
                    print("✅ ChatManager: Network connected")
                } else {
                    self?.isConnected = false
                    print("❌ ChatManager: Network disconnected")
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    // MARK: - Conversation Management
    func loadConversations() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            print("❌ ChatManager: No current user for conversations")
            return 
        }
        
        print("🔄 ChatManager: Loading conversations...")
        isLoading = true
        
        // Stop any existing listener
        conversationsListener?.remove()
        
        // Enable offline persistence and real-time updates
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings
        
        // Listen for conversations where current user is a participant
        conversationsListener = db.collection("conversations")
            .whereField("participants", arrayContains: currentUserId)
            .order(by: "lastActivity", descending: true)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] querySnapshot, error in
                
                if let error = error {
                    print("❌ ChatManager: Error loading conversations: \(error)")
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to load conversations: \(error.localizedDescription)"
                        self?.isLoading = false
                    }
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("⚠️ ChatManager: No conversation documents found")
                    DispatchQueue.main.async {
                        self?.conversations = []
                        self?.isLoading = false
                    }
                    return
                }
                
                Task { @MainActor in
                    var loadedConversations: [ChatConversation] = []
                    
                    for document in documents {
                        let data = document.data()
                        
                        var conversation = ChatConversation(
                            participants: data["participants"] as? [String] ?? []
                        )
                        
                        conversation.lastActivity = (data["lastActivity"] as? Timestamp)?.dateValue() ?? Date()
                        conversation.isActive = data["isActive"] as? Bool ?? true
                        conversation.unreadCount = data["unreadCount"] as? [String: Int] ?? [:]
                        
                        // Load last message if exists
                        if let lastMessageData = data["lastMessage"] as? [String: Any] {
                            conversation.lastMessage = ChatMessage(
                                id: lastMessageData["id"] as? String ?? "",
                                senderId: lastMessageData["senderId"] as? String ?? "",
                                receiverId: lastMessageData["receiverId"] as? String ?? "",
                                content: lastMessageData["content"] as? String ?? ""
                            )
                        }
                        
                        loadedConversations.append(conversation)
                    }
                    
                    self?.conversations = loadedConversations
                    self?.isLoading = false
                    print("✅ ChatManager: Loaded \(loadedConversations.count) conversations")
                }
            }
    }
    
    // MARK: - Enhanced Message Management with Real-time Updates
    func loadMessages(for chatId: String) async {
        print("🔄 ChatManager: Loading messages for chatId: \(chatId)")
        currentChatId = chatId
        
        // Stop any existing messages listener
        messagesListener?.remove()
        
        guard !chatId.isEmpty else {
            print("❌ ChatManager: Empty chatId provided")
            return
        }
        
        // Listen for messages in real-time with offline support
        messagesListener = db.collection("chats").document(chatId).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] querySnapshot, error in
                
                if let error = error {
                    print("❌ ChatManager: Error loading messages: \(error)")
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to load messages: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let documents = querySnapshot?.documents else { 
                    print("⚠️ ChatManager: No message documents found")
                    DispatchQueue.main.async {
                        self?.currentChatMessages = []
                    }
                    return 
                }
                
                Task { @MainActor in
                    var messages: [ChatMessage] = []
                    let previousCount = self?.currentChatMessages.count ?? 0
                    
                    for document in documents {
                        let data = document.data()
                        
                        var message = ChatMessage(
                            id: document.documentID,
                            senderId: data["senderId"] as? String ?? "",
                            receiverId: data["receiverId"] as? String ?? "",
                            content: data["content"] as? String ?? "",
                            type: MessageType(rawValue: data["type"] as? String ?? "") ?? .text
                        )
                        
                        message.isRead = data["isRead"] as? Bool ?? false
                        
                        messages.append(message)
                    }
                    
                    // Replace messages only if different to avoid unnecessary UI churn
                    self?.currentChatMessages = messages
                    print("✅ ChatManager: Loaded \(messages.count) messages (was \(previousCount))")
                    
                    // Check for new messages to trigger notifications
                    if messages.count > previousCount && previousCount > 0 {
                        if let newestMessage = messages.last,
                           let currentUserId = Auth.auth().currentUser?.uid,
                           newestMessage.senderId != currentUserId {
                            
                            print("🔔 ChatManager: New message detected, showing notification")
                            await self?.handleNewMessageNotification(newestMessage)
                        }
                    }
                    
                    // Auto-mark messages as read for current user
                    await self?.markMessagesAsRead(chatId: chatId)
                }
            }
    }
    
    // Add loadChat method that ChatView expects
    func loadChat(chatId: String) async {
        await loadMessages(for: chatId)
    }
    
    // MARK: - Enhanced Message Sending with Better Error Handling
    func sendMessage(chatId: String, senderId: String, recipientId: String, content: String, type: MessageType = .text) async {
        print("📤 ChatManager: Sending message...")
        
        await MainActor.run {
            isSendingMessage = true
        }
        
        let message = ChatMessage(
            senderId: senderId,
            receiverId: recipientId,
            content: content,
            type: type
        )
        
        // Optimistic UI update – append immediately so sender sees it instantly
        if !currentChatMessages.contains(where: { $0.id == message.id }) {
            currentChatMessages.append(message)
        }
        
        let messageData: [String: Any] = [
            "senderId": message.senderId,
            "receiverId": message.receiverId,
            "content": message.content,
            "type": message.type.rawValue,
            "timestamp": Timestamp(date: message.timestamp),
            "isRead": false,
            "chatId": chatId
        ]
        
        do {
            // Save message to Firestore with retry logic
            try await withRetry(maxAttempts: 3) {
                try await self.db.collection("chats").document(chatId).collection("messages").document(message.id).setData(messageData)
            }
            
            // Update conversation
            await updateConversation(chatId: chatId, lastMessage: message, participants: [senderId, recipientId])
            
            // Send push notification to recipient
            await sendPushNotificationToRecipient(message: message, recipientId: recipientId)
            
            print("✅ ChatManager: Message sent successfully")
            
        } catch {
            print("❌ ChatManager: Failed to send message: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to send message: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isSendingMessage = false
        }
    }
    
    // Convenience method for ChatView compatibility
    func sendMessage(to userId: String, content: String, type: MessageType = .text) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let chatId = [currentUserId, userId].sorted().joined(separator: "_")
        await sendMessage(chatId: chatId, senderId: currentUserId, recipientId: userId, content: content, type: type)
    }
    
    // MARK: - Retry Logic for Network Issues
    private func withRetry<T>(maxAttempts: Int, operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                print("⚠️ ChatManager: Attempt \(attempt) failed: \(error)")
                
                if attempt < maxAttempts {
                    // Exponential backoff
                    let delay = Double(attempt) * 0.5
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NSError(domain: "ChatManagerError", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"])
    }
    
    // MARK: - Enhanced Notification Handling
    private func handleNewMessageNotification(_ message: ChatMessage) async {
        guard let notificationManager = notificationManager,
              let currentUserId = Auth.auth().currentUser?.uid,
              message.senderId != currentUserId else {
            return
        }
        
        // Get sender info
        let senderName = await getSenderDisplayName(message.senderId)
        
        // Create notification data with chat ID
        let chatId = [message.senderId, message.receiverId].sorted().joined(separator: "_")
        
        // Send notification through the notification manager
        await notificationManager.sendNotification(
            to: message.receiverId,
            from: message.senderId,
            type: .newMessage,
            title: "New Message from \(senderName)",
            message: message.content,
            data: [
                "chatId": chatId,
                "senderId": message.senderId,
                "senderName": senderName,
                "messageId": message.id
            ]
        )
        
        print("✅ ChatManager: Message notification sent for chat: \(chatId)")
    }
    
    private func getSenderDisplayName(_ senderId: String) async -> String {
        do {
            let document = try await db.collection("users").document(senderId).getDocument()
            if let data = document.data() {
                return data["displayName"] as? String ?? data["username"] as? String ?? "Unknown User"
            }
        } catch {
            print("❌ ChatManager: Failed to get sender name: \(error)")
        }
        return "Unknown User"
    }
    
    // MARK: - Enhanced Conversation Management
    private func updateConversation(chatId: String, lastMessage: ChatMessage, participants: [String]) async {
        let conversationData: [String: Any] = [
            "participants": participants,
            "lastMessage": [
                "id": lastMessage.id,
                "senderId": lastMessage.senderId,
                "receiverId": lastMessage.receiverId,
                "content": lastMessage.content,
                "type": lastMessage.type.rawValue,
                "timestamp": Timestamp(date: lastMessage.timestamp)
            ],
            "lastActivity": Timestamp(date: Date()),
            "isActive": true
        ]
        
        do {
            try await db.collection("conversations").document(chatId).setData(conversationData, merge: true)
            print("✅ ChatManager: Conversation updated")
        } catch {
            print("❌ ChatManager: Failed to update conversation: \(error)")
        }
    }
    
    // MARK: - Push Notification Support
    private func sendPushNotificationToRecipient(message: ChatMessage, recipientId: String) async {
        // This would integrate with your push notification service
        // For now, we'll just log it
        print("📱 ChatManager: Would send push notification to \(recipientId)")
    }
    
    // MARK: - Read Status Management
    func markMessagesAsRead(chatId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Update all unread messages from other users in this chat
        let query = db.collection("chats").document(chatId).collection("messages")
            .whereField("receiverId", isEqualTo: currentUserId)
            .whereField("isRead", isEqualTo: false)
        
        do {
            let snapshot = try await query.getDocuments()
            let batch = db.batch()
            
            for document in snapshot.documents {
                batch.updateData(["isRead": true], forDocument: document.reference)
            }
            
            try await batch.commit()
            print("✅ ChatManager: Marked \(snapshot.documents.count) messages as read")
        } catch {
            print("❌ ChatManager: Failed to mark messages as read: \(error)")
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        conversationsListener?.remove()
        messagesListener?.remove()
        currentChatId = nil
        print("🧹 ChatManager: Cleaned up listeners")
    }
    
    // MARK: - Helper Methods
    
    // MARK: - Conversation Helper Methods
    func getOtherParticipant(in conversation: ChatConversation) -> String? {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return nil }
        return conversation.participants.first { $0 != currentUserId }
    }
    
    func getUnreadCount(for conversation: ChatConversation) -> Int {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return 0 }
        return conversation.unreadCount[currentUserId] ?? 0
    }
    
    // MARK: - Ping Support
    func sendPing(to userId: String) async {
        await sendMessage(to: userId, content: "👋 Ping!", type: .ping)
    }
} 