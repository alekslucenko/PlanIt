import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Enhanced Modern Friends View with Monotone Minimalism
struct FriendsView: View {
    @StateObject private var friendsManager = FriendsManager()
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var selectedTab: Int = 0
    @State private var searchText = ""
    @State private var showingAddFriend = false
    @State private var showingRemoveConfirmation = false
    @State private var friendToRemove: AppUser?
    @State private var selectedFriend: AppUser?
    @State private var chatFriend: AppUser?
    @State private var showingNotificationHistory = false
    
    // Animation states
    @State private var hasAppeared = false
    @State private var refreshing = false
    @State private var showCopiedAnimation = false
    
    var body: some View {
        ZStack {
            // Minimalist background with subtle gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Clean, minimal header
                modernMinimalHeader
                
                // Elegant tab switcher
                modernTabSwitcher
                
                // Content with smooth transitions
                TabView(selection: $selectedTab) {
                    // Friends List
                    modernFriendsList
                        .tag(0)
                    
                    // Friend Requests
                    modernFriendRequestsList
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
            }
            
            // Floating notification overlay
            if notificationManager.showInAppNotification, 
               let notification = notificationManager.currentInAppNotification {
                VStack {
                    notificationBanner(notification)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: notificationManager.showInAppNotification)
                    
                    Spacer()
                }
                .zIndex(1000)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView(friendsManager: friendsManager)
                .environmentObject(authService)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNotificationHistory) {
            NotificationHistoryView(notificationManager: notificationManager)
        }
        .fullScreenCover(item: $chatFriend) { friend in
            ChatView(friendUser: friend)
                .environmentObject(authService)
        }
        .alert("Remove Friend", isPresented: $showingRemoveConfirmation, presenting: friendToRemove) { friend in
            Button("Remove", role: .destructive) {
                Task {
                    await friendsManager.removeFriend(friend)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { friend in
            Text("Are you sure you want to remove \(friend.displayName) from your friends list?")
        }
    }
    
    // MARK: - Modern Minimal Header
    private var modernMinimalHeader: some View {
        VStack(spacing: 16) {
            // Header with horizontal layout
            HStack(alignment: .center, spacing: 16) {
                // User avatar section
                if let appUser = authService.currentAppUser {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(.systemBlue), Color(.systemIndigo)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(appUser.displayName.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                
                // Title and status in horizontal layout
                VStack(alignment: .leading, spacing: 2) {
                    Text("Friends")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Horizontal status layout with proper spacing
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        
                        Text("\(friendsManager.friends.count) friends")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        if friendsManager.friendRequests.count > 0 {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 3, height: 3)
                            
                            Text("\(friendsManager.friendRequests.count) requests")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons in horizontal layout
                HStack(spacing: 12) {
                    // Notifications button
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showingNotificationHistory = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "bell")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if notificationManager.unreadCount > 0 {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Text("\(min(notificationManager.unreadCount, 99))")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 12, y: -12)
                            }
                        }
                    }
                    .scaleEffect(hasAppeared ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
                    
                    // Add friend button
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showingAddFriend = true
                    }) {
                        Circle()
                            .fill(Color(.systemBlue))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .scaleEffect(hasAppeared ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .opacity(hasAppeared ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.1), value: hasAppeared)
    }
    
    // MARK: - Modern Tab Switcher
    private var modernTabSwitcher: some View {
        HStack(spacing: 0) {
            // Friends Tab
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedTab = 0
                }
            }) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == 0 ? .primary : .secondary)
                        
                        Text("Friends")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == 0 ? .primary : .secondary)
                    }
                    
                    Rectangle()
                        .fill(selectedTab == 0 ? Color(.systemBlue) : Color.clear)
                        .frame(height: 2)
                        .cornerRadius(1)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Friend Requests Tab
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedTab = 1
                }
            }) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ZStack {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedTab == 1 ? .primary : .secondary)
                            
                            if friendsManager.friendRequests.count > 0 {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Text("\(friendsManager.friendRequests.count)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 10, y: -8)
                            }
                        }
                        
                        Text("Requests")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == 1 ? .primary : .secondary)
                    }
                    
                    Rectangle()
                        .fill(selectedTab == 1 ? Color(.systemBlue) : Color.clear)
                        .frame(height: 2)
                        .cornerRadius(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .opacity(hasAppeared ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.2), value: hasAppeared)
    }
    
    // MARK: - Modern Friends List
    private var modernFriendsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if refreshing {
                    ForEach(0..<3) { _ in
                        MinimalistFriendRowSkeleton()
                    }
                } else {
                    ForEach(friendsManager.friends) { friend in
                        MinimalistFriendRow(
                            friend: friend,
                            onChatTapped: { selectedFriend in
                                chatFriend = selectedFriend
                            },
                            onPingTapped: { friend in
                                // Add ping functionality here
                            },
                            onRemoveTapped: { friend in
                                friendToRemove = friend
                                showingRemoveConfirmation = true
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                
                if friendsManager.friends.isEmpty && !friendsManager.isLoading {
                    MinimalistEmptyState(
                        title: "No friends yet",
                        subtitle: "Add friends to start connecting",
                        actionTitle: "Add Friend",
                        action: { showingAddFriend = true }
                    )
                    .padding(.top, 60)
                }
                
                if friendsManager.isLoading {
                    ForEach(0..<3) { _ in
                        MinimalistFriendRowSkeleton()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .refreshable {
            await refreshFriends()
        }
    }
    
    // MARK: - Modern Friend Requests List
    private var modernFriendRequestsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(friendsManager.friendRequests) { request in
                    MinimalistFriendRequestRow(
                        request: request,
                        onAccept: { request in
                            Task {
                                await friendsManager.acceptFriendRequest(request)
                            }
                        },
                        onDecline: { request in
                            Task {
                                await friendsManager.declineFriendRequest(request)
                            }
                        }
                    )
                }
                
                if friendsManager.friendRequests.isEmpty {
                    MinimalistEmptyState(
                        title: "No friend requests",
                        subtitle: "New requests will appear here",
                        actionTitle: nil,
                        action: nil
                    )
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Helper Functions
    private func refreshFriends() async {
        refreshing = true
        await friendsManager.loadFriends()
        refreshing = false
    }
    
    private func notificationBanner(_ notification: AppNotification) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemBlue))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(notification.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .onTapGesture {
            handleNotificationTap(notification)
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        notificationManager.hideInAppNotification()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        switch notification.type {
        case NotificationType.friendRequest.rawValue:
            selectedTab = 1
        case NotificationType.friendRequestAccepted.rawValue:
            selectedTab = 0
        case NotificationType.newMessage.rawValue:
            if let senderId = notification.senderId,
               let friend = friendsManager.friends.first(where: { $0.id == senderId }) {
                selectedFriend = friend
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    chatFriend = friend
                }
            }
        default:
            break
        }
    }
}

// MARK: - Modern Friend Row Component with Enhanced Animations
struct ModernFriendRow: View {
    let friend: AppUser
    let onChatTapped: (AppUser) -> Void
    let onPingTapped: (AppUser) -> Void
    let onRemoveTapped: (AppUser) -> Void
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingActionSheet = false
    @State private var isPressed = false
    
    // Computed property to determine online status
    private var isOnline: Bool {
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        return friend.lastActiveAt > fiveMinutesAgo
    }
    
    var body: some View {
        HStack(spacing: 16) {
            profileAvatar
            friendInfo
            Spacer()
            actionButtons
        }
        .padding(20)
        .background(cardBackground)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {
            // Long press action
        }
        .confirmationDialog("Friend Options", isPresented: $showingActionSheet) {
            Button("Remove Friend", role: .destructive) {
                onRemoveTapped(friend)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("What would you like to do with \(friend.displayName)?")
        }
        .alert("Action", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private var profileAvatar: some View {
        ZStack {
            AsyncImage(url: URL(string: friend.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
                        Text(friend.displayName.prefix(1))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            
                            // Online status
                if isOnline {
                    Circle()
                        .fill(.green)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(.black, lineWidth: 2)
                        )
                        .offset(x: 20, y: 20)
                }
        }
    }
    
    private var friendInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(friend.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text("#\(friend.userTag)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            HStack(spacing: 4) {
                Circle()
                    .fill(isOnline ? .green : .gray)
                    .frame(width: 6, height: 6)
                
                Text(isOnline ? "Online" : "Offline")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            pingButton
            chatButton
            moreButton
        }
    }
    
    private var pingButton: some View {
        Button(action: {
            onPingTapped(friend)
        }) {
            Image(systemName: "bell.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.orange)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 3)
                )
                .overlay(
                    Circle()
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var chatButton: some View {
        Button(action: {
            onChatTapped(friend)
        }) {
            Image(systemName: "message.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                )
                .overlay(
                    Circle()
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var moreButton: some View {
        Button(action: {
            showingActionSheet = true
        }) {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Friend Row Skeleton Loading
struct FriendRowSkeleton: View {
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar skeleton
            Circle()
                .fill(.gray.opacity(0.3))
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.1), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset)
                        .clipped()
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Name skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.3))
                    .frame(width: 120, height: 16)
                
                // Username skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.2))
                    .frame(width: 80, height: 12)
            }
            
            Spacer()
            
            // Action buttons skeleton
            HStack(spacing: 12) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(.gray.opacity(0.2))
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
    }
}

// MARK: - Enhanced Friend Request Row Component with Real-time Updates
struct FriendRequestRow: View {
    let request: FriendRequest
    let friendsManager: FriendsManager
    @State private var isProcessing = false
    @State private var showAcceptAnimation = false
    @State private var showDeclineAnimation = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile image placeholder with smooth animation
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange.opacity(0.8), .orange.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    Text(request.fromUserName.prefix(1))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                )
                .scaleEffect(isProcessing ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isProcessing)
            
            // Request info with enhanced typography
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Friend Request")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        Text(request.fullFromUsername)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(timeAgoString(from: request.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Action buttons (horizontally sized, not vertically stretched)
            if request.status == .pending && !isProcessing {
                HStack(spacing: 10) {
                    // Accept Button
                    Button(action: {
                        acceptRequest()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Accept")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: .green.opacity(0.3), radius: 6, x: 0, y: 3)
                        .scaleEffect(showAcceptAnimation ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: showAcceptAnimation)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onTapGesture {
                        showAcceptAnimation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showAcceptAnimation = false
                        }
                    }
                    
                    // Decline Button
                    Button(action: {
                        declineRequest()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Decline")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.red, .red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: .red.opacity(0.3), radius: 6, x: 0, y: 3)
                        .scaleEffect(showDeclineAnimation ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: showDeclineAnimation)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onTapGesture {
                        showDeclineAnimation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showDeclineAnimation = false
                        }
                    }
                }
            } else if isProcessing {
                // Processing state with smooth animation
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.blue)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func acceptRequest() {
        isProcessing = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        Task {
            await friendsManager.acceptFriendRequest(request)
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func declineRequest() {
        isProcessing = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        Task {
            await friendsManager.declineFriendRequest(request)
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

// MARK: - Notification History View
struct NotificationHistoryView: View {
    @ObservedObject var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss
    @State private var hasAppeared = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if notificationManager.notificationHistory.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "bell.slash")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.4))
                                
                                Text("No Notifications")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("You'll see your notifications here when they arrive")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 100)
                        } else {
                            ForEach(notificationManager.notificationHistory, id: \.id) { notification in
                                NotificationHistoryRow(notification: notification)
                                    .opacity(hasAppeared ? 1.0 : 0.0)
                                    .scaleEffect(hasAppeared ? 1.0 : 0.8)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(notificationManager.notificationHistory.firstIndex(where: { $0.id == notification.id }) ?? 0) * 0.1), value: hasAppeared)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                if !notificationManager.notificationHistory.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Clear All") {
                            notificationManager.clearAllNotifications()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .onAppear {
            // Mark all notifications as read
            notificationManager.markAllAsRead()
            
            withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Notification History Row
struct NotificationHistoryRow: View {
    let notification: AppNotification
    
    var body: some View {
        HStack(spacing: 16) {
            // Notification icon
            ZStack {
                Circle()
                    .fill(notificationColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: notificationIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(notificationColor)
            }
            
            // Notification content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(notification.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
                
                Text(timeAgoString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            if !notification.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var notificationColor: Color {
        switch notification.type {
        case "new_message":
            return .blue
        case "friend_request":
            return .green
        case "friend_request_accepted":
            return .green
        default:
            return .orange
        }
    }
    
    private var notificationIcon: String {
        switch notification.type {
        case "new_message":
            return "message.fill"
        case "friend_request":
            return "person.badge.plus.fill"
        case "friend_request_accepted":
            return "person.fill.checkmark"
        default:
            return "bell.fill"
        }
    }
    
    private var timeAgoString: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(notification.timestamp.dateValue())
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Preview
struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsView()
            .environmentObject(AuthenticationService())
    }
}

// MARK: - Minimalist Friend Row Component
struct MinimalistFriendRow: View {
    let friend: AppUser
    let onChatTapped: (AppUser) -> Void
    let onPingTapped: (AppUser) -> Void
    let onRemoveTapped: (AppUser) -> Void
    
    @State private var showingActionSheet = false
    @State private var isPressed = false
    
    private var isOnline: Bool {
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        return friend.lastActiveAt > fiveMinutesAgo
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(.systemBlue), Color(.systemIndigo)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Friend information with horizontal layout
            VStack(alignment: .leading, spacing: 4) {
                // Name and tag in horizontal layout
                HStack(spacing: 8) {
                    Text(friend.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("#\(friend.userTag)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(isOnline ? .green : Color(.systemGray3))
                        .frame(width: 6, height: 6)
                    
                    Text(isOnline ? "Online" : "Offline")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                // Chat button
                Button(action: {
                    onChatTapped(friend)
                }) {
                    Image(systemName: "message")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(.systemBlue))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                        )
                }
                
                // More actions button
                Button(action: {
                    showingActionSheet = true
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {}
        .confirmationDialog("Friend Options", isPresented: $showingActionSheet) {
            Button("Send Ping") {
                onPingTapped(friend)
            }
            Button("Remove Friend", role: .destructive) {
                onRemoveTapped(friend)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Minimalist Friend Request Row
struct MinimalistFriendRequestRow: View {
    let request: FriendRequest
    let onAccept: (FriendRequest) -> Void
    let onDecline: (FriendRequest) -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(.systemGray), Color(.systemGray2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(request.fromUserName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Request information
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(request.fromUserName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("#\(request.fromUserTag)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text("Friend request")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                HStack(spacing: 8) {
                    // Decline button
                    Button(action: {
                        isProcessing = true
                        onDecline(request)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(.systemGray6))
                            )
                    }
                    
                    // Accept button
                    Button(action: {
                        isProcessing = true
                        onAccept(request)
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(.systemBlue))
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Minimalist Empty State
struct MinimalistEmptyState: View {
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color(.systemBlue))
                                .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                        )
                }
            }
        }
    }
}

// MARK: - Minimalist Loading Skeleton
struct MinimalistFriendRowSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar skeleton
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
                .shimmer(isAnimating: isAnimating)
            
            // Content skeleton
            VStack(alignment: .leading, spacing: 6) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .frame(maxWidth: 120)
                    .shimmer(isAnimating: isAnimating)
                
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 12)
                    .frame(maxWidth: 80)
                    .shimmer(isAnimating: isAnimating)
            }
            
            Spacer()
            
            // Action buttons skeleton
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                    .shimmer(isAnimating: isAnimating)
                
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                    .shimmer(isAnimating: isAnimating)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Shimmer Effect Extension
extension View {
    func shimmer(isAnimating: Bool) -> some View {
        self.overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.6),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .rotationEffect(.degrees(30))
                .offset(x: isAnimating ? 200 : -200)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
        )
        .clipped()
    }
} 