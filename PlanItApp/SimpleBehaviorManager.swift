import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Simplified Behavior Manager for Demo
@MainActor
class SimpleBehaviorManager: ObservableObject {
    static let shared = SimpleBehaviorManager()
    private init() {}
    
    private let db = Firestore.firestore()
    
    /// Records place interaction linked to user email/display name  
    func recordUserBehavior(
        placeId: String,
        placeName: String,
        action: String, // "liked", "disliked", "viewed"
        userEmail: String,
        userDisplayName: String
    ) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let behaviorData: [String: Any] = [
            "placeId": placeId,
            "placeName": placeName,
            "action": action,
            "timestamp": Date(),
            "userEmail": userEmail,
            "userDisplayName": userDisplayName,
            "userId": uid
        ]
        
        var updates: [String: Any] = [
            "behaviorHistory": FieldValue.arrayUnion([behaviorData]),
            "lastActiveAt": FieldValue.serverTimestamp(),
            "userEmail": userEmail,
            "userDisplayName": userDisplayName
        ]
        
        // Update counters based on action
        if action == "liked" {
            updates["totalThumbsUp"] = FieldValue.increment(Int64(1))
            updates["likes"] = FieldValue.arrayUnion([placeName])
        } else if action == "disliked" {
            updates["totalThumbsDown"] = FieldValue.increment(Int64(1))  
            updates["dislikes"] = FieldValue.arrayUnion([placeName])
        } else if action == "viewed" {
            updates["totalPlaceViews"] = FieldValue.increment(Int64(1))
        }
        
        do {
            try await db.collection("users").document(uid).updateData(updates)
            print("✅ Recorded \(action) for \(placeName) by \(userEmail)")
        } catch {
            print("❌ Failed to record behavior: \(error)")
        }
    }
    
    /// Creates personalized recommendation prompt using user behavioral data
    func createPersonalizedPrompt(userEmail: String, userDisplayName: String) async -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            return "Generate 5 general recommendations"
        }
        
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            guard let data = doc.data() else {
                return "Generate 5 general recommendations"
            }
            
            let totalLikes = data["totalThumbsUp"] as? Int ?? 0
            let totalDislikes = data["totalThumbsDown"] as? Int ?? 0
            let totalViews = data["totalPlaceViews"] as? Int ?? 0
            let likes = data["likes"] as? [String] ?? []
            let dislikes = data["dislikes"] as? [String] ?? []
            
            return """
            PERSONALIZED RECOMMENDATION for \(userDisplayName) (\(userEmail))
            
            USER BEHAVIORAL DATA:
            - Total Likes: \(totalLikes)
            - Total Dislikes: \(totalDislikes) 
            - Total Views: \(totalViews)
            
            LIKED PLACES: \(likes.joined(separator: ", "))
            DISLIKED PLACES: \(dislikes.joined(separator: ", "))
            
            Generate 5 personalized recommendations based on this user's behavior.
            Avoid places similar to their dislikes.
            Focus on places similar to their likes.
            
            Return JSON: [{"name": "...", "reason": "...", "score": 0.9}]
            """
            
        } catch {
            print("❌ Failed to create prompt: \(error)")
            return "Generate 5 general recommendations"
        }
    }
    
    /// Migrates existing behavioral data to include user identity
    func linkExistingBehaviorToUserIdentity() async {
        print("🔄 Starting migration to link behavior data with user identity...")
        
        do {
            // Get all users
            let usersSnapshot = try await db.collection("users").getDocuments()
            
            for userDoc in usersSnapshot.documents {
                let data = userDoc.data()
                let userId = userDoc.documentID
                let email = data["email"] as? String ?? ""
                let displayName = data["displayName"] as? String ?? ""
                
                // Add user identity fields to behavioral data
                let updates: [String: Any] = [
                    "userEmail": email,
                    "userDisplayName": displayName,
                    "behaviorLinkedToIdentity": true,
                    "migrationDate": FieldValue.serverTimestamp()
                ]
                
                try await db.collection("users").document(userId).updateData(updates)
                print("✅ Linked behavior data for: \(email)")
            }
            
            print("🎉 Migration completed!")
            
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
} 