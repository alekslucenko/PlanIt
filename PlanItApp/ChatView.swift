import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Modern Luxurious Chat View
struct ChatView: View {
    let friendUser: AppUser
    @StateObject private var chatManager = ChatManager()
    @StateObject private var notificationManager = NotificationManager()
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var showingTypingIndicator = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var initializationError: String?
    @FocusState private var isMessageFieldFocused: Bool
    
    // Mute notifications state
    @State private var showMuteOptions = false
    @State private var inAppNotificationsMuted = false
    @State private var pushNotificationsMuted = false
    
    // Navigation control
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    
    // Connection status
    @State private var isInitialized = false
    
    private var chatId: String {
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            print("❌ ChatView: No current user ID available")
            return ""
        }
        let id = [currentUserId, friendUser.id].sorted().joined(separator: "_")
        print("💬 ChatView: Generated chatId: \(id)")
        return id
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            if let error = initializationError {
                errorStateView(error: error)
            } else if isLoading && !isInitialized {
                loadingStateView
            } else {
                mainChatContent
            }
            
            if showMuteOptions {
                muteOptionsOverlay
            }
            
            // Connection status indicator
            if !chatManager.isConnected {
                connectionStatusView
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            print("💬 ChatView appeared for friend: \(friendUser.displayName)")
            print("💬 Friend ID: \(friendUser.id)")
            print("💬 Current user: \(Auth.auth().currentUser?.uid ?? "No user")")
            
            // Inform notification manager that user is in chat view
            notificationManager.setInChatView(true, chatId: chatId)
            
            if !isInitialized {
                initializeChat()
            }
        }
        .onDisappear {
            print("💬 ChatView disappeared")
            
            // Inform notification manager that user left chat view
            notificationManager.setInChatView(false)
            
            // Mark messages as read when leaving chat
            if !chatId.isEmpty {
                Task {
                    await chatManager.markMessagesAsRead(chatId: chatId)
                }
            }
            removeKeyboardObservers()
        }
        .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
        .animation(.easeInOut(duration: 0.2), value: chatManager.isConnected)
    }
    
    // MARK: - View Components
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color.gray.opacity(0.9),
                Color.black.opacity(0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var connectionStatusView: some View {
        VStack {
            HStack {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
                Text("Connecting...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(.orange.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.top, 10)
            
            Spacer()
        }
    }
    
    private func errorStateView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Chat Error")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                initializeChat()
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(.blue)
            .foregroundColor(.white)
            .cornerRadius(25)
        }
    }
    
    private var loadingStateView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading chat with \(friendUser.displayName)...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var mainChatContent: some View {
        VStack(spacing: 0) {
            modernChatHeader
            messagesScrollView
        }
        // Pin the input bar to the bottom safe-area and lift it when the keyboard appears
        .safeAreaInset(edge: .bottom) {
            modernMessageInputBar
                .offset(y: -keyboardHeight)
        }
    }
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if chatManager.currentChatMessages.isEmpty && !isLoading {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "message.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("start_chatting".localized)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ForEach(chatManager.currentChatMessages) { message in
                            ModernChatMessageBubble(
                                message: message,
                                isCurrentUser: message.senderId == Auth.auth().currentUser?.uid,
                                friendUser: friendUser
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                        }
                    }
                    
                    if showingTypingIndicator {
                        TypingIndicatorView()
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    if chatManager.isSendingMessage {
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white.opacity(0.7))
                                Text("Sending...")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                        }
                        .padding(.horizontal, 20)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)
            }
            .refreshable {
                await refreshMessages()
            }
            .onChange(of: chatManager.currentChatMessages.count) { _, _ in
                if let lastMessage = chatManager.currentChatMessages.last {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onReceive(chatManager.$currentChatMessages) { newMessages in
                if !newMessages.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let lastMessage = chatManager.currentChatMessages.last {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
    

    
    private func refreshMessages() async {
        await chatManager.loadMessages(for: chatId)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.circle")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.4))
            
            Text("Start your conversation with \(friendUser.displayName)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
    }
    
    private var muteOptionsOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showMuteOptions = false
                    }
                }
            
            VStack(spacing: 20) {
                Text("Notification Settings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 16) {
                    notificationToggle(
                        title: "In-App Notifications",
                        subtitle: "Notifications shown within the app",
                        isOn: $inAppNotificationsMuted
                    )
                    
                    notificationToggle(
                        title: "Push Notifications",
                        subtitle: "Notifications when app is closed",
                        isOn: $pushNotificationsMuted
                    )
                }
                
                Button("Done") {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showMuteOptions = false
                    }
                    saveMuteSettings()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(.blue)
                .cornerRadius(25)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private func notificationToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .scaleEffect(0.8)
        }
    }
    
    // MARK: - Chat Initialization
    private func initializeChat() {
        print("🔄 ChatView: Initializing chat...")
        
        // Reset states
        initializationError = nil
        isLoading = true
        
        // Validate chat ID
        let currentChatId = chatId
        guard !currentChatId.isEmpty else {
            initializationError = "Unable to generate chat ID. Please check your authentication status."
            isLoading = false
            return
        }
        
        // Setup chat managers
        setupChatManagers()
        
        // Load chat data
        Task {
            do {
                print("💬 Loading chat with ID: \(currentChatId)")
                await chatManager.loadChat(chatId: currentChatId)
                
                await MainActor.run {
                    isLoading = false
                    isInitialized = true
                    print("✅ Chat initialized successfully")
                }
                
                // Setup keyboard observers after successful initialization
                setupKeyboardObservers()
                
                // Load mute settings
                loadMuteSettings()
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    initializationError = "Failed to load chat: \(error.localizedDescription)"
                    print("❌ Chat initialization failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Modern Chat Header with Mute Button
    private var modernChatHeader: some View {
        HStack(spacing: 16) {
            // Back Button
            Button(action: {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    dismiss()
                }
            }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Avatar + Name & Status
            HStack(spacing: 12) {
                ZStack {
                    AsyncImage(url: URL(string: friendUser.photoURL ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Text(friendUser.displayName.prefix(1))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                    
                    // Online Indicator
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.black, lineWidth: 1.5))
                        .offset(x: 16, y: 16)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(friendUser.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("Online")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green.opacity(0.9))
                    }
                }
            }
            
            Spacer()
            
            // Ping Button
            Button(action: sendPing) {
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.yellow)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .yellow.opacity(0.3), radius: 6, x: 0, y: 3)
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Mute Button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showMuteOptions = true
                }
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                Image(systemName: inAppNotificationsMuted || pushNotificationsMuted ? "bell.slash.fill" : "bell.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(inAppNotificationsMuted || pushNotificationsMuted ? .orange : .white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            .ultraThinMaterial.opacity(0.9)
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.white.opacity(0.1)),
            alignment: .bottom
        )
    }
    
    // MARK: - Modern Message Input Bar
    private var modernMessageInputBar: some View {
        VStack(spacing: 0) {
            // Gradient separator
            LinearGradient(
                colors: [.clear, .white.opacity(0.1), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            
            HStack(spacing: 12) {
                // Ping button
                Button(action: sendPing) {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                        .overlay(
                            Circle()
                                .stroke(.orange.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isMessageFieldFocused ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isMessageFieldFocused)
                
                // Message input field
                HStack(spacing: 12) {
                    TextField("type_message".localized, text: $messageText, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineLimit(1...6)
                        .focused($isMessageFieldFocused)
                        .onSubmit {
                            if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                sendMessage()
                            }
                        }
                    
                    if !messageText.isEmpty {
                        Button(action: clearMessage) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.blue)
                        .background(
                            Circle()
                                .fill(.white)
                                .frame(width: 40, height: 40)
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        .scaleEffect(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.8 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: messageText.isEmpty)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isSendingMessage)
                .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                .thinMaterial
                    .opacity(0.95)
            )
        }
    }
    
    // MARK: - Helper Methods
    private func setupChatManagers() {
        // Remove the guards that were causing the initial error
        print("💬 Setting up chat managers...")
        chatManager.setAuthService(authService)
        chatManager.setNotificationManager(notificationManager)
        print("✅ Chat managers setup complete")
    }
    
    private func loadMuteSettings() {
        // Load mute settings from UserDefaults
        let chatKey = "mute_\(chatId)"
        inAppNotificationsMuted = UserDefaults.standard.bool(forKey: "\(chatKey)_inapp")
        pushNotificationsMuted = UserDefaults.standard.bool(forKey: "\(chatKey)_push")
    }
    
    private func saveMuteSettings() {
        // Save mute settings to UserDefaults
        let chatKey = "mute_\(chatId)"
        UserDefaults.standard.set(inAppNotificationsMuted, forKey: "\(chatKey)_inapp")
        UserDefaults.standard.set(pushNotificationsMuted, forKey: "\(chatKey)_push")
        
        // Update notification manager with current settings
        notificationManager.setChatMuteSettings(
            chatId: chatId,
            inAppMuted: inAppNotificationsMuted,
            pushMuted: pushNotificationsMuted
        )
        
        print("💾 Saved mute settings for chat \(chatId): InApp=\(inAppNotificationsMuted), Push=\(pushNotificationsMuted)")
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let messageContent = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Clear input immediately for responsiveness
        messageText = ""
        
        // Show typing indicator briefly
        showingTypingIndicator = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingTypingIndicator = false
        }
        
        Task {
            await chatManager.sendMessage(
                chatId: chatId,
                senderId: currentUserId,
                recipientId: friendUser.id,
                content: messageContent,
                type: .text
            )
        }
    }
    
    private func sendPing() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            await chatManager.sendMessage(
                chatId: chatId,
                senderId: currentUserId,
                recipientId: friendUser.id,
                content: "👋 Ping!",
                type: .ping
            )
        }
    }
    
    private func clearMessage() {
        messageText = ""
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// MARK: - Modern Chat Message Bubble
struct ModernChatMessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    let friendUser: AppUser
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
                currentUserMessage
            } else {
                otherUserMessage
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var currentUserMessage: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                if message.type == .ping {
                    // Special ping message design
                    HStack(spacing: 8) {
                        Text("👋")
                            .font(.title2)
                        Text("Ping!")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
                } else {
                    Text(message.content)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                        )
                }
            }
            
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .padding(.trailing, 8)
        }
    }
    
    private var otherUserMessage: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if message.type == .ping {
                    // Special ping message design
                    HStack(spacing: 8) {
                        Text("👋")
                            .font(.title2)
                        Text("Ping!")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.gray.opacity(0.8), .gray.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                    )
                } else {
                    Text(message.content)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [.gray.opacity(0.8), .gray.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                        )
                }
            }
            
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 8)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Typing Indicator View
struct TypingIndicatorView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Typing")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(.white.opacity(0.7))
                        .frame(width: 4, height: 4)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Chat List View (for navigation from friends)
struct ChatListView: View {
    @StateObject private var chatManager = ChatManager()
    @StateObject private var notificationManager = NotificationManager()
    @EnvironmentObject var friendsManager: FriendsManager
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading conversations...")
                        .foregroundColor(.white)
                        .scaleEffect(1.2)
                } else if chatManager.conversations.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "message.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("No conversations yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Start chatting with your friends!")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Conversations list
                    List {
                        ForEach(chatManager.conversations) { conversation in
                            ChatConversationRow(
                                conversation: conversation,
                                chatManager: chatManager,
                                friendsManager: friendsManager
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            .background(
                LinearGradient(
                    colors: [.black, .gray.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                setupManagers()
                loadConversations()
            }
        }
    }
    
    private func setupManagers() {
        chatManager.setNotificationManager(notificationManager)
        friendsManager.setNotificationManager(notificationManager)
    }
    
    private func loadConversations() {
        Task {
            await chatManager.loadConversations()
            isLoading = false
        }
    }
}

// MARK: - Chat Conversation Row
struct ChatConversationRow: View {
    let conversation: ChatConversation
    let chatManager: ChatManager
    let friendsManager: FriendsManager
    
    @State private var friendUser: AppUser?
    
    var body: some View {
        HStack(spacing: 12) {
            // Friend Avatar
            AsyncImage(url: URL(string: friendUser?.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 50, height: 50)
            .cornerRadius(25)
            .background(.ultraThinMaterial)
            .cornerRadius(25)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(friendUser?.displayName ?? "Unknown")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let lastMessage = conversation.lastMessage {
                        Text(formatTime(lastMessage.timestamp))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                HStack {
                    Text(conversation.lastMessage?.content ?? "No messages")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    let unreadCount = chatManager.getUnreadCount(for: conversation)
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(.red)
                            .cornerRadius(10)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .onTapGesture {
            // Navigate to chat
            if friendUser != nil {
                // This would navigate to ChatView
            }
        }
        .onAppear {
            loadFriendUser()
        }
    }
    
    private func loadFriendUser() {
        // Get the other participant in the conversation
        if let otherUserId = chatManager.getOtherParticipant(in: conversation) {
            // Find friend in friends list
            friendUser = friendsManager.friends.first { $0.id == otherUserId }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
} 