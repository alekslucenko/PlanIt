import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// DynamicCategory is defined in AppModels.swift

// MARK: - Dynamic Category Manager
@MainActor
class DynamicCategoryManager: ObservableObject {
    static let shared = DynamicCategoryManager()
    
    @Published var dynamicCategories: [DynamicCategory] = []
    @Published var isGenerating = false
    @Published var lastGenerated = Date()
    @Published var isLoading = false
    @Published var isGeneratingCategories = false
    
    private let geminiService = GeminiAIService.shared
    private let fingerprintManager = UserFingerprintManager.shared
    private let placesService = GooglePlacesService()
    
    /// Generates fresh dynamic categories based on user fingerprint
    func generateDynamicCategories(location: CLLocation) async {
        guard let userFingerprint = fingerprintManager.fingerprint else {
            print("❌ No user fingerprint available for category generation")
            await generateFallbackCategories(location: location)
            return
        }
        
        isGenerating = true
        print("🎯 Generating dynamic categories based on user fingerprint...")
        
        // Generate AI-powered category ideas
        let categoryPrompt = buildCategoryGenerationPrompt(fingerprint: userFingerprint, location: location)
        
        let generatedCategories = await generateCategoriesWithGemini(prompt: categoryPrompt)
        
        // Fetch places for each category
        var enrichedCategories: [DynamicCategory] = []
        
        for category in generatedCategories {
            let places = await fetchPlacesForCategory(category: category, location: location)
            var enrichedCategory = category
            enrichedCategory.places = places
            
            // Only add categories that have places
            if !places.isEmpty {
                enrichedCategories.append(enrichedCategory)
            }
        }
        
        // Always ensure we have at least some categories with places
        if enrichedCategories.isEmpty || enrichedCategories.count < 3 {
            print("❌ Generated categories had insufficient places, using enhanced fallbacks")
            await generateFallbackCategories(location: location)
        } else {
            // Order by highest confidence (user-liking) first, then shuffle places for variety
            var orderedCategories = enrichedCategories.sorted { $0.confidence > $1.confidence }
            for index in orderedCategories.indices {
                orderedCategories[index].places.shuffle()
            }

            self.dynamicCategories = orderedCategories
            print("✅ Generated \(enrichedCategories.count) dynamic categories with \(enrichedCategories.reduce(0) { $0 + $1.places.count }) total places")
        }
        
        isGenerating = false
        lastGenerated = Date()
    }
    
    /// Builds the AI prompt for category generation
    private func buildCategoryGenerationPrompt(fingerprint: AppUserFingerprint, location: CLLocation) -> String {
        let timeOfDay = getCurrentTimeOfDay()
        let dayOfWeek = getCurrentDayOfWeek()
        
        // Extract user preferences from fingerprint
        let userLikes = fingerprint.likes?.joined(separator: ", ") ?? "general places"
        let userDislikes = fingerprint.dislikes?.joined(separator: ", ") ?? "none specified"
        
        let onboardingPrefs = extractOnboardingPreferences(fingerprint)
        let interactionPatterns = analyzeInteractionPatterns(fingerprint)
        
        return """
        RESPOND WITH ONLY VALID JSON ARRAY - NO OTHER TEXT OR MARKDOWN!

        Create 12 highly personalized categories for this user based on their behavioral data:

        USER DATA:
        Location: \(location.coordinate.latitude), \(location.coordinate.longitude)
        Time: \(timeOfDay) - \(dayOfWeek)
        Likes: \(userLikes)
        Dislikes: \(userDislikes)
        Preferences: \(onboardingPrefs)
        Interaction Patterns: \(interactionPatterns)
        Weather: \(getCurrentWeatherContext())
        
        CATEGORY REQUIREMENTS:
        - Use VERY specific, personalized titles (not generic like "restaurants")
        - Include emotional/vibe descriptors (cozy, trendy, intimate, energetic)
        - Reference specific cuisine types, atmospheres, or unique features
        - Make reasoning personal using "you" and specific user data
        - Vary confidence based on how well it matches user patterns
        - Include time-sensitive categories for current time/weather

        REQUIRED JSON FORMAT (COPY EXACTLY):
        [
          {
            "id": "cozy_italian_hideaways",
            "title": "Cozy Italian Hideaways You'll Love",
            "subtitle": "Intimate pasta spots with that warm, authentic vibe",
            "reasoning": "You love cozy atmospheres and Italian food based on your recent likes",
            "searchQuery": "italian restaurant cozy intimate authentic pasta near me",
            "category": "restaurants",
            "confidence": 0.95,
            "personalizedEmoji": "🍝",
            "vibeDescription": "Warm, intimate Italian dining with authentic charm"
          },
          {
            "id": "trendy_rooftop_cocktails",
            "title": "Trendy Rooftop Cocktail Scenes",
            "subtitle": "Instagram-worthy drinks with city views",
            "reasoning": "You enjoy trendy spots and cocktails, perfect for \(timeOfDay) vibes",
            "searchQuery": "rooftop bar cocktail trendy instagram views near me",
            "category": "bars",
            "confidence": 0.88,
            "personalizedEmoji": "🍹",
            "vibeDescription": "Elevated cocktail experiences with stunning views"
          },
          {
            "id": "artisanal_coffee_culture",
            "title": "Artisanal Coffee Culture Spots",
            "subtitle": "Third-wave coffee with laptop-friendly vibes",
            "reasoning": "Your morning routine shows you appreciate quality coffee experiences",
            "searchQuery": "specialty coffee third wave artisanal laptop friendly near me",
            "category": "cafes",
            "confidence": 0.92,
            "personalizedEmoji": "☕",
            "vibeDescription": "Serious coffee craft in welcoming, productive spaces"
          },
          {
            "id": "underground_music_venues",
            "title": "Underground Live Music Gems",
            "subtitle": "Intimate venues with emerging artists",
            "reasoning": "You've shown interest in live music and discovering new artists",
            "searchQuery": "live music venue underground intimate emerging artists near me",
            "category": "venues",
            "confidence": 0.78,
            "personalizedEmoji": "🎵",
            "vibeDescription": "Raw, authentic music experiences in intimate settings"
          },
          {
            "id": "sustainable_local_boutiques",
            "title": "Sustainable Local Boutiques",
            "subtitle": "Eco-conscious fashion and unique finds",
            "reasoning": "Your preferences suggest you value sustainability and unique items",
            "searchQuery": "sustainable boutique local eco fashion unique near me",
            "category": "shopping",
            "confidence": 0.85,
            "personalizedEmoji": "🌱",
            "vibeDescription": "Conscious shopping with one-of-a-kind discoveries"
          },
          {
            "id": "speakeasy_cocktail_dens",
            "title": "Secret Speakeasy Cocktail Dens",
            "subtitle": "Hidden bars with craft cocktails and mystery",
            "reasoning": "You love discovering hidden gems and unique experiences",
            "searchQuery": "speakeasy hidden bar craft cocktails secret entrance near me",
            "category": "bars",
            "confidence": 0.83,
            "personalizedEmoji": "🕵️",
            "vibeDescription": "Mysterious cocktail experiences behind hidden doors"
          },
          {
            "id": "farm_to_table_brunch",
            "title": "Farm-to-Table Brunch Havens",
            "subtitle": "Fresh, local ingredients in Instagram-worthy dishes",
            "reasoning": "Perfect for your weekend brunch preferences and love of fresh food",
            "searchQuery": "farm to table brunch local organic fresh ingredients near me",
            "category": "restaurants",
            "confidence": 0.89,
            "personalizedEmoji": "🥑",
            "vibeDescription": "Fresh, seasonal dining in bright, welcoming spaces"
          },
          {
            "id": "vintage_vinyl_record_shops",
            "title": "Vintage Vinyl & Record Treasures",
            "subtitle": "Dig through rare finds and musical history",
            "reasoning": "Your music interests suggest you'd love discovering vinyl gems",
            "searchQuery": "vinyl record shop vintage music rare finds near me",
            "category": "shopping",
            "confidence": 0.76,
            "personalizedEmoji": "💿",
            "vibeDescription": "Musical archaeology in cozy, nostalgic spaces"
          },
          {
            "id": "craft_beer_microbreweries",
            "title": "Local Craft Beer Microbreweries",
            "subtitle": "Small-batch brews with brewery tours",
            "reasoning": "You appreciate craft beverages and local experiences",
            "searchQuery": "craft beer microbrewery local small batch brewery tour near me",
            "category": "bars",
            "confidence": 0.81,
            "personalizedEmoji": "🍺",
            "vibeDescription": "Artisanal beer experiences with brewery insights"
          },
          {
            "id": "comedy_improv_nights",
            "title": "Comedy & Improv Night Spots",
            "subtitle": "Laugh-filled evenings with emerging comedians",
            "reasoning": "Great for your social side and love of entertainment",
            "searchQuery": "comedy club improv night stand up emerging comedians near me",
            "category": "venues",
            "confidence": 0.74,
            "personalizedEmoji": "😂",
            "vibeDescription": "Spontaneous laughs and social energy"
          },
          {
            "id": "artisan_food_markets",
            "title": "Artisan Food Markets & Tastings",
            "subtitle": "Local producers and gourmet discoveries",
            "reasoning": "Your foodie interests suggest you'd love exploring local artisans",
            "searchQuery": "artisan food market local producers gourmet tasting near me",
            "category": "shopping",
            "confidence": 0.87,
            "personalizedEmoji": "🧀",
            "vibeDescription": "Culinary discoveries from passionate local makers"
          },
          {
            "id": "wellness_meditation_spaces",
            "title": "Wellness & Meditation Sanctuaries",
            "subtitle": "Peaceful spaces for mindfulness and self-care",
            "reasoning": "Perfect for balance and wellness in your busy lifestyle",
            "searchQuery": "meditation wellness spa mindfulness relaxation sanctuary near me",
            "category": "venues",
            "confidence": 0.72,
            "personalizedEmoji": "🧘",
            "vibeDescription": "Tranquil spaces for mental clarity and rejuvenation"
          }
        ]
        
        CRITICAL: Make each category hyper-personalized using the user's specific data. Avoid generic titles.
        """
    }
    
    /// Generates categories using Gemini AI
    private func generateCategoriesWithGemini(prompt: String) async -> [DynamicCategory] {
        return await withCheckedContinuation { continuation in
            geminiService.generateStructuredResponse(prompt: prompt) { response in
                if let data = response.data(using: .utf8) {
                        // First try to decode as array
                        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                            var categories: [DynamicCategory] = []
                            
                            for categoryData in jsonArray {
                                // Safely extract and validate category enum
                                guard let categoryString = categoryData["category"] as? String else {
                                    print("⚠️ Missing category field in dynamic category")
                                    continue
                                }
                                
                                // Map string to valid PlaceCategory enum
                                let categoryEnum: PlaceCategory
                                switch categoryString.lowercased() {
                                case "restaurant", "restaurants":
                                    categoryEnum = .restaurants
                                case "cafe", "cafes":
                                    categoryEnum = .cafes
                                case "bar", "bars":
                                    categoryEnum = .bars
                                case "venue", "venues":
                                    categoryEnum = .venues
                                case "shopping":
                                    categoryEnum = .shopping
                                default:
                                    print("⚠️ Invalid category string: \(categoryString), defaulting to restaurants")
                                    categoryEnum = .restaurants
                                }
                                
                                // Build dynamic category with proper validation
                                if let id = categoryData["id"] as? String,
                                   let title = categoryData["title"] as? String,
                                   let subtitle = categoryData["subtitle"] as? String,
                                   let reasoning = categoryData["reasoning"] as? String,
                                   let searchQuery = categoryData["searchQuery"] as? String {
                                    
                                    let category = DynamicCategory(
                                        id: id,
                                        title: title,
                                        subtitle: subtitle,
                                        reasoning: reasoning,
                                        searchQuery: searchQuery,
                                        category: categoryEnum, // Use validated enum
                                        confidence: categoryData["confidence"] as? Double ?? 0.8,
                                        personalizedEmoji: categoryData["personalizedEmoji"] as? String ?? "📍",
                                        vibeDescription: categoryData["vibeDescription"] as? String ?? "Great local spot",
                                        socialProofText: categoryData["socialProofText"] as? String,
                                        psychologyHook: categoryData["psychologyHook"] as? String
                                    )
                                    categories.append(category)
                                } else {
                                    print("⚠️ Missing required fields in dynamic category data")
                                }
                            }
                            
                            print("✅ Successfully parsed \(categories.count) dynamic categories")
                            continuation.resume(returning: categories)
                        } else {
                            print("❌ Invalid JSON structure for dynamic categories")
                            continuation.resume(returning: [])
                        }
                } else {
                    print("❌ No data from dynamic category generation")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /// Fetches places for a specific category with proper radius filtering
    private func fetchPlacesForCategory(category: DynamicCategory, location: CLLocation) async -> [Place] {
        // Get user's selected radius from LocationManager (convert miles to meters)
        let radiusInMiles = UserDefaults.standard.double(forKey: "selectedRadius") == 0 ? 2.0 : UserDefaults.standard.double(forKey: "selectedRadius")
        let radiusInMeters = Int(radiusInMiles * 1609.34) // Convert miles to meters
        
        print("🔍 Fetching places for category: \(category.title)")
        print("📍 Search query: '\(category.searchQuery)'")
        print("📍 Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("📍 Radius: \(radiusInMiles) miles (\(radiusInMeters) meters)")
        
        // Capture user fingerprint data ONCE (on main-actor) before async callback to keep closure synchronous
        let fpSnapshot = await MainActor.run { UserFingerprintManager.shared.fingerprint }
        let globalAffinitiesSnapshot = fpSnapshot?.tagAffinities ?? [:]
        let likeRatioConstSnapshot: Double = {
            let likes = Double(fpSnapshot?.likeCount ?? 0)
            let dislikes = Double(fpSnapshot?.dislikeCount ?? 0)
            return likes + dislikes > 0 ? (likes / max(1, likes + dislikes)) : 0.5
        }()
        
        return await withCheckedContinuation { continuation in
            placesService.searchPlacesByText(
                query: category.searchQuery,
                location: location,
                radius: radiusInMeters // Use user's selected radius
            ) { googlePlaces in
                print("📡 Google Places API returned \(googlePlaces.count) places for '\(category.searchQuery)'")
                
                let convertedPlaces = googlePlaces.compactMap { googlePlace in
                    googlePlace.toAppPlace()
                }
                
                print("🔄 Converted \(convertedPlaces.count) GooglePlaces to Places")
                
                // Additional filtering to ensure places are within radius
                let filteredPlaces = DistanceCalculator.filterPlacesWithinRadius(
                    places: convertedPlaces,
                    userLocation: location,
                    radiusMiles: radiusInMiles
                )
                
                print("📏 \(filteredPlaces.count) places after distance filtering")
                
                // Use pre-captured fingerprint snapshot
                let globalAffinities = globalAffinitiesSnapshot
                let likeRatioConst = likeRatioConstSnapshot
                
                func score(for place: Place) -> Double {
                    // Distance weight
                    let dist = place.distanceFromUser(userLocation: location) ?? 9999
                    let distanceScore = 1.0 / pow(dist + 0.2, 1.3)
                    // Tag affinity
                    var tagBoost = 0.0
                    if let tags = place.descriptiveTags {
                        for tag in tags {
                            if let val = globalAffinities[tag] { tagBoost += Double(val) }
                        }
                    }
                    tagBoost = 1 + (tagBoost / 10.0)
                    // Like ratio boost (simple)
                    let lrBoost = 0.8 + likeRatioConst * 0.4 // ranges 0.8 – 1.2
                    return distanceScore * tagBoost * lrBoost
                }

                let sortedPlaces = filteredPlaces.sorted { score(for: $0) > score(for: $1) }
                
                print("✅ Final result: \(sortedPlaces.count) places for category: \(category.title)")
                
                // Log first few places for debugging
                for (index, place) in sortedPlaces.prefix(3).enumerated() {
                    print("  \(index + 1). \(place.name) - \(place.rating)⭐ - \(place.priceRange)")
                }
                
                continuation.resume(returning: sortedPlaces)
            }
        }
    }
    
    /// Fetch additional places for infinite scrolling
    func fetchMorePlacesForCategory(_ categoryId: String, location: CLLocation, offset: Int = 0) async -> [Place] {
        guard let categoryIndex = dynamicCategories.firstIndex(where: { $0.id == categoryId }) else {
            return []
        }
        
        let category = dynamicCategories[categoryIndex]
        let radiusInMiles = UserDefaults.standard.double(forKey: "selectedRadius") == 0 ? 2.0 : UserDefaults.standard.double(forKey: "selectedRadius")
        
        // Create broader search queries for infinite scrolling
        let broaderQueries = generateBroaderSearchQueries(for: category)
        var allNewPlaces: [Place] = []
        
        for query in broaderQueries {
            let places = await fetchPlacesWithQuery(query: query, location: location, radiusMiles: radiusInMiles)
            allNewPlaces.append(contentsOf: places)
        }
        
        // Remove duplicates and places already in the category
        let existingPlaceIds = Set(category.places.map { $0.googlePlaceId })
        let uniqueNewPlaces = allNewPlaces.filter { 
            if let googlePlaceId = $0.googlePlaceId {
                return !existingPlaceIds.contains(googlePlaceId)
            }
            return true
        }
        
        // Sort by distance and return subset
        let sortedPlaces = uniqueNewPlaces.sorted { place1, place2 in
            let distance1 = place1.distanceFromUser(userLocation: location) ?? Double.greatestFiniteMagnitude
            let distance2 = place2.distanceFromUser(userLocation: location) ?? Double.greatestFiniteMagnitude
            return distance1 < distance2
        }
        
        return Array(sortedPlaces.prefix(10)) // Return 10 more places per load
    }
    
    /// Generate broader search queries for infinite scrolling
    private func generateBroaderSearchQueries(for category: DynamicCategory) -> [String] {
        switch category.category {
        case .restaurants:
            return [
                "restaurant dining food near",
                "eatery bistro grill near",
                "cuisine kitchen dining near",
                "food restaurant meal near"
            ]
        case .cafes:
            return [
                "cafe coffee shop near",
                "coffee espresso latte near",
                "coffeehouse brew near",
                "cafe breakfast pastry near"
            ]
        case .bars:
            return [
                "bar pub drinks near",
                "cocktail lounge bar near",
                "brewery taproom near",
                "nightlife bar drinks near"
            ]
        case .venues:
            return [
                "entertainment venue near",
                "event space venue near",
                "theater concert venue near",
                "music venue entertainment near"
            ]
        case .shopping:
            return [
                "shop store retail near",
                "boutique shopping store near",
                "market shopping retail near",
                "store shopping boutique near"
            ]
        }
    }
    
    /// Helper function to fetch places with a specific query
    private func fetchPlacesWithQuery(query: String, location: CLLocation, radiusMiles: Double) async -> [Place] {
        return await withCheckedContinuation { continuation in
            let radiusInMeters = Int(radiusMiles * 1609.34)
            
            placesService.searchPlacesByText(
                query: query,
                location: location,
                radius: radiusInMeters
            ) { googlePlaces in
                let convertedPlaces = googlePlaces.compactMap { $0.toAppPlace() }
                let filteredPlaces = DistanceCalculator.filterPlacesWithinRadius(
                    places: convertedPlaces,
                    userLocation: location,
                    radiusMiles: radiusMiles
                )
                continuation.resume(returning: filteredPlaces)
            }
        }
    }
    
    /// Gets current weather context for AI category generation
    private func getCurrentWeatherContext() -> String {
        // This would integrate with WeatherService
        let weather = "Clear, 72°F" // Placeholder - integrate with actual weather service
        return weather
    }
    
    /// Creates fallback categories when AI generation fails
    private func generateFallbackCategories(location: CLLocation) async {
        let fallbackCategories = [
            DynamicCategory(
                id: "top_restaurants",
                title: "Top Restaurants",
                subtitle: "Highly rated dining near you",
                reasoning: "Based on high ratings and reviews",
                searchQuery: "restaurant", // Simplified query
                category: .restaurants,
                confidence: 0.85,
                personalizedEmoji: "🍽️",
                vibeDescription: "Exceptional dining experiences",
                socialProofText: nil,
                psychologyHook: nil
            ),
            DynamicCategory(
                id: "coffee_shops",
                title: "Coffee & Cafes", 
                subtitle: "Perfect spots for coffee",
                reasoning: "Great for coffee lovers",
                searchQuery: "cafe", // Simplified query
                category: .cafes,
                confidence: 0.9,
                personalizedEmoji: "☕",
                vibeDescription: "Quality coffee experiences",
                socialProofText: nil,
                psychologyHook: nil
            ),
            DynamicCategory(
                id: "bars_lounges",
                title: "Bars & Lounges",
                subtitle: "Perfect for drinks",
                reasoning: "Great for evening entertainment",
                searchQuery: "bar", // Simplified query
                category: .bars,
                confidence: 0.8,
                personalizedEmoji: "🍸",
                vibeDescription: "Quality nightlife venues",
                socialProofText: nil,
                psychologyHook: nil
            ),
            DynamicCategory(
                id: "entertainment", 
                title: "Entertainment",
                subtitle: "Fun activities & venues",
                reasoning: "For fun and entertainment",
                searchQuery: "entertainment", // Simplified query
                category: .venues,
                confidence: 0.75,
                personalizedEmoji: "🎭",
                vibeDescription: "Live entertainment venues",
                socialProofText: nil,
                psychologyHook: nil
            ),
            DynamicCategory(
                id: "shopping",
                title: "Shopping",
                subtitle: "Stores & boutiques",
                reasoning: "Shopping experiences",
                searchQuery: "store", // Simplified query
                category: .shopping,
                confidence: 0.7,
                personalizedEmoji: "🛍️",
                vibeDescription: "Local shopping destinations",
                socialProofText: nil,
                psychologyHook: nil
            )
        ]
        
        var enrichedCategories: [DynamicCategory] = []
        for category in fallbackCategories {
            let places = await fetchPlacesForCategory(category: category, location: location)
            var enrichedCategory = category
            enrichedCategory.places = places
            
            // Add category even if it has fewer places, but at least 1
            if !places.isEmpty {
                enrichedCategories.append(enrichedCategory)
                print("✅ Fallback category '\(category.title)' has \(places.count) places")
            } else {
                print("⚠️ Fallback category '\(category.title)' has no places")
            }
        }
        
        // If even fallback categories fail, create some mock categories with at least empty arrays
        if enrichedCategories.isEmpty {
            print("❌ Even fallback categories failed, creating demo categories with sample places")
            enrichedCategories = createDemoCategories(location: location)
        }
        
        // Order fallback categories by confidence as well
        self.dynamicCategories = enrichedCategories.sorted { $0.confidence > $1.confidence }
        for index in self.dynamicCategories.indices {
            self.dynamicCategories[index].places.shuffle()
        }
        
        print("✅ Generated \(enrichedCategories.count) fallback categories with \(enrichedCategories.reduce(0) { $0 + $1.places.count }) total places")
        
        // Ensure loading state is cleared after generating fallback categories
        isGenerating = false
        lastGenerated = Date()
    }
    
    /// Generate sample categories when location is not available
    func generateSampleCategories() async {
        isGenerating = true
        
        let sampleCategories = [
            DynamicCategory(
                id: "sample_restaurants",
                title: "🍽️ Popular Restaurants",
                subtitle: "Great dining experiences",
                reasoning: "Top-rated restaurants in your area",
                searchQuery: "restaurant",
                category: .restaurants,
                confidence: 0.8,
                personalizedEmoji: "🍽️",
                vibeDescription: "Excellent dining options"
            ),
            DynamicCategory(
                id: "sample_cafes",
                title: "☕ Coffee & Cafes",
                subtitle: "Perfect for coffee breaks",
                reasoning: "Quality coffee experiences",
                searchQuery: "cafe",
                category: .cafes,
                confidence: 0.85,
                personalizedEmoji: "☕",
                vibeDescription: "Great coffee culture"
            ),
            DynamicCategory(
                id: "sample_bars",
                title: "🍸 Bars & Nightlife",
                subtitle: "Evening entertainment",
                reasoning: "Perfect for drinks and socializing",
                searchQuery: "bar",
                category: .bars,
                confidence: 0.75,
                personalizedEmoji: "🍸",
                vibeDescription: "Vibrant nightlife scene"
            ),
            DynamicCategory(
                id: "sample_venues",
                title: "🎭 Entertainment Venues",
                subtitle: "Live events and shows",
                reasoning: "Great for entertainment and culture",
                searchQuery: "venue",
                category: .venues,
                confidence: 0.7,
                personalizedEmoji: "🎭",
                vibeDescription: "Cultural entertainment"
            ),
            DynamicCategory(
                id: "sample_shopping",
                title: "🛍️ Shopping Destinations",
                subtitle: "Retail and boutiques",
                reasoning: "Great shopping experiences",
                searchQuery: "shopping",
                category: .shopping,
                confidence: 0.65,
                personalizedEmoji: "🛍️",
                vibeDescription: "Diverse shopping options"
            )
        ]
        
        await MainActor.run {
            self.dynamicCategories = sampleCategories
            self.isGenerating = false
            print("✅ Generated \(sampleCategories.count) sample categories")
        }
    }
    
    /// Records user interaction with a place for fingerprint learning
    func recordPlaceInteraction(place: Place, interaction: PlaceInteraction, userLocation: CLLocation? = nil) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        print("📊 Recording \(interaction.rawValue) interaction for \(place.name)")
        
        // Create timestamp as Date() for nested data (Firebase doesn't allow FieldValue.serverTimestamp() in nested structures)
        let interactionData: [String: Any] = [
            "placeId": place.googlePlaceId ?? "",
            "placeName": place.name,
            "category": place.category.rawValue,
            "interaction": interaction.rawValue,
            "timestamp": Date(), // Use Date() instead of FieldValue.serverTimestamp() in nested data
            "location": [
                "latitude": userLocation?.coordinate.latitude ?? 0.0,
                "longitude": userLocation?.coordinate.longitude ?? 0.0
            ],
            "rating": place.rating,
            "priceRange": place.priceRange
        ]
        
        var updates: [String: Any] = [
            "interactionLogs": FieldValue.arrayUnion([interactionData]),
            "lastInteractionTime": FieldValue.serverTimestamp() // Use serverTimestamp for top-level fields only
        ]
        
        // Update likes/dislikes based on interaction
        switch interaction {
        case .liked:
            updates["likes"] = FieldValue.arrayUnion([place.name])
            updates["dislikes"] = FieldValue.arrayRemove([place.name])
            updates["likeCount"] = FieldValue.increment(Int64(1))
            if let tags = place.descriptiveTags {
                for tag in tags {
                    updates["tagAffinities.\(tag)"] = FieldValue.increment(Int64(1))
                }
            }
        case .disliked:
            updates["dislikes"] = FieldValue.arrayUnion([place.name])
            updates["likes"] = FieldValue.arrayRemove([place.name])
            updates["dislikeCount"] = FieldValue.increment(Int64(1))
        case .bookmarked:
            updates["likes"] = FieldValue.arrayUnion([place.name])
            updates["likeCount"] = FieldValue.increment(Int64(1))
        case .shared:
            if let tags = place.descriptiveTags {
                for tag in tags {
                    updates["tagAffinities.\(tag)"] = FieldValue.increment(Int64(1))
                }
            }
        case .visited:
            if let tags = place.descriptiveTags {
                for tag in tags {
                    updates["tagAffinities.\(tag)"] = FieldValue.increment(Int64(1))
                }
            }
        case .called:
            break
        case .navigated:
            break
        case .reviewed:
            if let tags = place.descriptiveTags {
                for tag in tags {
                    updates["tagAffinities.\(tag)"] = FieldValue.increment(Int64(1))
                }
            }
        case .photographed:
            break
        case .recommended:
            break
        case .viewed:
            break
        }
        
        // Update aggregated behavior metrics fields
        updates["behavior.totalPlaceViews"] = FieldValue.increment(Int64(1))
        if interaction == .liked {
            updates["behavior.totalThumbsUp"] = FieldValue.increment(Int64(1))
        } else if interaction == .disliked {
            updates["behavior.totalThumbsDown"] = FieldValue.increment(Int64(1))
        }
        
        do {
            try await Firestore.firestore().collection("users").document(uid).updateData(updates)
            print("✅ User fingerprint updated with \(interaction.rawValue) interaction")
        } catch {
            print("❌ Error updating fingerprint: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon" 
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }
    
    private func getCurrentDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
    
    private func extractOnboardingPreferences(_ fingerprint: AppUserFingerprint) -> String {
        guard let responses = fingerprint.onboardingResponses else {
            return "No onboarding preferences available"
        }
        
        var preferences: [String] = []
        
        for response in responses {
            if let questionId = response["questionId"]?.value as? String,
               let selectedOptions = response["selectedOptions"]?.value as? [String] {
                let options = selectedOptions.joined(separator: ", ")
                preferences.append("\(questionId): \(options)")
            }
        }
        
        return preferences.isEmpty ? "No preferences available" : preferences.joined(separator: "\n")
    }
    
    private func analyzeInteractionPatterns(_ fingerprint: AppUserFingerprint) -> String {
        guard let logs = fingerprint.interactionLogs else {
            return "No interaction history available"
        }
        
        var patterns: [String] = []
        
        let recentLogs = logs.prefix(10) // Analyze last 10 interactions
        let likedPlaces = recentLogs.compactMap { log -> String? in
            if let reaction = log["reaction"]?.value as? String,
               let placeName = log["placeName"]?.value as? String,
               reaction == "liked" {
                return placeName
            }
            return nil
        }
        
        if !likedPlaces.isEmpty {
            patterns.append("Recently liked: \(likedPlaces.joined(separator: ", "))")
        }
        
        return patterns.isEmpty ? "No recent interaction patterns" : patterns.joined(separator: "\n")
    }
    
    /// Creates demo categories with sample places as a last resort
    private func createDemoCategories(location: CLLocation) -> [DynamicCategory] {
        let samplePlaces = [
            createSamplePlace(
                name: "Great Local Restaurant",
                category: .restaurants,
                description: "Delicious food and great atmosphere",
                rating: 4.5,
                priceRange: "$$",
                location: location
            ),
            createSamplePlace(
                name: "Amazing Coffee Shop",
                category: .cafes,
                description: "Perfect coffee and cozy vibes",
                rating: 4.3,
                priceRange: "$",
                location: location
            ),
            createSamplePlace(
                name: "Popular Bar & Lounge",
                category: .bars,
                description: "Great drinks and atmosphere",
                rating: 4.2,
                priceRange: "$$",
                location: location
            ),
            createSamplePlace(
                name: "Entertainment Venue",
                category: .venues,
                description: "Fun activities and events",
                rating: 4.0,
                priceRange: "$$",
                location: location
            ),
            createSamplePlace(
                name: "Local Shopping Center",
                category: .shopping,
                description: "Great stores and boutiques",
                rating: 4.1,
                priceRange: "$$",
                location: location
            )
        ]
        
        return [
            DynamicCategory(
                id: "demo_restaurants",
                title: "Recommended Restaurants",
                subtitle: "Great dining options nearby",
                reasoning: "Sample recommendations",
                searchQuery: "restaurant",
                category: .restaurants,
                places: [samplePlaces[0]],
                confidence: 0.8,
                personalizedEmoji: "🍽️",
                vibeDescription: "Great local dining",
                socialProofText: nil,
                psychologyHook: nil
            ),
            DynamicCategory(
                id: "demo_cafes",
                title: "Coffee & Cafes",
                subtitle: "Perfect for coffee lovers",
                reasoning: "Sample recommendations",
                searchQuery: "cafe",
                category: .cafes,
                places: [samplePlaces[1]],
                confidence: 0.8,
                personalizedEmoji: "☕",
                vibeDescription: "Cozy coffee spots",
                socialProofText: nil,
                psychologyHook: nil
            ),
            DynamicCategory(
                id: "demo_bars",
                title: "Bars & Nightlife",
                subtitle: "Great for evening drinks",
                reasoning: "Sample recommendations",
                searchQuery: "bar",
                category: .bars,
                places: [samplePlaces[2]],
                confidence: 0.8,
                personalizedEmoji: "🍸",
                vibeDescription: "Lively nightlife",
                socialProofText: nil,
                psychologyHook: nil
            )
        ]
    }
    
    /// Creates a sample place for demo purposes
    private func createSamplePlace(name: String, category: PlaceCategory, description: String, rating: Double, priceRange: String, location: CLLocation) -> Place {
        // Create coordinates slightly offset from user location
        let offsetLat = location.coordinate.latitude + Double.random(in: -0.01...0.01)
        let offsetLng = location.coordinate.longitude + Double.random(in: -0.01...0.01)
        
        return Place(
            id: UUID(),
            name: name,
            description: description,
            category: category,
            rating: rating,
            reviewCount: Int.random(in: 50...500),
            priceRange: priceRange,
            images: [getDefaultImageForCategory(category)],
            location: "Near your location",
            hours: "Open • Closes at 10:00 PM",
            detailedHours: nil,
            phone: "(555) 123-4567",
            website: "www.example.com",
            menuItems: [],
            reviews: [],
            googlePlaceId: "demo_\(UUID().uuidString)",
            sentiment: nil,
            isCurrentlyOpen: true,
            hasActualMenu: false,
            coordinates: Coordinates(latitude: offsetLat, longitude: offsetLng)
        )
    }
    
    private func getDefaultImageForCategory(_ category: PlaceCategory) -> String {
        switch category {
        case .restaurants:
            return "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&h=600&fit=crop"
        case .cafes:
            return "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800&h=600&fit=crop"
        case .bars:
            return "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800&h=600&fit=crop"
        case .venues:
            return "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800&h=600&fit=crop"
        case .shopping:
            return "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800&h=600&fit=crop"
        }
    }
}

// MARK: - Supporting Enums

enum UserReaction: String, CaseIterable {
    case liked = "liked"
    case disliked = "disliked"
} 