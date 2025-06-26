import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import SwiftUI
import CoreLocation

@MainActor
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userDisplayName: String = ""
    @Published var userPhotoURL: String = ""
    
    // MARK: - AppUser for Friends System
    @Published var currentAppUser: AppUser?
    
    // MARK: - Computed Properties for Compatibility
    var currentUser: User? {
        return user
    }
    
    private let db = Firestore.firestore()
    
    init() {
        // Listen for authentication state changes
        _ = Auth.auth().addStateDidChangeListener { auth, user in
            Task { @MainActor in
                self.user = user
                self.isAuthenticated = user != nil
                
                if let user = user {
                    // Update display properties
                    self.userDisplayName = user.displayName ?? ""
                    self.userPhotoURL = user.photoURL?.absoluteString ?? ""
                    
                    // Load or create AppUser data
                    await self.loadAppUserData()
                    
                    // Run migration for existing users (once per app launch)
                    await self.migrateExistingUsersToUserTag()
                } else {
                    // Clear AppUser data when signed out
                    self.currentAppUser = nil
                    self.userDisplayName = ""
                    self.userPhotoURL = ""
                }
            }
        }
        print("🔥 Firebase AuthenticationService initialized")
    }
    
    // MARK: - Enhanced Sign Up Function with Firestore Integration and 4-digit identifier
    func signUp(email: String, password: String, displayName: String, onboardingData: [String: Any]? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                }
                completion(.failure(error))
                return
            }

            guard let uid = authResult?.user.uid else {
                let noUIDError = NSError(domain: "App", code: 500, userInfo: [NSLocalizedDescriptionKey: "No UID found."])
                DispatchQueue.main.async {
                    self?.errorMessage = "Authentication failed - no user ID found."
                }
                completion(.failure(noUIDError))
                return
            }

            // Update display name
            let changeRequest = authResult?.user.createProfileChangeRequest()
            changeRequest?.displayName = displayName
            changeRequest?.commitChanges { error in
                if let error = error {
                    print("⚠️ Error updating display name: \(error)")
                }
            }

            // Validate and clean username for storage
            let cleanedUsername = AppUser.validateUsername(displayName)
            
            // Create AppUser with permanent 4-digit tag
            let appUser = AppUser(
                id: uid,
                email: email,
                username: cleanedUsername, // Use cleaned version as username
                displayName: displayName,
                photoURL: authResult?.user.photoURL?.absoluteString
            )
            
            // Prepare user data for Firestore - CRITICAL: Save the generated userTag permanently
            var userData: [String: Any] = [
                "uid": uid,
                "email": email,
                "username": appUser.username,
                "displayName": displayName,
                "userTag": appUser.userTag, // This is the permanent 4-digit tag
                "createdAt": FieldValue.serverTimestamp(),
                "lastActiveAt": FieldValue.serverTimestamp(),
                "friends": appUser.friends,
                "sentFriendRequests": appUser.sentFriendRequests,
                "receivedFriendRequests": appUser.receivedFriendRequests,
                "blockedUsers": appUser.blockedUsers
            ]
            
            // Add photo URL if available
            if let photoURL = appUser.photoURL {
                userData["photoURL"] = photoURL
            }
            
            // Add onboarding data if provided
            if let onboardingData = onboardingData {
                userData["onboarding"] = onboardingData
            }

            // Save to Firestore
            self?.db.collection("users").document(uid).setData(userData) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = "Failed to save user data: \(error.localizedDescription)"
                        completion(.failure(error))
                    } else {
                        print("✅ User data saved successfully with permanent tag: #\(appUser.userTag)")
                        self?.userDisplayName = displayName
                        self?.currentAppUser = appUser
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    // MARK: - Create AppUser in Firestore
    func createAppUserInFirestore() async {
        guard let user = user else { return }
        
        do {
            // Check if user already exists in Firestore
            let document = try await db.collection("users").document(user.uid).getDocument()
            
            if document.exists {
                // User already exists, load their existing data (preserving userTag)
                await loadAppUserData()
                return
            }
            
            // User doesn't exist, create new AppUser with permanent 4-digit tag
            let newAppUser = AppUser(
                id: user.uid,
                email: user.email ?? "",
                username: AppUser.validateUsername(user.displayName ?? "User"),
                displayName: user.displayName ?? "User",
                photoURL: user.photoURL?.absoluteString
            )
            
            // Save to Firestore with permanent userTag
            let userData: [String: Any] = [
                "uid": newAppUser.id,
                "email": newAppUser.email,
                "username": newAppUser.username,
                "displayName": newAppUser.displayName,
                "userTag": newAppUser.userTag, // This will be generated once and never change
                "photoURL": newAppUser.photoURL ?? "",
                "createdAt": Timestamp(date: newAppUser.createdAt),
                "lastActiveAt": Timestamp(date: newAppUser.lastActiveAt),
                "friends": newAppUser.friends,
                "sentFriendRequests": newAppUser.sentFriendRequests,
                "receivedFriendRequests": newAppUser.receivedFriendRequests,
                "blockedUsers": newAppUser.blockedUsers
            ]
            
            try await db.collection("users").document(user.uid).setData(userData)
            
            // Set the current AppUser
            self.currentAppUser = newAppUser
            
            print("✅ Created new AppUser in Firestore with permanent tag: #\(newAppUser.userTag)")
            
        } catch {
            self.errorMessage = "Failed to create user profile: \(error.localizedDescription)"
            print("❌ Error creating AppUser: \(error)")
        }
    }
    
    // MARK: - Load AppUser Data from Firestore - NEVER regenerate userTag
    func loadAppUserData() async {
        guard let uid = user?.uid else { return }
        
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            if document.exists, let data = document.data() {
                // CRITICAL: Handle existing users who might not have userTag yet
                var existingUserTag = data["userTag"] as? String
                
                // If user doesn't have userTag, generate one and save it permanently
                if existingUserTag == nil || existingUserTag?.isEmpty == true {
                    existingUserTag = AppUser.generateUserTag()
                    
                    // Update Firestore with the new permanent userTag
                    try await db.collection("users").document(uid).updateData([
                        "userTag": existingUserTag!
                    ])
                    
                    print("🔄 Migrated existing user to have permanent userTag: #\(existingUserTag!)")
                }
                
                // Handle both 'username' and 'userName' fields for backward compatibility
                let username = data["username"] as? String ?? data["userName"] as? String ?? data["displayName"] as? String ?? ""
                
                let appUser = AppUser(
                    id: data["uid"] as? String ?? uid,
                    email: data["email"] as? String ?? "",
                    username: AppUser.validateUsername(username),
                    displayName: data["displayName"] as? String ?? "",
                    userTag: existingUserTag!, // Use the permanent tag from Firestore
                    photoURL: data["photoURL"] as? String,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    lastActiveAt: (data["lastActiveAt"] as? Timestamp)?.dateValue() ?? Date()
                )
                
                // Load friend-related arrays
                var loadedUser = appUser
                loadedUser.friends = data["friends"] as? [String] ?? []
                loadedUser.sentFriendRequests = data["sentFriendRequests"] as? [String] ?? []
                loadedUser.receivedFriendRequests = data["receivedFriendRequests"] as? [String] ?? []
                loadedUser.blockedUsers = data["blockedUsers"] as? [String] ?? []
                
                self.currentAppUser = loadedUser
                
                print("✅ Loaded AppUser with persistent tag: #\(loadedUser.userTag)")
            } else {
                // Document doesn't exist, create new user
                await createAppUserInFirestore()
            }
        } catch {
            self.errorMessage = "Failed to load user profile: \(error.localizedDescription)"
            print("❌ Error loading AppUser: \(error)")
        }
    }
    
    // MARK: - Migration Method for Existing Users
    func migrateExistingUsersToUserTag() async {
        print("🔄 Starting migration for users without userTag...")
        
        do {
            // Find all users without userTag field
            let querySnapshot = try await db.collection("users").getDocuments()
            
            var usersToMigrate: [(String, [String: Any])] = []
            
            for document in querySnapshot.documents {
                let data = document.data()
                let userTag = data["userTag"] as? String
                
                // If user doesn't have userTag or it's empty, they need migration
                if userTag == nil || userTag?.isEmpty == true {
                    usersToMigrate.append((document.documentID, data))
                }
            }
            
            print("🔍 Found \(usersToMigrate.count) users to migrate")
            
            // Migrate each user
            for (userId, userData) in usersToMigrate {
                let newUserTag = AppUser.generateUserTag()
                
                // Update user with permanent userTag and ensure username field exists
                let username = userData["username"] as? String ?? userData["userName"] as? String ?? userData["displayName"] as? String ?? ""
                
                var updateData: [String: Any] = [
                    "userTag": newUserTag,
                    "username": AppUser.validateUsername(username) // Ensure username field exists
                ]
                
                // Add friends arrays if they don't exist
                if userData["friends"] == nil {
                    updateData["friends"] = []
                }
                if userData["sentFriendRequests"] == nil {
                    updateData["sentFriendRequests"] = []
                }
                if userData["receivedFriendRequests"] == nil {
                    updateData["receivedFriendRequests"] = []
                }
                if userData["blockedUsers"] == nil {
                    updateData["blockedUsers"] = []
                }
                
                try await db.collection("users").document(userId).updateData(updateData)
                
                print("✅ Migrated user \(userId) with tag: #\(newUserTag)")
            }
            
            print("🎉 Migration completed successfully!")
            
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
    
    // MARK: - Enhanced Sign In Function
    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                } else {
                    // Update last login timestamp
                    if let uid = authResult?.user.uid {
                        self?.db.collection("users").document(uid).updateData([
                            "lastLoginAt": FieldValue.serverTimestamp()
                        ]) { error in
                            if let error = error {
                                print("⚠️ Error updating last login: \(error)")
                            }
                        }
                    }
                    print("✅ Sign in successful")
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - Google Sign-In
    func signInWithGoogle() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Get the presenting window scene and root view controller
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                print("❌ Could not find root view controller")
                await MainActor.run {
                    errorMessage = "Unable to present Google Sign-In"
                    isLoading = false
                }
                return
            }
            
            // Get the topmost view controller
            let presentingViewController = getTopViewController(from: rootViewController)
            
            print("🚀 Starting Google Sign-In flow...")
            
            // Start the Google Sign-In flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            
            print("✅ Google Sign-In returned result")
            
            guard let _ = result.user.userID,
                  let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingGoogleCredentials
            }
            
            print("🔑 Creating Firebase credential...")
            
            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            // Sign in with Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            
            print("✅ Google Sign-In successful: \(authResult.user.email ?? "No email")")
            
            // Update user info
            await MainActor.run {
                userDisplayName = authResult.user.displayName ?? "Google User"
                userPhotoURL = authResult.user.photoURL?.absoluteString ?? ""
            }
            
            // Save/update user data in Firestore with AppUser structure
            await saveGoogleUserDataWithAppUser(authResult.user)
            
        } catch {
            print("❌ Google Sign-In error: \(error)")
            await MainActor.run {
                if let gidError = error as? GIDSignInError {
                    switch gidError.code {
                    case .canceled:
                        errorMessage = "Sign-in was canceled"
                    default:
                        errorMessage = "Google Sign-In failed: \(gidError.localizedDescription)"
                    }
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // Helper function to get the topmost view controller
    private func getTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presentedViewController = viewController.presentedViewController {
            return getTopViewController(from: presentedViewController)
        }
        
        if let navigationController = viewController as? UINavigationController,
           let topViewController = navigationController.topViewController {
            return getTopViewController(from: topViewController)
        }
        
        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return getTopViewController(from: selectedViewController)
        }
        
        return viewController
    }
    
    // MARK: - Email/Password Authentication
    func signInWithEmail(_ email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ Email Sign-In successful: \(authResult.user.email ?? "No email")")
            
            // Update last login
            try await db.collection("users").document(authResult.user.uid).updateData([
                "lastLoginAt": FieldValue.serverTimestamp()
            ])
            
            // Load AppUser data (this will create it if it doesn't exist)
            await loadAppUserData()
        } catch {
            print("❌ Email Sign-In error: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    func signUpWithEmail(_ email: String, password: String, displayName: String, onboardingData: [String: Any]? = nil) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update the user's display name
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            
            print("✅ Email Sign-Up successful: \(authResult.user.email ?? "No email")")
            
            await MainActor.run {
                userDisplayName = displayName
            }
            
            // Create AppUser with permanent userTag
            let cleanedUsername = AppUser.validateUsername(displayName)
            let appUser = AppUser(
                id: authResult.user.uid,
                email: email,
                username: cleanedUsername,
                displayName: displayName,
                photoURL: authResult.user.photoURL?.absoluteString
            )
            
            // Save comprehensive user data to Firestore
            var userData: [String: Any] = [
                "uid": authResult.user.uid,
                "email": email,
                "username": appUser.username,
                "displayName": displayName,
                "userTag": appUser.userTag, // Permanent 4-digit tag
                "createdAt": FieldValue.serverTimestamp(),
                "lastLoginAt": FieldValue.serverTimestamp(),
                "authProvider": "email",
                "friends": appUser.friends,
                "sentFriendRequests": appUser.sentFriendRequests,
                "receivedFriendRequests": appUser.receivedFriendRequests,
                "blockedUsers": appUser.blockedUsers
            ]
            
            // Add onboarding data if provided
            if let onboardingData = onboardingData {
                userData["onboarding"] = onboardingData
                userData["onboardingCompleted"] = true
                userData["onboardingCompletedAt"] = FieldValue.serverTimestamp()
            }
            
            try await db.collection("users").document(authResult.user.uid).setData(userData)
            
            // Set the current AppUser
            await MainActor.run {
                self.currentAppUser = appUser
            }
            
            print("✅ User created with permanent tag: #\(appUser.userTag)")
            
        } catch {
            print("❌ Email Sign-Up error: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Enhanced User Data Management
    func saveOnboardingData(_ onboardingData: OnboardingData, location: CLLocation?) async {
        guard let user = user else {
            await MainActor.run {
                errorMessage = "No authenticated user"
            }
            return
        }
        
        do {
            let userDocRef = db.collection("users").document(user.uid)
            
            // Convert onboarding data to JSON-compatible format
            let onboardingJSON: [String: Any] = [
                "selectedCategories": onboardingData.selectedCategories.map { $0.rawValue },
                "responses": onboardingData.responses.map { response in
                    var responseData: [String: Any] = [
                        "questionId": response.questionId,
                        "categoryId": response.categoryId
                    ]
                    
                    if let selectedOptions = response.selectedOptions {
                        responseData["selectedOptions"] = selectedOptions
                    }
                    if let sliderValue = response.sliderValue {
                        responseData["sliderValue"] = sliderValue
                    }
                    if let ratingValue = response.ratingValue {
                        responseData["ratingValue"] = ratingValue
                    }
                    if let textValue = response.textValue {
                        responseData["textValue"] = textValue
                    }
                    
                    // Fix timestamp issue: Use ISO8601 string instead of serverTimestamp for nested data
                    responseData["timestamp"] = ISO8601DateFormatter().string(from: response.timestamp)
                    
                    return responseData
                },
                "userName": onboardingData.userName,
                "completedAt": FieldValue.serverTimestamp()
            ]
            
            var updatePayload: [String: Any] = [
                "onboarding": onboardingJSON,
                "onboardingCompleted": true,
                "onboardingCompletedAt": FieldValue.serverTimestamp()
            ]

            // Save GeoPoint if we have a location
            if let loc = location {
                updatePayload["location"] = GeoPoint(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            }

            // Initialize likes/dislikes arrays if they don't exist yet
            updatePayload["likes"] = FieldValue.arrayUnion([])
            updatePayload["dislikes"] = FieldValue.arrayUnion([])
            updatePayload["interactionLogs"] = FieldValue.arrayUnion([])

            // Update user document with onboarding data + location
            try await userDocRef.setData(updatePayload, merge: true)
            
            print("✅ Onboarding data & location saved successfully")
            
        } catch {
            print("❌ Error saving onboarding data: \(error)")
            await MainActor.run {
                errorMessage = "Failed to save preferences: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Legacy method removed - using loadAppUserData instead
    
    private func saveGoogleUserDataWithAppUser(_ user: User) async {
        do {
            // Check if user already exists in Firestore
            let document = try await db.collection("users").document(user.uid).getDocument()
            
            if document.exists {
                // User exists, just update login time and load data
                try await db.collection("users").document(user.uid).updateData([
                    "lastLoginAt": FieldValue.serverTimestamp()
                ])
                await loadAppUserData()
            } else {
                // New Google user, create AppUser with permanent userTag
                let cleanedUsername = AppUser.validateUsername(user.displayName ?? "GoogleUser")
                let appUser = AppUser(
                    id: user.uid,
                    email: user.email ?? "",
                    username: cleanedUsername,
                    displayName: user.displayName ?? "Google User",
                    photoURL: user.photoURL?.absoluteString
                )
                
                let userData: [String: Any] = [
                    "uid": user.uid,
                    "email": user.email ?? "",
                    "username": appUser.username,
                    "displayName": user.displayName ?? "Google User",
                    "userTag": appUser.userTag, // Permanent 4-digit tag
                    "photoURL": user.photoURL?.absoluteString ?? "",
                    "lastLoginAt": FieldValue.serverTimestamp(),
                    "createdAt": FieldValue.serverTimestamp(),
                    "authProvider": "google",
                    "friends": appUser.friends,
                    "sentFriendRequests": appUser.sentFriendRequests,
                    "receivedFriendRequests": appUser.receivedFriendRequests,
                    "blockedUsers": appUser.blockedUsers
                ]
                
                try await db.collection("users").document(user.uid).setData(userData)
                
                // Set the current AppUser
                await MainActor.run {
                    self.currentAppUser = appUser
                }
                
                print("✅ Google user created with permanent tag: #\(appUser.userTag)")
            }
        } catch {
            print("❌ Error saving Google user data: \(error)")
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        do {
            try Auth.auth().signOut()
            await MainActor.run {
                user = nil
                isAuthenticated = false
                userDisplayName = ""
                userPhotoURL = ""
                errorMessage = nil
            }
            print("✅ Sign out successful")
        } catch {
            print("❌ Sign out error: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("✅ Password reset email sent")
        } catch {
            print("❌ Password reset error: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Real-time Preference Updates
    /// Adds placeId to likes[] and removes from dislikes[], also writes to interactionLogs.
    func likePlace(_ placeId: String) async {
        await updatePreference(placeId: placeId, action: "liked")
    }

    /// Adds placeId to dislikes[] and removes from likes[].
    func dislikePlace(_ placeId: String) async {
        await updatePreference(placeId: placeId, action: "disliked")
    }

    private func updatePreference(placeId: String, action: String) async {
        guard let uid = user?.uid else { return }
        let docRef = db.collection("users").document(uid)
        do {
            if action == "liked" {
                try await docRef.updateData([
                    "likes": FieldValue.arrayUnion([placeId]),
                    "dislikes": FieldValue.arrayRemove([placeId]),
                    "interactionLogs": FieldValue.arrayUnion([["placeId": placeId, "action": action, "timestamp": FieldValue.serverTimestamp()]])
                ])
            } else if action == "disliked" {
                try await docRef.updateData([
                    "dislikes": FieldValue.arrayUnion([placeId]),
                    "likes": FieldValue.arrayRemove([placeId]),
                    "interactionLogs": FieldValue.arrayUnion([["placeId": placeId, "action": action, "timestamp": FieldValue.serverTimestamp()]])
                ])
            }
            print("✅ Updated preference: \(action) for placeId \(placeId)")
        } catch {
            print("❌ Failed to update preference: \(error)")
        }
    }
}

// MARK: - Authentication Errors
enum AuthError: Error, LocalizedError {
    case missingGoogleCredentials
    case invalidCredentials
    case userNotFound
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .missingGoogleCredentials:
            return "Missing Google credentials"
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .userNotFound:
            return "User not found"
        case .networkError:
            return "Network connection error"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - Extensions for OnboardingData
extension OnboardingData {
    func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "OnboardingDataError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert to dictionary"])
        }
        
        return dictionary
    }
}

extension UIApplication {
    var windows: [UIWindow] {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
    }
} 