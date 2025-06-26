import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Migration Utility for Behavioral Data
// This utility links existing behavioral data (like in your screenshot) to user email/display name
@MainActor
class MigrationUtility: ObservableObject {
    static let shared = MigrationUtility()
    private init() {}
    
    private let db = Firestore.firestore()
    
    // MARK: - Sample Migration Functions
    
    /// Links existing behavioral data to user identity for recommendations
    func linkBehaviorDataToUserIdentity() async {
        print("🔄 Starting behavioral data migration to link with user identity...")
        
        do {
            // Step 1: Get all users with their emails and display names
            let usersSnapshot = try await db.collection("users").getDocuments()
            var userMap: [String: UserInfo] = [:]
            
            for userDoc in usersSnapshot.documents {
                let data = userDoc.data()
                let userId = userDoc.documentID
                
                let userInfo = UserInfo(
                    userId: userId,
                    email: data["email"] as? String ?? "",
                    displayName: data["displayName"] as? String ?? "",
                    username: data["username"] as? String ?? ""
                )
                
                userMap[userId] = userInfo
                print("Found user: \(userInfo.email) with ID: \(userId)")
            }
            
            // Step 2: Update user documents with behavioral data structure
            for (userId, userInfo) in userMap {
                await migrateSingleUserBehaviorData(userId: userId, userInfo: userInfo)
            }
            
            print("🎉 Migration completed successfully!")
            
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
    
    /// Demonstrates how to update the user document from your screenshot data
    func demoUpdateUserWithBehaviorData() async {
        // This simulates updating the user document with data from your screenshot
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user")
            return
        }
        
        // Sample data from your screenshot
        let behaviorData: [String: Any] = [
            "sessionCount": 24,
            "totalPlaceViews": 30,
            "totalThumbsUp": 18,
            "totalThumbsDown": 12,
            "dislikeCount": 12,
            "dislikes": ["The Beat Museum", "Bouche", "Cafe Broadway", "Mellis Cafe"],
            "blockedUsers": [],
            "authProvider": "email",
            "createdAt": Date(),
            
            // Enhanced with user identity linking
            "behaviorLinkedToIdentity": true,
            "lastBehaviorSync": FieldValue.serverTimestamp(),
            
            // Add comprehensive behavioral analytics
            "behaviorAnalytics": [
                "explorationStyle": "selective", // Based on dislike ratio
                "venuePreferences": analyzeVenuePreferences(["The Beat Museum", "Bouche", "Cafe Broadway", "Mellis Cafe"]),
                "engagementLevel": calculateEngagementLevel(views: 30, likes: 18, dislikes: 12),
                "recommendationReadiness": true
            ]
        ]
        
        do {
            try await db.collection("users").document(uid).updateData(behaviorData)
            print("✅ Demo: Updated user with enhanced behavioral data")
            
            // Create personalized recommendation
            await createPersonalizedRecommendationDemo(userId: uid)
            
        } catch {
            print("❌ Failed to update user: \(error)")
        }
    }
    
    /// Creates a personalized recommendation using the enhanced behavioral data
    func createPersonalizedRecommendationDemo(userId: String) async {
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let userData = userDoc.data() else { return }
            
            let email = userData["email"] as? String ?? ""
            let displayName = userData["displayName"] as? String ?? ""
            let dislikes = userData["dislikes"] as? [String] ?? []
            let totalLikes = userData["totalThumbsUp"] as? Int ?? 0
            let totalDislikes = userData["totalThumbsDown"] as? Int ?? 0
            
            // Generate personalized prompt using behavioral data
            let personalizedPrompt = """
            ULTRA-PERSONALIZED RECOMMENDATION for \(displayName) (\(email))
            
            USER BEHAVIORAL PROFILE:
            - Total Likes: \(totalLikes) 
            - Total Dislikes: \(totalDislikes)
            - Places to AVOID: \(dislikes.joined(separator: ", "))
            
            BEHAVIORAL INSIGHTS:
            - Selectivity Score: \(Double(totalDislikes) / Double(totalLikes + totalDislikes))
            - Exploration Style: \(totalDislikes > 5 ? "Cautious Explorer" : "Open Explorer")
            - Venue Type Pattern: \(analyzeDislikedVenueTypes(dislikes))
            
            Based on this user's specific behavioral patterns, generate 3 recommendations that:
            1. AVOID similar venues to their dislikes
            2. Match their selectivity preferences
            3. Consider their exploration style
            
            Return as JSON: [{"name": "...", "reason": "...", "confidence": 0.9}]
            """
            
            print("📝 Generated personalized prompt for \(email):")
            print(personalizedPrompt)
            
            // In a real implementation, you'd send this to Gemini AI
            await saveDemoRecommendation(userId: userId, prompt: personalizedPrompt)
            
        } catch {
            print("❌ Failed to create personalized recommendation: \(error)")
        }
    }
    
    // MARK: - Migration Helper Functions
    
    private func migrateSingleUserBehaviorData(userId: String, userInfo: UserInfo) async {
        do {
            // Check if user already has enhanced behavioral data
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let existingData = userDoc.data() else { return }
            
            // Only migrate if they don't already have enhanced data
            if existingData["behaviorLinkedToIdentity"] == nil {
                let enhancedData: [String: Any] = [
                    "userEmail": userInfo.email,
                    "userDisplayName": userInfo.displayName,
                    "behaviorLinkedToIdentity": true,
                    "migrationDate": FieldValue.serverTimestamp(),
                    
                    // Ensure these fields exist with defaults
                    "sessionCount": existingData["sessionCount"] ?? 0,
                    "totalPlaceViews": existingData["totalPlaceViews"] ?? 0,
                    "totalThumbsUp": existingData["totalThumbsUp"] ?? 0,
                    "totalThumbsDown": existingData["totalThumbsDown"] ?? 0,
                    "likes": existingData["likes"] ?? [],
                    "dislikes": existingData["dislikes"] ?? [],
                    "interactionLogs": existingData["interactionLogs"] ?? []
                ]
                
                try await db.collection("users").document(userId).updateData(enhancedData)
                print("✅ Migrated behavioral data for: \(userInfo.email)")
            } else {
                print("ℹ️ User \(userInfo.email) already has enhanced behavioral data")
            }
            
        } catch {
            print("❌ Failed to migrate user \(userInfo.email): \(error)")
        }
    }
    
    private func saveDemoRecommendation(userId: String, prompt: String) async {
        let demoRecommendation: [String: Any] = [
            "userId": userId,
            "personalizedPrompt": prompt,
            "generatedAt": FieldValue.serverTimestamp(),
            "type": "demo_behavioral_recommendation",
            "status": "ready_for_ai_processing"
        ]
        
        do {
            try await db.collection("personalizedRecommendations").document(userId).setData(demoRecommendation)
            print("✅ Saved demo recommendation for processing")
        } catch {
            print("❌ Failed to save demo recommendation: \(error)")
        }
    }
    
    // MARK: - Behavioral Analysis Functions
    
    private func analyzeVenuePreferences(_ dislikes: [String]) -> [String: Any] {
        var venueTypes: [String: Int] = [:]
        
        for place in dislikes {
            let lowercased = place.lowercased()
            if lowercased.contains("museum") {
                venueTypes["museums"] = (venueTypes["museums"] ?? 0) + 1
            } else if lowercased.contains("cafe") || lowercased.contains("coffee") {
                venueTypes["cafes"] = (venueTypes["cafes"] ?? 0) + 1
            } else if lowercased.contains("restaurant") || lowercased.contains("dining") {
                venueTypes["restaurants"] = (venueTypes["restaurants"] ?? 0) + 1
            } else {
                venueTypes["other"] = (venueTypes["other"] ?? 0) + 1
            }
        }
        
        return [
            "dislikedVenueTypes": venueTypes,
            "recommendAvoid": Array(venueTypes.keys),
            "preferenceStrength": venueTypes.values.max() ?? 0
        ]
    }
    
    private func calculateEngagementLevel(views: Int, likes: Int, dislikes: Int) -> [String: Any] {
        let totalInteractions = likes + dislikes
        let engagementRate = totalInteractions > 0 ? Double(totalInteractions) / Double(views) : 0.0
        
        let level = switch engagementRate {
        case 0.0..<0.3: "low"
        case 0.3..<0.6: "moderate"
        default: "high"
        }
        
        return [
            "engagementRate": engagementRate,
            "level": level,
            "totalInteractions": totalInteractions,
            "likesToDislikesRatio": dislikes > 0 ? Double(likes) / Double(dislikes) : Double(likes)
        ]
    }
    
    private func analyzeDislikedVenueTypes(_ dislikes: [String]) -> String {
        let analysis = analyzeVenuePreferences(dislikes)
        guard let dislikedTypes = analysis["dislikedVenueTypes"] as? [String: Int],
              let mostDisliked = dislikedTypes.max(by: { $0.value < $1.value }) else {
            return "No clear pattern"
        }
        
        return "Tends to dislike \(mostDisliked.key) (\(mostDisliked.value) instances)"
    }
}

// MARK: - Helper Models

struct UserInfo {
    let userId: String
    let email: String
    let displayName: String
    let username: String
}

// MARK: - Demo Usage Extension

extension MigrationUtility {
    
    /// Call this function to run a complete demo of the behavioral data linking
    func runCompleteMigrationDemo() async {
        print("🚀 Starting Complete Behavioral Data Migration Demo")
        print("=" * 50)
        
        // Step 1: Link behavioral data to user identity
        await linkBehaviorDataToUserIdentity()
        
        print("\n" + "=" * 50)
        
        // Step 2: Demo updating a user with enhanced behavioral data
        await demoUpdateUserWithBehaviorData()
        
        print("\n" + "=" * 50)
        print("✅ Demo completed! Your behavioral data is now linked to user identity for enhanced recommendations.")
        
        // Step 3: Show how to use this data in practice
        print("\n📋 NEXT STEPS:")
        print("1. Use BehaviorDataManager.shared.recordPlaceInteraction() for new interactions")
        print("2. Call BehaviorDataManager.shared.createPersonalizedPrompt() for AI recommendations")
        print("3. Your existing data from the screenshot is now linked to user emails")
        print("4. Recommendation engine will use both behavioral data AND user identity")
    }
}

// MARK: - String Extension for Demo Formatting

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
} 