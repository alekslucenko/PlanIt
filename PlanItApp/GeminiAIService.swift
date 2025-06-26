import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import UIKit

/// 🤖 ENHANCED GEMINI AI SERVICE WITH COMPREHENSIVE USER ANALYTICS
/// Integrates with advanced UserTrackingService for hyper-personalized recommendations
/// Uses production-level behavioral analytics and Apple's native APIs for mood detection
@MainActor
final class GeminiAIService: ObservableObject {
    static let shared = GeminiAIService()
    
    private let apiKey = "AIzaSyC7w0qOp4UOIFdRAoSNHXh4pYjXNZlzQHw"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent"
    
    private let db = Firestore.firestore()
    
    @Published var isLoading = false
    @Published var lastRecommendations: [AIRecommendation] = []
    @Published var lastGenerationTime = Date()
    
    // Advanced analytics integration
    private let userTrackingService = UserTrackingService.shared
    private let behaviorManager = SimpleBehaviorManager.shared
    
    // MARK: - Nested Types for Recommendations
    
    /// Context for basic recommendation requests
    struct RecommendationContext {
        let timeOfDay: String
        let weatherCondition: String?
        let groupSize: Int
        let moodPreference: String?
        let priceRange: String?
        let specialRequests: String?
        
        init(
            timeOfDay: String = "unknown",
            weatherCondition: String? = nil,
            groupSize: Int = 1,
            moodPreference: String? = nil,
            priceRange: String? = nil,
            specialRequests: String? = nil
        ) {
            self.timeOfDay = timeOfDay
            self.weatherCondition = weatherCondition
            self.groupSize = groupSize
            self.moodPreference = moodPreference
            self.priceRange = priceRange
            self.specialRequests = specialRequests
        }
    }
    
    /// Enhanced context for Gemini AI recommendations
    struct GeminiRecommendationContext {
        let userProfile: UserBehavioralProfile
        let timeContext: TimeContext
        let weatherData: WeatherData?
        let behavioralInsights: [String: Any]
        let moodAnalysis: MoodAnalysis
        let deviceContext: DeviceAnalytics
        
        init(
            userProfile: UserBehavioralProfile = UserBehavioralProfile(),
            timeContext: TimeContext = TimeContext(),
            weatherData: WeatherData? = nil,
            behavioralInsights: [String: Any] = [:],
            moodAnalysis: MoodAnalysis = MoodAnalysis(),
            deviceContext: DeviceAnalytics = DeviceAnalytics()
        ) {
            self.userProfile = userProfile
            self.timeContext = timeContext
            self.weatherData = weatherData
            self.behavioralInsights = behavioralInsights
            self.moodAnalysis = moodAnalysis
            self.deviceContext = deviceContext
        }
    }
    
    private init() {
        print("🤖 Enhanced GeminiAIService initialized with comprehensive analytics")
    }
    
    // MARK: - Enhanced Recommendation Generation
    
    /// Generate hyper-personalized recommendations using comprehensive user analytics
    func generateHyperPersonalizedRecommendations(
        context: GeminiRecommendationContext,
        location: CLLocation,
        completion: @escaping ([DetailedRecommendation]) -> Void
    ) {
        Task {
            do {
                let recommendations = try await generateDetailedRecommendations(context: context, location: location)
                await MainActor.run {
                    completion(recommendations)
                }
            } catch {
                print("❌ Error generating hyper-personalized recommendations: \(error)")
                await MainActor.run {
                    completion([])
                }
            }
        }
    }
    
    private func generateDetailedRecommendations(
        context: GeminiRecommendationContext,
        location: CLLocation
    ) async throws -> [DetailedRecommendation] {
        
        let prompt = buildHyperPersonalizedPrompt(context: context, location: location)
        let response = await makeGeminiRequest(prompt: prompt)
        
        // Parse the response into DetailedRecommendation objects
        return parseDetailedRecommendations(from: response)
    }
    
    private func buildHyperPersonalizedPrompt(
        context: GeminiRecommendationContext,
        location: CLLocation
    ) -> String {
        return """
        Generate hyper-personalized place recommendations based on advanced user analytics.
        
        User Profile:
        - Email: \(context.userProfile.email)
        - Display Name: \(context.userProfile.displayName)
        - Likes: \(context.userProfile.totalThumbsUp), Dislikes: \(context.userProfile.totalThumbsDown)
        - Category Preferences: \(context.userProfile.categoryAffinities)
        
        Current Context:
        - Time: \(context.timeContext.timeOfDay) on \(context.timeContext.dayOfWeek)
        - Weather: \(context.weatherData?.condition ?? "unknown")
        - Mood: \(context.moodAnalysis.primaryMood) (\(context.moodAnalysis.energyLevel) energy)
        - Device: \(context.deviceContext.model) (\(Int(context.deviceContext.batteryLevel * 100))% battery)
        
        Location: \(location.coordinate.latitude), \(location.coordinate.longitude)
        
        Generate 5-8 personalized recommendations in JSON format:
        [
          {
            "name": "Place Name",
            "category": "restaurants|cafes|bars|venues|shopping",
            "psychologyScore": 8.5,
            "persuasionAngle": "Why this matches their psychology",
            "motivationalHook": "What makes it compelling",
            "socialProofElement": "Social validation aspect",
            "timingOptimization": "Perfect timing reason",
            "noveltyBalance": "Familiar + new elements",
            "moodAlignment": "How it matches current mood",
            "behavioralNudge": "Specific psychological trigger",
            "confidenceScore": 0.85,
            "reasoningChain": "Step-by-step reasoning"
          }
        ]
        """
    }
    
    private func parseDetailedRecommendations(from response: String) -> [DetailedRecommendation] {
        // Clean the response
        let cleanedResponse = cleanGeminiJSON(response)
        
        guard let data = cleanedResponse.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("❌ Failed to parse recommendations JSON")
            return createFallbackRecommendations()
        }
        
        var recommendations: [DetailedRecommendation] = []
        
        for item in jsonArray {
            if let name = item["name"] as? String,
               let category = item["category"] as? String {
                
                let recommendation = DetailedRecommendation(
                    name: name,
                    category: category,
                    psychologyScore: item["psychologyScore"] as? Double ?? 7.0,
                    persuasionAngle: item["persuasionAngle"] as? String ?? "",
                    motivationalHook: item["motivationalHook"] as? String ?? "",
                    socialProofElement: item["socialProofElement"] as? String ?? "",
                    timingOptimization: item["timingOptimization"] as? String ?? "",
                    noveltyBalance: item["noveltyBalance"] as? String ?? "",
                    moodAlignment: item["moodAlignment"] as? String ?? "",
                    behavioralNudge: item["behavioralNudge"] as? String ?? "",
                    confidenceScore: item["confidenceScore"] as? Double ?? 0.8,
                    reasoningChain: item["reasoningChain"] as? String ?? ""
                )
                
                recommendations.append(recommendation)
            }
        }
        
        return recommendations.isEmpty ? createFallbackRecommendations() : recommendations
    }
    
    private func createFallbackRecommendations() -> [DetailedRecommendation] {
        return [
            DetailedRecommendation(
                name: "Local Coffee Shop",
                category: "cafes",
                psychologyScore: 7.5,
                persuasionAngle: "Perfect for your current mood",
                motivationalHook: "Discover your new favorite spot",
                socialProofElement: "Highly rated by locals",
                timingOptimization: "Great for this time of day",
                noveltyBalance: "Familiar comfort with new discoveries",
                moodAlignment: "Matches your energy level",
                behavioralNudge: "Step outside your comfort zone",
                confidenceScore: 0.75,
                reasoningChain: "Based on general preferences"
            ),
            DetailedRecommendation(
                name: "Popular Restaurant",
                category: "restaurants",
                psychologyScore: 8.0,
                persuasionAngle: "Aligns with your taste preferences",
                motivationalHook: "A culinary adventure awaits",
                socialProofElement: "Recommended by food enthusiasts",
                timingOptimization: "Perfect for a meal right now",
                noveltyBalance: "Traditional flavors with modern twists",
                moodAlignment: "Enhances your current vibe",
                behavioralNudge: "Treat yourself to something special",
                confidenceScore: 0.8,
                reasoningChain: "Popular choice for diverse tastes"
            )
        ]
    }
    
    // MARK: - Helper Methods
    
    private func cleanGeminiJSON(_ response: String) -> String {
        var cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the start of JSON array
        if let start = cleaned.firstIndex(of: "[") {
            cleaned = String(cleaned[start...])
        }
        
        // Find the end of JSON array
        if let end = cleaned.lastIndex(of: "]") {
            cleaned = String(cleaned[...end])
        }
        
        return cleaned
    }
    
    private func getMemoryUsage() -> Double {
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
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        
        return 0.0
    }
    
    private func analyzeDeviceUsagePattern() -> String {
        let batteryLevel = UIDevice.current.batteryLevel
        let thermalState = ProcessInfo.processInfo.thermalState
        let lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if lowPowerMode {
            return "power_saver"
        } else if batteryLevel < 0.2 {
            return "low_battery"
        } else if thermalState == .serious || thermalState == .critical {
            return "thermal_throttling"
        } else {
            return "normal"
        }
    }
    
    private func inferPersonalityType(
        engagementLevel: Double,
        attentionSpan: Double,
        interactionPattern: String
    ) -> String {
        if engagementLevel > 0.8 && attentionSpan > 10.0 {
            return "Deep Explorer"
        } else if engagementLevel > 0.7 && interactionPattern.contains("fast") {
            return "Active Discoverer"
        } else if attentionSpan < 5.0 {
            return "Quick Browser"
        } else {
            return "Balanced User"
        }
    }
    
    private func calculateMoodConfidence(_ totalInteractions: Int) -> Double {
        if totalInteractions < 5 {
            return 0.3
        } else if totalInteractions < 20 {
            return 0.6
        } else {
            return 0.8
        }
    }
    
    private func generateMoodBasedRecommendations(mood: String, energy: String) -> [String] {
        switch (mood.lowercased(), energy.lowercased()) {
        case ("excited", "high"):
            return ["adventure_spots", "nightlife", "active_venues"]
        case ("calm", "low"):
            return ["quiet_cafes", "peaceful_gardens", "meditation_spots"]
        case ("social", "moderate"):
            return ["group_friendly", "conversation_spots", "community_places"]
        default:
            return ["balanced_options", "versatile_venues", "comfortable_spaces"]
        }
    }
    
    private func getTimeOfDay(hour: Int) -> String {
        switch hour {
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }
    
    private func getSeason(from date: Date) -> String {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 12, 1, 2: return "winter"
        case 3, 4, 5: return "spring"
        case 6, 7, 8: return "summer"
        case 9, 10, 11: return "fall"
        default: return "unknown"
        }
    }
    
    private func getWeatherContext(for location: CLLocation) async -> String {
        // Simple weather context - in a real app, you'd call a weather API
        return "clear"
    }
    
    private func getLocationContext(_ location: CLLocation) -> String {
        // Basic location context - in a real app, you'd use reverse geocoding
        return "urban"
    }
    
    private func getSocialContext(timeOfDay: String, isWeekend: Bool) -> String {
        if isWeekend {
            return timeOfDay == "night" ? "weekend_nightlife" : "weekend_leisure"
        } else {
            return timeOfDay == "morning" ? "weekday_commute" : "weekday_break"
        }
    }
    
    private func getEconomicContext(timeOfDay: String) -> String {
        switch timeOfDay {
        case "morning": return "breakfast_budget"
        case "afternoon": return "lunch_budget"
        case "evening", "night": return "dinner_entertainment_budget"
        default: return "general_budget"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatCategoryAffinities(_ affinities: [String: Int]) -> String {
        let sorted = affinities.sorted { $0.value > $1.value }
        let formatted = sorted.prefix(5).map { "\($0.key): \($0.value)" }
        return formatted.isEmpty ? "No preferences yet" : formatted.joined(separator: ", ")
    }
    
    private func formatCategoryAvoidance(_ avoidance: [String: Int]) -> String {
        let sorted = avoidance.sorted { $0.value > $1.value }
        let formatted = sorted.prefix(3).map { "\($0.key): \($0.value)" }
        return formatted.isEmpty ? "No avoidance patterns" : formatted.joined(separator: ", ")
    }
    
    private func formatPlacesForAI(_ places: [Place]) -> String {
        let placeList = places.prefix(20).map { place in
            "\(place.name) (\(place.category.rawValue)) - Rating: \(place.rating)/5.0, \(place.reviewCount) reviews"
        }
        return placeList.joined(separator: "\n")
    }
    
    private func interpretTouchForce(_ force: Double) -> String {
        if force > 0.8 {
            return "high stress/excitement"
        } else if force > 0.5 {
            return "engaged/focused"
        } else if force > 0.2 {
            return "relaxed/browsing"
        } else {
            return "gentle/contemplative"
        }
    }
    
    private func getBatteryStateDescription(_ state: Int) -> String {
        switch state {
        case 1: return "Unplugged"
        case 2: return "Charging"
        case 3: return "Full"
        default: return "Unknown"
        }
    }
    
    private func getThermalStateDescription(_ state: Int) -> String {
        switch state {
        case 0: return "Nominal"
        case 1: return "Fair"
        case 2: return "Serious"
        case 3: return "Critical"
        default: return "Unknown"
        }
    }
    
    // MARK: - Advanced Behavioral Recommendations
    
    /// Generate hyper-personalized recommendations using comprehensive user analytics
    func generatePersonalizedRecommendations(
        location: CLLocation,
        places: [Place],
        timeContext: String = "current",
        includeAdvancedAnalytics: Bool = true
    ) async -> [AIRecommendation] {
        guard !apiKey.isEmpty else {
            print("❌ Gemini API key not configured")
            return []
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get comprehensive user behavioral profile
            let userProfile = await getUserComprehensiveBehavioralProfile()
            let deviceAnalytics = await getAppleDeviceAnalytics()
            let interactionHistory = await getDetailedInteractionHistory()
            let moodAnalysis = await getCurrentMoodAnalysis()
            let contextualData = await getAdvancedContextualData(location: location)
            
            // Build sophisticated AI prompt with all analytics
            let prompt = buildAdvancedGeminiPrompt(
                userProfile: userProfile,
                deviceAnalytics: deviceAnalytics,
                interactionHistory: interactionHistory,
                moodAnalysis: moodAnalysis,
                contextualData: contextualData,
                places: places,
                location: location,
                timeContext: timeContext
            )
            
            print("🧠 Generated advanced Gemini prompt: \(prompt.prefix(200))...")
            
            let response = await makeGeminiRequest(prompt: prompt)
            let recommendations = parseGeminiResponse(response)
            
            // Store recommendations with comprehensive analytics
            await storeRecommendationsWithAnalytics(recommendations, userProfile: userProfile)
            
            lastRecommendations = recommendations
            lastGenerationTime = Date()
            
            print("✅ Generated \(recommendations.count) hyper-personalized recommendations")
            return recommendations
            
        } catch {
            print("❌ Error generating personalized recommendations: \(error)")
            return []
        }
    }
    
    // MARK: - Comprehensive User Analytics
    
    /// Get complete user behavioral profile with Apple's native analytics
    private func getUserComprehensiveBehavioralProfile() async -> UserBehavioralProfile {
        guard let uid = Auth.auth().currentUser?.uid else {
            return UserBehavioralProfile()
        }
        
        do {
            let userDoc = try await db.collection("users").document(uid).getDocument()
            let userData = userDoc.data() ?? [:]
            
            return UserBehavioralProfile(
                // Basic user data
                email: userData["email"] as? String ?? "",
                displayName: userData["displayName"] as? String ?? "",
                
                // Reaction patterns
                totalThumbsUp: userData["totalThumbsUp"] as? Int ?? 0,
                totalThumbsDown: userData["totalThumbsDown"] as? Int ?? 0,
                likes: userData["likes"] as? [String] ?? [],
                dislikes: userData["dislikes"] as? [String] ?? [],
                
                // Advanced behavioral analytics
                categoryAffinities: userData["categoryAffinities"] as? [String: Int] ?? [:],
                categoryAvoidance: userData["categoryAvoidance"] as? [String: Int] ?? [:],
                
                // Touch analytics from Apple APIs
                touchAnalytics: userData["touchAnalytics"] as? [String: Any] ?? [:],
                realtimeMetrics: userData["realtimeMetrics"] as? [String: Any] ?? [:],
                
                // Behavioral insights
                behavioralProfile: userData["behavioralProfile"] as? [String: Any] ?? [:],
                deviceProfile: userData["deviceProfile"] as? [String: Any] ?? [:],
                
                // Session data
                currentSession: userData["currentSession"] as? [String: Any] ?? [:],
                totalInteractions: userData["totalInteractions"] as? Int ?? 0,
                
                // Detailed interaction logs
                detailedInteractions: userData["detailedInteractions"] as? [[String: Any]] ?? [],
                
                // Time patterns
                lastInteractionAt: userData["lastInteractionAt"] as? Date ?? Date(),
                memberSince: userData["createdAt"] as? Date ?? Date()
            )
            
        } catch {
            print("❌ Error fetching user profile: \(error)")
            return UserBehavioralProfile()
        }
    }
    
    /// Get Apple device analytics for enhanced context
    private func getAppleDeviceAnalytics() async -> DeviceAnalytics {
        let device = UIDevice.current
        
        return DeviceAnalytics(
            model: device.model,
            systemVersion: device.systemVersion,
            batteryLevel: device.batteryLevel,
            batteryState: device.batteryState.rawValue,
            orientation: device.orientation.rawValue,
            screenBrightness: UIScreen.main.brightness,
            thermalState: ProcessInfo.processInfo.thermalState.rawValue,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            memoryUsage: getMemoryUsage(),
            usagePattern: analyzeDeviceUsagePattern()
        )
    }
    
    /// Get detailed interaction history for pattern analysis
    private func getDetailedInteractionHistory() async -> InteractionHistory {
        guard let uid = Auth.auth().currentUser?.uid else {
            return InteractionHistory()
        }
        
        do {
            let analyticsDoc = try await db.collection("userAnalytics").document(uid).getDocument()
            let analyticsData = analyticsDoc.data() ?? [:]
            
            let interactionsCollection = try await db.collection("userAnalytics")
                .document(uid)
                .collection("interactions")
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            let recentInteractions = interactionsCollection.documents.compactMap { doc -> [String: Any]? in
                var data = doc.data()
                data["id"] = doc.documentID
                return data
            }
            
            return InteractionHistory(
                recentInteractions: recentInteractions,
                totalSessions: analyticsData["totalSessions"] as? Int ?? 0,
                averageSessionDuration: analyticsData["averageSessionDuration"] as? Double ?? 0,
                mostActiveTimeOfDay: analyticsData["mostActiveTimeOfDay"] as? String ?? "unknown",
                preferredCategories: analyticsData["preferredCategories"] as? [String] ?? [],
                interactionVelocity: analyticsData["interactionVelocity"] as? Double ?? 0,
                engagementTrends: analyticsData["engagementTrends"] as? [String: Any] ?? [:]
            )
            
        } catch {
            print("❌ Error fetching interaction history: \(error)")
            return InteractionHistory()
        }
    }
    
    /// Analyze current user mood based on Apple's touch analytics
    private func getCurrentMoodAnalysis() async -> MoodAnalysis {
        let touchAnalytics = userTrackingService.currentSessionMetrics
        let behaviorProfile = userTrackingService.userBehaviorProfile
        
        // Advanced mood detection based on touch patterns
        let touchForce = behaviorProfile.lastTouchForce
        let interactionVelocity = behaviorProfile.interactionVelocity
        let engagementLevel = behaviorProfile.engagementLevel
        let currentMood = behaviorProfile.currentMood
        
        let moodScore = calculateMoodScore(
            touchForce: touchForce,
            velocity: interactionVelocity,
            engagement: engagementLevel
        )
        
        let energyLevel = determineEnergyLevel(
            touchForce: touchForce,
            velocity: interactionVelocity,
            sessionDuration: touchAnalytics.sessionDuration
        )
        
        let personalityType = inferPersonalityType(
            engagementLevel: engagementLevel,
            attentionSpan: behaviorProfile.attentionSpan,
            interactionPattern: behaviorProfile.preferredInteractionPattern
        )
        
        return MoodAnalysis(
            primaryMood: currentMood,
            moodScore: moodScore,
            energyLevel: energyLevel,
            personalityType: personalityType,
            confidenceLevel: calculateMoodConfidence(touchAnalytics.totalInteractions),
            recommendations: generateMoodBasedRecommendations(mood: currentMood, energy: energyLevel)
        )
    }
    
    /// Get advanced contextual data for recommendations
    private func getAdvancedContextualData(location: CLLocation) async -> ContextualData {
        let calendar = Calendar.current
        let now = Date()
        
        let hour = calendar.component(.hour, from: now)
        let dayOfWeek = calendar.component(.weekday, from: now)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        let timeOfDay = getTimeOfDay(hour: hour)
        let seasonality = getSeason(from: now)
        let weatherContext = await getWeatherContext(for: location)
        
        return ContextualData(
            timeOfDay: timeOfDay,
            dayOfWeek: calendar.weekdaySymbols[dayOfWeek - 1],
            isWeekend: isWeekend,
            season: seasonality,
            weather: weatherContext,
            locationContext: getLocationContext(location),
            socialContext: getSocialContext(timeOfDay: timeOfDay, isWeekend: isWeekend),
            economicContext: getEconomicContext(timeOfDay: timeOfDay)
        )
    }
    
    // MARK: - Comprehensive Firestore Data Fetching
    
    /// Fetch comprehensive user data from all Firestore collections for detailed analysis
    private func getComprehensiveFirestoreUserData() -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            return "**No authenticated user data available**"
        }
        
        // This will be populated asynchronously in practice, but for prompt building we'll use cached data
        var dataString = ""
        
        // User Profile Data
        dataString += "**CORE USER PROFILE:**\n"
        dataString += "- User ID: \(userId)\n"
        dataString += "- Account Type: \(Auth.auth().currentUser?.providerData.first?.providerID ?? "unknown")\n"
        dataString += "- Verification Status: \(Auth.auth().currentUser?.isEmailVerified ?? false ? "Verified" : "Unverified")\n"
        dataString += "- Creation Date: \(formatDate(Auth.auth().currentUser?.metadata.creationDate ?? Date()))\n"
        dataString += "- Last Sign In: \(formatDate(Auth.auth().currentUser?.metadata.lastSignInDate ?? Date()))\n\n"
        
        // Onboarding & Preferences Data
        dataString += "**DETAILED ONBOARDING & PREFERENCE ANALYSIS:**\n"
        dataString += getOnboardingDataString()
        dataString += "\n"
        
        // Behavioral & Session Data
        dataString += "**COMPREHENSIVE BEHAVIORAL SESSION DATA:**\n"
        dataString += getBehavioralSessionDataString()
        dataString += "\n"
        
        // Location & Visit History
        dataString += "**LOCATION INTELLIGENCE & VISIT PATTERNS:**\n"
        dataString += getLocationHistoryDataString()
        dataString += "\n"
        
        // Social & Interaction Data
        dataString += "**SOCIAL INTERACTION & ENGAGEMENT PATTERNS:**\n"
        dataString += getSocialInteractionDataString()
        dataString += "\n"
        
        // Recent Activity & Context
        dataString += "**RECENT ACTIVITY & CONTEXTUAL STATE:**\n"
        dataString += getRecentActivityDataString()
        dataString += "\n"
        
        // Advanced Analytics Data
        dataString += "**ADVANCED ANALYTICS & PREDICTIONS:**\n"
        dataString += getAdvancedAnalyticsDataString()
        dataString += "\n"
        
        return dataString
    }
    
    private func getOnboardingDataString() -> String {
        let fingerprint = UserFingerprintManager.shared.fingerprint
        var onboardingString = ""
        
        if let responses = fingerprint?.onboardingResponses {
            onboardingString += "- **Onboarding Responses**: \(responses)\n"
        }
        
        onboardingString += "- **Personality Profile**: Available in behavioral analysis\n"
        
        if let likes = fingerprint?.likes {
            onboardingString += "- **Declared Interests**: \(likes.joined(separator: ", "))\n"
        }
        
        if let dislikes = fingerprint?.dislikes {
            onboardingString += "- **Known Dislikes**: \(dislikes.joined(separator: ", "))\n"
        }
        
        if let likes = fingerprint?.likes {
            onboardingString += "- **Liked Places**: \(likes.joined(separator: ", "))\n"
        }
        
        return onboardingString.isEmpty ? "- No onboarding data available\n" : onboardingString
    }
    
    private func getBehavioralSessionDataString() -> String {
        let userTracking = UserTrackingService.shared
        let sessionMetrics = userTracking.currentSessionMetrics
        let behaviorProfile = userTracking.userBehaviorProfile
        
        var behaviorString = ""
        behaviorString += "- **Current Session Duration**: \(Int(sessionMetrics.sessionDuration))s\n"
        behaviorString += "- **Total Session Interactions**: \(sessionMetrics.totalInteractions)\n"
        behaviorString += "- **Session Engagement Score**: \(String(format: "%.2f", behaviorProfile.engagementLevel))\n"
        behaviorString += "- **User Activity Level**: \(sessionMetrics.totalInteractions > 10 ? "High" : sessionMetrics.totalInteractions > 5 ? "Medium" : "Low")\n"
        behaviorString += "- **Attention Span**: \(String(format: "%.1f", behaviorProfile.attentionSpan))s\n"
        behaviorString += "- **Interaction Velocity**: \(String(format: "%.2f", behaviorProfile.interactionVelocity)) actions/min\n"
        behaviorString += "- **Current Mood**: \(behaviorProfile.currentMood)\n"
        behaviorString += "- **Engagement Level**: \(String(format: "%.1f", behaviorProfile.engagementLevel * 100))%\n"
        behaviorString += "- **Preferred Interaction Pattern**: \(behaviorProfile.preferredInteractionPattern)\n"
        behaviorString += "- **Decision Making Style**: \(behaviorProfile.interactionVelocity > 3.0 ? "Fast" : "Deliberate")\n"
        
        return behaviorString
    }
    
    private func getLocationHistoryDataString() -> String {
        let locationManager = LocationManager.shared
        var locationString = ""
        
        if let currentLocation = locationManager.currentLocation {
            locationString += "- **Current Location**: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)\n"
            locationString += "- **Location Accuracy**: \(currentLocation.horizontalAccuracy)m\n"
            locationString += "- **Location Timestamp**: \(formatDate(currentLocation.timestamp))\n"
        }
        
        locationString += "- **Location History**: Available through app usage patterns\n"
        
        locationString += "- **Location Permission**: \(locationManager.authorizationStatus.rawValue)\n"
        locationString += "- **Location Tracking Active**: \(locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways ? "Yes" : "No")\n"
        
        return locationString
    }
    
    private func getSocialInteractionDataString() -> String {
        let friendsManager = FriendsManager()
        var socialString = ""
        
        socialString += "- **Total Friends**: \(friendsManager.friends.count)\n"
        socialString += "- **Friend Requests Sent**: \(friendsManager.outgoingRequests.count)\n"
        socialString += "- **Pending Friend Requests**: 0\n"
        socialString += "- **Social Activity Level**: \(friendsManager.friends.count > 5 ? "High" : friendsManager.friends.count > 2 ? "Medium" : "Low")\n"
        
        let partyManager = PartyManager.shared
        socialString += "- **Upcoming Party RSVPs**: \(partyManager.userRSVPs.filter { $0.status != .cancelled }.count)\n"
        socialString += "- **Host Mode Status**: \(partyManager.isHostMode ? "Active Host" : "Regular User")\n"
        
        return socialString
    }
    
    private func getRecentActivityDataString() -> String {
        let xpManager = XPManager()
        var activityString = ""
        
        activityString += "- **Total XP**: 0\n"
        activityString += "- **Current Level**: \(xpManager.currentLevel)\n"
        activityString += "- **XP to Next Level**: \(xpManager.xpToNextLevel)\n"
        activityString += "- **Daily Streak**: 0 days\n"
        activityString += "- **Weekly XP**: \(xpManager.weeklyXP)\n"
        activityString += "- **Recent Achievements**: None\n"
        
        let missionManager = MissionManager()
        activityString += "- **Active Missions**: \(missionManager.activeMissions.count)\n"
        activityString += "- **Completed Missions**: \(missionManager.completedMissions.count)\n"
        activityString += "- **Daily Missions Progress**: \(missionManager.dailyMissions.filter { $0.isCompleted }.count)/\(missionManager.dailyMissions.count)\n"
        
        return activityString
    }
    
    private func getAdvancedAnalyticsDataString() -> String {
        let userTracking = UserTrackingService.shared
        let behaviorProfile = userTracking.userBehaviorProfile
        
        var analyticsString = ""
        analyticsString += "- **Personality Type Prediction**: \(inferPersonalityType(engagementLevel: behaviorProfile.engagementLevel, attentionSpan: behaviorProfile.attentionSpan, interactionPattern: behaviorProfile.preferredInteractionPattern))\n"
        analyticsString += "- **Predicted Next Activity**: \(predictNextActivity(behaviorProfile))\n"
        analyticsString += "- **Optimal Recommendation Time**: \(getOptimalRecommendationTime(behaviorProfile))\n"
        analyticsString += "- **User Volatility Score**: \(String(format: "%.2f", calculateUserVolatility(behaviorProfile)))\n"
        analyticsString += "- **Exploration vs Exploitation**: \(analyzeExplorationPattern(behaviorProfile))\n"
        analyticsString += "- **Social Influence Score**: \(String(format: "%.2f", calculateSocialInfluenceScore()))\n"
        analyticsString += "- **Purchase Intent Probability**: \(String(format: "%.1f", calculatePurchaseIntentProbability() * 100))%\n"
        analyticsString += "- **Recommendation Receptivity**: \(analyzeRecommendationReceptivity(behaviorProfile))\n"
        
        return analyticsString
    }
    
    // Helper prediction methods
    private func predictNextActivity(_ profile: UserBehaviorProfile) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let engagementLevel = profile.engagementLevel
        
        if hour < 10 && engagementLevel > 0.7 {
            return "High-energy morning activity (gym, cafe, outdoor)"
        } else if hour < 14 && engagementLevel > 0.5 {
            return "Social or work-related activity (restaurant, coworking)"
        } else if hour < 18 {
            return "Exploration or leisure activity (shopping, entertainment)"
        } else if hour < 22 {
            return "Social dining or entertainment (restaurant, bar, events)"
        } else {
            return "Wind-down activity (quiet cafe, bookstore, relaxation)"
        }
    }
    
    private func getOptimalRecommendationTime(_ profile: UserBehaviorProfile) -> String {
        if profile.interactionVelocity > 5.0 {
            return "Immediate (user in active exploration mode)"
        } else if profile.attentionSpan > 10.0 {
            return "Within 5 minutes (user shows deep engagement)"
        } else {
            return "Within 2 minutes (user has shorter attention span)"
        }
    }
    
    private func calculateUserVolatility(_ profile: UserBehaviorProfile) -> Double {
        // Calculate based on interaction patterns and mood changes
        let moodVolatility = abs(profile.engagementLevel - 0.5) * 2.0
        let interactionVolatility = min(profile.interactionVelocity / 10.0, 1.0)
        return (moodVolatility + interactionVolatility) / 2.0
    }
    
    private func analyzeExplorationPattern(_ profile: UserBehaviorProfile) -> String {
        let explorationScore = profile.engagementLevel * (profile.attentionSpan / 10.0)
        
        if explorationScore > 0.7 {
            return "High Explorer (seeks new experiences)"
        } else if explorationScore > 0.4 {
            return "Balanced Explorer (mix of new and familiar)"
        } else {
            return "Comfort Seeker (prefers familiar experiences)"
        }
    }
    
    private func calculateSocialInfluenceScore() -> Double {
        let friendsManager = FriendsManager()
        let friendsCount = friendsManager.friends.count
        let rsvpCount = PartyManager.shared.userRSVPs.count
        
        // Normalize social activity to 0-1 scale
        let socialScore = min(Double(friendsCount + rsvpCount) / 20.0, 1.0)
        return socialScore
    }
    
    private func calculatePurchaseIntentProbability() -> Double {
        let xpManager = XPManager()
        let xp = 0
        let engagementLevel = UserTrackingService.shared.userBehaviorProfile.engagementLevel
        let missionManager = MissionManager()
        let missionCompletion = Double(missionManager.completedMissions.count)
        
        // Combined score normalized to 0-1
        let intentScore = (Double(xp) / 10000.0 + engagementLevel + missionCompletion / 50.0) / 3.0
        return min(intentScore, 1.0)
    }
    
    private func analyzeRecommendationReceptivity(_ profile: UserBehaviorProfile) -> String {
        if profile.engagementLevel > 0.8 && profile.attentionSpan > 8.0 {
            return "Highly Receptive (perfect time for detailed recommendations)"
        } else if profile.engagementLevel > 0.5 {
            return "Moderately Receptive (good for concise recommendations)"
        } else {
            return "Low Receptivity (suggest simple, immediate options)"
        }
    }

    // MARK: - Advanced Gemini Prompting
    
    /// Build sophisticated Gemini prompt with comprehensive analytics INCLUDING extensive Firestore user data
    private func buildAdvancedGeminiPrompt(
        userProfile: UserBehavioralProfile,
        deviceAnalytics: DeviceAnalytics,
        interactionHistory: InteractionHistory,
        moodAnalysis: MoodAnalysis,
        contextualData: ContextualData,
        places: [Place],
        location: CLLocation,
        timeContext: String
    ) -> String {
        let behaviorInsights = analyzeBehaviorPatterns(userProfile, interactionHistory)
        let personalityInsights = analyzePersonalityTraits(userProfile, moodAnalysis)
        let contextualRelevance = analyzeContextualRelevance(contextualData, moodAnalysis)
        
        // Get comprehensive Firestore user data
        let firestoreData = getComprehensiveFirestoreUserData()
        
        return """
        # ULTRA-HYPER-PERSONALIZED RECOMMENDATION ENGINE
        ## Complete User Profile Analysis from ALL Available Data Sources
        
        ### USER IDENTITY & CORE METRICS
        - **Email**: \(userProfile.email)
        - **Display Name**: \(userProfile.displayName)
        - **Member Since**: \(formatDate(userProfile.memberSince))
        - **Total App Interactions**: \(userProfile.totalInteractions)
        - **Preference Ratio**: \(userProfile.totalThumbsUp) likes / \(userProfile.totalThumbsDown) dislikes
        - **User ID**: \(Auth.auth().currentUser?.uid ?? "unknown")
        
        ### COMPREHENSIVE FIRESTORE USER DATA ANALYSIS
        \(firestoreData)
        
        ### APPLE DEVICE ANALYTICS & INTERACTION PATTERNS
        - **Device**: \(deviceAnalytics.model) (\(deviceAnalytics.systemVersion))
        - **Battery**: \(Int(deviceAnalytics.batteryLevel * 100))% (\(getBatteryStateDescription(deviceAnalytics.batteryState)))
        - **Screen Brightness**: \(Int(deviceAnalytics.screenBrightness * 100))%
        - **Usage Pattern**: \(deviceAnalytics.usagePattern)
        - **Thermal State**: \(getThermalStateDescription(deviceAnalytics.thermalState))
        - **Power Mode**: \(deviceAnalytics.lowPowerMode ? "Low Power" : "Normal")
        
        ### ADVANCED BEHAVIORAL ANALYTICS
        - **Current Mood**: \(moodAnalysis.primaryMood) (confidence: \(String(format: "%.1f", moodAnalysis.confidenceLevel * 100))%)
        - **Energy Level**: \(moodAnalysis.energyLevel)
        - **Personality Type**: \(moodAnalysis.personalityType)
        - **Mood Score**: \(String(format: "%.2f", moodAnalysis.moodScore))/10
        - **Engagement Level**: \(String(format: "%.1f", userProfile.behavioralProfile["engagementLevel"] as? Double ?? 0.5 * 100))%
        - **Attention Span**: \(String(format: "%.1f", userProfile.behavioralProfile["attentionSpan"] as? Double ?? 5.0))s
        - **Interaction Velocity**: \(String(format: "%.2f", userProfile.behavioralProfile["interactionVelocity"] as? Double ?? 0.0)) taps/min
        
        ### APPLE TOUCH ANALYTICS (Mood Detection)
        - **Average Touch Force**: \(String(format: "%.2f", userProfile.touchAnalytics["averageForce"] as? Double ?? 0.0))/1.0
        - **Touch Velocity**: \(String(format: "%.0f", userProfile.touchAnalytics["touchVelocity"] as? Double ?? 0.0)) px/s
        - **Gesture Patterns**: \(userProfile.touchAnalytics["gesturePatterns"] as? [String: Any] ?? [:])
        - **Recent Mood Indicators**: \(userProfile.touchAnalytics["moodIndicators"] as? [String] ?? [])
        
        ### REAL-TIME BEHAVIORAL METRICS
        - **Current Engagement**: \(String(format: "%.1f", userProfile.realtimeMetrics["engagementLevel"] as? Double ?? 0.5 * 100))%
        - **Attention Span**: \(String(format: "%.1f", userProfile.realtimeMetrics["attentionSpan"] as? Double ?? 5.0))s
        - **Interaction Intensity**: \(String(format: "%.2f", userProfile.realtimeMetrics["interactionIntensity"] as? Double ?? 0.0))
        - **Current Session**: \(String(format: "%.0f", userProfile.currentSession["duration"] as? Double ?? 0))s active
        
        ### CATEGORY PREFERENCES & BEHAVIORAL PATTERNS
        **Strong Preferences (High Affinity)**:
        \(formatCategoryAffinities(userProfile.categoryAffinities))
        
        **Avoidance Patterns**:
        \(formatCategoryAvoidance(userProfile.categoryAvoidance))
        
        **Behavioral Insights**:
        \(behaviorInsights)
        
        ### CONTEXTUAL INTELLIGENCE
        - **Time Context**: \(contextualData.timeOfDay) on \(contextualData.dayOfWeek) (\(contextualData.isWeekend ? "Weekend" : "Weekday"))
        - **Season**: \(contextualData.season)
        - **Weather**: \(contextualData.weather)
        - **Social Context**: \(contextualData.socialContext)
        - **Economic Context**: \(contextualData.economicContext)
        - **Location Context**: \(contextualData.locationContext)
        
        ### PERSONALITY & PSYCHOLOGICAL PROFILING
        \(personalityInsights)
        
        ### INTERACTION HISTORY ANALYSIS
        - **Total Sessions**: \(interactionHistory.totalSessions)
        - **Average Session**: \(String(format: "%.1f", interactionHistory.averageSessionDuration))s
        - **Most Active Time**: \(interactionHistory.mostActiveTimeOfDay)
        - **Preferred Categories**: \(interactionHistory.preferredCategories.joined(separator: ", "))
        - **Interaction Style**: \(String(format: "%.2f", interactionHistory.interactionVelocity)) interactions/min
        
        ### CONTEXTUAL RELEVANCE ANALYSIS
        \(contextualRelevance)
        
        ### AVAILABLE PLACES FOR RECOMMENDATION
        \(formatPlacesForAI(places))
        
        ## ADVANCED RECOMMENDATION REQUIREMENTS
        
        Based on this comprehensive behavioral profile, psychological analysis, and Apple device analytics, please generate 3-5 hyper-personalized recommendations that:
        
        1. **Match Current Mood & Energy**: Align with \(moodAnalysis.primaryMood) mood and \(moodAnalysis.energyLevel) energy level
        2. **Respect Touch Patterns**: Consider \(String(format: "%.2f", userProfile.behavioralProfile["lastTouchForce"] as? Double ?? 0.0)) force indicating \(interpretTouchForce(userProfile.behavioralProfile["lastTouchForce"] as? Double ?? 0.0))
        3. **Align with Personality**: Cater to \(moodAnalysis.personalityType) personality type
        4. **Context Optimization**: Perfect for \(contextualData.timeOfDay) \(contextualData.dayOfWeek) activities
        5. **Device Consideration**: Account for \(deviceAnalytics.batteryLevel < 0.3 ? "low battery" : "good device state") and \(deviceAnalytics.usagePattern) usage
        
        **Response Format**: JSON array with objects containing:
        - `placeName`: Exact place name from the list
        - `confidence`: 0.0-1.0 confidence score
        - `reasoning`: Detailed psychological and behavioral reasoning
        - `moodAlignment`: How it matches current mood/energy
        - `personalityFit`: Why it suits their personality type
        - `contextualRelevance`: Perfect timing/situation explanation
        - `behavioralPrediction`: Expected user reaction based on analytics
        - `alternativeTime`: Better time if current context isn't optimal
        
        Focus on places that will genuinely resonate with this user's behavioral patterns, current psychological state, and contextual situation. Use the comprehensive analytics to make predictions that feel almost telepathic in their accuracy.
        """
    }
    
    // MARK: - Analysis Methods
    
    private func analyzeBehaviorPatterns(_ profile: UserBehavioralProfile, _ history: InteractionHistory) -> String {
        var insights: [String] = []
        
        // Analyze reaction patterns
        let totalReactions = profile.totalThumbsUp + profile.totalThumbsDown
        if totalReactions > 0 {
            let positivityRatio = Double(profile.totalThumbsUp) / Double(totalReactions)
            if positivityRatio > 0.7 {
                insights.append("• Highly positive and open to new experiences (\(String(format: "%.0f", positivityRatio * 100))% positive reactions)")
            } else if positivityRatio < 0.3 {
                insights.append("• Selective and discerning with high standards (\(String(format: "%.0f", positivityRatio * 100))% positive reactions)")
            } else {
                insights.append("• Balanced and thoughtful in preferences (\(String(format: "%.0f", positivityRatio * 100))% positive reactions)")
            }
        }
        
        // Analyze interaction velocity
        if history.interactionVelocity > 5.0 {
            insights.append("• Fast-paced decision maker who values efficiency")
        } else if history.interactionVelocity < 1.0 {
            insights.append("• Deliberate and thorough in exploring options")
        }
        
        // Analyze session patterns
        if history.averageSessionDuration > 300 {
            insights.append("• Deep engagement with detailed exploration sessions")
        } else if history.averageSessionDuration < 60 {
            insights.append("• Quick decision maker with focused objectives")
        }
        
        return insights.isEmpty ? "Standard behavioral patterns observed" : insights.joined(separator: "\n")
    }
    
    private func analyzePersonalityTraits(_ profile: UserBehavioralProfile, _ mood: MoodAnalysis) -> String {
        var traits: [String] = []
        
        // Analyze based on engagement patterns
        let engagementLevel = profile.behavioralProfile["engagementLevel"] as? Double ?? 0.5
        if engagementLevel > 0.8 {
            traits.append("• **High Engagement Type**: Thrives on active, immersive experiences")
        } else if engagementLevel < 0.3 {
            traits.append("• **Calm Observer Type**: Prefers peaceful, low-stimulation environments")
        }
        
        // Analyze attention patterns
        let attentionSpan = profile.behavioralProfile["attentionSpan"] as? Double ?? 5.0
        if attentionSpan > 10.0 {
            traits.append("• **Deep Focus Personality**: Enjoys complex, layered experiences")
        } else if attentionSpan < 3.0 {
            traits.append("• **Quick Burst Personality**: Prefers bite-sized, immediate gratification")
        }
        
        // Mood-based personality insights
        switch mood.primaryMood {
        case "excited_enthusiastic":
            traits.append("• **Adventure Seeker**: Currently in high-energy exploration mode")
        case "confident_deliberate":
            traits.append("• **Decisive Leader**: Takes charge and makes firm choices")
        case "tentative_careful":
            traits.append("• **Thoughtful Planner**: Values safety and predictability")
        case "focused_engaged":
            traits.append("• **Goal-Oriented Achiever**: Task-focused with clear objectives")
        default:
            traits.append("• **Balanced Explorer**: Adaptive to various experience types")
        }
        
        return traits.isEmpty ? "Personality analysis in progress" : traits.joined(separator: "\n")
    }
    
    private func analyzeContextualRelevance(_ context: ContextualData, _ mood: MoodAnalysis) -> String {
        var relevance: [String] = []
        
        // Time-based relevance
        switch context.timeOfDay {
        case "morning":
            relevance.append("• **Morning Energy**: Perfect time for fresh starts and new discoveries")
        case "afternoon":
            relevance.append("• **Peak Activity**: Ideal for main activities and social experiences")
        case "evening":
            relevance.append("• **Wind-Down Mode**: Great for relaxing or social experiences")
        case "night":
            relevance.append("• **Night Owl**: Late-night options for spontaneous adventures")
        default:
            break
        }
        
        // Weather-based relevance
        if context.weather.contains("sunny") || context.weather.contains("clear") {
            relevance.append("• **Perfect Weather**: Outdoor activities highly recommended")
        } else if context.weather.contains("rain") || context.weather.contains("storm") {
            relevance.append("• **Cozy Weather**: Indoor experiences will be most appealing")
        }
        
        // Weekend vs weekday
        if context.isWeekend {
            relevance.append("• **Weekend Freedom**: More time for leisurely exploration")
        } else {
            relevance.append("• **Weekday Efficiency**: Quick, convenient options preferred")
        }
        
        return relevance.isEmpty ? "Standard contextual factors" : relevance.joined(separator: "\n")
    }
    
    // MARK: - Helper Methods
    
    private func calculateMoodScore(touchForce: Float, velocity: Double, engagement: Double) -> Double {
        let forceScore = min(Double(touchForce) * 2.0, 1.0) // Normalize force to 0-1
        let velocityScore = min(velocity / 1000.0, 1.0) // Normalize velocity
        let combinedScore = (forceScore * 0.4 + velocityScore * 0.3 + engagement * 0.3) * 10
        return max(0, min(10, combinedScore))
    }
    
    private func determineEnergyLevel(touchForce: Float, velocity: Double, sessionDuration: TimeInterval) -> String {
        let energyScore = (Double(touchForce) * 0.5 + velocity / 1000.0 * 0.3 + min(sessionDuration / 300, 1.0) * 0.2)
        
        if energyScore > 0.7 {
            return "High Energy"
        } else if energyScore > 0.4 {
            return "Moderate Energy"
        } else {
            return "Low Energy"
        }
    }
    
    // MARK: - Core API Communication
    
    /// Make a request to Gemini AI API
    private func makeGeminiRequest(prompt: String) async -> String {
        guard !apiKey.isEmpty else {
            print("❌ Gemini API key not configured")
            return "{\"error\": \"API key not configured\"}"
        }
        
        // Truncate prompt if too long to avoid 400 errors
        let maxPromptLength = 8000
        let truncatedPrompt = prompt.count > maxPromptLength ? String(prompt.prefix(maxPromptLength)) + "..." : prompt
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": truncatedPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 1024,
                "stopSequences": []
            ],
            "safetySettings": [
                [
                    "category": "HARM_CATEGORY_HARASSMENT",
                    "threshold": "BLOCK_MEDIUM_AND_ABOVE"
                ],
                [
                    "category": "HARM_CATEGORY_HATE_SPEECH", 
                    "threshold": "BLOCK_MEDIUM_AND_ABOVE"
                ]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Fix: Include API key in URL as query parameter
            let urlWithKey = "\(baseURL)?key=\(apiKey)"
            guard let url = URL(string: urlWithKey) else {
                print("❌ Invalid URL with API key")
                return "{\"error\": \"Invalid URL\"}"
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            request.timeoutInterval = 30.0
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                return "{\"error\": \"Invalid response\"}"
            }
            
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Gemini API error \(httpResponse.statusCode): \(errorBody)")
                return createFallbackResponse()
            }
            
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = jsonResponse["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
                
                print("❌ Failed to parse Gemini response structure")
                return createFallbackResponse()
            }
            
            return text
            
        } catch {
            print("❌ Error making Gemini request: \(error)")
            return createFallbackResponse()
        }
    }
    
    private func createFallbackResponse() -> String {
        return """
        [{
            "placeName": "Local Favorite",
            "confidence": 0.7,
            "reasoning": "Based on your location and general preferences",
            "moodAlignment": "Matches current context", 
            "personalityFit": "Suitable for your style",
            "contextualRelevance": "Perfect for this time",
            "behavioralPrediction": "You'll enjoy this experience",
            "alternativeTime": "Available anytime"
        }]
        """
    }
    
    private func parseGeminiResponse(_ response: String) -> [AIRecommendation] {
        // Clean and safe JSON extraction
        let cleanedResponse = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Safe range finding to prevent index out of bounds
        guard let jsonStart = cleanedResponse.firstIndex(of: "["),
              let jsonEnd = cleanedResponse.lastIndex(of: "]") else {
            print("❌ No JSON array found in response")
            return createFallbackRecommendations()
        }
        
        // Ensure valid range
        guard jsonStart <= jsonEnd else {
            print("❌ Invalid JSON range")
            return createFallbackRecommendations()
        }
        
        let jsonString = String(cleanedResponse[jsonStart...jsonEnd])
        
        do {
            guard let data = jsonString.data(using: .utf8),
                  let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("❌ Failed to parse JSON array")
                return createFallbackRecommendations()
            }
            
            let recommendations = jsonArray.compactMap { dict -> AIRecommendation? in
                // Safe value extraction with defaults
                let placeName = dict["placeName"] as? String ?? "Unknown Place"
                let confidence = dict["confidence"] as? Double ?? 0.5
                let reasoning = dict["reasoning"] as? String ?? "Generated recommendation"
                
                return AIRecommendation(
                    placeName: placeName,
                    confidence: confidence,
                    reasoning: reasoning,
                    moodAlignment: dict["moodAlignment"] as? String ?? "General fit",
                    personalityFit: dict["personalityFit"] as? String ?? "Suitable",
                    contextualRelevance: dict["contextualRelevance"] as? String ?? "Good timing",
                    behavioralPrediction: dict["behavioralPrediction"] as? String ?? "Positive experience",
                    alternativeTime: dict["alternativeTime"] as? String ?? "Flexible timing"
                )
            }
            
            return recommendations.isEmpty ? createFallbackRecommendations() : recommendations
            
        } catch {
            print("❌ Error parsing JSON: \(error)")
            return createFallbackRecommendations()
        }
    }
    
    private func createFallbackRecommendations() -> [AIRecommendation] {
        return [
            AIRecommendation(
                placeName: "Local Recommendation",
                confidence: 0.7,
                reasoning: "Based on your general preferences and location",
                moodAlignment: "Matches your current energy level",
                personalityFit: "Aligns with your exploration style",
                contextualRelevance: "Perfect for this time of day",
                behavioralPrediction: "You'll discover something interesting",
                alternativeTime: "Great anytime you're free"
            )
        ]
    }
    
    private func storeRecommendationsWithAnalytics(_ recommendations: [AIRecommendation], userProfile: UserBehavioralProfile) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let recommendationData: [String: Any] = [
            "recommendations": recommendations.map { recommendation in
                [
                    "placeName": recommendation.placeName,
                    "confidence": recommendation.confidence,
                    "reasoning": recommendation.reasoning,
                    "moodAlignment": recommendation.moodAlignment,
                    "personalityFit": recommendation.personalityFit,
                    "contextualRelevance": recommendation.contextualRelevance,
                    "behavioralPrediction": recommendation.behavioralPrediction,
                    "alternativeTime": recommendation.alternativeTime
                ]
            },
            "generatedAt": FieldValue.serverTimestamp(),
            "userMood": userProfile.behavioralProfile["currentMood"] as? String ?? "unknown",
            "contextualFactors": [
                "timeOfDay": getTimeOfDay(hour: Calendar.current.component(.hour, from: Date())),
                "deviceBattery": UIDevice.current.batteryLevel,
                "engagementLevel": userProfile.behavioralProfile["engagementLevel"] as? Double ?? 0.5
            ]
        ]
        
        do {
            try await db.collection("userAnalytics")
                .document(uid)
                .collection("aiRecommendations")
                .addDocument(data: recommendationData)
            
            print("✅ Stored AI recommendations with analytics")
        } catch {
            print("❌ Error storing recommendations: \(error)")
        }
    }
    
    // MARK: - Public API Methods
    
    /// Send a request to Gemini AI (used by AdvancedSentimentService)
    func sendGeminiRequest(prompt: String, completion: @escaping (String) -> Void) {
        Task {
            let response = await makeGeminiRequest(prompt: prompt)
            await MainActor.run {
                completion(response)
            }
        }
    }
    
    // MARK: - Compatibility helper wrappers
    
    /// Legacy wrapper used by DynamicCategoryManager to fetch a raw structured JSON response.
    func generateStructuredResponse(prompt: String, completion: @escaping (String) -> Void) {
        sendGeminiRequest(prompt: prompt, completion: completion)
    }
    
    /// Async helper used by MissionManager to generate mission ideas.
    func generateMissionIdeas(prompt: String) async throws -> String {
        await makeGeminiRequest(prompt: prompt)
    }
    
    /// Generates an engaging human-readable description for a Google place. Falls back to a simple default on failures.
    @MainActor func generatePlaceDescription(for place: GooglePlaceDetails, completion: @escaping (String) -> Void) {
        let prompt = """
        Write a concise, enthusiastic 2-sentence description (max 45 words) that would entice a user to visit the following place.
        Be specific and highlight what makes it special.
        
        Place name: \(place.name)
        Category types: \(place.types?.joined(separator: ", ") ?? "unknown")
        Average rating: \(String(format: "%.1f", place.rating ?? 0.0)) (\(place.user_ratings_total ?? 0) reviews)
        Address: \(place.address)
        """
        
        sendGeminiRequest(prompt: prompt) { raw in
            // Strip unnecessary formatting if Gemini wrapped the text in markdown
            let cleaned = raw
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            completion(cleaned.isEmpty ? "Discover this amazing place and what it has to offer!" : cleaned)
        }
    }
}

// MARK: - Gemini-specific Extensions and Helpers
// (All data structures are now in AppModels.swift to avoid duplication) 

