import Foundation
import CoreLocation
import UIKit

class PlaceDataService: ObservableObject {
    static let shared = PlaceDataService()
    
    private let googlePlacesService = GooglePlacesService()
    private var geminiService: GeminiAIService? = nil
    
    // Lazy property to get gemini service on main actor
    private func getGeminiService() async -> GeminiAIService {
        if let service = geminiService {
            return service
        }
        
        return await MainActor.run {
            let service = GeminiAIService.shared
            self.geminiService = service
            return service
        }
    }
    
    @Published var placesByCategory: [PlaceCategory: [Place]] = [:]
    @Published var isLoading = false
    @Published var isLoadingMore: [PlaceCategory: Bool] = [:]
    @Published var errorMessage: String?
    @Published var searchResults: [Place] = []
    @Published var isSearching = false
    @Published var searchQuery = ""
    
    // Track current location to ensure we only show places for current location
    @Published var currentLocationKey: String = ""
    @Published var currentRadius: Double = 2.0
    
    // Enhanced infinite scroll system - REAL PLACES ONLY
    private var paginationTokens: [PlaceCategory: String] = [:]
    private var nextPageTokens: [PlaceCategory: String] = [:]
    var hasMorePlaces: [PlaceCategory: Bool] = [:]
    private var loadingStates: [PlaceCategory: Bool] = [:]
    private var exhaustedCategories: Set<PlaceCategory> = [] // Track categories that have no more API places
    
    // Advanced caching system with thread safety - PER LOCATION
    private let cacheQueue = DispatchQueue(label: "com.planit.cache", attributes: .concurrent)
    private var locationPlacesCache: [String: [PlaceCategory: [Place]]] = [:]
    private var detailedPlaceCache: [String: Place] = [:]
    
    // Cache management with TTL (Time To Live) - 1 hour default
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheTTL: TimeInterval = 3600 // 1 hour
    private let maxCacheSize = 500 // Maximum places to keep in memory
    
    // UserDefaults keys for persistence
    private let allPlacesCacheKey = "allPlacesCache_v3"
    private let cacheTimestampsKey = "cacheTimestamps_v3"
    private let paginationTokensKey = "paginationTokens_v3"
    
    @Published var lastUpdated: Date?
    @Published var recommendedPlaces: [Place] = []
    @Published var nearbyPlaces: [Place] = []
    @Published var filteredPlaces: [Place] = []
    @Published var isGeneratingRecommendations = false
    
    // AI Enhancement State
    @Published var enhancedDescriptions: [String: String] = [:] // place_id -> description
    @Published var isEnhancingPlaces = false
    
    // Location-based caching
    private var lastLocation: CLLocation?
    private var cacheExpirationTime: TimeInterval = 900 // 15 minutes
    
    private init() {
        print("🏪 PlaceDataService initialized")
        
        // Initialize all categories as having more places initially
        for category in PlaceCategory.allCases {
            hasMorePlaces[category] = true
            loadingStates[category] = false
            isLoadingMore[category] = false
        }
        
        loadCachedData()
        setupAppLifecycleObservers()
    }
    
    // MARK: - Clear Data for Location Changes
    
    func clearAllPlacesData() {
        DispatchQueue.main.async {
            self.placesByCategory.removeAll()
            self.searchResults.removeAll()
            self.errorMessage = nil
            
            // Reset pagination states
            for category in PlaceCategory.allCases {
                self.hasMorePlaces[category] = true
                self.loadingStates[category] = false
                self.isLoadingMore[category] = false
            }
            
            self.paginationTokens.removeAll()
            self.nextPageTokens.removeAll()
            self.exhaustedCategories.removeAll()
        }
        
        print("🧹 Cleared all places data for location change")
    }
    
    private func generateLocationKey(for location: CLLocation, radius: Double) -> String {
        return "\(String(format: "%.4f", location.coordinate.latitude)),\(String(format: "%.4f", location.coordinate.longitude))_\(radius)"
    }
    
    // MARK: - App Lifecycle Management
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.saveAllPlacesToCache()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.saveAllPlacesToCache()
        }
    }
    
    // MARK: - Enhanced Cache-First Loading System
    
    func loadCachedPlacesFirst(for locationKey: String) {
        guard locationKey == currentLocationKey else {
            print("🚫 Skipping cache load - location key mismatch")
            return
        }
        
        cacheQueue.async(flags: .barrier) {
            // Load cached places from UserDefaults for immediate display
            if let data = UserDefaults.standard.data(forKey: self.allPlacesCacheKey),
               let cachedAllPlaces = try? JSONDecoder().decode([String: [PlaceCategory: [Place]]].self, from: data),
               let placesForLocation = cachedAllPlaces[locationKey] {
                
                // Load cache timestamps
                if let timestampData = UserDefaults.standard.data(forKey: self.cacheTimestampsKey),
                   let timestamps = try? JSONDecoder().decode([String: Date].self, from: timestampData) {
                    self.cacheTimestamps = timestamps
                }
                
                // Check cache freshness and randomize for variety
                let now = Date()
                var freshPlaces: [PlaceCategory: [Place]] = [:]
                
                for (category, places) in placesForLocation {
                    let cacheKey = "\(locationKey)_\(category.rawValue)"
                    if let cacheTime = self.cacheTimestamps[cacheKey],
                       now.timeIntervalSince(cacheTime) < self.cacheTTL {
                        // Cache is still fresh, randomize for variety
                        freshPlaces[category] = places.shuffled()
                    }
                }
                
                DispatchQueue.main.async {
                    // Only update if we're still on the same location
                    if locationKey == self.currentLocationKey {
                        self.placesByCategory = freshPlaces
                        let totalCached = freshPlaces.values.reduce(0) { $0 + $1.count }
                        print("📦 Loaded \(totalCached) fresh cached places for location: \(locationKey)")
                    }
                }
            }
        }
    }
    
    // MARK: - Advanced Infinite Scroll Implementation
    
    func loadPlacesForAllCategories(at location: CLLocation, radius: Double = 2.0, initialLoad: Bool = true) {
        let newLocationKey = generateLocationKey(for: location, radius: radius)
        
        // Clear data immediately if location changed
        if newLocationKey != currentLocationKey || initialLoad {
            clearAllPlacesData()
            currentLocationKey = newLocationKey
            currentRadius = radius
            print("🔄 Location changed to: \(newLocationKey)")
        }
        
        print("🏗️ Loading places for all categories at: \(location.coordinate) with radius: \(radius)")
        
        if initialLoad {
            // Load cached places first for instant display (only for current location)
            loadCachedPlacesFirst(for: newLocationKey)
        }
        
        isLoading = true
        errorMessage = nil
        
        let categories = PlaceCategory.allCases
        let group = DispatchGroup()
        
        for category in categories {
            group.enter()
            loadMorePlacesForCategory(category, location: location, radius: radius, isInitial: initialLoad) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Only update loading state if we're still on the same location
            if newLocationKey == self.currentLocationKey {
                self.isLoading = false
                let totalPlaces = self.placesByCategory.values.reduce(0) { $0 + $1.count }
                print("✅ Finished loading \(totalPlaces) places across all categories for location: \(newLocationKey)")
                
                if totalPlaces == 0 {
                    self.errorMessage = "No places found in this area. Try expanding your search radius."
                } else {
                    self.saveAllPlacesToCache()
                }
            }
        }
    }
    
    func loadMorePlaces(for category: PlaceCategory, location: CLLocation, radius: Double = 2.0) {
        let locationKey = generateLocationKey(for: location, radius: radius)
        
        // Don't load more if location changed
        guard locationKey == currentLocationKey else {
            print("🚫 Skipping load more - location changed")
            return
        }
        
        guard hasMorePlaces[category] == true, 
              loadingStates[category] != true,
              isLoadingMore[category] != true,
              !exhaustedCategories.contains(category) else { 
            print("⚠️ Cannot load more places for \(category.rawValue): exhausted=\(exhaustedCategories.contains(category)), loading=\(loadingStates[category] ?? false)")
            return 
        }
        
        print("📡 Loading more places for \(category.rawValue)")
        loadMorePlacesForCategory(category, location: location, radius: radius, isInitial: false) {
            // Completion handled in the method
        }
    }
    
    private func loadMorePlacesForCategory(_ category: PlaceCategory, location: CLLocation, radius: Double, isInitial: Bool, completion: @escaping () -> Void) {
        let locationKey = generateLocationKey(for: location, radius: radius)
        
        // Don't load if location changed during request
        guard locationKey == currentLocationKey else {
            print("🚫 Cancelling load - location changed during request")
            completion()
            return
        }
        
        loadingStates[category] = true
        
        if !isInitial {
            DispatchQueue.main.async {
                if locationKey == self.currentLocationKey {
                    self.isLoadingMore[category] = true
                }
            }
        }
        
        let pageToken = isInitial ? nil : nextPageTokens[category]
        
        googlePlacesService.searchPlaces(
            for: category,
            location: location,
            radius: Int(radius * 1609.34),
            pageToken: pageToken
        ) { [weak self] result in
            guard let self = self else { 
                completion()
                return 
            }
            
            var places = self.convertBasicGooglePlacesToPlaces(result.places, category: category)
            
            // Filter by real distance to respect user-selected radius
            let maxDistanceMeters = radius * 1609.34
            places = places.filter { plc in
                if let coords = plc.coordinates {
                    let placeLoc = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
                    return placeLoc.distance(from: location) <= maxDistanceMeters
                }
                return false
            }
            
            DispatchQueue.main.async {
                // Ensure we're still on the same location before updating
                guard locationKey == self.currentLocationKey else {
                    completion()
                    return
                }
                
                // Update places array
                if isInitial {
                    // For initial load, merge with cached places and randomize
                    var existingPlaces = self.placesByCategory[category] ?? []
                    let newPlaces = places.filter { [self] newPlace in
                        !self.isDuplicate(newPlace, in: existingPlaces)
                    }
                    existingPlaces.append(contentsOf: newPlaces)
                    self.placesByCategory[category] = existingPlaces.shuffled()
                    print("✅ Initial load for \(category.rawValue): \(newPlaces.count) new, \(existingPlaces.count) total")
                } else {
                    // For pagination, append new unique places
                    var existingPlaces = self.placesByCategory[category] ?? []
                    let newPlaces = places.filter { [self] newPlace in
                        !self.isDuplicate(newPlace, in: existingPlaces)
                    }
                    existingPlaces.append(contentsOf: newPlaces)
                    self.placesByCategory[category] = existingPlaces
                    print("✅ Pagination for \(category.rawValue): \(newPlaces.count) new, \(existingPlaces.count) total")
                }
                
                // Update pagination state
                self.nextPageTokens[category] = result.nextPageToken
                
                // Mark API as exhausted when no more real places are available
                if result.nextPageToken == nil || places.isEmpty {
                    self.exhaustedCategories.insert(category)
                    self.hasMorePlaces[category] = false
                    print("🔄 API places exhausted for \(category.rawValue) - no more places available")
                } else {
                    self.hasMorePlaces[category] = true
                }
                
                self.loadingStates[category] = false
                self.isLoadingMore[category] = false
                
                // Cache the updated results
                self.cacheUpdatedPlaces(for: category)
                
                print("✅ Loaded \(places.count) new places for \(category.rawValue). Total: \(self.placesByCategory[category]?.count ?? 0)")
                
                // IMPORTANT: Always call completion
                completion()
            }
        }
    }
    
    // MARK: - Advanced Cache Management with Thread Safety
    
    private func cacheUpdatedPlaces(for category: PlaceCategory) {
        cacheQueue.async(flags: .barrier) {
            let cacheKey = "\(self.currentLocationKey)_\(category.rawValue)"
            self.cacheTimestamps[cacheKey] = Date()
            
            // Implement cache size management
            if let places = self.placesByCategory[category], places.count > self.maxCacheSize {
                // Keep only the most recent places to manage memory
                let trimmedPlaces = Array(places.suffix(self.maxCacheSize))
                DispatchQueue.main.async {
                    self.placesByCategory[category] = trimmedPlaces
                }
            }
        }
    }
    
    func saveAllPlacesToCache() {
        cacheQueue.async(flags: .barrier) {
            // Save places organized by location
            var locationBasedCache: [String: [PlaceCategory: [Place]]] = [:]
            if !self.currentLocationKey.isEmpty {
                locationBasedCache[self.currentLocationKey] = self.placesByCategory
            }
            
            // Merge with existing cache
            if let data = UserDefaults.standard.data(forKey: self.allPlacesCacheKey),
               let existingCache = try? JSONDecoder().decode([String: [PlaceCategory: [Place]]].self, from: data) {
                // Keep existing locations but update current location
                for (locationKey, places) in existingCache {
                    if locationKey != self.currentLocationKey {
                        locationBasedCache[locationKey] = places
                    }
                }
            }
            
            // Save updated cache
            if let encoded = try? JSONEncoder().encode(locationBasedCache) {
                UserDefaults.standard.set(encoded, forKey: self.allPlacesCacheKey)
            }
            
            // Save cache timestamps
            if let timestampData = try? JSONEncoder().encode(self.cacheTimestamps) {
                UserDefaults.standard.set(timestampData, forKey: self.cacheTimestampsKey)
            }
            
            // Save pagination tokens per location
            var locationTokens: [String: [PlaceCategory: String]] = [:]
            if !self.currentLocationKey.isEmpty {
                locationTokens[self.currentLocationKey] = self.nextPageTokens
            }
            
            if let tokenData = try? JSONEncoder().encode(locationTokens) {
                UserDefaults.standard.set(tokenData, forKey: self.paginationTokensKey)
            }
            
            let totalPlaces = self.placesByCategory.values.reduce(0) { $0 + $1.count }
            print("💾 Saved \(totalPlaces) places to cache for location: \(self.currentLocationKey)")
        }
    }
    
    private func loadCachedData() {
        cacheQueue.async {
            // Load timestamps
            if let timestampData = UserDefaults.standard.data(forKey: self.cacheTimestampsKey),
               let timestamps = try? JSONDecoder().decode([String: Date].self, from: timestampData) {
                self.cacheTimestamps = timestamps
            }
            
            print("📂 Loaded cache data on initialization")
        }
    }
    
    // MARK: - Cache Cleanup and Management
    
    func clearExpiredCache() {
        cacheQueue.async(flags: .barrier) {
            let now = Date()
            var expiredKeys: [String] = []
            
            for (key, timestamp) in self.cacheTimestamps {
                if now.timeIntervalSince(timestamp) > self.cacheTTL {
                    expiredKeys.append(key)
                }
            }
            
            for key in expiredKeys {
                self.cacheTimestamps.removeValue(forKey: key)
                // Clear corresponding cached data
                if let category = PlaceCategory.allCases.first(where: { "\($0.rawValue)_cache" == key }) {
                    DispatchQueue.main.async {
                        self.placesByCategory[category] = []
                        self.hasMorePlaces[category] = true
                        self.nextPageTokens[category] = nil
                    }
                }
            }
            
            print("🧹 Cleared \(expiredKeys.count) expired cache entries")
        }
    }
    
    // MARK: - ON-DEMAND DETAILED LOADING (Called when place card is tapped)
    
    func loadDetailedPlace(for place: Place, completion: @escaping (Place?) -> Void) {
        print("🔍 Loading detailed info for: \(place.name) (ON-DEMAND)")
        
        // Check cache first
        if let cachedPlace = detailedPlaceCache[place.googlePlaceId ?? ""] {
            print("📦 Using cached detailed place: \(place.name)")
            completion(cachedPlace)
            return
        }
        
        // Only make API calls when user actually taps on a place
        guard let placeId = place.googlePlaceId else {
            print("❌ No place ID available for: \(place.name)")
            completion(nil)
            return
        }
        
        // Fetch detailed information
        googlePlacesService.getPlaceDetails(placeId: placeId) { [weak self] details in
            guard let details = details, let self = self else {
                print("❌ Failed to get details for place: \(place.name)")
                completion(nil)
                return
            }
            
            // Enhance with AI only when needed
            self.enhancePlaceWithAI(details: details, originalCategory: place.category) { enhancedPlace in
                if let enhancedPlace = enhancedPlace {
                    // Cache the detailed place
                    self.detailedPlaceCache[placeId] = enhancedPlace
                    print("✅ Cached detailed place: \(enhancedPlace.name)")
                }
                completion(enhancedPlace)
            }
        }
    }
    
    // MARK: - BASIC PLACE CONVERSION (No API calls)
    
    private func convertBasicGooglePlacesToPlaces(_ googlePlaces: [GooglePlace], category: PlaceCategory) -> [Place] {
        return googlePlaces.compactMap { googlePlace in
            // ONLY store the first photo reference - don't create URLs yet (lazy loading)
            let photoReference = googlePlace.photos?.first?.photo_reference
            let basicImages = photoReference != nil ? [photoReference!] : [getDefaultImageForCategory(category)]
            
            let priceRange = convertPriceLevel(googlePlace.price_level)
            
            return Place(
                id: UUID(),
                name: googlePlace.name,
                description: "Tap to learn more about this place", // Generic description
                category: category,
                rating: googlePlace.rating ?? 0.0,
                reviewCount: 0, // Not available in this GooglePlace model
                priceRange: priceRange,
                images: basicImages, // Now contains photo references, not URLs
                location: googlePlace.address,
                hours: "Hours available when you tap for details",
                detailedHours: nil,
                phone: "Phone available when you tap for details",
                website: nil,
                menuItems: [],
                reviews: [],
                googlePlaceId: googlePlace.placeId,
                sentiment: nil,
                isCurrentlyOpen: true, // Default to true, will be updated by detailed API call
                hasActualMenu: false,
                coordinates: Coordinates(latitude: googlePlace.geometry?.location.lat ?? 0.0, longitude: googlePlace.geometry?.location.lng ?? 0.0)
            )
        }
        .filter { $0.rating >= 3.0 } // Only show quality places
    }
    
    // MARK: - AI ENHANCEMENT (Only called on-demand)
    
    private func enhancePlaceWithAI(details: GooglePlaceDetails, originalCategory: PlaceCategory, completion: @escaping (Place?) -> Void) {
        let enhanceGroup = DispatchGroup()
        
        var aiDescription = "Discover this amazing place!"
        var sentiment: CustomerSentiment?
        var verifiedCategory = originalCategory
        
        // 1. Verify and correct category using AI + get description
        enhanceGroup.enter()
        Task { @MainActor in
            let geminiService = await self.getGeminiService()
            geminiService.generatePlaceDescription(for: details) { categoryAndDescription in
                // Parse the response to extract category - assume it's JSON or simple text
                if let categoryData = categoryAndDescription.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: categoryData) as? [String: Any],
                   let categoryString = json["category"] as? String,
                   let parsedCategory = PlaceCategory.fromString(categoryString) {
                    verifiedCategory = parsedCategory
                    aiDescription = json["description"] as? String ?? categoryAndDescription
                } else {
                    // Fallback for simple text response
                    verifiedCategory = originalCategory
                    aiDescription = categoryAndDescription
                }
                enhanceGroup.leave()
            }
        }
        
        // 2. Analyze sentiment from reviews if available
        if let reviews = details.reviews, !reviews.isEmpty {
            enhanceGroup.enter()
            Task { @MainActor in
                let geminiService = await self.getGeminiService()
                geminiService.sendGeminiRequest(prompt: "Analyze sentiment from reviews: \(reviews.map { $0.text }.joined(separator: " "))") { sentimentResult in
                    // Parse sentiment result to determine positive/negative/neutral
                    let lowercased = sentimentResult.lowercased()
                    if lowercased.contains("positive") || lowercased.contains("good") || lowercased.contains("excellent") {
                        sentiment = CustomerSentiment(
                            overallScore: 0.8,
                            positiveWords: ["great", "excellent", "amazing"],
                            negativeWords: [],
                            summary: "Generally positive customer feedback"
                        )
                    } else if lowercased.contains("negative") || lowercased.contains("bad") || lowercased.contains("poor") {
                        sentiment = CustomerSentiment(
                            overallScore: 0.3,
                            positiveWords: [],
                            negativeWords: ["bad", "poor", "disappointing"],
                            summary: "Generally negative customer feedback"
                        )
                    } else {
                        sentiment = CustomerSentiment(
                            overallScore: 0.5,
                            positiveWords: ["good", "decent"],
                            negativeWords: ["okay", "average"],
                            summary: "Mixed customer feedback"
                        )
                    }
                    enhanceGroup.leave()
                }
            }
        }
        
        enhanceGroup.notify(queue: .main) {
            let place = self.convertDetailedGooglePlaceToPlace(
                details, 
                category: verifiedCategory, 
                aiDescription: aiDescription, 
                sentiment: sentiment
            )
            completion(place)
        }
    }
    
    // MARK: - DETAILED PLACE CONVERSION (Only called on-demand)
    
    private func convertDetailedGooglePlaceToPlace(_ details: GooglePlaceDetails, category: PlaceCategory, aiDescription: String, sentiment: CustomerSentiment?) -> Place {
        // Store photo references for lazy loading in slideshow (limit to 5 for performance)
        let photoReferences = details.photos?.prefix(5).map { photo in
            photo.photo_reference
        } ?? []
        
        // Use default if no photos available
        let images = photoReferences.isEmpty ? [getDefaultImageForCategory(category)] : photoReferences
        
        let priceRange = convertPriceLevel(details.price_level)
        
        // Format hours properly with more detail
        let hours = formatDetailedOpeningHours(details.opening_hours)
        
        // Create detailed hours structure (already created above)
        // let detailedHours = createDetailedHours(from: details.opening_hours) // Removed duplicate
        
        // Convert reviews with better formatting and multiple sources
        let reviews = enhanceReviewsWithMultipleSources(details.reviews ?? [], placeName: details.name)
        
        // Enhanced menu items based on place details and AI analysis - Only for food places with actual menus
        let menuItems = shouldShowMenu(for: category, details: details) ? generateIntelligentMenuItems(for: category, placeDetails: details) : []
        
        // Ensure we have proper contact information
        let phoneNumber = details.formatted_phone_number ?? "Phone not available"
        
        // Determine if place is currently open
        let isCurrentlyOpen = details.opening_hours?.open_now == true
        
        // Determine if this place should show menu
        let hasActualMenu = shouldShowMenu(for: category, details: details)
        
        return Place(
            id: UUID(),
            name: details.name,
            description: aiDescription,
            category: category,
            rating: details.rating ?? 3.5,
            reviewCount: details.user_ratings_total ?? 0,
            priceRange: priceRange,
            images: images, // Now contains photo references for lazy loading
            location: details.formatted_address ?? "Location details not available",
            hours: hours,
            detailedHours: createDetailedHours(from: details.opening_hours),
            phone: phoneNumber,
            website: details.website,
            menuItems: menuItems,
            reviews: reviews,
            googlePlaceId: details.place_id,
            sentiment: sentiment,
            isCurrentlyOpen: isCurrentlyOpen,
            hasActualMenu: hasActualMenu,
            coordinates: Coordinates(latitude: details.geometry.location.lat, longitude: details.geometry.location.lng)
        )
    }
    
    // MARK: - CACHE MANAGEMENT
    
    func clearLocationCache() {
        locationPlacesCache.removeAll()
        currentLocationKey = ""
        print("🗑️ Location cache cleared for fresh randomization")
    }
    
    func clearDetailedCache() {
        detailedPlaceCache.removeAll()
        print("🗑️ Detailed place cache cleared")
    }
    
    // MARK: - HELPER FUNCTIONS (Unchanged)
    
    private func formatDetailedOpeningHours(_ openingHours: GoogleOpeningHours?) -> String {
        guard let openingHours = openingHours else {
            return "Hours not available"
        }
        
        if let weekdayText = openingHours.weekday_text, !weekdayText.isEmpty {
            // Format the hours nicely
            let formattedHours = weekdayText.map { day in
                // Clean up the format from "Monday: 9:00 AM – 10:00 PM" to "Mon: 9AM-10PM"
                let cleaned = day
                    .replacingOccurrences(of: ":00", with: "")
                    .replacingOccurrences(of: " AM", with: "AM")
                    .replacingOccurrences(of: " PM", with: "PM")
                    .replacingOccurrences(of: " – ", with: "-")
                return cleaned
            }
            
            let openStatus = openingHours.open_now == true ? "🟢 Open Now" : "🔴 Closed"
            return "\(openStatus)\n\n" + formattedHours.joined(separator: "\n")
        }
        
        let openStatus = openingHours.open_now == true ? "🟢 Open Now" : "🔴 Closed"
        return openStatus
    }
    
    private func convertPriceLevel(_ priceLevel: Int?) -> String {
        switch priceLevel {
        case 1:
            return "$"
        case 2:
            return "$$"
        case 3:
            return "$$$"
        case 4:
            return "$$$$"
        default:
            return "$$"
        }
    }
    
    private func getDefaultImageForCategory(_ category: PlaceCategory) -> String {
        switch category {
        case .restaurants:
            return "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&h=400"
        case .cafes:
            return "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600&h=400"
        case .bars:
            return "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=600&h=400"
        case .venues:
            return "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=600&h=400"
        case .shopping:
            return "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=600&h=400"
        }
    }
    
    private func createDetailedHours(from openingHours: GoogleOpeningHours?) -> DetailedHours? {
        guard let openingHours = openingHours,
              let weekdayText = openingHours.weekday_text,
              !weekdayText.isEmpty else {
            return nil
        }
        
        let today = Calendar.current.component(.weekday, from: Date())
        let todayIndex = (today + 5) % 7 // Convert Calendar weekday to Google's format
        
        let weeklyHours = weekdayText.enumerated().map { index, dayText in
            let components = dayText.components(separatedBy: ": ")
            let day = components.first ?? "Unknown"
            
            if components.count > 1 && components[1] != "Closed" {
                let timeRange = components[1].components(separatedBy: " – ")
                let openTime = timeRange.first?.replacingOccurrences(of: ":00", with: "")
                let closeTime = timeRange.count > 1 ? timeRange[1].replacingOccurrences(of: ":00", with: "") : nil
                
                return DetailedHours.DayHours(
                    day: day,
                    openTime: openTime ?? "Unknown",
                    closeTime: closeTime ?? "Unknown",
                    isClosed: false
                )
            } else {
                return DetailedHours.DayHours(
                    day: day,
                    openTime: nil,
                    closeTime: nil,
                    isClosed: true
                )
            }
        }
        
                    let todayHours = todayIndex < weeklyHours.count ? weeklyHours[todayIndex] : (weeklyHours.first ?? DetailedHours.DayHours(day: "Today", openTime: "Unknown", closeTime: "Unknown", isClosed: true))
        let isOpen = openingHours.open_now == true
        
        // Calculate when it opens next if currently closed
        var opensNextAt: String? = nil
        if !isOpen {
            for i in 0..<7 {
                let nextDayIndex = (todayIndex + i) % 7
                if nextDayIndex < weeklyHours.count {
                    let nextDay = weeklyHours[nextDayIndex]
                    if !nextDay.isClosed, let openTime = nextDay.openTime {
                        opensNextAt = i == 0 ? openTime : "\(nextDay.day) at \(openTime)"
                        break
                    }
                }
            }
        }
        
        return DetailedHours(
            monday: weeklyHours.count > 1 && !weeklyHours[1].isClosed ? "\(weeklyHours[1].openTime ?? "Unknown") - \(weeklyHours[1].closeTime ?? "Unknown")" : nil,
            tuesday: weeklyHours.count > 2 && !weeklyHours[2].isClosed ? "\(weeklyHours[2].openTime ?? "Unknown") - \(weeklyHours[2].closeTime ?? "Unknown")" : nil,
            wednesday: weeklyHours.count > 3 && !weeklyHours[3].isClosed ? "\(weeklyHours[3].openTime ?? "Unknown") - \(weeklyHours[3].closeTime ?? "Unknown")" : nil,
            thursday: weeklyHours.count > 4 && !weeklyHours[4].isClosed ? "\(weeklyHours[4].openTime ?? "Unknown") - \(weeklyHours[4].closeTime ?? "Unknown")" : nil,
            friday: weeklyHours.count > 5 && !weeklyHours[5].isClosed ? "\(weeklyHours[5].openTime ?? "Unknown") - \(weeklyHours[5].closeTime ?? "Unknown")" : nil,
            saturday: weeklyHours.count > 6 && !weeklyHours[6].isClosed ? "\(weeklyHours[6].openTime ?? "Unknown") - \(weeklyHours[6].closeTime ?? "Unknown")" : nil,
            sunday: weeklyHours.count > 0 && !weeklyHours[0].isClosed ? "\(weeklyHours[0].openTime ?? "Unknown") - \(weeklyHours[0].closeTime ?? "Unknown")" : nil
        )
    }
    
    private func enhanceReviewsWithMultipleSources(_ googleReviews: [GoogleReview], placeName: String) -> [Review] {
        return googleReviews.prefix(5).map { googleReview in
            Review(
                authorName: googleReview.author_name,
                rating: Double(googleReview.rating),
                text: googleReview.text,
                time: Date(timeIntervalSince1970: TimeInterval(googleReview.time))
            )
        }
    }
    
    private func formatReviewDate(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func shouldShowMenu(for category: PlaceCategory, details: GooglePlaceDetails) -> Bool {
        return category == .restaurants || category == .cafes
    }
    
    private func generateIntelligentMenuItems(for category: PlaceCategory, placeDetails: GooglePlaceDetails) -> [MenuItem] {
        // Generate basic menu items without AI to avoid extra API calls
        switch category {
        case .restaurants:
            return [
                MenuItem(name: "Popular Dishes", description: "Ask about today's specials", price: "Market Price", category: "Main Course"),
                MenuItem(name: "Seasonal Menu", description: "Fresh seasonal offerings", price: "Varies", category: "Seasonal")
            ]
        case .cafes:
            return [
                MenuItem(name: "Coffee & Espresso", description: "Freshly brewed coffee", price: "$3-6", category: "Beverages"),
                MenuItem(name: "Pastries & Light Bites", description: "Fresh baked goods", price: "$4-8", category: "Pastries")
            ]
        default:
            return []
        }
    }
    
    // MARK: - Search Functionality
    func searchPlaces(query: String, location: CLLocation, radius: Double = 2.0) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            searchQuery = ""
            return
        }
        
        isSearching = true
        searchQuery = query
        
        print("🔍 Searching for: '\(query)' near location")
        
        googlePlacesService.searchPlacesByText(
            query: query,
            location: location,
            radius: Int(radius * 1609.34) // Convert miles to meters
        ) { [weak self] googlePlaces in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isSearching = false
                
                if googlePlaces.isEmpty {
                    self.searchResults = []
                    print("❌ No search results found for: '\(query)'")
                    return
                }
                
                // Convert GooglePlaces to Places and auto-categorize
                var searchPlaces: [Place] = []
                
                for googlePlace in googlePlaces {
                    let detectedCategory = self.detectCategoryFromTypes(googlePlace.types ?? [])
                    let place = self.convertBasicGooglePlaceToPlace(googlePlace, category: detectedCategory)
                    searchPlaces.append(place)
                    
                    // Cache the search result
                    PlaceDetailCacheManager.shared.cacheViewedPlace(place, for: detectedCategory)
                }
                
                self.searchResults = searchPlaces
                print("✅ Found \(searchPlaces.count) search results for: '\(query)'")
            }
        }
    }
    
    private func detectCategoryFromTypes(_ types: [String]) -> PlaceCategory {
        let typeSet = Set(types.map { $0.lowercased() })
        
        // Restaurant detection
        if typeSet.contains("restaurant") || typeSet.contains("food") || 
           typeSet.contains("meal_takeaway") || typeSet.contains("meal_delivery") {
            return .restaurants
        }
        
        // Cafe detection
        if typeSet.contains("cafe") || typeSet.contains("coffee") || 
           typeSet.contains("bakery") {
            return .cafes
        }
        
        // Bar detection
        if typeSet.contains("bar") || typeSet.contains("night_club") || 
           typeSet.contains("liquor_store") {
            return .bars
        }
        
        // Shopping detection
        if typeSet.contains("store") || typeSet.contains("shopping_mall") || 
           typeSet.contains("clothing_store") || typeSet.contains("department_store") {
            return .shopping
        }
        
        // Venue detection (fallback for entertainment)
        if typeSet.contains("amusement_park") || typeSet.contains("bowling_alley") || 
           typeSet.contains("movie_theater") || typeSet.contains("gym") {
            return .venues
        }
        
        // Default fallback based on keywords in place types
        return .restaurants // Most common category as fallback
    }
    
    private func convertBasicGooglePlaceToPlace(_ googlePlace: GooglePlace, category: PlaceCategory) -> Place {
        // Get photo reference for lazy loading
        let photoReference = googlePlace.photos?.first?.photo_reference
        let basicImages = photoReference != nil ? [photoReference!] : [getDefaultImageForCategory(category)]
        
        let priceRange = convertPriceLevel(googlePlace.price_level)
        
        return Place(
            id: UUID(),
            name: googlePlace.name,
            description: "Search result - tap to learn more",
            category: category,
            rating: googlePlace.rating ?? 0.0,
            reviewCount: 0, // Not available in this GooglePlace model
            priceRange: priceRange,
            images: basicImages,
            location: googlePlace.address,
            hours: "Hours available when you tap for details",
            detailedHours: nil,
            phone: "Phone available when you tap for details",
            website: nil,
            menuItems: [],
            reviews: [],
            googlePlaceId: googlePlace.placeId,
            sentiment: nil,
            isCurrentlyOpen: true, // Default to true, will be updated by detailed API call
            hasActualMenu: false,
            coordinates: Coordinates(
                latitude: googlePlace.geometry?.location.lat ?? 0.0,
                longitude: googlePlace.geometry?.location.lng ?? 0.0
            )
        )
    }
    
    func clearSearchResults() {
        searchResults = []
        searchQuery = ""
        isSearching = false
    }
    
    // MARK: - Debug Stats for Developer Screen
    
    func getCacheStats() -> [String: Any] {
        return [
            "totalCachedPlaces": placesByCategory.values.reduce(0) { $0 + $1.count },
            "cachedCategories": placesByCategory.keys.count,
            "exhaustedCategories": exhaustedCategories.count,
            "locationsCached": locationPlacesCache.keys.count,
            "detailedPlacesCached": detailedPlaceCache.keys.count,
            "cacheTimestamps": cacheTimestamps.keys.count
        ]
    }
    
    func getAllCachedPlaces() -> [PlaceCategory: [Place]] {
        return placesByCategory
    }
    
    // MARK: - Duplicate Detection Helper
    /// Returns true if `newPlace` already exists in `array` based on Google Place ID (preferred) or case-insensitive name comparison.
    private func isDuplicate(_ newPlace: Place, in array: [Place]) -> Bool {
        if let gpId = newPlace.googlePlaceId {
            if array.contains(where: { $0.googlePlaceId == gpId }) { return true }
        }
        // Fallback to name comparison when ID is missing
        return array.contains(where: { $0.name.lowercased() == newPlace.name.lowercased() })
    }
} 