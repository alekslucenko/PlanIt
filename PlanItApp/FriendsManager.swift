import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// MARK: - Friends Manager with Real-time Capabilities
@MainActor
class FriendsManager: ObservableObject {
    @Published var friends: [AppUser] = []
    @Published var friendRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var friendsListener: ListenerRegistration?
    private var friendRequestsListener: ListenerRegistration?
    private var outgoingRequestsListener: ListenerRegistration?
    private var userUpdatesListener: ListenerRegistration?
    
    // Reference to auth service and notification manager
    private var authService: AuthenticationService?
    var notificationManager: NotificationManager?
    
    init(authService: AuthenticationService? = nil) {
        self.authService = authService
    }
    
    deinit {
        // Stop listeners directly without Task to avoid capture warnings
        friendsListener?.remove()
        friendRequestsListener?.remove()
        outgoingRequestsListener?.remove()
        userUpdatesListener?.remove()
        
        friendsListener = nil
        friendRequestsListener = nil
        outgoingRequestsListener = nil
        userUpdatesListener = nil
        
        print("🛑 All real-time listeners stopped in deinit")
    }
    
    func setAuthService(_ authService: AuthenticationService) {
        self.authService = authService
    }
    
    func setNotificationManager(_ manager: NotificationManager) {
        self.notificationManager = manager
    }
    
    // MARK: - Real-time Listener Management
    private var isListenersActive = false
    private var currentListenerUserId: String?
    
    func startRealtimeListeners() {
        guard let currentUserId = getCurrentUserId() else { return }
        
        // Prevent duplicate listeners for same user
        if isListenersActive && currentListenerUserId == currentUserId {
            print("🔄 Listeners already active for user: \(currentUserId)")
            return
        }
        
        print("🔄 Starting real-time listeners for user: \(currentUserId)")
        
        // Stop any existing listeners first
        stopAllListeners()
        
        // Start all real-time listeners
        startFriendsListener(for: currentUserId)
        startFriendRequestsListener(for: currentUserId)
        startOutgoingRequestsListener(for: currentUserId)
        startUserUpdatesListener(for: currentUserId)
        
        isListenersActive = true
        currentListenerUserId = currentUserId
    }
    
    func stopAllListeners() {
        friendsListener?.remove()
        friendRequestsListener?.remove()
        outgoingRequestsListener?.remove()
        userUpdatesListener?.remove()
        
        friendsListener = nil
        friendRequestsListener = nil
        outgoingRequestsListener = nil
        userUpdatesListener = nil
        
        isListenersActive = false
        currentListenerUserId = nil
        
        print("🛑 All real-time listeners stopped")
    }
    
    // MARK: - Real-time Friends Listener
    private func startFriendsListener(for userId: String) {
        friendsListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                if let error = error {
                    print("❌ Friends listener error: \(error)")
                    return
                }
                
                guard let document = documentSnapshot,
                      document.exists,
                      let data = document.data(),
                      let friendIds = data["friends"] as? [String] else {
                    print("📝 No friends data found")
                    Task { @MainActor in
                        self?.friends = []
                    }
                    return
                }
                
                // Load detailed friend information
                Task {
                    await self?.loadFriendsDetails(friendIds: friendIds)
                }
            }
    }
    
    private func loadFriendsDetails(friendIds: [String]) async {
        // Prevent excessive loading by checking if friend IDs actually changed
        let currentFriendIds = Set(friends.map { $0.id })
        let newFriendIds = Set(friendIds)
        
        if currentFriendIds == newFriendIds && !friends.isEmpty {
            // No change in friend list, skip loading
            return
        }
        
        var loadedFriends: [AppUser] = []
        
        for friendId in friendIds {
            do {
                let friendDoc = try await db.collection("users").document(friendId).getDocument()
                if let friendData = friendDoc.data() {
                    let friend = AppUser(
                        id: friendData["uid"] as? String ?? friendId,
                        email: friendData["email"] as? String ?? "",
                        username: friendData["username"] as? String ?? friendData["displayName"] as? String ?? "",
                        displayName: friendData["displayName"] as? String ?? "",
                        userTag: friendData["userTag"] as? String ?? "",
                        photoURL: friendData["photoURL"] as? String,
                        createdAt: (friendData["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        lastActiveAt: (friendData["lastActiveAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                    loadedFriends.append(friend)
                }
            } catch {
                print("❌ Error loading friend \(friendId): \(error)")
            }
        }
        
        await MainActor.run {
            // Only update if there's actually a change
            if Set(self.friends.map { $0.id }) != Set(loadedFriends.map { $0.id }) {
                self.friends = loadedFriends
                print("✅ Real-time friends update: \(loadedFriends.count) friends")
            }
        }
    }
    
    // MARK: - Real-time Friend Requests Listener (Incoming)
    private func startFriendRequestsListener(for userId: String) {
        friendRequestsListener = db.collection("friendRequests")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] querySnapshot, error in
                if let error = error {
                    print("❌ Friend requests listener error: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    Task { @MainActor in
                        self?.friendRequests = []
                    }
                    return
                }
                
                Task { @MainActor in
                    var requests: [FriendRequest] = []
                    for document in documents {
                        let data = document.data()
                        
                        let request = FriendRequest(
                            id: document.documentID,
                            fromUserId: data["fromUserId"] as? String ?? "",
                            toUserId: data["toUserId"] as? String ?? "",
                            fromUserName: data["fromUserName"] as? String ?? "",
                            fromUserTag: data["fromUserTag"] as? String ?? "",
                            status: FriendRequestStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                            respondedAt: (data["respondedAt"] as? Timestamp)?.dateValue()
                        )
                        requests.append(request)
                    }
                    
                    // Check for new requests to show notifications
                    let previousCount = self?.friendRequests.count ?? 0
                    let newCount = requests.count
                    
                    if newCount > previousCount {
                        // New friend request received
                        let newRequests = requests.filter { newRequest in
                            !(self?.friendRequests.contains { $0.id == newRequest.id } ?? false)
                        }
                        
                        for newRequest in newRequests {
                            await self?.showFriendRequestNotification(request: newRequest)
                        }
                    }
                    
                    self?.friendRequests = requests
                    print("✅ Real-time friend requests update: \(requests.count) pending")
                }
            }
    }
    
    // MARK: - Real-time Outgoing Requests Listener
    private func startOutgoingRequestsListener(for userId: String) {
        outgoingRequestsListener = db.collection("friendRequests")
            .whereField("fromUserId", isEqualTo: userId)
            .addSnapshotListener { [weak self] querySnapshot, error in
                if let error = error {
                    print("❌ Outgoing requests listener error: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    Task { @MainActor in
                        self?.outgoingRequests = []
                    }
                    return
                }
                
                Task { @MainActor in
                    var requests: [FriendRequest] = []
                    for document in documents {
                        let data = document.data()
                        
                        let request = FriendRequest(
                            id: document.documentID,
                            fromUserId: data["fromUserId"] as? String ?? "",
                            toUserId: data["toUserId"] as? String ?? "",
                            fromUserName: data["fromUserName"] as? String ?? "",
                            fromUserTag: data["fromUserTag"] as? String ?? "",
                            status: FriendRequestStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                            respondedAt: (data["respondedAt"] as? Timestamp)?.dateValue()
                        )
                        requests.append(request)
                    }
                    
                    // Check for accepted requests to show notifications
                    let previousAccepted = self?.outgoingRequests.filter { $0.status == .accepted }.count ?? 0
                    let newAccepted = requests.filter { $0.status == .accepted }.count
                    
                    if newAccepted > previousAccepted {
                        // Someone accepted our request
                        let newlyAccepted = requests.filter { request in
                            request.status == .accepted &&
                            !(self?.outgoingRequests.contains { $0.id == request.id && $0.status == .accepted } ?? false)
                        }
                        
                        for acceptedRequest in newlyAccepted {
                            await self?.showFriendRequestAcceptedNotification(request: acceptedRequest)
                        }
                    }
                    
                    self?.outgoingRequests = requests
                    print("✅ Real-time outgoing requests update: \(requests.count) total")
                }
            }
    }
    
    // MARK: - User Updates Listener for Profile Changes
    private func startUserUpdatesListener(for userId: String) {
        userUpdatesListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                if let error = error {
                    print("❌ User updates listener error: \(error)")
                    return
                }
                
                // FIXED: Only log and process meaningful changes, add debouncing
                guard let document = documentSnapshot, 
                      document.exists,
                      let data = document.data() else { return }
                
                // Only process if friends array actually changed (not just any document update)
                if let friendIds = data["friends"] as? [String] {
                    let currentFriendIds = self?.friends.map { $0.id } ?? []
                    if Set(friendIds) != Set(currentFriendIds) {
                        print("🔄 User friends list updated in real-time")
                        // The friends listener will handle this update
                    }
                }
                
                // Prevent unused variable warning
                _ = self
            }
    }
    
    // MARK: - Real-time Notifications
    private func showFriendRequestNotification(request: FriendRequest) async {
        guard let notificationManager = notificationManager else { return }
        
        await notificationManager.sendNotification(
            to: request.toUserId,
            from: request.fromUserId,
            type: .friendRequest,
            title: "New Friend Request",
            message: "\(request.fromUserName)#\(request.fromUserTag) wants to be your friend!",
            data: [
                "requestId": request.id,
                "fromUserId": request.fromUserId,
                "fromUserName": request.fromUserName,
                "fromUserTag": request.fromUserTag,
                "senderName": request.fromUserName
            ]
        )
        
        print("📱 Friend request notification sent for: \(request.fromUserName)")
    }
    
    private func showFriendRequestAcceptedNotification(request: FriendRequest) async {
        guard let notificationManager = notificationManager else { return }
        
        // Get the accepter's info
        do {
            let userDoc = try await db.collection("users").document(request.toUserId).getDocument()
            if let userData = userDoc.data() {
                let accepterName = userData["username"] as? String ?? userData["displayName"] as? String ?? "Someone"
                let accepterTag = userData["userTag"] as? String ?? ""
                
                await notificationManager.sendNotification(
                    to: request.fromUserId,
                    from: request.toUserId,
                    type: .friendRequestAccepted,
                    title: "Friend Request Accepted! 🎉",
                    message: "\(accepterName)#\(accepterTag) accepted your friend request!",
                    data: [
                        "requestId": request.id,
                        "accepterId": request.toUserId,
                        "accepterName": accepterName,
                        "accepterTag": accepterTag,
                        "senderName": accepterName
                    ]
                )
                
                print("🎉 Friend request accepted notification sent to: \(request.fromUserId)")
            }
        } catch {
            print("❌ Error sending acceptance notification: \(error)")
        }
    }
    
    // MARK: - Load Friends (Legacy - kept for backward compatibility)
    func loadFriends() async {
        // This is now handled by real-time listeners
        // But we keep it for initial load if listeners haven't started
        if friendsListener == nil {
            guard let currentUserId = getCurrentUserId() else { return }
            
            isLoading = true
            do {
                let document = try await db.collection("users").document(currentUserId).getDocument()
                if let data = document.data(),
                   let friendIds = data["friends"] as? [String] {
                    await loadFriendsDetails(friendIds: friendIds)
                }
            } catch {
                self.errorMessage = "Failed to load friends: \(error.localizedDescription)"
                print("❌ Error loading friends: \(error)")
            }
            isLoading = false
        }
    }
    
    // MARK: - Load Friend Requests (Legacy - kept for backward compatibility)
    func loadFriendRequests() async {
        // This is now handled by real-time listeners
        // But we keep it for initial load if listeners haven't started
        if friendRequestsListener == nil {
            guard let currentUserId = getCurrentUserId() else { return }
            
            do {
                let query = db.collection("friendRequests")
                    .whereField("toUserId", isEqualTo: currentUserId)
                    .whereField("status", isEqualTo: "pending")
                
                let querySnapshot = try await query.getDocuments()
                
                var requests: [FriendRequest] = []
                for document in querySnapshot.documents {
                    let data = document.data()
                    
                    let request = FriendRequest(
                        id: document.documentID,
                        fromUserId: data["fromUserId"] as? String ?? "",
                        toUserId: data["toUserId"] as? String ?? "",
                        fromUserName: data["fromUserName"] as? String ?? "",
                        fromUserTag: data["fromUserTag"] as? String ?? "",
                        status: FriendRequestStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        respondedAt: (data["respondedAt"] as? Timestamp)?.dateValue()
                    )
                    requests.append(request)
                }
                
                self.friendRequests = requests
            } catch {
                self.errorMessage = "Failed to load friend requests: \(error.localizedDescription)"
                print("❌ Error loading friend requests: \(error)")
            }
        }
    }

    // MARK: - Enhanced Search for User by Username#Tag with Case-Insensitive Support
    func searchUser(by fullUsername: String, completion: @escaping (AppUser?, String) -> Void) {
        let trimmedInput = fullUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate format: username#1234
        let parts = trimmedInput.components(separatedBy: "#")
        guard parts.count == 2,
              let username = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              let tag = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines),
              !username.isEmpty,
              tag.count == 4,
              Int(tag) != nil else {
            completion(nil, "Invalid format. Use: username#1234 (e.g., john#1234)")
            return
        }
        
        let searchUsername = username.lowercased()
        let userTag = tag
        
        print("🔍 Searching for user: \(searchUsername)#\(userTag)")
        
        // First search by userTag (4-digit ID) for efficiency
        db.collection("users")
            .whereField("userTag", isEqualTo: userTag)
            .getDocuments { [weak self] querySnapshot, error in
                if let error = error {
                    print("❌ Search error: \(error)")
                    completion(nil, "Search failed: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                    print("❌ No user found with userTag: #\(userTag)")
                    completion(nil, "No user found with ID #\(userTag). Please check the 4-digit number.")
                    return
                }
                
                // Filter by username (case-insensitive)
                var foundUser: AppUser? = nil
                
                for document in documents {
                    let data = document.data()
                    
                    // Check multiple username fields for compatibility
                    let storedUsername = (data["username"] as? String ?? "").lowercased()
                    let storedUserName = (data["userName"] as? String ?? "").lowercased()
                    let storedDisplayName = AppUser.validateUsername(data["displayName"] as? String ?? "").lowercased()
                    
                    print("🔍 Comparing search '\(searchUsername)' with stored usernames:")
                    print("   - username: '\(storedUsername)'")
                    print("   - userName: '\(storedUserName)'") 
                    print("   - displayName-derived: '\(storedDisplayName)'")
                    
                    // Try exact matches in order of priority
                    if storedUsername == searchUsername || 
                       storedUserName == searchUsername || 
                       storedDisplayName == searchUsername {
                        
                        foundUser = AppUser(
                            id: data["uid"] as? String ?? document.documentID,
                            email: data["email"] as? String ?? "",
                            username: data["username"] as? String ?? data["userName"] as? String ?? data["displayName"] as? String ?? "",
                            displayName: data["displayName"] as? String ?? "",
                            userTag: data["userTag"] as? String ?? "",
                            photoURL: data["photoURL"] as? String,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                            lastActiveAt: (data["lastActiveAt"] as? Timestamp)?.dateValue() ?? Date()
                        )
                        
                        print("✅ Found matching user: \(foundUser!.username)#\(foundUser!.userTag)")
                        break
                    }
                }
                
                if let user = foundUser {
                    // Prevent self-friending
                    if let currentUserId = self?.getCurrentUserId(), user.id == currentUserId {
                        completion(nil, "You cannot add yourself as a friend!")
                        return
                    }
                    
                    completion(user, "User \(user.fullUsername) found!")
                } else {
                    completion(nil, "No user found with username '\(username)#\(userTag)'. Please check the spelling.")
                }
            }
    }
    
    // MARK: - Send Friend Request (Enhanced with Real-time Updates)
    func sendFriendRequest(to user: AppUser, completion: @escaping (Bool, String) -> Void) {
        guard let currentUserId = getCurrentUserId(),
              let currentUser = getCurrentAppUser() else {
            completion(false, "Please sign in to send friend requests")
            return
        }
        
        // Check if already friends
        if friends.contains(where: { $0.id == user.id }) {
            completion(false, "You are already friends with this user")
            return
        }
        
        // Check if request already sent
        if outgoingRequests.contains(where: { $0.toUserId == user.id && $0.status == .pending }) {
            completion(false, "Friend request already sent")
            return
        }
        
        // Create friend request
        let requestId = UUID().uuidString
        let friendRequest = FriendRequest(
            id: requestId,
            fromUserId: currentUserId,
            toUserId: user.id,
            fromUserName: currentUser.username,
            fromUserTag: currentUser.userTag,
            status: .pending,
            createdAt: Date(),
            respondedAt: nil
        )
        
        // Prepare Firestore data
        let requestData: [String: Any] = [
            "id": friendRequest.id,
            "fromUserId": friendRequest.fromUserId,
            "toUserId": friendRequest.toUserId,
            "fromUserName": friendRequest.fromUserName,
            "fromUserTag": friendRequest.fromUserTag,
            "status": friendRequest.status.rawValue,
            "createdAt": Timestamp(date: friendRequest.createdAt),
            "respondedAt": friendRequest.respondedAt as Any
        ]
        
        // Save to Firestore - Real-time listeners will handle the updates
        db.collection("friendRequests").document(requestId).setData(requestData) { [weak self] error in
            if let error = error {
                completion(false, "Failed to send friend request: \(error.localizedDescription)")
                return
            }
            
            // Update current user's sent requests
            self?.updateUserSentRequests(userId: currentUserId, addUserId: user.id)
            
            // Update target user's received requests
            self?.updateUserReceivedRequests(userId: user.id, addUserId: currentUserId)
            
            // Send real-time notification to the target user
            Task {
                await self?.showFriendRequestNotification(request: friendRequest)
            }
            
            completion(true, "Friend request sent successfully!")
            print("✅ Friend request sent to \(user.fullUsername)")
        }
    }
    
    // MARK: - Update User Sent Requests
    private func updateUserSentRequests(userId: String, addUserId: String) {
        db.collection("users").document(userId).updateData([
            "sentFriendRequests": FieldValue.arrayUnion([addUserId])
        ]) { error in
            if let error = error {
                print("❌ Failed to update sent requests: \(error)")
            }
        }
    }
    
    // MARK: - Update User Received Requests
    private func updateUserReceivedRequests(userId: String, addUserId: String) {
        db.collection("users").document(userId).updateData([
            "receivedFriendRequests": FieldValue.arrayUnion([addUserId])
        ]) { error in
            if let error = error {
                print("❌ Failed to update received requests: \(error)")
            }
        }
    }
    
    // MARK: - Accept Friend Request (Enhanced with Real-time Updates)
    func acceptFriendRequest(_ request: FriendRequest) async {
        guard let currentUserId = getCurrentUserId() else { return }
        
        do {
            // Update friend request status
            try await db.collection("friendRequests").document(request.id).updateData([
                "status": FriendRequestStatus.accepted.rawValue,
                "respondedAt": Timestamp(date: Date())
            ])
            
            // Add each user to the other's friends list
            try await db.collection("users").document(currentUserId).updateData([
                "friends": FieldValue.arrayUnion([request.fromUserId]),
                "receivedFriendRequests": FieldValue.arrayRemove([request.fromUserId])
            ])
            
            try await db.collection("users").document(request.fromUserId).updateData([
                "friends": FieldValue.arrayUnion([currentUserId]),
                "sentFriendRequests": FieldValue.arrayRemove([currentUserId])
            ])
            
            print("✅ Friend request accepted successfully")
            
            // Send acceptance notification to the requester
            await showFriendRequestAcceptedNotification(request: request)
            
            // Real-time listeners will handle the UI updates automatically
            
        } catch {
            print("❌ Error accepting friend request: \(error)")
            self.errorMessage = "Failed to accept friend request: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Decline Friend Request (Enhanced with Real-time Updates)
    func declineFriendRequest(_ request: FriendRequest) async {
        guard let currentUserId = getCurrentUserId() else { return }
        
        do {
            // Update friend request status
            try await db.collection("friendRequests").document(request.id).updateData([
                "status": FriendRequestStatus.declined.rawValue,
                "respondedAt": Timestamp(date: Date())
            ])
            
            // Remove from received requests
            try await db.collection("users").document(currentUserId).updateData([
                "receivedFriendRequests": FieldValue.arrayRemove([request.fromUserId])
            ])
            
            // Remove from sender's sent requests
            try await db.collection("users").document(request.fromUserId).updateData([
                "sentFriendRequests": FieldValue.arrayRemove([currentUserId])
            ])
            
            print("✅ Friend request declined successfully")
            
            // Real-time listeners will handle the UI updates automatically
            
        } catch {
            print("❌ Error declining friend request: \(error)")
            self.errorMessage = "Failed to decline friend request: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Remove Friend (New Functionality)
    func removeFriend(_ friend: AppUser) async {
        guard let currentUserId = getCurrentUserId() else { return }
        
        do {
            // Remove friend from both users' friends lists
            try await db.collection("users").document(currentUserId).updateData([
                "friends": FieldValue.arrayRemove([friend.id])
            ])
            
            try await db.collection("users").document(friend.id).updateData([
                "friends": FieldValue.arrayRemove([currentUserId])
            ])
            
            print("✅ Friend \(friend.fullUsername) removed successfully")
            
            // Real-time listeners will handle the UI updates automatically
            
        } catch {
            print("❌ Error removing friend: \(error)")
            self.errorMessage = "Failed to remove friend: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Helper Methods
    private func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    private func getCurrentAppUser() -> AppUser? {
        return authService?.currentAppUser
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
} 