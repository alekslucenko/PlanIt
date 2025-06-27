import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Enhanced Modern Friends View with Lazy Loading
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
    @State private var isInitialized = false
    
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
            
            if !isInitialized {
                // Show loading while initializing
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.blue)
                    
                    Text("Loading friends...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else {
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
            if !hasAppeared {
                hasAppeared = true
                initializeFriendsView()
            }
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView(friendsManager: friendsManager)
                .environmentObject(authService)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNotificationHistory) {
            NotificationHistorySheet(notificationManager: notificationManager)
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
    
    // MARK: - Lazy Initialization
    private func initializeFriendsView() {
        print("🔄 FriendsView: Initializing with lazy loading...")
        
        Task {
            // Set up service references
            friendsManager.setAuthService(authService)
            friendsManager.setNotificationManager(notificationManager)
            
            // Start listeners only when view is actually used
            friendsManager.startRealtimeListeners()
            
            // Small delay to show loading state
            try? await Task.sleep(for: .milliseconds(300))
            
            await MainActor.run {
                isInitialized = true
                print("✅ FriendsView: Initialization complete")
            }
        }
    }
    
    // MARK: - Header Section
    private var modernMinimalHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Friends")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 16) {
                    // Notification history button
                    Button(action: { showingNotificationHistory = true }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "bell")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Add friend button
                    Button(action: { showingAddFriend = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
    }
    
    // MARK: - Tab Switcher
    private var modernTabSwitcher: some View {
        HStack(spacing: 0) {
            tabSwitcherButton(
                title: "Friends", 
                count: friendsManager.friends.count,
                isSelected: selectedTab == 0,
                action: { withAnimation(.easeInOut(duration: 0.3)) { selectedTab = 0 } }
            )
            
            tabSwitcherButton(
                title: "Requests", 
                count: friendsManager.friendRequests.count,
                isSelected: selectedTab == 1,
                action: { withAnimation(.easeInOut(duration: 0.3)) { selectedTab = 1 } }
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
    
    private func tabSwitcherButton(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .blue : .secondary)
                    
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.blue : Color.gray)
                            )
                    }
                }
                
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Friends List
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
    }
    
    // MARK: - Friend Requests List
    private var modernFriendRequestsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if friendsManager.friendRequests.isEmpty && !friendsManager.isLoading {
                    MinimalistEmptyState(
                        title: "No friend requests",
                        subtitle: "Friend requests will appear here",
                        actionTitle: "Add Friend",
                        action: { showingAddFriend = true }
                    )
                    .padding(.top, 60)
                } else {
                    ForEach(friendsManager.friendRequests) { request in
                        MinimalistFriendRequestRow(
                            request: request,
                            onAccept: { 
                                Task { await friendsManager.acceptFriendRequest(request) }
                            },
                            onDecline: { 
                                Task { await friendsManager.declineFriendRequest(request) }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                
                if friendsManager.isLoading {
                    ForEach(0..<2) { _ in
                        MinimalistFriendRowSkeleton()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Notification Banner
    private func notificationBanner(_ notification: AppNotification) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: notification.type == "friend_request" ? "person.badge.plus" : "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(notification.message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: { notificationManager.hideInAppNotification() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
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

// MARK: - Supporting Views
struct MinimalistFriendRow: View {
    let friend: AppUser
    let onChatTapped: (AppUser) -> Void
    let onPingTapped: (AppUser) -> Void
    let onRemoveTapped: (AppUser) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile avatar
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(friend.username.prefix(1).uppercased())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                )
            
            // Friend info
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName.isEmpty ? friend.username : friend.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("@\(friend.username)#\(friend.userTag)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: { onChatTapped(friend) }) {
                    Image(systemName: "message.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                Menu {
                    Button("Remove Friend", role: .destructive) {
                        onRemoveTapped(friend)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

struct MinimalistFriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile avatar
            Circle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(request.fromUserName.prefix(1).uppercased())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.orange)
                )
            
            // Request info
            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromUserName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Wants to be your friend")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: onAccept) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                }
                
                Button(action: onDecline) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

struct MinimalistEmptyState: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "person.2")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
            }
        }
    }
}

struct MinimalistFriendRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 14)
                    .cornerRadius(7)
                
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 12)
                    .cornerRadius(6)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 24, height: 24)
                
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 24, height: 24)
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Notification History Sheet
struct NotificationHistorySheet: View {
    let notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if notificationManager.notificationHistory.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No Notifications")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Your notification history will appear here")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(notificationManager.notificationHistory) { notification in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(notification.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(formatTimestamp(notification.timestamp))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(notification.message)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Extensions
// Note: AppUser already conforms to Identifiable in AppModels.swift