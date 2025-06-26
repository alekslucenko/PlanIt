import Foundation
import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import CoreLocation

// MARK: - Notification Extensions
extension Notification.Name {
    static let fingerprintDidChange = Notification.Name("fingerprintDidChange")
}

// MARK: - AppUserFingerprint
/// A lightweight, codable representation of the user document that we care about
/// for AI recommendations.  This intentionally mirrors the Firestore schema so
/// that we can serialise / deserialise quickly.
struct AppUserFingerprint: Codable, Equatable {
    var displayName: String?
    var email: String?
    var location: LocationPoint?
    var onboardingCompleted: Bool?
    var onboardingResponses: [[String: AnyCodable]]? // generic for now
    var likes: [String]?
    var dislikes: [String]?
    var interactionLogs: [[String: AnyCodable]]?
    // New advanced metrics
    var likeCount: Int?
    var dislikeCount: Int?
    var tagAffinities: [String: Int]?
    
    // Additional properties for mission generation
    var preferredPlaceTypes: [String]
    var moodHistory: [String]
    var cuisineHistory: [String]
    var currentLocation: LocationPoint?
    
    // Default initializer with sensible defaults
    init() {
        self.displayName = nil
        self.email = nil
        self.location = nil
        self.onboardingCompleted = false
        self.onboardingResponses = nil
        self.likes = nil
        self.dislikes = nil
        self.interactionLogs = nil
        self.likeCount = 0
        self.dislikeCount = 0
        self.tagAffinities = [:]
        self.preferredPlaceTypes = ["restaurant", "cafe", "park", "shopping"]
        self.moodHistory = ["Relaxing", "Social"]
        self.cuisineHistory = ["Italian", "Mexican", "Asian"]
        self.currentLocation = nil
    }
    
    // Custom Equatable implementation since AnyCodable doesn't conform to Equatable
    static func == (lhs: AppUserFingerprint, rhs: AppUserFingerprint) -> Bool {
        return lhs.displayName == rhs.displayName &&
               lhs.email == rhs.email &&
               lhs.location == rhs.location &&
               lhs.onboardingCompleted == rhs.onboardingCompleted &&
               lhs.likes == rhs.likes &&
               lhs.dislikes == rhs.dislikes &&
               lhs.likeCount == rhs.likeCount &&
               lhs.dislikeCount == rhs.dislikeCount &&
               lhs.tagAffinities == rhs.tagAffinities &&
               lhs.preferredPlaceTypes == rhs.preferredPlaceTypes &&
               lhs.moodHistory == rhs.moodHistory &&
               lhs.cuisineHistory == rhs.cuisineHistory &&
               lhs.currentLocation == rhs.currentLocation &&
               compareAnyCodableArrays(lhs.onboardingResponses, rhs.onboardingResponses) &&
               compareAnyCodableArrays(lhs.interactionLogs, rhs.interactionLogs)
    }
    
    private static func compareAnyCodableArrays(_ lhs: [[String: AnyCodable]]?, _ rhs: [[String: AnyCodable]]?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (let lhsArray?, let rhsArray?):
            guard lhsArray.count == rhsArray.count else { return false }
            for (lhsDict, rhsDict) in zip(lhsArray, rhsArray) {
                guard lhsDict.count == rhsDict.count else { return false }
                for (key, lhsValue) in lhsDict {
                    guard let rhsValue = rhsDict[key] else { return false }
                    // Simple comparison based on string representation
                    if String(describing: lhsValue) != String(describing: rhsValue) {
                        return false
                    }
                }
            }
            return true
        default:
            return false
        }
    }
}

// MARK: - LocationPoint (using shared LocationPoint from UserFingerprint.swift)

// MARK: - Type-erased Codable helper
/// Allows us to embed arbitrary JSON structures (e.g. arrays of heterogenous
/// dictionaries) while still conforming to `Codable`.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as common types first
        if let int = try? container.decode(Int.self) { 
            value = int
            return 
        }
        if let double = try? container.decode(Double.self) { 
            value = double
            return 
        }
        if let bool = try? container.decode(Bool.self) { 
            value = bool
            return 
        }
        if let string = try? container.decode(String.self) { 
            value = string
            return 
        }
        
        // Try to decode as arrays and dictionaries
        if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
            return
        }
        if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
            return
        }
        
        // Handle null values
        if container.decodeNil() { 
            value = NSNull()
            return 
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let int as Int: 
            try container.encode(int)
        case let double as Double: 
            try container.encode(double)
        case let bool as Bool: 
            try container.encode(bool)
        case let string as String: 
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dictionary as [String: Any]:
            let codableDictionary = dictionary.mapValues { AnyCodable($0) }
            try container.encode(codableDictionary)
        case is NSNull:
            try container.encodeNil()
        default: 
            try container.encodeNil()
        }
    }
}

// MARK: - UserFingerprintManager
@MainActor
final class UserFingerprintManager: ObservableObject {
    static let shared = UserFingerprintManager()
    private init() {}

    // Published fingerprint so views/services can respond to changes
    @Published private(set) var fingerprint: AppUserFingerprint?
    @Published private(set) var legacyFingerprint: AppUserFingerprint? // Keep for backwards compatibility
    @Published private(set) var lastFingerprintUpdate: Date?

    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var listener: ListenerRegistration?

    /// Call this immediately after authentication to begin listening for
    /// fingerprint updates in real-time.
    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { 
            print("❌ No authenticated user for fingerprint listening")
            return 
        }
        
        // Remove any existing listener
        stopListening()
        
        print("🧬 Starting enhanced fingerprint listener for user: \(uid)")
        
        listener = db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Fingerprint listener error: \(error.localizedDescription)")
                return
            }
            
            guard let doc = snapshot, let data = doc.data() else {
                print("❌ No fingerprint document data found")
                return
            }

            // Convert Firestore data to JSON-compatible format
            // This handles Firebase Timestamp objects that can't be directly serialized
            do {
                let sanitizedData = self.sanitizeFirestoreData(data)
                
                // Create a more robust decoder with missing field handling
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                // Add default values for missing fields
                var fingerprintData = sanitizedData
                if fingerprintData["preferredPlaceTypes"] == nil {
                    fingerprintData["preferredPlaceTypes"] = ["restaurant", "cafe", "park", "shopping"]
                }
                if fingerprintData["moodHistory"] == nil {
                    fingerprintData["moodHistory"] = ["Relaxing", "Social"]
                }
                if fingerprintData["cuisineHistory"] == nil {
                    fingerprintData["cuisineHistory"] = ["Italian", "Mexican", "Asian"]
                }
                if fingerprintData["likeCount"] == nil {
                    fingerprintData["likeCount"] = 0
                }
                if fingerprintData["dislikeCount"] == nil {
                    fingerprintData["dislikeCount"] = 0
                }
                if fingerprintData["tagAffinities"] == nil {
                    fingerprintData["tagAffinities"] = [:]
                }
                
                let jsonData = try JSONSerialization.data(withJSONObject: fingerprintData, options: [])
                let decoded = try decoder.decode(AppUserFingerprint.self, from: jsonData)
                
                DispatchQueue.main.async {
                    let previousFingerprint = self.fingerprint
                    self.fingerprint = decoded
                    self.lastFingerprintUpdate = Date()
                    
                    print("🧬 Fingerprint updated – Triggering downstream consumers")
                    
                    // Check if this is a significant change that should trigger re-recommendations
                    if self.shouldTriggerRecommendationRefresh(
                        previous: previousFingerprint,
                        current: decoded
                    ) {
                        print("🔄 Significant fingerprint change detected - will refresh recommendations")
                        self.notifyRecommendationRefreshNeeded()
                    }
                }
            } catch {
                print("❌ Failed to decode fingerprint: \(error)")
                print("📄 Raw data: \(data)")
                
                // Create a fallback fingerprint to prevent app from breaking
                DispatchQueue.main.async {
                    if self.fingerprint == nil {
                        print("🔧 Creating fallback fingerprint")
                        self.fingerprint = AppUserFingerprint()
                        self.lastFingerprintUpdate = Date()
                    }
                }
            }
        }
    }
    
    /// Stops the real-time listener
    func stopListening() {
        listener?.remove()
        listener = nil
        print("🧬 Fingerprint listener stopped")
    }
    
    /// Determines if fingerprint changes are significant enough to refresh recommendations
    private func shouldTriggerRecommendationRefresh(
        previous: AppUserFingerprint?,
        current: AppUserFingerprint
    ) -> Bool {
        // If this is the first fingerprint load, don't trigger refresh
        guard let previous = previous else { return false }
        
        // Check for significant changes
        let likesChanged = previous.likes != current.likes
        let dislikesChanged = previous.dislikes != current.dislikes
        let interactionLogsChanged = (previous.interactionLogs?.count ?? 0) != (current.interactionLogs?.count ?? 0)
        
        return likesChanged || dislikesChanged || interactionLogsChanged
    }
    
    /// Notifies the recommendation manager that a refresh is needed
    private func notifyRecommendationRefreshNeeded() {
        // Post a notification that the RecommendationManager can listen to
        NotificationCenter.default.post(
            name: .fingerprintDidChange,
            object: self,
            userInfo: ["fingerprint": fingerprint as Any]
        )
    }

    /// Simple helper that produces the raw prompt we will send to Gemini. This
    /// is *not* yet the final implementation, but it satisfies compile-time
    /// needs and provides a central place to evolve later.
    func buildGeminiPrompt(currentDate: Date = Date()) -> String {
        guard let fp = fingerprint else { 
            print("⚠️ No fingerprint available for Gemini prompt")
            return "User has no fingerprint data available. Please provide general recommendations." 
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        var prompt = "You are PlanIt AI Recommendation engine. Today is \(dateFormatter.string(from: currentDate))."
        
        if let name = fp.displayName { 
            prompt += "\nUser Display Name: \(name)" 
        }
        
        if let location = fp.location {
            prompt += "\nUser Coordinates: {lat: \(location.latitude), lon: \(location.longitude)}"
        }
        
        if let responses = fp.onboardingResponses {
            prompt += "\nOnboarding Responses: \(responses)"
        }
        
        if let likes = fp.likes, !likes.isEmpty {
            prompt += "\nPreviously liked places: \(likes.joined(separator: ", "))"
        }
        
        if let dislikes = fp.dislikes, !dislikes.isEmpty {
            prompt += "\nDisliked places: \(dislikes.joined(separator: ", "))"
        }

        prompt += "\n\nPlease suggest new places using Google Places style tags. Focus on places that match the user's preferences and location. Return recommendations as detailed JSON with place categories, descriptions, and reasoning."
        
        return prompt
    }
    
    /// Converts Firestore data to JSON-compatible types
    /// Specifically handles Firebase Timestamp objects by converting them to ISO 8601 strings
    private func sanitizeFirestoreData(_ data: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]
        
        for (key, value) in data {
            sanitized[key] = sanitizeValue(value)
        }
        
        return sanitized
    }
    
    /// Recursively sanitizes values, converting Timestamps to strings
    private func sanitizeValue(_ value: Any) -> Any {
        if let timestamp = value as? Timestamp {
            // Convert Firebase Timestamp to ISO 8601 string
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: timestamp.dateValue())
        } else if let array = value as? [Any] {
            return array.map { sanitizeValue($0) }
        } else if let dict = value as? [String: Any] {
            var sanitizedDict: [String: Any] = [:]
            for (key, val) in dict {
                sanitizedDict[key] = sanitizeValue(val)
            }
            return sanitizedDict
        } else if let geoPoint = value as? GeoPoint {
            // Convert GeoPoint to a simple dictionary
            return [
                "latitude": geoPoint.latitude,
                "longitude": geoPoint.longitude
            ]
        } else {
            return value
        }
    }

    /// Call when app launches to increment session count
    func incrementSessionCount() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                try await Firestore.firestore().collection("users").document(uid).updateData([
                    "behavior.sessionCount": FieldValue.increment(Int64(1))
                ])
            } catch {
                print("❌ Failed to increment session count: \(error)")
            }
        }
    }

    func recordPlaceInteraction(place: Place, interaction: PlaceInteraction, userLocation: CLLocation? = nil) async {
        // Enhanced tracking - record more behavioral data
        let enhancedInteractionData: [String: Any] = [
            "placeId": place.googlePlaceId ?? "",
            "placeName": place.name,
            "category": place.category.rawValue,
            "interaction": interaction.rawValue,
            "timestamp": Date(),
            "location": [
                "latitude": userLocation?.coordinate.latitude ?? 0.0,
                "longitude": userLocation?.coordinate.longitude ?? 0.0
            ],
            "rating": place.rating,
            "priceRange": place.priceRange,
            // NEW: Enhanced behavioral tracking
            "timeOfDay": getCurrentTimeOfDay(),
            "dayOfWeek": getCurrentDayOfWeek(),
            "sessionDuration": getSessionDuration(),
            "scrollBehavior": getScrollBehavior(),
            "dwellTime": getDwellTime(),
            "weatherConditions": getCurrentWeather(),
            "deviceUsagePattern": getDeviceUsagePattern(),
            "socialContext": getSocialContext(),
            "emotionalState": inferEmotionalState(),
            "attentionLevel": getAttentionLevel()
        ]
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        print("📊 Recording \(interaction.rawValue) interaction for \(place.name)")
        
        var updates: [String: Any] = [
            "interactionLogs": FieldValue.arrayUnion([enhancedInteractionData]),
            "lastInteractionTime": FieldValue.serverTimestamp(),
            // NEW: Enhanced behavioral analytics
            "behavioralPatterns.timePreferences.\(getCurrentTimeOfDay())": FieldValue.increment(Int64(1)),
            "behavioralPatterns.dayPreferences.\(getCurrentDayOfWeek())": FieldValue.increment(Int64(1)),
            "behavioralPatterns.weatherPreferences.\(getCurrentWeather())": FieldValue.increment(Int64(1)),
            "psychographics.explorationStyle": getExplorationStyle(),
            "psychographics.socialTendency": getSocialTendency(),
            "psychographics.riskTolerance": getRiskTolerance()
        ]
        
        Firestore.firestore()
            .collection("userFingerprints")
            .document(uid)
            .updateData(updates) { error in
                if let error = error {
                    print("❌ Failed to record interaction: \(error)")
                } else {
                    print("✅ Interaction recorded")
                }
            }
    }

    // MARK: - Advanced Behavioral Tracking & UX Psychology
    
    // Track for curiosity gap and novelty exposure
    private var lastInteractionTimestamps: [Date] = []
    private var dwellTimeTracker: [String: Date] = [:]
    private var scrollVelocityMeasurements: [Double] = []
    private var tapPatternData: [TapData] = []
    public var sessionStartTime: Date = Date()
    public var lastTabSwitchTime: Date = Date()
    public var lastLocationAccuracy: Double?
    
    struct TapData {
        let timestamp: Date
        let force: Double
        let duration: Double
        let target: String
    }
    
    func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }
    
    private func getCurrentDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date()).lowercased()
    }
    
    func getSessionDuration() -> TimeInterval {
        return Date().timeIntervalSince(sessionStartTime)
    }
    
    // Advanced scroll behavior analysis for engagement patterns
    private func getScrollBehavior() -> String {
        let averageVelocity = scrollVelocityMeasurements.isEmpty ? 0 : scrollVelocityMeasurements.reduce(0, +) / Double(scrollVelocityMeasurements.count)
        
        switch averageVelocity {
        case 0..<200: return "deliberate_reader"     // Slow, careful scrolling
        case 200..<500: return "moderate_explorer"   // Balanced browsing
        case 500..<1000: return "quick_scanner"      // Fast browsing
        default: return "impatient_seeker"           // Very fast, seeking specific content
        }
    }
    
    // Dwell time analysis for attention patterns
    func trackDwellTime(for contentId: String, action: String) {
        if action == "start" {
            dwellTimeTracker[contentId] = Date()
        } else if action == "end", let startTime = dwellTimeTracker[contentId] {
            let dwellTime = Date().timeIntervalSince(startTime)
            recordDwellPattern(contentId: contentId, duration: dwellTime)
            dwellTimeTracker.removeValue(forKey: contentId)
        }
    }
    
    private func recordDwellPattern(contentId: String, duration: TimeInterval) {
        // Record dwell patterns for attention analysis
        Task {
            await recordBehavioralPattern("dwellTime", data: [
                "contentId": contentId,
                "duration": duration,
                "attentionLevel": classifyAttentionLevel(duration)
            ])
        }
    }
    
    private func classifyAttentionLevel(_ duration: TimeInterval) -> String {
        switch duration {
        case 0..<2: return "glance"           // Quick look
        case 2..<10: return "scan"            // Brief engagement
        case 10..<30: return "read"           // Moderate attention
        case 30..<60: return "study"          // Deep attention
        default: return "immersed"            // Very deep engagement
        }
    }
    
    private func getDwellTime() -> TimeInterval {
        // Average dwell time for current session
        return 15.0 // This would be calculated from actual data
    }
    
    // Weather integration for contextual recommendations
    private func getCurrentWeather() -> String {
        // This would integrate with WeatherService
        // For now, basic time-based inference
        let hour = Calendar.current.component(.hour, from: Date())
        let month = Calendar.current.component(.month, from: Date())
        
        // Simple seasonal and time-based weather inference
        switch (month, hour) {
        case (12...2, _): return "cold"
        case (3...5, 6..<18): return "spring_mild"
        case (6...8, 6..<18): return "sunny_warm"
        case (6...8, 18...23): return "warm_evening"
        case (9...11, _): return "autumn_cool"
        default: return "moderate"
        }
    }
    
    // Device usage pattern analysis
    private func getDeviceUsagePattern() -> String {
        let sessionDuration = getSessionDuration()
        let interactionVelocity = getRecentInteractionVelocity()
        let batteryLevel = UIDevice.current.batteryLevel
        
        // Analyze usage patterns for engagement optimization
        if sessionDuration < 5 && interactionVelocity > 8 {
            return "quick_task_focused"      // Short, intense usage
        } else if sessionDuration > 20 && interactionVelocity < 3 {
            return "leisurely_browsing"      // Long, relaxed usage
        } else if batteryLevel < 0.2 {
            return "battery_conscious"       // Low battery affects behavior
        } else {
            return "balanced_exploration"    // Normal usage pattern
        }
    }
    
    // Social context inference (could be enhanced with proximity sensors, etc.)
    private func getSocialContext() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        
        // Infer social context from time patterns
        if dayOfWeek == 1 || dayOfWeek == 7 { // Weekend
            if hour >= 18 && hour <= 23 {
                return "social_evening"      // Likely with others
            } else if hour >= 10 && hour <= 16 {
                return "leisure_time"        // Could be social or solo
            }
        } else { // Weekday
            if hour >= 7 && hour <= 9 {
                return "commute_time"        // Likely solo
            } else if hour >= 12 && hour <= 14 {
                return "lunch_break"         // Could be social
            } else if hour >= 17 && hour <= 19 {
                return "after_work"          // Transition time
            }
        }
        
        return "solo_exploration"
    }
    
    // Emotional state inference from interaction patterns
    private func inferEmotionalState() -> String {
        let sessionDuration = getSessionDuration()
        let recentInteractions = getRecentInteractionVelocity()
        let scrollBehavior = getScrollBehavior()
        let timeOfDay = getCurrentTimeOfDay()
        
        // Multi-factor emotional state inference
        if recentInteractions > 8 && scrollBehavior == "quick_scanner" {
            return "excited_discovery"       // High energy, seeking new things
        } else if sessionDuration > 15 && scrollBehavior == "deliberate_reader" {
            return "contemplative_mood"      // Thoughtful, taking time
        } else if timeOfDay == "morning" && recentInteractions > 5 {
            return "optimistic_energy"       // Morning enthusiasm
        } else if timeOfDay == "evening" && recentInteractions < 3 {
            return "relaxed_unwinding"       // Evening calm
        } else if recentInteractions < 2 && sessionDuration < 5 {
            return "distracted_browsing"     // Unfocused, interrupted
        } else {
            return "balanced_exploration"    // Neutral, balanced state
        }
    }
    
    // MARK: - Session and Interaction Tracking Methods
    
    func startNewSession() {
        sessionStartTime = Date()
        lastTabSwitchTime = Date()
        print("🧬 Started new fingerprint session")
    }
    
    func recordTabInteraction(
        tab: String,
        timeSpent: TimeInterval,
        context: [String: Any]
    ) async {
        lastTabSwitchTime = Date()
        
        // Record tab interaction in fingerprint
        Task { @MainActor in
            guard let currentFingerprint = fingerprint else { return }
            
            // You could extend UserFingerprint to include tab interactions
            // For now, we'll just update the last interaction time
            self.recordInteraction(type: "tab_switch", target: tab, metadata: context)
        }
    }
    
    func recordNotificationInteraction(
        notificationType: String,
        action: String,
        context: [String: Any]
    ) async {
        Task { @MainActor in
            recordInteraction(type: "notification_\(action)", target: notificationType, metadata: context)
        }
    }
    
    func recordRecommendationInteraction(_ interaction: UserInteraction) async {
        Task { @MainActor in
            recordInteraction(
                type: interaction.interactionType,
                target: interaction.targetId,
                metadata: interaction.context
            )
        }
    }
    
    private func recordBehavioralPattern(_ pattern: String, data: [String: Any]) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let patternData: [String: Any] = [
            "pattern": pattern,
            "data": data,
            "timestamp": Date()
        ]
        
        do {
            try await Firestore.firestore()
                .collection("userFingerprints")
                .document(uid)
                .updateData([
                    "behavioralPatterns": FieldValue.arrayUnion([patternData])
                ])
        } catch {
            print("❌ Failed to record behavioral pattern: \(error)")
        }
    }
    
    private func getRecentInteractionVelocity() -> Int {
        let recentWindow = Date().addingTimeInterval(-300) // Last 5 minutes
        let recentInteractions = lastInteractionTimestamps.filter { $0 > recentWindow }
        return recentInteractions.count
    }
    
    private func getAttentionLevel() -> String {
        let sessionDuration = getSessionDuration()
        let interactionVelocity = getRecentInteractionVelocity()
        
        if sessionDuration > 10 && interactionVelocity < 2 {
            return "focused"
        } else if interactionVelocity > 8 {
            return "highly_engaged"
        } else if sessionDuration < 2 {
            return "browsing"
        } else {
            return "moderate"
        }
    }
    
    private func getExplorationStyle() -> String {
        let sessionDuration = getSessionDuration()
        let scrollBehavior = getScrollBehavior()
        
        if scrollBehavior == "deliberate_reader" && sessionDuration > 10 {
            return "thorough_explorer"
        } else if scrollBehavior == "quick_scanner" {
            return "efficient_seeker"
        } else {
            return "balanced_explorer"
        }
    }
    
    private func getSocialTendency() -> String {
        let timeOfDay = getCurrentTimeOfDay()
        let dayOfWeek = getCurrentDayOfWeek()
        
        if (dayOfWeek == "friday" || dayOfWeek == "saturday") && 
           (timeOfDay == "evening" || timeOfDay == "night") {
            return "social_oriented"
        } else if timeOfDay == "morning" {
            return "solo_focused"
        } else {
            return "situational"
        }
    }
    
    private func getRiskTolerance() -> String {
        let explorationStyle = getExplorationStyle()
        let attentionLevel = getAttentionLevel()
        
        if explorationStyle == "thorough_explorer" && attentionLevel == "focused" {
            return "conservative"
        } else if explorationStyle == "efficient_seeker" {
            return "moderate_risk"
        } else {
            return "balanced"
        }
    }
    
    private func analyzeInteractionDepth() -> String {
        // Analyze how deeply users engage with content
        let tapCount = tapPatternData.count
        let sessionDuration = getSessionDuration()
        
        if sessionDuration > 0 {
            let interactionRate = Double(tapCount) / sessionDuration * 60 // interactions per minute
            
            switch interactionRate {
            case 0..<2: return "shallow"
            case 2..<5: return "moderate"
            default: return "deep"
            }
        }
        
        return "moderate"
    }

    
    // MARK: - Advanced Analytics Methods
    
    private func calculateSearchToDiscoveryRatio() -> Double {
        // Would analyze actual user behavior data
        return 0.4 // Placeholder
    }
    
    private func calculateRepeatVisitRate() -> Double {
        // Would analyze revisit patterns
        return 0.3 // Placeholder
    }
    
    private func analyzeSocialContextHistory() -> [String: Double] {
        // Would analyze historical social context data
        return ["social_evening": 0.3, "solo_exploration": 0.7]
    }
    
    private func getGroupPlanningEngagement() -> Double {
        // Would analyze group planning feature usage
        return 0.2 // Placeholder
    }
    
    private func calculateNewPlaceRatio() -> Double {
        // Would analyze how often they try completely new places
        return 0.5 // Placeholder
    }
    
    private func calculateAverageRatingPreference() -> Double {
        // Would analyze the average rating of places they choose
        return 4.1 // Placeholder
    }
    

    
    private func recordSessionStart() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let sessionData: [String: Any] = [
            "sessionId": UUID().uuidString,
            "startTime": Date(),
            "deviceInfo": getDeviceInfo(),
            "appVersion": getAppVersion(),
            "locationPermission": getLocationPermissionStatus(),
            "notificationPermission": getNotificationPermissionStatus()
        ]
        
        let updates: [String: Any] = [
            "sessions": FieldValue.arrayUnion([sessionData]),
            "totalSessions": FieldValue.increment(Int64(1)),
            "lastActiveTime": FieldValue.serverTimestamp()
        ]
        
        Firestore.firestore()
            .collection("userFingerprints")
            .document(uid)
            .updateData(updates) { error in
                if let error = error {
                    print("❌ Failed to record session start: \(error)")
                } else {
                    print("✅ Session start recorded")
                }
            }
    }
    
    private func getDeviceInfo() -> [String: Any] {
        return [
            "model": UIDevice.current.model,
            "systemVersion": UIDevice.current.systemVersion,
            "screenSize": "\(UIScreen.main.bounds.width)x\(UIScreen.main.bounds.height)"
        ]
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getLocationPermissionStatus() -> String {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return "granted"
        case .denied, .restricted: return "denied"
        case .notDetermined: return "not_determined"
        @unknown default: return "unknown"
        }
    }
    
    private func getNotificationPermissionStatus() -> String {
        // Check notification permission status
        return "granted" // Placeholder
    }

    // MARK: - Session Management (additional methods)
    
    func getCurrentSessionDuration() -> Double {
        return Date().timeIntervalSince(sessionStartTime)
    }
    
    // MARK: - User Interaction Recording
    
    /// Records a general user interaction with detailed metadata
    func recordInteraction(type: String, target: String, metadata: [String: Any] = [:]) {
        Task {
            await UserTrackingService.shared.recordUserInteraction(
                type: type,
                details: ["target": target],
                context: metadata
            )
        }
    }
    
    /// Records a tab switch interaction
    func recordTabSwitch(to tab: String, context: [String: Any] = [:]) {
        recordInteraction(type: "tab_switch", target: tab, metadata: context)
    }
    
    /// Records a notification interaction
    func recordNotificationAction(_ action: String, notificationType: String, context: [String: Any] = [:]) {
        recordInteraction(type: "notification_\(action)", target: notificationType, metadata: context)
    }
}

// MARK: - Supporting Data Structures for Advanced Tracking
// UserInteraction is defined in AppModels.swift

enum InteractionType: String, CaseIterable {
    case viewed = "viewed"
    case liked = "liked"
    case shared = "shared"
    case visited = "visited"
    case dismissed = "dismissed"
    case dwellTime = "dwell_time"
    case scroll = "scroll"
    case search = "search"
    case filter = "filter"
    case bookmark = "bookmark"
}

// Enhanced PlaceInteraction for behavioral tracking
enum PlaceInteraction: String, CaseIterable {
    case viewed = "viewed"
    case liked = "liked" 
    case disliked = "disliked"
    case shared = "shared"
    case visited = "visited"
    case bookmarked = "bookmarked"
    case called = "called"
    case navigated = "navigated"
    case reviewed = "reviewed"
    case photographed = "photographed"
    case recommended = "recommended"
}

// Notification extension moved to avoid duplicate
