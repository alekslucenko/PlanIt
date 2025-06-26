import Foundation
import Combine
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class RecommendationManager: ObservableObject {
    static let shared = RecommendationManager()
    
    private init() {
        setupFingerprintListener()
    }

    @Published private(set) var personalizedRecommendations: [PersonalizedRecommendation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var currentContext: RecommendationContext?
    
    private let fingerprintManager = UserFingerprintManager.shared
    private let geminiService = GeminiAIService.shared
    private let placesService = GooglePlacesService()
    private let weatherService = WeatherService()
    private let db = Firestore.firestore()
    
    private var cancellables = Set<AnyCancellable>()
    private var currentLocation: CLLocation?
    
    /// Sets up listener for fingerprint changes to auto-refresh recommendations
    private func setupFingerprintListener() {
        NotificationCenter.default.addObserver(
            forName: .fingerprintDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      let location = self.currentLocation else { return }
                
                print("🔄 Auto-refreshing recommendations due to fingerprint change")
                await self.generatePersonalizedRecommendations(currentLocation: location)
            }
        }
    }
    
    /// Generates personalized recommendations based on user's JSON fingerprint
    func generatePersonalizedRecommendations(currentLocation: CLLocation?) async {
        guard let location = currentLocation else {
            print("❌ No location available for recommendations")
            return
        }
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user for recommendations")
            return
        }
        
        // Store current location for auto-refresh
        self.currentLocation = location
        
        isLoading = true
        
        print("🤖 Generating ultra-personalized recommendations using user fingerprint...")
        
        // Build comprehensive context from user fingerprint
        let context = await buildPersonalizedContext(location: location, userId: uid)
        currentContext = context
        
        // Generate AI-powered recommendations
        let recommendations = await generateAIRecommendations(context: context, location: location)
        
        // Fetch real Google Places data for each recommendation
        let enhancedRecommendations = await enhanceWithGooglePlaces(recommendations: recommendations, location: location)
        
        personalizedRecommendations = enhancedRecommendations
        lastUpdateTime = Date()
        isLoading = false
        
        print("✅ Generated \(enhancedRecommendations.count) personalized recommendations")
    }
    
    /// Updates user fingerprint when they react to a place
    func updateUserFingerprintFromReaction(place: Place, reaction: UserReaction) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        print("🧬 Updating user fingerprint from \(reaction.rawValue) on \(place.name)")
        
        // Get user info from Firestore for enhanced tracking
        do {
            let userDoc = try await db.collection("users").document(uid).getDocument()
            if let userData = userDoc.data() {
                let userEmail = userData["email"] as? String ?? ""
                let userDisplayName = userData["displayName"] as? String ?? ""
                
                // Use SimpleBehaviorManager for enhanced tracking
                let action = reaction == .liked ? "liked" : "disliked"
                await SimpleBehaviorManager.shared.recordUserBehavior(
                    placeId: place.googlePlaceId ?? place.id.uuidString,
                    placeName: place.name,
                    action: action,
                    userEmail: userEmail,
                    userDisplayName: userDisplayName
                )
                
                // Legacy update for backward compatibility
                let interactionLog: [String: Any] = [
                    "placeId": place.googlePlaceId ?? "",
                    "placeName": place.name,
                    "category": place.category.rawValue,
                    "reaction": reaction.rawValue,
                    "timestamp": FieldValue.serverTimestamp(),
                    "location": place.location,
                    "rating": place.rating,
                    "priceRange": place.priceRange,
                    "userEmail": userEmail,
                    "userDisplayName": userDisplayName
                ]
                
                // Update likes/dislikes arrays
                var updates: [String: Any] = [
                    "interactionLogs": FieldValue.arrayUnion([interactionLog])
                ]
                
                switch reaction {
                case .liked:
                    updates["likes"] = FieldValue.arrayUnion([place.name])
                    updates["dislikes"] = FieldValue.arrayRemove([place.name])
                case .disliked:
                    updates["dislikes"] = FieldValue.arrayUnion([place.name])
                    updates["likes"] = FieldValue.arrayRemove([place.name])
                }
                
                try await db.collection("users").document(uid).updateData(updates)
                print("✅ Enhanced fingerprint updated for \(userEmail)")
                
                // Trigger re-recommendation with personalized data
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    Task {
                        if let location = LocationManager().selectedLocation {
                            await self.generatePersonalizedRecommendations(currentLocation: location)
                        }
                    }
                }
            }
        } catch {
            print("❌ Error updating fingerprint: \(error)")
        }
    }
    
    /// Refreshes recommendations when fingerprint changes
    func refreshRecommendations(currentLocation: CLLocation?) {
        Task {
            await generatePersonalizedRecommendations(currentLocation: currentLocation)
        }
    }
    
    // MARK: - Private Methods
    
    private func buildPersonalizedContext(location: CLLocation, userId: String) async -> RecommendationContext {
        let fingerprint = fingerprintManager.fingerprint
        
        let context = RecommendationContext(
            userId: userId,
            location: location,
            currentTime: Date(),
            weatherCondition: weatherService.currentWeather?.condition,
            userFingerprint: fingerprint,
            previousRecommendations: personalizedRecommendations.map { $0.place.name }
        )
        
        return context
    }
    
    private func generateAIRecommendations(context: RecommendationContext, location: CLLocation) async -> [AIRecommendation] {
        let prompt = buildUltraPersonalizedPrompt(context: context)
        
        return await withCheckedContinuation { continuation in
            geminiService.generatePersonalizedRecommendations(prompt: prompt) { recommendations in
                continuation.resume(returning: recommendations)
            }
        }
    }
    
    private func enhanceWithGooglePlaces(recommendations: [AIRecommendation], location: CLLocation) async -> [PersonalizedRecommendation] {
        var enhanced: [PersonalizedRecommendation] = []
        
        for aiRec in recommendations {
            // Search for the specific place using Google Places API
            let googlePlaces = await searchGooglePlaces(for: aiRec, near: location)
            
            for googlePlace in googlePlaces.prefix(1) { // Take the best match
                let personalizedRec = PersonalizedRecommendation(
                    id: UUID().uuidString,
                    place: googlePlace.toAppPlace(),
                    aiRecommendation: aiRec,
                    whyRecommended: aiRec.personalizedReason,
                    confidenceScore: aiRec.confidenceScore,
                    matchingPreferences: aiRec.matchingPreferences
                )
                enhanced.append(personalizedRec)
            }
        }
        
        return enhanced.sorted { $0.confidenceScore > $1.confidenceScore }
    }
    
    private func searchGooglePlaces(for aiRec: AIRecommendation, near location: CLLocation) async -> [GooglePlace] {
        return await withCheckedContinuation { continuation in
            placesService.searchPlacesByText(
                query: "\(aiRec.placeName) \(aiRec.category)",
                location: location,
                radius: 5000
            ) { places in
                continuation.resume(returning: places)
            }
        }
    }
    
    private func buildUltraPersonalizedPrompt(context: RecommendationContext) -> String {
        guard let fingerprint = context.userFingerprint else {
            return "Generate 5 general recommendations for restaurants, cafes, and entertainment venues."
        }
        
        // Enhanced behavioral prompt (asynchronous, will be implemented separately)
        // For now, using existing fingerprint approach
        
        var prompt = """
        You are PlanIt's ultra-personalized AI recommendation engine. Analyze this user's complete profile and generate highly personalized place recommendations.
        
        USER PROFILE:
        """
        
        if let name = fingerprint.displayName {
            prompt += "\nName: \(name)"
        }
        
        prompt += "\n\nUSER PREFERENCES:"
        if !fingerprint.preferredPlaceTypes.isEmpty {
            prompt += "\nPreferred Place Types: \(fingerprint.preferredPlaceTypes.joined(separator: ", "))"
        }
        
        if !fingerprint.moodHistory.isEmpty {
            prompt += "\nRecent Moods: \(fingerprint.moodHistory.joined(separator: ", "))"
        }
        
        if !fingerprint.cuisineHistory.isEmpty {
            prompt += "\nCuisine Preferences: \(fingerprint.cuisineHistory.joined(separator: ", "))"
        }
        
        if let likes = fingerprint.likes, !likes.isEmpty {
            prompt += "\n\nLIKED PLACES: \(likes.joined(separator: ", "))"
        }
        
        if let dislikes = fingerprint.dislikes, !dislikes.isEmpty {
            prompt += "\nDISLIKED PLACES: \(dislikes.joined(separator: ", "))"
        }
        
        if let tagAffinities = fingerprint.tagAffinities, !tagAffinities.isEmpty {
            let topTags = tagAffinities.sorted { $0.value > $1.value }.prefix(5)
            prompt += "\nTOP INTERESTS: \(topTags.map { "\($0.key) (\($0.value))" }.joined(separator: ", "))"
        }
        
        prompt += """
        
        RESPOND WITH ONLY JSON ARRAY - NO OTHER TEXT!
        
        Context: \(context.location.coordinate.latitude), \(context.location.coordinate.longitude) at \(DateFormatter.localizedString(from: context.currentTime, dateStyle: .medium, timeStyle: .short))
        
        [
          {
            "placeName": "Trending Restaurant",
            "category": "restaurant",
            "personalizedReason": "Highly rated local favorite with excellent reviews",
            "confidenceScore": 0.95,
            "matchingPreferences": ["highly rated", "local favorite"]
          },
          {
            "placeName": "Coffee Discovery",
            "category": "cafe",
            "personalizedReason": "Perfect coffee shop for your caffeine needs",
            "confidenceScore": 0.90,
            "matchingPreferences": ["coffee", "cozy atmosphere"]
          },
          {
            "placeName": "Local Favorite",
            "category": "bar", 
            "personalizedReason": "Great spot for evening drinks and socializing",
            "confidenceScore": 0.85,
            "matchingPreferences": ["nightlife", "good drinks"]
          }
        ]
        """
        
        return prompt
    }
}

// MARK: - Models

struct RecommendationContext {
    let userId: String
    let location: CLLocation
    let currentTime: Date
    let weatherCondition: String?
    let userFingerprint: AppUserFingerprint?
    let previousRecommendations: [String]
}

struct AIRecommendation: Codable {
    // Core fields returned by newest Gemini prompting
    let placeName: String
    let confidence: Double
    let reasoning: String
    let moodAlignment: String
    let personalityFit: String
    let contextualRelevance: String
    let behavioralPrediction: String
    let alternativeTime: String

    // Legacy / compatibility fields (still used in other modules)
    let category: String
    let personalizedReason: String
    let confidenceScore: Double
    let matchingPreferences: [String]

    // MARK: - Designated initializer for newest Gemini response
    init(
        placeName: String,
        confidence: Double,
        reasoning: String,
        moodAlignment: String = "",
        personalityFit: String = "",
        contextualRelevance: String = "",
        behavioralPrediction: String = "",
        alternativeTime: String = ""
    ) {
        // New-era properties
        self.placeName = placeName
        self.confidence = confidence
        self.reasoning = reasoning
        self.moodAlignment = moodAlignment
        self.personalityFit = personalityFit
        self.contextualRelevance = contextualRelevance
        self.behavioralPrediction = behavioralPrediction
        self.alternativeTime = alternativeTime

        // Provide safe defaults for legacy fields so older code continues to compile
        self.category = "unknown"
        self.personalizedReason = reasoning
        self.confidenceScore = confidence
        self.matchingPreferences = []
    }

    // MARK: - Legacy initializer kept for existing calls
    init(
        placeName: String,
        category: String,
        personalizedReason: String,
        confidenceScore: Double,
        matchingPreferences: [String]
    ) {
        // Legacy properties
        self.placeName = placeName
        self.category = category
        self.personalizedReason = personalizedReason
        self.confidenceScore = confidenceScore
        self.matchingPreferences = matchingPreferences

        // Map to new schema with sensible defaults
        self.confidence = confidenceScore
        self.reasoning = personalizedReason
        self.moodAlignment = ""
        self.personalityFit = ""
        self.contextualRelevance = ""
        self.behavioralPrediction = ""
        self.alternativeTime = ""
    }
}

struct PersonalizedRecommendation: Identifiable {
    let id: String
    let place: Place
    let aiRecommendation: AIRecommendation
    let whyRecommended: String
    let confidenceScore: Double
    let matchingPreferences: [String]
}



// MARK: - Extensions

extension GeminiAIService {
    func generatePersonalizedRecommendations(prompt: String, completion: @escaping ([AIRecommendation]) -> Void) {
        sendGeminiRequest(prompt: prompt) { response in
            // Clean the response to extract JSON
            let cleanedResponse = self.extractJSON(from: response)
            
            guard let data = cleanedResponse.data(using: .utf8) else {
                print("❌ No data from AI recommendations")
                completion(self.generateFallbackRecommendations())
                return
            }
            
            do {
                let recommendations = try JSONDecoder().decode([AIRecommendation].self, from: data)
                print("✅ Generated \(recommendations.count) AI recommendations")
                completion(recommendations)
            } catch {
                print("❌ Failed to parse AI recommendations: \(error)")
                print("❌ Raw response: \(response)")
                print("❌ Cleaned response: \(cleanedResponse)")
                
                // Try to extract valid recommendations from malformed JSON
                let extractedRecommendations = self.extractRecommendationsFromText(response)
                if !extractedRecommendations.isEmpty {
                    print("✅ Extracted \(extractedRecommendations.count) recommendations from text")
                    completion(extractedRecommendations)
                } else {
                    completion(self.generateFallbackRecommendations())
                }
            }
        }
    }
    
    private func extractJSON(from text: String) -> String {
        // First, remove any markdown code blocks
        var cleanText = text.replacingOccurrences(of: "```json", with: "")
        cleanText = cleanText.replacingOccurrences(of: "```", with: "")
        
        // Remove any text before the first [ or {
        if let startBracket = cleanText.firstIndex(of: "[") {
            cleanText = String(cleanText[startBracket...])
        } else if let startBrace = cleanText.firstIndex(of: "{") {
            cleanText = String(cleanText[startBrace...])
        }
        
        // Remove any text after the last ] or }
        if let lastBracket = cleanText.lastIndex(of: "]") {
            cleanText = String(cleanText[...lastBracket])
        } else if let lastBrace = cleanText.lastIndex(of: "}") {
            cleanText = String(cleanText[...lastBrace])
        }
        
        // Try to find a complete JSON array using NSRegularExpression for multiline support
        let arrayPattern = "\\[.*\\]"
        if let regex = try? NSRegularExpression(pattern: arrayPattern, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: cleanText, options: [], range: NSRange(location: 0, length: cleanText.count)) {
            let range = Range(match.range, in: cleanText)!
            return String(cleanText[range])
        }
        
        // Try to find a complete JSON object and wrap it in an array
        let objectPattern = "\\{.*\\}"
        if let regex = try? NSRegularExpression(pattern: objectPattern, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: cleanText, options: [], range: NSRange(location: 0, length: cleanText.count)) {
            let range = Range(match.range, in: cleanText)!
            let jsonObject = String(cleanText[range])
            return "[\(jsonObject)]"
        }
        
        return cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractRecommendationsFromText(_ text: String) -> [AIRecommendation] {
        var recommendations: [AIRecommendation] = []
        
        // Try to extract structured data from text even if JSON parsing fails
        let lines = text.components(separatedBy: .newlines)
        
        var currentRec: [String: String] = [:]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.contains("\"placeName\":") {
                if let placeName = extractValue(from: trimmed, key: "placeName") {
                    currentRec["placeName"] = placeName
                }
            } else if trimmed.contains("\"category\":") {
                if let category = extractValue(from: trimmed, key: "category") {
                    currentRec["category"] = category
                }
            } else if trimmed.contains("\"personalizedReason\":") {
                if let reason = extractValue(from: trimmed, key: "personalizedReason") {
                    currentRec["personalizedReason"] = reason
                }
            } else if trimmed.contains("\"confidenceScore\":") {
                if let confidence = extractValue(from: trimmed, key: "confidenceScore") {
                    currentRec["confidenceScore"] = confidence
                }
            } else if trimmed.contains("\"matchingPreferences\":") {
                // Simple extraction of preferences array
                currentRec["matchingPreferences"] = "[]"
            }
            
            // If we have enough data, create recommendation
            if currentRec.count >= 4 {
                let recommendation = AIRecommendation(
                    placeName: currentRec["placeName"] ?? "Recommendation",
                    category: currentRec["category"] ?? "restaurant",
                    personalizedReason: currentRec["personalizedReason"] ?? "Selected based on your preferences",
                    confidenceScore: Double(currentRec["confidenceScore"] ?? "0.7") ?? 0.7,
                    matchingPreferences: []
                )
                recommendations.append(recommendation)
                currentRec.removeAll()
            }
        }
        
        return recommendations
    }
    
    private func extractValue(from line: String, key: String) -> String? {
        let pattern = "\"\(key)\":\\s*\"([^\"]*)\""
        if let range = line.range(of: pattern, options: .regularExpression) {
            let match = String(line[range])
            let components = match.components(separatedBy: "\"")
            return components.count >= 4 ? components[3] : nil
        }
        return nil
    }
    
    private func generateFallbackRecommendations() -> [AIRecommendation] {
        return [
            AIRecommendation(
                placeName: "Trending Restaurant",
                category: "restaurant",
                personalizedReason: "Popular choice in your area with great reviews",
                confidenceScore: 0.8,
                matchingPreferences: ["highly rated", "local favorite"]
            ),
            AIRecommendation(
                placeName: "Coffee Discovery",
                category: "cafe",
                personalizedReason: "Perfect for your coffee preferences",
                confidenceScore: 0.7,
                matchingPreferences: ["coffee", "cozy atmosphere"]
            ),
            AIRecommendation(
                placeName: "Local Favorite",
                category: "bar",
                personalizedReason: "Highly rated spot for evening plans",
                confidenceScore: 0.6,
                matchingPreferences: ["nightlife", "good drinks"]
            )
        ]
    }
}

extension GooglePlace {
    func distanceMiles(from location: CLLocation) -> Double {
        guard let lat = self.geometry?.location.lat, let lng = self.geometry?.location.lng else {
            return Double.greatestFiniteMagnitude
        }
        let placeLoc = CLLocation(latitude: lat, longitude: lng)
        return placeLoc.distance(from: location) / 1609.34
    }
} 