import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

enum PlaceReaction: String, Codable {
    case liked
    case disliked
}

/// Production-level ReactionManager with comprehensive Firestore integration and invasive user tracking
@MainActor
final class ReactionManager: ObservableObject {
    static let shared = ReactionManager()
    private let storageKey = "planit_reactions_v1"
    @Published private(set) var reactions: [String: PlaceReaction] = [:]
    
    // Production tracking dependencies
    private let db = Firestore.firestore()
    private let trackingService = UserTrackingService.shared
    private let locationManager = LocationManager()
    
    // Session tracking for invasive analytics
    private var sessionStartTime = Date()
    private var currentSession: [String: Any] = [:]
    private var reactionTimestamps: [Date] = []
    
    private init() {
        load()
        startInvasiveTracking()
    }
    
    // MARK: - Public Interface
    func reaction(for placeId: String) -> PlaceReaction? {
        reactions[placeId]
    }
    
    /// Sets reaction and ALWAYS updates Firestore with comprehensive tracking
    func setReaction(_ reaction: PlaceReaction?, for placeId: String, place: Place? = nil) {
        // Update local storage immediately for responsive UI
        if let reaction = reaction {
            reactions[placeId] = reaction
        } else {
            reactions.removeValue(forKey: placeId)
        }
        save()
        
        // Record comprehensive tracking data in Firestore
        Task {
            await recordReactionWithInvasiveTracking(
                reaction: reaction,
                placeId: placeId,
                place: place
            )
        }
    }
    
    // MARK: - Comprehensive Firestore Integration
    private func recordReactionWithInvasiveTracking(
        reaction: PlaceReaction?,
        placeId: String,
        place: Place?
    ) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user for reaction tracking")
            return
        }
        
        // Get user context for detailed tracking
        let userDoc = try? await db.collection("users").document(uid).getDocument()
        let userData = userDoc?.data()
        let userEmail = userData?["email"] as? String ?? ""
        let userDisplayName = userData?["displayName"] as? String ?? ""
        
        let timestamp = Date()
        let timeOfDay = getCurrentTimeOfDay()
        let dayOfWeek = getCurrentDayOfWeek()
        
        // Build comprehensive tracking data
        let reactionData: [String: Any] = [
            "placeId": placeId,
            "placeName": place?.name ?? "Unknown Place",
            "placeCategory": place?.category.rawValue ?? "unknown",
            "placeRating": place?.rating ?? 0.0,
            "placePriceRange": place?.priceRange ?? "",
            "reaction": reaction?.rawValue ?? "removed",
            "timestamp": timestamp,
            "userEmail": userEmail,
            "userDisplayName": userDisplayName,
            "userId": uid,
            
            // Temporal context for behavioral analysis
            "timeOfDay": timeOfDay,
            "dayOfWeek": dayOfWeek,
            "hour": Calendar.current.component(.hour, from: timestamp),
            "minute": Calendar.current.component(.minute, from: timestamp),
            "sessionDuration": timestamp.timeIntervalSince(sessionStartTime),
            
            // Location context if available
            "userLocation": getCurrentLocationData(),
            
            // Behavioral pattern analysis
            "reactionVelocity": calculateReactionVelocity(),
            "sessionReactionCount": reactionTimestamps.count,
            "timeSinceLastReaction": getTimeSinceLastReaction(),
            
            // Device and app context
            "deviceInfo": getDeviceInfo(),
            "appVersion": getAppVersion(),
            "connectionType": getConnectionType()
        ]
        
        // Track reaction timing for behavioral analysis
        reactionTimestamps.append(timestamp)
        
        // Prepare comprehensive Firestore updates
        var updates: [String: Any] = [
            "reactionHistory": FieldValue.arrayUnion([reactionData]),
            "lastActiveAt": FieldValue.serverTimestamp(),
            "lastReactionAt": FieldValue.serverTimestamp(),
            "userEmail": userEmail,
            "userDisplayName": userDisplayName,
            
            // Session tracking
            "currentSessionData": getCurrentSessionData(),
            "totalSessions": FieldValue.increment(Int64(1)),
            
            // Behavioral analytics
            "behaviorAnalytics.reactionPatterns.\(timeOfDay)": FieldValue.increment(Int64(1)),
            "behaviorAnalytics.reactionPatterns.\(dayOfWeek)": FieldValue.increment(Int64(1)),
            "behaviorAnalytics.totalReactions": FieldValue.increment(Int64(1))
        ]
        
        // Update based on reaction type with detailed counters
        if let reaction = reaction {
            switch reaction {
            case .liked:
                updates["totalThumbsUp"] = FieldValue.increment(Int64(1))
                updates["likes"] = FieldValue.arrayUnion([place?.name ?? placeId])
                updates["dislikes"] = FieldValue.arrayRemove([place?.name ?? placeId])
                updates["behaviorAnalytics.likingVelocity"] = calculateLikingVelocity()
                updates["recentLikes"] = FieldValue.arrayUnion([place?.name ?? placeId])
                
                // Track place category preferences
                if let category = place?.category {
                    updates["categoryPreferences.\(category.rawValue).likes"] = FieldValue.increment(Int64(1))
                    updates["categoryAffinities.\(category.rawValue)"] = FieldValue.increment(Int64(1))
                }
                
            case .disliked:
                updates["totalThumbsDown"] = FieldValue.increment(Int64(1))
                updates["dislikes"] = FieldValue.arrayUnion([place?.name ?? placeId])
                updates["likes"] = FieldValue.arrayRemove([place?.name ?? placeId])
                updates["behaviorAnalytics.dislikingVelocity"] = calculateDislikingVelocity()
                updates["recentDislikes"] = FieldValue.arrayUnion([place?.name ?? placeId])
                
                // Track what they avoid
                if let category = place?.category {
                    updates["categoryPreferences.\(category.rawValue).dislikes"] = FieldValue.increment(Int64(1))
                    updates["categoryAvoidance.\(category.rawValue)"] = FieldValue.increment(Int64(1))
                }
            }
        } else {
            // Reaction removed - track this behavior too
            updates["behaviorAnalytics.reactionsRemoved"] = FieldValue.increment(Int64(1))
            updates["behaviorAnalytics.indecisionMetrics"] = FieldValue.increment(Int64(1))
        }
        
        // Execute Firestore update
        do {
            try await db.collection("users").document(uid).updateData(updates)
            print("✅ Comprehensive reaction tracking recorded for \(userEmail)")
            
            // Trigger additional invasive tracking
            await trackingService.recordUserInteraction(
                type: "place_reaction",
                details: reactionData,
                context: getCurrentContextData()
            )
            
            // Update recommendation algorithm with new data
            await updateRecommendationAlgorithm(reaction: reaction, place: place)
            
        } catch {
            print("❌ Failed to record reaction tracking: \(error)")
            
            // Fallback: Store failed updates for retry
            await storePendingUpdate(updates: updates, error: error)
        }
    }
    
    // MARK: - Advanced Analytics Methods
    
    private func startInvasiveTracking() {
        sessionStartTime = Date()
        currentSession = [
            "sessionId": UUID().uuidString,
            "startTime": sessionStartTime,
            "initialLocation": getCurrentLocationData(),
            "deviceInfo": getDeviceInfo()
        ]
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon" 
        case 17..<21: return "evening"
        default: return "night"
        }
    }
    
    private func getCurrentDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date()).lowercased()
    }
    
    private func getCurrentLocationData() -> [String: Any] {
        guard let location = locationManager.currentLocation else {
            return ["available": false]
        }
        
        return [
            "available": true,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "timestamp": location.timestamp
        ]
    }
    
    private func calculateReactionVelocity() -> Double {
        guard reactionTimestamps.count > 1 else { return 0.0 }
        
        let timeWindow: TimeInterval = 300 // 5 minutes
        let recentReactions = reactionTimestamps.filter { 
            Date().timeIntervalSince($0) <= timeWindow 
        }
        
        return Double(recentReactions.count) / (timeWindow / 60) // reactions per minute
    }
    
    private func calculateLikingVelocity() -> Double {
        let likes = reactions.values.filter { $0 == .liked }.count
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        return Double(likes) / max(sessionDuration / 60, 1) // likes per minute
    }
    
    private func calculateDislikingVelocity() -> Double {
        let dislikes = reactions.values.filter { $0 == .disliked }.count
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        return Double(dislikes) / max(sessionDuration / 60, 1) // dislikes per minute
    }
    
    private func getTimeSinceLastReaction() -> TimeInterval {
        guard let lastReaction = reactionTimestamps.last else { return 0 }
        return Date().timeIntervalSince(lastReaction)
    }
    
    private func getCurrentSessionData() -> [String: Any] {
        var sessionData = currentSession
        sessionData["currentDuration"] = Date().timeIntervalSince(sessionStartTime)
        sessionData["totalReactions"] = reactionTimestamps.count
        sessionData["reactionVelocity"] = calculateReactionVelocity()
        return sessionData
    }
    
    private func getCurrentContextData() -> [String: Any] {
        return [
            "timeOfDay": getCurrentTimeOfDay(),
            "dayOfWeek": getCurrentDayOfWeek(),
            "sessionDuration": Date().timeIntervalSince(sessionStartTime),
            "totalReactions": reactionTimestamps.count,
            "location": getCurrentLocationData(),
            "batteryLevel": getBatteryLevel(),
            "memoryUsage": getMemoryUsage()
        ]
    }
    
    private func getDeviceInfo() -> [String: Any] {
        return [
            "model": UIDevice.current.model,
            "systemVersion": UIDevice.current.systemVersion,
            "screenSize": "\(UIScreen.main.bounds.width)x\(UIScreen.main.bounds.height)",
            "timezone": TimeZone.current.identifier,
            "locale": Locale.current.identifier
        ]
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getConnectionType() -> String {
        // Simplified - in production you'd use network monitoring
        return "wifi" // placeholder
    }
    
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    private func getMemoryUsage() -> [String: Any] {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return [
                "resident_size": info.resident_size,
                "virtual_size": info.virtual_size
            ]
        }
        
        return ["available": false]
    }
    
    private func updateRecommendationAlgorithm(reaction: PlaceReaction?, place: Place?) async {
        // Trigger recommendation system update with new behavioral data
        if let place = place {
            let interaction: PlaceInteraction = reaction == .liked ? .liked : .disliked
            await DynamicCategoryManager.shared.recordPlaceInteraction(
                place: place, 
                interaction: interaction
            )
        }
    }
    
    private func storePendingUpdate(updates: [String: Any], error: Error) async {
        // Store failed updates for retry when connection is restored
        let pendingUpdate = [
            "updates": updates,
            "error": error.localizedDescription,
            "timestamp": Date(),
            "retryCount": 0
        ] as [String : Any]
        
        // Store in local database for retry
        UserDefaults.standard.set(pendingUpdate, forKey: "pending_reaction_updates")
    }
    
    // MARK: - Local Persistence (Backup)
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: PlaceReaction].self, from: data) {
            reactions = decoded
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(reactions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Supporting Extensions
extension ReactionManager {
    /// Convenience method for updating reactions with place data
    func setReaction(_ reaction: PlaceReaction?, for place: Place) {
        let placeId = place.googlePlaceId ?? place.id.uuidString
        setReaction(reaction, for: placeId, place: place)
    }
    
    /// Get comprehensive analytics for current user
    func getUserAnalytics() async -> [String: Any]? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            return doc.data()
        } catch {
            print("❌ Failed to fetch user analytics: \(error)")
            return nil
        }
    }
} 