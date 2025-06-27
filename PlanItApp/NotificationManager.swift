import Foundation
import UserNotifications
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - Global Helper Functions
func markNotificationAsRead(_ notificationId: String) async {
    await NotificationManager.shared.markNotificationAsRead(notificationId)
}

// MARK: - NotificationType
enum NotificationType: String, CaseIterable, Codable {
    case newMessage = "new_message"
    case ping = "ping"
    case friendRequest = "friend_request"
    case friendRequestAccepted = "friend_request_accepted"
    case newRecommendation = "new_recommendation"
    case systemAlert = "system_alert"
    
    var displayTitle: String {
        switch self {
        case .newMessage: return "new_message".localized
        case .ping: return "ping".localized
        case .friendRequest: return "friend_request".localized
        case .friendRequestAccepted: return "friend_request_accepted".localized
        case .newRecommendation: return "new_recommendation".localized
        case .systemAlert: return "system_alert".localized
        }
    }
}

// MARK: - Enhanced Notification Manager with Anti-Spam Protection
@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var hasPermission = false
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var showInAppNotification: Bool = false
    @Published var currentInAppNotification: AppNotification?
    @Published var isInChatView = false
    @Published var currentChatId: String?
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var hasLocationPermission: Bool = false
    @Published var isListeningForNotifications: Bool = false
    @Published var isShowingNotification: Bool = false
    @Published var unreadNotifications: [AppNotification] = []
    @Published var notificationHistory: [AppNotification] = []
    
    private let db = Firestore.firestore()
    private var notificationListener: ListenerRegistration?
    private var audioPlayer: AVAudioPlayer?
    
    // Anti-spam protection
    private var processedNotificationIds: Set<String> = []
    private var lastNotificationTime: [String: Date] = [:]
    private var notificationCooldown: TimeInterval = 1.0 // Prevent same type notifications within 1 second
    
    // Notification queue for managing multiple notifications
    private var notificationQueue: [AppNotification] = []
    private var isProcessingQueue = false
    
    // Mute settings for different chats
    private var chatMuteSettings: [String: (inApp: Bool, push: Bool)] = [:]
    
    // Auth service reference
    private var authService: AuthenticationService?
    
    override init() {
        super.init()
        checkNotificationPermission()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
        requestNotificationPermission()
        loadMuteSettings()
    }
    
    deinit {
        notificationListener?.remove()
    }
    
    // MARK: - Improved Listener Management
    func startListeningForNotifications(userId: String) {
        // Prevent multiple listeners
        if isListeningForNotifications {
            print("⚠️ NotificationManager: Already listening for notifications")
            return
        }
        
        print("🔄 NotificationManager: Starting notification listener for user: \(userId)")
        
        // Remove existing listener if any
        notificationListener?.remove()
        
        let query = db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
        
        notificationListener = query.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("❌ NotificationManager: Error listening for notifications: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            Task { @MainActor in
                await self?.processNotifications(documents: documents)
            }
        }
        
        isListeningForNotifications = true
        print("✅ NotificationManager: Listener started successfully")
    }
    
    private func processNotifications(documents: [QueryDocumentSnapshot]) async {
        var newNotifications: [AppNotification] = []
        var foundNewNotification = false
        
        for document in documents {
            let data = document.data()
            
            // Skip if already processed
            if processedNotificationIds.contains(document.documentID) {
                continue
            }
            
            let notification = AppNotification(
                userId: data["userId"] as? String ?? "",
                type: data["type"] as? String ?? "",
                title: data["title"] as? String ?? "",
                message: data["message"] as? String ?? "",
                timestamp: data["timestamp"] as? Timestamp ?? Timestamp(),
                senderId: data["senderId"] as? String,
                senderName: data["senderName"] as? String,
                data: data["data"] as? [String: String]
            )
            
            // Set the document ID
            var notificationWithId = notification
            notificationWithId.id = document.documentID
            
            newNotifications.append(notificationWithId)
            
            // Check if this is actually new (within last 30 seconds)
            let notificationAge = Date().timeIntervalSince(notification.timestamp.dateValue())
            if notificationAge < 30 {
                foundNewNotification = true
                
                // Add to processed set to prevent duplicates
                processedNotificationIds.insert(document.documentID)
                
                // Show in-app notification for truly new notifications
                await showInAppNotificationIfAppropriate(notificationWithId)
            } else {
                // Mark older notifications as processed without showing
                processedNotificationIds.insert(document.documentID)
            }
        }
        
        // Update the notifications array
        notifications = newNotifications
        unreadCount = newNotifications.count
        
        // Update notification history (combining new and existing)
        var updatedHistory = newNotifications
        for existingNotification in notificationHistory {
            if !updatedHistory.contains(where: { $0.id == existingNotification.id }) {
                updatedHistory.append(existingNotification)
            }
        }
        notificationHistory = Array(updatedHistory.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }.prefix(100))
        
        if foundNewNotification {
            print("✅ NotificationManager: Processed \(newNotifications.count) notifications, found \(foundNewNotification ? "new" : "no new") notifications")
        }
    }
    
    // MARK: - Smart In-App Notification Display
    private func showInAppNotificationIfAppropriate(_ notification: AppNotification) async {
        // Anti-spam check
        if let lastTime = lastNotificationTime[notification.type],
           Date().timeIntervalSince(lastTime) < notificationCooldown {
            print("🚫 NotificationManager: Notification blocked due to cooldown")
            return
        }
        
        lastNotificationTime[notification.type] = Date()
        
        // Check if user is in the relevant chat
        if let chatId = notification.data?["chatId"],
           chatId == currentChatId && isInChatView {
            print("🤐 NotificationManager: User is in the same chat, skipping notification")
            return
        }
        
        // Check mute settings
        if let chatId = notification.data?["chatId"],
           isChatMuted(chatId: chatId, type: .inApp) {
            print("🔕 NotificationManager: In-app notification muted for chat")
            return
        }
        
        // Add to queue or display immediately
        if isShowingNotification || isProcessingQueue {
            notificationQueue.append(notification)
            print("➕ NotificationManager: Added to queue (size: \(notificationQueue.count))")
        } else {
            await displayNotification(notification)
        }
    }
    
    private func displayNotification(_ notification: AppNotification) async {
        isShowingNotification = true
        currentInAppNotification = notification
        showInAppNotification = true
        
        // Enhanced feedback
        playEnhancedNotificationFeedback(for: notification.type)
        
        print("✅ NotificationManager: Displaying notification: \(notification.title)")
        
        // Auto-dismiss after appropriate time
        let dismissTime: TimeInterval = notification.type == "newMessage" ? 8.0 : 5.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissTime) {
            Task { @MainActor in
                await self.processNextNotification()
            }
        }
    }
    
    // MARK: - Queue Management
    func hideInAppNotification() {
        showInAppNotification = false
        isShowingNotification = false
        currentInAppNotification = nil
        
        // Process next notification in queue
        Task {
            await processNextNotification()
        }
    }
    
    private func processNextNotification() async {
        guard !notificationQueue.isEmpty else {
            isProcessingQueue = false
            return
        }
        
        isProcessingQueue = true
        let nextNotification = notificationQueue.removeFirst()
        
        // Small delay for smooth transitions
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        await displayNotification(nextNotification)
        isProcessingQueue = false
    }
    
    // MARK: - Chat State Management
    func setInChatView(_ inChat: Bool, chatId: String? = nil) {
        isInChatView = inChat
        currentChatId = chatId
        print("📱 NotificationManager: Chat state - inChat: \(inChat), chatId: \(chatId ?? "none")")
        
        if inChat, let chatId = chatId {
            // Mark any pending notifications for this chat as processed
            markChatNotificationsAsProcessed(chatId: chatId)
        }
    }
    
    private func markChatNotificationsAsProcessed(chatId: String) {
        for notification in notificationQueue {
            if notification.data?["chatId"] == chatId {
                if let id = notification.id {
                    processedNotificationIds.insert(id)
                }
            }
        }
        
        // Remove chat notifications from queue
        notificationQueue.removeAll { notification in
            notification.data?["chatId"] == chatId
        }
    }
    
    // MARK: - Enhanced Notification Categories Setup
    private func setupNotificationCategories() {
        // Friend Request Category
        let acceptAction = UNNotificationAction(
            identifier: "ACCEPT_FRIEND",
            title: "accept".localized,
            options: [.foreground]
        )
        
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_FRIEND",
            title: "decline".localized, 
            options: [.destructive]
        )
        
        let friendRequestCategory = UNNotificationCategory(
            identifier: "FRIEND_REQUEST",
            actions: [acceptAction, declineAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Message Category
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_MESSAGE",
            title: "reply".localized,
            options: [.foreground],
            textInputButtonTitle: "send".localized,
            textInputPlaceholder: "type_message".localized
        )
        
        let viewChatAction = UNNotificationAction(
            identifier: "VIEW_CHAT",
            title: "view_chat".localized,
            options: [.foreground]
        )
        
        let messageCategory = UNNotificationCategory(
            identifier: "MESSAGE",
            actions: [replyAction, viewChatAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            friendRequestCategory,
            messageCategory
        ])
        
        print("✅ Enhanced notification categories configured")
    }
    
    // MARK: - Mute Settings Management
    private func loadMuteSettings() {
        // Load existing mute settings from UserDefaults
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("mute_") && key.hasSuffix("_inapp") {
                let chatId = String(key.dropFirst(5).dropLast(6)) // Remove "mute_" and "_inapp"
                let inAppMuted = UserDefaults.standard.bool(forKey: key)
                let pushMuted = UserDefaults.standard.bool(forKey: "mute_\(chatId)_push")
                chatMuteSettings[chatId] = (inApp: inAppMuted, push: pushMuted)
            }
        }
    }
    
    func setChatMuteSettings(chatId: String, inAppMuted: Bool, pushMuted: Bool) {
        chatMuteSettings[chatId] = (inApp: inAppMuted, push: pushMuted)
        
        UserDefaults.standard.set(inAppMuted, forKey: "mute_\(chatId)_inapp")
        UserDefaults.standard.set(pushMuted, forKey: "mute_\(chatId)_push")
        
        print("🔕 Updated mute settings for chat \(chatId): InApp=\(inAppMuted), Push=\(pushMuted)")
    }
    
    func isChatMuted(chatId: String, type: MuteType) -> Bool {
        if chatMuteSettings[chatId] == nil {
            let inAppMuted = UserDefaults.standard.bool(forKey: "mute_\(chatId)_inapp")
            let pushMuted = UserDefaults.standard.bool(forKey: "mute_\(chatId)_push")
            chatMuteSettings[chatId] = (inApp: inAppMuted, push: pushMuted)
        }
        
        guard let settings = chatMuteSettings[chatId] else { return false }
        switch type {
        case .inApp:
            return settings.inApp
        case .push:
            return settings.push
        }
    }
    
    enum MuteType {
        case inApp, push
    }
    
    // MARK: - Enhanced Notification Feedback
    private func playEnhancedNotificationFeedback(for typeString: String) {
        guard let type = NotificationType(rawValue: typeString) else {
            AudioServicesPlaySystemSound(1016)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            return
        }
        
        switch type {
        case .newMessage:
            AudioServicesPlaySystemSound(1003) // More noticeable for messages
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
        case .ping:
            AudioServicesPlaySystemSound(1013)
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
        case .friendRequest:
            AudioServicesPlaySystemSound(1016)
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
        case .friendRequestAccepted:
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.success)
            
        default:
            AudioServicesPlaySystemSound(1016)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    // MARK: - Permission Management
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasPermission = settings.authorizationStatus == .authorized
                self.notificationPermissionStatus = settings.authorizationStatus
                print("📱 NotificationManager: Permission status: \(settings.authorizationStatus.rawValue)")
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.hasPermission = granted
                if granted {
                    print("✅ NotificationManager: Permission granted")
                } else {
                    print("❌ NotificationManager: Permission denied")
                    if let error = error {
                        print("❌ Error: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Notification Creation and Management
    func sendNotification(to userId: String, from fromUserId: String, type: NotificationType, title: String, message: String, data: [String: String] = [:]) async {
        let notification = AppNotification(
            userId: userId,
            type: type.rawValue,
            title: title,
            message: message,
            timestamp: Timestamp(date: Date()),
            senderId: fromUserId,
            senderName: data["senderName"],
            data: data
        )
        
        await saveNotificationToFirestore(notification)
    }
    
    private func saveNotificationToFirestore(_ notification: AppNotification) async {
        do {
            let notificationData: [String: Any] = [
                "userId": notification.userId,
                "type": notification.type,
                "title": notification.title,
                "message": notification.message,
                "timestamp": notification.timestamp,
                "isRead": notification.isRead,
                "senderId": notification.senderId as Any,
                "senderName": notification.senderName as Any,
                "data": notification.data as Any
            ]
            
            try await db.collection("notifications").addDocument(data: notificationData)
            print("✅ Notification saved to Firestore")
        } catch {
            print("❌ Error saving notification to Firestore: \(error)")
        }
    }
    
    // MARK: - Cleanup Methods
    func stopListeningForNotifications() {
        notificationListener?.remove()
        isListeningForNotifications = false
        print("🛑 NotificationManager: Stopped listening for notifications")
    }
    
    func clearProcessedNotifications() {
        processedNotificationIds.removeAll()
        lastNotificationTime.removeAll()
        print("🧹 NotificationManager: Cleared processed notifications cache")
    }
    
    // MARK: - Navigation Handling
    func handleNotificationTap(_ notification: AppNotification) -> (screen: String, data: [String: String]) {
        switch notification.type {
        case NotificationType.newMessage.rawValue:
            return ("chat", notification.data ?? [:])
        case NotificationType.friendRequest.rawValue:
            return ("friends", notification.data ?? [:])
        case NotificationType.friendRequestAccepted.rawValue:
            return ("friends", notification.data ?? [:])
        default:
            return ("main", [:])
        }
    }
    
    // MARK: - Notification History Management
    func markAllAsRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        for i in notificationHistory.indices {
            notificationHistory[i].isRead = true
        }
        unreadCount = 0
        
        // Update in Firestore
        Task {
            await markAllNotificationsAsReadInFirestore()
        }
    }
    
    func clearAllNotifications() {
        notificationHistory.removeAll()
        notifications.removeAll()
        unreadCount = 0
        
        // Update in Firestore
        Task {
            await clearAllNotificationsInFirestore()
        }
    }
    
    func markNotificationAsRead(_ notificationId: String) async {
        // Update local arrays
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index].isRead = true
        }
        if let index = notificationHistory.firstIndex(where: { $0.id == notificationId }) {
            notificationHistory[index].isRead = true
        }
        
        // Recalculate unread count
        unreadCount = notifications.filter { !$0.isRead }.count
        
        // Update in Firestore
        do {
            try await db.collection("notifications").document(notificationId).updateData([
                "isRead": true
            ])
            print("✅ Marked notification as read: \(notificationId)")
        } catch {
            print("❌ Error marking notification as read: \(error)")
        }
    }
    
    private func markAllNotificationsAsReadInFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("notifications")
                .whereField("userId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .getDocuments()
            
            let batch = db.batch()
            for document in snapshot.documents {
                batch.updateData(["isRead": true], forDocument: document.reference)
            }
            
            try await batch.commit()
            print("✅ Marked all notifications as read in Firestore")
        } catch {
            print("❌ Error marking all notifications as read: \(error)")
        }
    }
    
    private func clearAllNotificationsInFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("notifications")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            
            try await batch.commit()
            print("✅ Cleared all notifications from Firestore")
        } catch {
            print("❌ Error clearing notifications: \(error)")
        }
    }
    
    // MARK: - Service Configuration
    func setAuthService(_ authService: AuthenticationService) {
        self.authService = authService
        print("✅ NotificationManager: AuthService configured")
    }
}

// MARK: - Enhanced UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground for real-time updates
        completionHandler([.banner, .badge, .sound])
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification tap
        if let notificationId = userInfo["notificationId"] as? String {
            Task {
                await markNotificationAsRead(notificationId)
            }
        }
        
        // Handle different notification types and actions
        if let typeString = userInfo["type"] as? String,
           let type = NotificationType(rawValue: typeString) {
            
            switch response.actionIdentifier {
            case "ACCEPT_FRIEND":
                // Handle friend request acceptance from notification
                if let fromUserId = userInfo["fromUserId"] as? String {
                    Task { @MainActor in
                        await self.handleFriendRequestAction(action: "ACCEPT_FRIEND", userInfo: userInfo)
                    }
                }
                
            case "DECLINE_FRIEND":
                // Handle friend request decline from notification
                if let fromUserId = userInfo["fromUserId"] as? String {
                    Task { @MainActor in
                        await self.handleFriendRequestAction(action: "DECLINE_FRIEND", userInfo: userInfo)
                    }
                }
                
            case "OPEN_CHAT":
                // Handle open chat action
                if let fromUserId = userInfo["fromUserId"] as? String {
                    Task { @MainActor in
                        await self.handleOpenChatAction(userInfo: userInfo)
                    }
                }
                
            case "REPLY_MESSAGE":
                // Handle reply to message
                if let textResponse = response as? UNTextInputNotificationResponse,
                   let chatId = userInfo["chatId"] as? String,
                   let fromUserId = userInfo["fromUserId"] as? String {
                    Task { @MainActor in
                        await self.handleReplyMessage(textResponse: textResponse, userInfo: userInfo)
                    }
                }
                
            case "MARK_READ":
                // Handle mark as read
                if let chatId = userInfo["chatId"] as? String {
                    Task { @MainActor in
                        await self.handleMarkMessageRead(userInfo: userInfo)
                    }
                }
                
            case UNNotificationDefaultActionIdentifier:
                // Handle normal notification tap (open app)
                Task { @MainActor in
                    await self.handleNotificationTap(type: type, userInfo: userInfo)
                }
                
            default:
                break
            }
        }
        
        completionHandler()
    }
    
    // MARK: - Action Handler Methods
    
    func handleFriendRequestAction(action: String, userInfo: [AnyHashable: Any]) async {
        guard let fromUserId = userInfo["fromUserId"] as? String,
              let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ Missing user information for friend request action")
            return
        }
        
        switch action {
        case "ACCEPT_FRIEND":
            // Accept friend request logic
            do {
                // Add to friends collections for both users
                try await db.collection("users").document(currentUserId).updateData([
                    "friends": FieldValue.arrayUnion([fromUserId]),
                    "receivedFriendRequests": FieldValue.arrayRemove([fromUserId])
                ])
                
                try await db.collection("users").document(fromUserId).updateData([
                    "friends": FieldValue.arrayUnion([currentUserId]),
                    "sentFriendRequests": FieldValue.arrayRemove([currentUserId])
                ])
                
                print("✅ Friend request accepted")
            } catch {
                print("❌ Error accepting friend request: \(error)")
            }
            
        case "DECLINE_FRIEND":
            // Decline friend request logic
            do {
                try await db.collection("users").document(currentUserId).updateData([
                    "receivedFriendRequests": FieldValue.arrayRemove([fromUserId])
                ])
                
                try await db.collection("users").document(fromUserId).updateData([
                    "sentFriendRequests": FieldValue.arrayRemove([currentUserId])
                ])
                
                print("✅ Friend request declined")
            } catch {
                print("❌ Error declining friend request: \(error)")
            }
        default:
            break
        }
    }
    
    func handleOpenChatAction(userInfo: [AnyHashable: Any]) async {
        guard let fromUserId = userInfo["fromUserId"] as? String else {
            print("❌ Missing fromUserId for open chat action")
            return
        }
        
        // Navigate to chat - this would typically be handled by the main app
        print("📱 Opening chat with user: \(fromUserId)")
        // Post notification to navigate to chat
        NotificationCenter.default.post(name: Notification.Name("OpenChat"), object: fromUserId)
    }
    
    func handleReplyMessage(textResponse: UNTextInputNotificationResponse, userInfo: [AnyHashable: Any]) async {
        guard let chatId = userInfo["chatId"] as? String,
              let receiverId = userInfo["fromUserId"] as? String,
              let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ Missing information for reply message")
            return
        }
        
        let messageText = textResponse.userText
        let message = ChatMessage(
            senderId: currentUserId,
            receiverId: receiverId,
            content: messageText,
            type: .text
        )
        
        do {
            // Save message to Firestore
            try await db.collection("messages").addDocument(data: [
                "id": message.id,
                "senderId": message.senderId,
                "receiverId": message.receiverId,
                "content": message.content,
                "type": message.type.rawValue,
                "timestamp": message.timestamp,
                "isRead": message.isRead,
                "chatId": message.chatId
            ])
            
            print("✅ Reply message sent")
        } catch {
            print("❌ Error sending reply message: \(error)")
        }
    }
    
    func handleMarkMessageRead(userInfo: [AnyHashable: Any]) async {
        guard let chatId = userInfo["chatId"] as? String,
              let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ Missing information for mark message read")
            return
        }
        
        do {
            // Mark all messages in chat as read
            let messagesRef = db.collection("messages")
                .whereField("chatId", isEqualTo: chatId)
                .whereField("receiverId", isEqualTo: currentUserId)
                .whereField("isRead", isEqualTo: false)
            
            let snapshot = try await messagesRef.getDocuments()
            
            for document in snapshot.documents {
                try await document.reference.updateData(["isRead": true])
            }
            
            print("✅ Messages marked as read for chat: \(chatId)")
        } catch {
            print("❌ Error marking messages as read: \(error)")
        }
    }
    
    func handleNotificationTap(type: NotificationType, userInfo: [AnyHashable: Any]) async {
        // Handle navigation based on notification type
        switch type {
        case .newMessage:
            if let fromUserId = userInfo["fromUserId"] as? String {
                NotificationCenter.default.post(name: Notification.Name("OpenChat"), object: fromUserId)
            }
        case .friendRequest:
            NotificationCenter.default.post(name: Notification.Name("OpenFriends"), object: nil)
        case .friendRequestAccepted:
            NotificationCenter.default.post(name: Notification.Name("OpenFriends"), object: nil)
        default:
            NotificationCenter.default.post(name: Notification.Name("OpenMain"), object: nil)
        }
    }
}

 