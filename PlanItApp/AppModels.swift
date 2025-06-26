import SwiftUI
import Foundation
import CoreData
import FirebaseFirestore
import CoreLocation

// MARK: - Core Data Models (REQUIRED)

/// Core place category enum - this must match what PlaceDataService and other services expect
enum PlaceCategory: String, CaseIterable, Codable {
    case restaurants = "restaurants"
    case cafes = "cafes" 
    case bars = "bars"
    case venues = "venues"
    case shopping = "shopping"
    
    var displayName: String {
        switch self {
        case .restaurants: return "Restaurants"
        case .cafes: return "Cafes"
        case .bars: return "Bars"
        case .venues: return "Venues"
        case .shopping: return "Shopping"
        }
    }
    
    var iconName: String {
        switch self {
        case .restaurants: return "fork.knife"
        case .cafes: return "cup.and.saucer.fill"
        case .bars: return "wineglass.fill"
        case .venues: return "building.columns.fill"
        case .shopping: return "bag.fill"
        }
    }
    
    var color: String {
        switch self {
        case .restaurants: return "#FF6B6B"
        case .cafes: return "#4ECDC4"
        case .bars: return "#45B7D1"
        case .venues: return "#96CEB4"
        case .shopping: return "#FECA57"
        }
    }
    
    // String conversion helper
    static func fromString(_ string: String) -> PlaceCategory? {
        switch string.lowercased() {
        case "restaurants", "restaurant": return .restaurants
        case "cafes", "cafe", "coffee": return .cafes
        case "bars", "bar", "nightlife": return .bars
        case "venues", "venue", "entertainment": return .venues
        case "shopping", "shop", "retail": return .shopping
        default: return nil
        }
    }
}

/// Core coordinates struct
struct Coordinates: Codable {
    let latitude: Double
    let longitude: Double
}

/// Core Place model - this is what everything depends on
struct Place: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let category: PlaceCategory
    let rating: Double
    let reviewCount: Int
    let priceRange: String
    let images: [String] // Can contain URLs or photo references
    let location: String // Address string
    let hours: String
    let detailedHours: DetailedHours?
    let phone: String
    let website: String?
    let menuItems: [MenuItem]
    let reviews: [Review]
    let googlePlaceId: String?
    let sentiment: CustomerSentiment?
    let isCurrentlyOpen: Bool
    let hasActualMenu: Bool
    let coordinates: Coordinates?
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: PlaceCategory,
        rating: Double,
        reviewCount: Int = 0,
        priceRange: String,
        images: [String] = [],
        location: String,
        hours: String = "",
        detailedHours: DetailedHours? = nil,
        phone: String = "",
        website: String? = nil,
        menuItems: [MenuItem] = [],
        reviews: [Review] = [],
        googlePlaceId: String? = nil,
        sentiment: CustomerSentiment? = nil,
        isCurrentlyOpen: Bool = true,
        hasActualMenu: Bool = false,
        coordinates: Coordinates? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.rating = rating
        self.reviewCount = reviewCount
        self.priceRange = priceRange
        self.images = images
        self.location = location
        self.hours = hours
        self.detailedHours = detailedHours
        self.phone = phone
        self.website = website
        self.menuItems = menuItems
        self.reviews = reviews
        self.googlePlaceId = googlePlaceId
        self.sentiment = sentiment
        self.isCurrentlyOpen = isCurrentlyOpen
        self.hasActualMenu = hasActualMenu
        self.coordinates = coordinates
    }
}

// MARK: - Supporting Models

struct DetailedHours: Codable {
    let monday: String?
    let tuesday: String?
    let wednesday: String?
    let thursday: String?
    let friday: String?
    let saturday: String?
    let sunday: String?
    
    struct DayHours: Codable {
        let day: String
        let openTime: String?
        let closeTime: String?
        let isClosed: Bool
        
        init(day: String, openTime: String?, closeTime: String?, isClosed: Bool = false) {
            self.day = day
            self.openTime = openTime
            self.closeTime = closeTime
            self.isClosed = isClosed
        }
    }
    
    init(
        monday: String? = nil,
        tuesday: String? = nil,
        wednesday: String? = nil,
        thursday: String? = nil,
        friday: String? = nil,
        saturday: String? = nil,
        sunday: String? = nil
    ) {
        self.monday = monday
        self.tuesday = tuesday
        self.wednesday = wednesday
        self.thursday = thursday
        self.friday = friday
        self.saturday = saturday
        self.sunday = sunday
    }
}

struct MenuItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let price: String
    let category: String
    
    init(id: UUID = UUID(), name: String, description: String, price: String, category: String) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.category = category
    }
}

struct Review: Identifiable, Codable {
    let id: UUID
    let authorName: String
    let rating: Double
    let text: String
    let time: Date
    let profilePhotoUrl: String?
    
    init(id: UUID = UUID(), authorName: String, rating: Double, text: String, time: Date = Date(), profilePhotoUrl: String? = nil) {
        self.id = id
        self.authorName = authorName
        self.rating = rating
        self.text = text
        self.time = time
        self.profilePhotoUrl = profilePhotoUrl
    }
}

struct CustomerSentiment: Codable {
    let overallScore: Double
    let positiveWords: [String]
    let negativeWords: [String]
    let summary: String
}

// MARK: - Place Extensions
extension Place {
    func distanceFrom(_ location: CLLocation?) -> String {
        guard let location = location,
              let coordinates = coordinates else { return "" }
        
        let placeLocation = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        let distance = location.distance(from: placeLocation)
        let miles = distance * 0.000621371
        
        if miles < 0.1 {
            return "< 0.1 mi"
        } else if miles < 1.0 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
    
    func distanceFromUser(userLocation: CLLocation?) -> Double? {
        guard let userLocation = userLocation,
              let coordinates = coordinates else { return nil }
        
        let placeLocation = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        return userLocation.distance(from: placeLocation) * 0.000621371 // Convert to miles
    }
    
    var descriptiveTags: [String]? {
        // Generate tags based on category and other properties
        var tags: [String] = []
        tags.append(category.rawValue)
        
        if rating >= 4.5 {
            tags.append("highly_rated")
        }
        
        if priceRange == "$" {
            tags.append("budget_friendly")
        } else if priceRange == "$$$$" {
            tags.append("luxury")
        }
        
        return tags.isEmpty ? nil : tags
    }
}

// MARK: - Onboarding Manager
class OnboardingManager: ObservableObject {
    @Published var hasCompletedOnboarding = false
    @Published var onboardingData: OnboardingData?
    @Published var userName: String = ""
    
    private let userDefaults = UserDefaults.standard
    private let completedKey = "planit_onboarding_completed"
    private let dataKey = "planit_onboarding_data"
    private let userNameKey = "planit_user_name"
    
    init() {
        loadOnboardingStatus()
    }
    
    func loadOnboardingStatus() {
        hasCompletedOnboarding = userDefaults.bool(forKey: completedKey)
        userName = userDefaults.string(forKey: userNameKey) ?? ""
        
        if let data = userDefaults.data(forKey: dataKey) {
            do {
                onboardingData = try JSONDecoder().decode(OnboardingData.self, from: data)
                print("📁 Loaded onboarding data from UserDefaults")
            } catch {
                print("❌ Error loading onboarding data: \(error)")
            }
        }
        
        print("🔍 Onboarding status loaded: completed = \(hasCompletedOnboarding)")
    }
    
    func completeOnboarding(with data: OnboardingData) {
        print("🎯 OnboardingManager: Starting completion process...")
        
        DispatchQueue.main.async {
            self.onboardingData = data
            self.hasCompletedOnboarding = true
            print("✅ OnboardingManager: hasCompletedOnboarding set to \(self.hasCompletedOnboarding)")
        }
        
        userDefaults.set(true, forKey: completedKey)
        userDefaults.set(userName, forKey: userNameKey)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(data)
            userDefaults.set(jsonData, forKey: dataKey)
            print("💾 OnboardingManager: Data saved to UserDefaults")

            // Also save to a JSON file for developer access
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not get documents directory")
            return
        }
            let fileURL = documentsURL.appendingPathComponent("onboarding_data.json")
            try jsonData.write(to: fileURL, options: .atomic)
            print("📄 OnboardingManager: Data exported to \(fileURL.path)")
        } catch {
            print("❌ Error encoding or saving onboarding data: \(error)")
        }
        
        userDefaults.synchronize()
        print("🚀 Ready to transition to main app!")
    }
    
    func setUserName(_ name: String) {
        userName = name
        userDefaults.set(name, forKey: userNameKey)
        userDefaults.synchronize()
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        onboardingData = nil
        userName = ""
        userDefaults.removeObject(forKey: completedKey)
        userDefaults.removeObject(forKey: dataKey)
        userDefaults.removeObject(forKey: userNameKey)
        userDefaults.synchronize()
    }
    
    func clearOnboardingData() {
        resetOnboarding()
    }
    
    func exportOnboardingDataAsJSON() -> String {
        guard let data = onboardingData else { return "No onboarding data available" }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(data)
            return String(data: jsonData, encoding: .utf8) ?? "Failed to encode data"
        } catch {
            return "Error encoding data: \(error.localizedDescription)"
        }
    }
}

// MARK: - Enhanced Onboarding Data Models
struct OnboardingData: Codable {
    let selectedCategories: [OnboardingCategory]
    let responses: [OnboardingResponse]
    let completedAt: Date
    let appVersion: String
    let deviceInfo: DeviceInfo
    let userName: String
    
    init(selectedCategories: [OnboardingCategory], responses: [OnboardingResponse], userName: String = "") {
        self.selectedCategories = selectedCategories
        self.responses = responses
        self.userName = userName
        self.completedAt = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.deviceInfo = DeviceInfo()
    }
}

struct DeviceInfo: Codable {
    let deviceModel: String
    let systemVersion: String
    let screenSize: String
    
    init() {
        self.deviceModel = UIDevice.current.model
        self.systemVersion = UIDevice.current.systemVersion
        let screenBounds = UIScreen.main.bounds
        self.screenSize = "\(Int(screenBounds.width))x\(Int(screenBounds.height))"
    }
}

struct OnboardingResponse: Codable {
    let questionId: String
    let categoryId: String
    let selectedOptions: [String]?
    let sliderValue: Double?
    let ratingValue: Int?
    let textValue: String?
    let timestamp: Date
    
    init(questionId: String, categoryId: String, selectedOptions: [String]? = nil, sliderValue: Double? = nil, ratingValue: Int? = nil, textValue: String? = nil) {
        self.questionId = questionId
        self.categoryId = categoryId
        self.selectedOptions = selectedOptions
        self.sliderValue = sliderValue
        self.ratingValue = ratingValue
        self.textValue = textValue
        self.timestamp = Date()
    }
    
    // Custom decoding to handle various timestamp formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        questionId = try container.decode(String.self, forKey: .questionId)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        selectedOptions = try container.decodeIfPresent([String].self, forKey: .selectedOptions)
        sliderValue = try container.decodeIfPresent(Double.self, forKey: .sliderValue)
        ratingValue = try container.decodeIfPresent(Int.self, forKey: .ratingValue)
        textValue = try container.decodeIfPresent(String.self, forKey: .textValue)
        
        // Handle timestamp with multiple fallback strategies
        if let timestampDate = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = timestampDate
        } else if let timestampString = try? container.decode(String.self, forKey: .timestamp) {
            // Try ISO8601 format first
            let iso8601Formatter = ISO8601DateFormatter()
            if let date = iso8601Formatter.date(from: timestampString) {
                timestamp = date
            } else {
                // Try standard date formatter
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                if let date = dateFormatter.date(from: timestampString) {
                    timestamp = date
                } else {
                    // Fallback to current date
                    print("⚠️ Could not parse timestamp: \(timestampString), using current date")
                    timestamp = Date()
                }
            }
        } else if let timestampDouble = try? container.decode(Double.self, forKey: .timestamp) {
            // Handle Unix timestamp
            timestamp = Date(timeIntervalSince1970: timestampDouble)
        } else {
            // Ultimate fallback
            print("⚠️ No valid timestamp found, using current date")
            timestamp = Date()
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case questionId, categoryId, selectedOptions, sliderValue, ratingValue, textValue, timestamp
    }
}

// MARK: - Enhanced Onboarding Categories with More Questions
enum OnboardingCategory: String, CaseIterable, Codable, Identifiable {
    case global = "global"
    case restaurants = "restaurants"
    case hangoutSpots = "hangout_spots"
    case nature = "nature"
    case entertainment = "entertainment"
    case shopping = "shopping"
    case culture = "culture"
    case fitness = "fitness"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .restaurants: return "Restaurants"
        case .hangoutSpots: return "Hangout Spots"
        case .nature: return "Nature & Outdoors"
        case .entertainment: return "Entertainment"
        case .shopping: return "Shopping"
        case .culture: return "Culture & Arts"
        case .fitness: return "Fitness & Sports"
        case .global: return "Profile"
        }
    }
    
    var emoji: String {
        switch self {
        case .restaurants: return "🍽️"
        case .hangoutSpots: return "🎯"
        case .nature: return "🌿"
        case .entertainment: return "🎭"
        case .shopping: return "🛍️"
        case .culture: return "🎨"
        case .fitness: return "💪"
        case .global: return "🌎"
        }
    }
    
    var iconName: String {
        switch self {
        case .restaurants: return "fork.knife"
        case .hangoutSpots: return "person.2.fill"
        case .nature: return "leaf.fill"
        case .entertainment: return "theatermasks.fill"
        case .shopping: return "bag.fill"
        case .culture: return "building.columns.fill"
        case .fitness: return "figure.run"
        case .global: return "globe"
        }
    }
    
    var color: String {
        switch self {
        case .restaurants: return "#FF6B6B"
        case .hangoutSpots: return "#4ECDC4"
        case .nature: return "#45B7D1"
        case .entertainment: return "#96CEB4"
        case .shopping: return "#FECA57"
        case .culture: return "#FF9FF3"
        case .fitness: return "#54A0FF"
        case .global: return "#FFFFFF"
        }
    }
    
    var questions: [OnboardingQuestion] {
        switch self {
        case .restaurants:
            return [
                OnboardingQuestion(
                    id: "rest_1",
                    text: "What type of cuisine excites your taste buds most?",
                    type: .singleChoice,
                    options: [
                        "Italian & Mediterranean",
                        "Asian & Fusion",
                        "American & Comfort Food",
                        "Mexican & Latin American",
                        "International & Exotic",
                        "Vegetarian & Plant-Based"
                    ]
                ),
                OnboardingQuestion(
                    id: "rest_2",
                    text: "What's your ideal dining atmosphere?",
                    type: .singleChoice,
                    options: [
                        "Intimate & Romantic",
                        "Lively & Social",
                        "Casual & Relaxed",
                        "Upscale & Elegant",
                        "Quick & Convenient"
                    ]
                ),
                OnboardingQuestion(
                    id: "rest_3",
                    text: "How important is price range to you?",
                    type: .slider,
                    sliderRange: (1, 5),
                    sliderLabels: ("Budget-Friendly", "Premium Dining")
                ),
                OnboardingQuestion(
                    id: "rest_4",
                    text: "What crowd size do you prefer?",
                    type: .singleChoice,
                    options: [
                        "Popular & Bustling",
                        "Moderately Busy",
                        "Quiet & Intimate",
                        "Hidden Gems"
                    ]
                ),
                OnboardingQuestion(
                    id: "rest_5",
                    text: "Rate how adventurous you are with food",
                    type: .rating,
                    ratingMax: 5
                )
            ]
        case .hangoutSpots:
            return [
                OnboardingQuestion(
                    id: "hang_1",
                    text: "What's your ideal hangout vibe?",
                    type: .singleChoice,
                    options: [
                        "Cozy Coffee Shops",
                        "Trendy Bars & Lounges",
                        "Outdoor Patios",
                        "Gaming & Activity Centers",
                        "Quiet Study Spaces"
                    ]
                ),
                OnboardingQuestion(
                    id: "hang_2",
                    text: "What time do you usually hang out?",
                    type: .multipleChoice,
                    options: [
                        "Morning (6AM-12PM)",
                        "Afternoon (12PM-6PM)",
                        "Evening (6PM-10PM)",
                        "Late Night (10PM+)"
                    ]
                ),
                OnboardingQuestion(
                    id: "hang_3",
                    text: "How important is WiFi and tech amenities?",
                    type: .slider,
                    sliderRange: (1, 5),
                    sliderLabels: ("Not Important", "Essential")
                ),
                OnboardingQuestion(
                    id: "hang_4",
                    text: "Preferred noise level?",
                    type: .singleChoice,
                    options: [
                        "Silent & Peaceful",
                        "Soft Background Music",
                        "Moderate Conversation",
                        "Lively & Energetic"
                    ]
                )
            ]
        case .nature:
            return [
                OnboardingQuestion(
                    id: "nature_1",
                    text: "What outdoor activities call to you?",
                    type: .multipleChoice,
                    options: [
                        "Hiking & Walking Trails",
                        "Water Activities",
                        "Mountain & Rock Climbing",
                        "Parks & Gardens",
                        "Beach & Coastal Areas",
                        "Wildlife & Bird Watching"
                    ]
                ),
                OnboardingQuestion(
                    id: "nature_2",
                    text: "How challenging do you like your outdoor adventures?",
                    type: .slider,
                    sliderRange: (1, 5),
                    sliderLabels: ("Easy & Relaxing", "Extreme & Challenging")
                ),
                OnboardingQuestion(
                    id: "nature_3",
                    text: "What's your ideal natural setting?",
                    type: .singleChoice,
                    options: [
                        "Mountains & Hills",
                        "Forests & Woods",
                        "Lakes & Rivers",
                        "Ocean & Beaches",
                        "Deserts & Canyons",
                        "Urban Parks"
                    ]
                ),
                OnboardingQuestion(
                    id: "nature_4",
                    text: "How far are you willing to travel for nature?",
                    type: .slider,
                    sliderRange: (5, 120),
                    sliderLabels: ("5 min", "2+ hours")
                )
            ]
        case .entertainment:
            return [
                OnboardingQuestion(
                    id: "ent_1",
                    text: "What type of entertainment do you love most?",
                    type: .multipleChoice,
                    options: [
                        "Movies & Cinema",
                        "Live Music & Concerts",
                        "Theater & Performances",
                        "Comedy Shows",
                        "Nightlife & Dancing",
                        "Festivals & Events"
                    ]
                ),
                OnboardingQuestion(
                    id: "ent_2",
                    text: "What's your preferred entertainment timing?",
                    type: .singleChoice,
                    options: [
                        "Afternoon Shows",
                        "Evening Events",
                        "Late Night Fun",
                        "Weekend Specials"
                    ]
                ),
                OnboardingQuestion(
                    id: "ent_3",
                    text: "How much do you typically spend on entertainment?",
                    type: .slider,
                    sliderRange: (10, 200),
                    sliderLabels: ("$10", "$200+")
                ),
                OnboardingQuestion(
                    id: "ent_4",
                    text: "Do you prefer mainstream or indie entertainment?",
                    type: .slider,
                    sliderRange: (1, 5),
                    sliderLabels: ("Mainstream", "Indie & Alternative")
                )
            ]
        case .shopping:
            return [
                OnboardingQuestion(
                    id: "shop_1",
                    text: "What shopping experience do you enjoy?",
                    type: .multipleChoice,
                    options: [
                        "Large Malls & Centers",
                        "Boutique & Local Shops",
                        "Outdoor Markets",
                        "Vintage & Thrift Stores",
                        "Luxury & Designer Stores",
                        "Online Pickup Locations"
                    ]
                ),
                OnboardingQuestion(
                    id: "shop_2",
                    text: "What's your typical shopping budget?",
                    type: .slider,
                    sliderRange: (25, 500),
                    sliderLabels: ("$25", "$500+")
                ),
                OnboardingQuestion(
                    id: "shop_3",
                    text: "How important are sales and discounts?",
                    type: .rating,
                    ratingMax: 5
                ),
                OnboardingQuestion(
                    id: "shop_4",
                    text: "What shopping atmosphere do you prefer?",
                    type: .singleChoice,
                    options: [
                        "Busy & Energetic",
                        "Calm & Organized",
                        "Unique & Eclectic",
                        "Luxury & Exclusive"
                    ]
                )
            ]
        case .culture:
            return [
                OnboardingQuestion(
                    id: "culture_1",
                    text: "What cultural experiences inspire you?",
                    type: .multipleChoice,
                    options: [
                        "Museums & Galleries",
                        "Historical Sites",
                        "Architecture & Design",
                        "Local Traditions",
                        "Art Workshops",
                        "Cultural Festivals"
                    ]
                ),
                OnboardingQuestion(
                    id: "culture_2",
                    text: "How deeply do you like to explore cultural sites?",
                    type: .slider,
                    sliderRange: (1, 5),
                    sliderLabels: ("Quick Visit", "Deep Dive")
                ),
                OnboardingQuestion(
                    id: "culture_3",
                    text: "Your preferred cultural setting?",
                    type: .singleChoice,
                    options: [
                        "World-Famous Landmarks",
                        "Local Hidden Gems",
                        "Interactive Experiences",
                        "Peaceful Contemplation"
                    ]
                ),
                OnboardingQuestion(
                    id: "culture_4",
                    text: "How important is cultural authenticity?",
                    type: .rating,
                    ratingMax: 5
                )
            ]
        case .fitness:
            return [
                OnboardingQuestion(
                    id: "fitness_1",
                    text: "What fitness activities energize you?",
                    type: .multipleChoice,
                    options: [
                        "Gym & Weight Training",
                        "Yoga & Pilates",
                        "Running & Cardio",
                        "Swimming & Water Sports",
                        "Team Sports",
                        "Rock Climbing & Adventure"
                    ]
                ),
                OnboardingQuestion(
                    id: "fitness_2",
                    text: "What's your current fitness level?",
                    type: .slider,
                    sliderRange: (1, 5),
                    sliderLabels: ("Beginner", "Advanced Athlete")
                ),
                OnboardingQuestion(
                    id: "fitness_3",
                    text: "How often do you work out?",
                    type: .singleChoice,
                    options: [
                        "Daily",
                        "4-5 times per week",
                        "2-3 times per week",
                        "Weekly",
                        "Occasionally"
                    ]
                ),
                OnboardingQuestion(
                    id: "fitness_4",
                    text: "Do you prefer working out alone or in groups?",
                    type: .singleChoice,
                    options: [
                        "Solo Workouts",
                        "Small Groups (2-5)",
                        "Classes (6-20)",
                        "Large Groups (20+)"
                    ]
                )
            ]
        case .global:
            return []
        }
    }
}

// MARK: - Onboarding Question Models
struct OnboardingQuestion: Codable {
    let id: String
    let text: String
    let type: QuestionType
    let options: [String]?
    let sliderRange: (min: Double, max: Double)?
    let sliderLabels: (min: String, max: String)?
    let ratingMax: Int?
    
    init(id: String, text: String, type: QuestionType, options: [String]? = nil, sliderRange: (Double, Double)? = nil, sliderLabels: (String, String)? = nil, ratingMax: Int? = nil) {
        self.id = id
        self.text = text
        self.type = type
        self.options = options
        self.sliderRange = sliderRange
        self.sliderLabels = sliderLabels
        self.ratingMax = ratingMax
    }
    
    // Custom coding to handle tuples
    enum CodingKeys: String, CodingKey {
        case id, text, type, options, ratingMax
        case sliderMinValue, sliderMaxValue
        case sliderMinLabel, sliderMaxLabel
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        type = try container.decode(QuestionType.self, forKey: .type)
        options = try container.decodeIfPresent([String].self, forKey: .options)
        ratingMax = try container.decodeIfPresent(Int.self, forKey: .ratingMax)
        
        // Handle slider range
        if let minValue = try container.decodeIfPresent(Double.self, forKey: .sliderMinValue),
           let maxValue = try container.decodeIfPresent(Double.self, forKey: .sliderMaxValue) {
            sliderRange = (minValue, maxValue)
        } else {
            sliderRange = nil
        }
        
        // Handle slider labels
        if let minLabel = try container.decodeIfPresent(String.self, forKey: .sliderMinLabel),
           let maxLabel = try container.decodeIfPresent(String.self, forKey: .sliderMaxLabel) {
            sliderLabels = (minLabel, maxLabel)
        } else {
            sliderLabels = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(options, forKey: .options)
        try container.encodeIfPresent(ratingMax, forKey: .ratingMax)
        
        // Handle slider range
        if let range = sliderRange {
            try container.encode(range.min, forKey: .sliderMinValue)
            try container.encode(range.max, forKey: .sliderMaxValue)
        }
        
        // Handle slider labels
        if let labels = sliderLabels {
            try container.encode(labels.min, forKey: .sliderMinLabel)
            try container.encode(labels.max, forKey: .sliderMaxLabel)
        }
    }
}

enum QuestionType: String, Codable {
    case singleChoice = "single_choice"
    case multipleChoice = "multiple_choice"
    case slider = "slider"
    case rating = "rating"
    case textInput = "text_input"
}

// MARK: - Reaffirmation Data
struct ReaffirmationContent {
    let title: String
    let message: String
    let statistic: String
    let icon: String
    let backgroundColor: [String]
    
    static let contents: [ReaffirmationContent] = [
        ReaffirmationContent(
            title: "Great Choice!",
            message: "Users who complete personalization find 3x more places they love",
            statistic: "94% satisfaction rate",
            icon: "heart.fill",
            backgroundColor: ["#FF6B6B", "#FF8E8E"]
        ),
        ReaffirmationContent(
            title: "You're Doing Amazing!",
            message: "Personalized recommendations save users 2+ hours per week",
            statistic: "2.3 hours saved weekly",
            icon: "clock.fill",
            backgroundColor: ["#4ECDC4", "#26D0CE"]
        ),
        ReaffirmationContent(
            title: "Almost There!",
            message: "Complete profiles discover 40% more hidden gems nearby",
            statistic: "40% more discoveries",
            icon: "sparkles",
            backgroundColor: ["#45B7D1", "#96CEB4"]
        ),
        ReaffirmationContent(
            title: "Perfect!",
            message: "Users with your preferences rate their experiences 4.8/5 stars",
            statistic: "4.8★ average rating",
            icon: "star.fill",
            backgroundColor: ["#FECA57", "#FF9FF3"]
        ),
        ReaffirmationContent(
            title: "Excellent Progress!",
            message: "Detailed preferences lead to 60% better place matches",
            statistic: "60% better matches",
            icon: "target",
            backgroundColor: ["#54A0FF", "#5F27CD"]
        ),
        ReaffirmationContent(
            title: "Fantastic!",
            message: "Your taste profile is 85% more refined than average users",
            statistic: "Top 15% of users",
            icon: "crown.fill",
            backgroundColor: ["#F093FB", "#F5576C"]
        ),
        ReaffirmationContent(
            title: "Impressive!",
            message: "Users like you discover premium experiences 70% faster",
            statistic: "70% faster discovery",
            icon: "bolt.fill",
            backgroundColor: ["#667EEA", "#764BA2"]
        ),
        ReaffirmationContent(
            title: "Outstanding!",
            message: "Your detailed preferences unlock exclusive local recommendations",
            statistic: "200+ exclusive spots",
            icon: "key.fill",
            backgroundColor: ["#96CEB4", "#FFEAA7"]
        ),
        ReaffirmationContent(
            title: "Brilliant!",
            message: "Complete profiles get 5x more personalized event invitations",
            statistic: "5x more invitations",
            icon: "envelope.fill",
            backgroundColor: ["#FD79A8", "#FDCB6E"]
        ),
        ReaffirmationContent(
            title: "Superb!",
            message: "Users with your dedication save $200+ yearly on better choices",
            statistic: "$200+ saved yearly",
            icon: "dollarsign.circle.fill",
            backgroundColor: ["#00B894", "#00CEC9"]
        ),
        ReaffirmationContent(
            title: "Remarkable!",
            message: "Your preferences match 92% with top-rated local experiences",
            statistic: "92% compatibility",
            icon: "checkmark.seal.fill",
            backgroundColor: ["#A29BFE", "#6C5CE7"]
        ),
        ReaffirmationContent(
            title: "Phenomenal!",
            message: "Detailed users like you get priority access to new features",
            statistic: "VIP early access",
            icon: "star.circle.fill",
            backgroundColor: ["#FD79A8", "#E84393"]
        )
    ]
}

// MARK: - App Statistics
struct AppStatistic: Identifiable, Codable {
    var id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let iconName: String
    let color: String
    let trend: String?
    
    static let sampleStats: [AppStatistic] = [
        AppStatistic(title: "Total Users", value: "50K+", subtitle: "Active monthly users", iconName: "person.3.fill", color: "#FF6B6B", trend: "+12%"),
        AppStatistic(title: "Places Discovered", value: "1M+", subtitle: "Locations in database", iconName: "location.fill", color: "#4ECDC4", trend: "+5%"),
        AppStatistic(title: "Recommendations", value: "500K+", subtitle: "AI-powered suggestions", iconName: "brain.head.profile", color: "#45B7D1", trend: "+8%"),
        AppStatistic(title: "User Rating", value: "4.9★", subtitle: "Average app rating", iconName: "star.fill", color: "#FECA57", trend: "+0.1")
    ]
}

// MARK: - Reaffirmation Types
enum ReaffirmationType {
    case interests
    case preferences
    case final
}

// MARK: - User Preferences for Professional Onboarding
struct UserPreferences {
    var interests: [String] = []
    var distance: String = ""
    var budget: String = ""
    var name: String = ""
    var age: Int = 0
    var location: String = ""
    var travelDistance: Double = 5.0
    var preferredTime: String = ""
    var dietaryRestrictions: [String] = []
    var accessibility: [String] = []
}

// MARK: - User Model for Friends System
struct AppUser: Identifiable, Codable, Equatable {
    let id: String // Firebase UID
    var email: String
    var username: String // Changed from displayName to username (alphanumeric only)
    var displayName: String // This will be for profile display
    var userTag: String // 4-digit identifier like #1234
    var photoURL: String?
    var createdAt: Date
    var lastActiveAt: Date
    
    // XP System fields
    var userXP: UserXP = UserXP()
    
    // Friends system fields
    var friends: [String] = [] // Array of friend UIDs
    var sentFriendRequests: [String] = [] // Array of UIDs where this user sent requests
    var receivedFriendRequests: [String] = [] // Array of UIDs where this user received requests
    var blockedUsers: [String] = [] // Array of blocked user UIDs
    
    // Additional properties for mission generation
    var interactionLogs: [[String: AnyCodable]]?
    var likeCount: Int?
    var dislikeCount: Int?
    var tagAffinities: [String: Int]? // e.g. ["Cozy Vibes": 5]
    var behavior: BehaviorMetrics
    
    // Additional properties for mission generation
    var preferredPlaceTypes: [String]
    var cuisineHistory: [String]
    var currentLocation: LocationPoint?
    
    // Computed property for full username display
    var fullUsername: String {
        return "\(username)#\(userTag)"
    }
    
    // Initialize with automatic 4-digit tag generation
    init(id: String, email: String, username: String, displayName: String? = nil, photoURL: String? = nil) {
        self.id = id
        self.email = email
        self.username = AppUser.validateUsername(username)
        self.displayName = displayName ?? username
        self.userTag = AppUser.generateUserTag()
        self.photoURL = photoURL
        self.createdAt = Date()
        self.lastActiveAt = Date()
        self.interactionLogs = nil
        self.likeCount = 0
        self.dislikeCount = 0
        self.tagAffinities = [:]
        self.behavior = BehaviorMetrics()
        self.preferredPlaceTypes = ["restaurant", "cafe", "park", "shopping"]
        self.cuisineHistory = []
        self.currentLocation = nil
    }
    
    // Initialize with existing userTag (for loading from Firestore)
    init(id: String, email: String, username: String, displayName: String, userTag: String, photoURL: String? = nil, createdAt: Date = Date(), lastActiveAt: Date = Date()) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.userTag = userTag
        self.photoURL = photoURL
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.interactionLogs = nil
        self.likeCount = 0
        self.dislikeCount = 0
        self.tagAffinities = [:]
        self.behavior = BehaviorMetrics()
        self.preferredPlaceTypes = ["restaurant", "cafe", "park", "shopping"]
        self.cuisineHistory = []
        self.currentLocation = nil
    }
    
    // Validate username: only letters and numbers, no spaces or special characters
    static func validateUsername(_ username: String) -> String {
        let cleaned = username.filter { $0.isLetter || $0.isNumber }
        return cleaned.isEmpty ? "User" : cleaned
    }
    
    // Check if username is valid
    static func isValidUsername(_ username: String) -> Bool {
        let cleaned = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleaned.isEmpty && 
               cleaned.count >= 3 && 
               cleaned.count <= 20 &&
               cleaned.allSatisfy { $0.isLetter || $0.isNumber } &&
               !cleaned.contains("#") &&
               !cleaned.contains(" ")
    }
    
    // Generate a random 4-digit tag - called ONLY ONCE during user creation
    static func generateUserTag() -> String {
        let tag = Int.random(in: 1000...9999)
        let tagString = String(tag)
        print("🔢 Generated new permanent userTag: #\(tagString)")
        return tagString
    }
    
    // Check if users are friends
    func isFriend(with userId: String) -> Bool {
        return friends.contains(userId)
    }
    
    // Check if friend request was sent to user
    func hasSentFriendRequest(to userId: String) -> Bool {
        return sentFriendRequests.contains(userId)
    }
    
    // Check if friend request was received from user
    func hasReceivedFriendRequest(from userId: String) -> Bool {
        return receivedFriendRequests.contains(userId)
    }
    
    // Check if user is blocked
    func isBlocked(userId: String) -> Bool {
        return blockedUsers.contains(userId)
    }
}

// MARK: - Manual Hashable & Equatable for AppUser
extension AppUser: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension AppUser {
    static func == (lhs: AppUser, rhs: AppUser) -> Bool {
        return lhs.id == rhs.id && lhs.email == rhs.email && lhs.username == rhs.username && lhs.tagAffinities == rhs.tagAffinities && lhs.behavior == rhs.behavior
    }
}

// MARK: - Friend Request Model
struct FriendRequest: Identifiable, Codable, Hashable, Equatable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let fromUserName: String
    let fromUserTag: String
    let status: FriendRequestStatus
    let createdAt: Date
    let respondedAt: Date?
    
    var fullFromUsername: String {
        return "\(fromUserName)#\(fromUserTag)"
    }
}

// MARK: - Friend Request Status
enum FriendRequestStatus: String, Codable, CaseIterable, Hashable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case cancelled = "cancelled"
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let senderId: String
    let receiverId: String
    let content: String
    let type: MessageType
    let timestamp: Date
    var isRead: Bool
    let chatId: String // To group messages by conversation
    
    init(id: String = UUID().uuidString, senderId: String, receiverId: String, content: String, type: MessageType = .text) {
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.isRead = false
        // Create consistent chat ID (alphabetically sorted user IDs)
        self.chatId = [senderId, receiverId].sorted().joined(separator: "_")
    }
}

// MARK: - Chat Conversation Model
struct ChatConversation: Identifiable, Codable, Hashable, Equatable {
    let id: String // Same as chatId
    let participants: [String] // Array of user IDs
    var lastMessage: ChatMessage?
    var lastActivity: Date
    var isActive: Bool
    var unreadCount: [String: Int] // UserID -> unread count
    
    init(participants: [String]) {
        self.id = participants.sorted().joined(separator: "_")
        self.participants = participants.sorted()
        self.lastMessage = nil
        self.lastActivity = Date()
        self.isActive = true
        self.unreadCount = [:]
        
        // Initialize unread count for each participant
        participants.forEach { participantId in
            self.unreadCount[participantId] = 0
        }
    }
}

// MARK: - Message Types
enum MessageType: String, Codable, Hashable {
    case text = "text"
    case ping = "ping"
    case image = "image"
    case location = "location"
    case friendRequest = "friend_request"
}

// MARK: - Notification Model
struct AppNotification: Identifiable, Codable {
    var id: String?
    let userId: String
    let type: String
    let title: String
    let message: String
    let timestamp: Timestamp
    var isRead: Bool = false
    
    // Additional fields for different notification types
    let senderId: String?
    let senderName: String?
    let data: [String: String]?
    
    init(userId: String, type: String, title: String, message: String, timestamp: Timestamp, senderId: String? = nil, senderName: String? = nil, data: [String: String]? = nil) {
        self.id = nil
        self.userId = userId
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.isRead = false
        self.senderId = senderId
        self.senderName = senderName
        self.data = data
    }
    
    private enum CodingKeys: String, CodingKey {
        case userId, type, title, message, timestamp, isRead
        case senderId, senderName, data
    }
}

// MARK: - Friendship Status
enum FriendshipStatus {
    case notFriends
    case friends
    case requestSent
    case requestReceived
    case blocked
}

// MARK: - XP & Level System Models
struct UserXP: Codable, Hashable, Equatable {
    var currentXP: Int
    var level: Int
    var xpHistory: [XPEvent]
    var weeklyXP: Int
    var lastXPUpdate: Date
    var currentUserId: String? // Added for leaderboard tracking
    
    init() {
        self.currentXP = 0
        self.level = 1
        self.xpHistory = []
        self.weeklyXP = 0
        self.lastXPUpdate = Date()
        self.currentUserId = nil
    }
    
    // Calculate level from XP (500 XP per level)
    static func calculateLevel(from xp: Int) -> Int {
        return max(1, (xp / 500) + 1)
    }
    
    // Calculate XP needed for next level
    func xpToNextLevel() -> Int {
        let nextLevel = level + 1
        let xpNeededForNextLevel = (nextLevel - 1) * 500
        return xpNeededForNextLevel - currentXP
    }
    
    // Calculate progress to next level (0.0 to 1.0)
    func progressToNextLevel() -> Double {
        let currentLevelXP = (level - 1) * 500
        let nextLevelXP = level * 500
        let progressXP = currentXP - currentLevelXP
        let totalXPForLevel = nextLevelXP - currentLevelXP
        return Double(progressXP) / Double(totalXPForLevel)
    }
}

struct XPEvent: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let event: String
    let xp: Int
    let timestamp: Date
    let placeId: String?
    let missionId: String?
    let details: String?
    
    init(event: String, xp: Int, placeId: String? = nil, missionId: String? = nil, details: String? = nil) {
        self.id = UUID().uuidString
        self.event = event
        self.xp = xp
        self.timestamp = Date()
        self.placeId = placeId
        self.missionId = missionId
        self.details = details
    }
}

// MARK: - Mission System Models
struct Mission: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let prompt: String? // Legacy property for backward compatibility
    let description: String // New concise description
    let xpReward: Int
    let vibeTag: String? // Legacy property for backward compatibility
    let locationType: String? // Legacy property for backward compatibility
    let status: MissionStatus
    let createdAt: Date
    var completedAt: Date?
    let placeOptions: [MissionPlace]? // Legacy property for backward compatibility
    let targetPlaces: [MissionTargetPlace] // New places system
    var visitedPlaces: [String] // Array of visited place IDs
    let userId: String?
    let isDaily: Bool // Flag for daily missions
    
    // Legacy initializer for backward compatibility
    init(title: String, prompt: String, xpReward: Int, vibeTag: String, locationType: String, placeOptions: [MissionPlace], userId: String) {
        self.id = UUID().uuidString
        self.title = title
        self.prompt = prompt
        self.description = prompt // Use prompt as description for legacy missions
        self.xpReward = xpReward
        self.vibeTag = vibeTag
        self.locationType = locationType
        self.status = .active
        self.createdAt = Date()
        self.completedAt = nil
        self.placeOptions = placeOptions
        self.targetPlaces = [] // Empty for legacy missions
        self.visitedPlaces = []
        self.userId = userId
        self.isDaily = false
    }
    
    // New initializer for daily missions
    init(id: String, title: String, description: String, targetPlaces: [MissionTargetPlace], visitedPlaces: [String], xpReward: Int, createdAt: Date, status: MissionStatus, isDaily: Bool = false) {
        self.id = id
        self.title = title
        self.prompt = nil // No prompt for new missions
        self.description = description
        self.xpReward = xpReward
        self.vibeTag = nil // No vibe tag for new missions
        self.locationType = nil // No location type for new missions
        self.status = status
        self.createdAt = createdAt
        self.completedAt = nil
        self.placeOptions = nil // No place options for new missions
        self.targetPlaces = targetPlaces
        self.visitedPlaces = visitedPlaces
        self.userId = nil // User ID stored separately
        self.isDaily = isDaily
    }
    
    var isCompleted: Bool {
        if let placeOptions = placeOptions {
            return placeOptions.contains { $0.completed } // Legacy check
        } else {
            return visitedPlaces.count >= targetPlaces.count // New check
        }
    }
    
    var completedPlacesCount: Int {
        if let placeOptions = placeOptions {
            return placeOptions.filter { $0.completed }.count // Legacy count
        } else {
            return visitedPlaces.count // New count
        }
    }
}

struct MissionPlace: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let placeId: String
    let name: String
    let address: String
    var completed: Bool
    var completedAt: Date?
    
    init(placeId: String, name: String, address: String) {
        self.id = UUID().uuidString
        self.placeId = placeId
        self.name = name
        self.address = address
        self.completed = false
        self.completedAt = nil
    }
}

enum MissionStatus: String, Codable, CaseIterable, Hashable {
    case active = "active"
    case completed = "completed"
    case expired = "expired"
}

// MARK: - Mission Target Place Model
struct MissionTargetPlace: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let placeId: String
    let name: String
    let address: String
    let rating: Double
    let category: String
    
    init(placeId: String, name: String, address: String, rating: Double, category: String) {
        self.id = UUID().uuidString
        self.placeId = placeId
        self.name = name
        self.address = address
        self.rating = rating
        self.category = category
    }
}

// MARK: - Leaderboard Models
struct LeaderboardPlayer: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let name: String
    let xp: Int
    let level: Int
    let avatarURL: String?
    
    init(id: String, name: String, xp: Int, level: Int, avatarURL: String? = nil) {
        self.id = id
        self.name = name
        self.xp = xp
        self.level = level
        self.avatarURL = avatarURL
    }
}

struct LeaderboardEntry: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let userId: String
    let username: String
    let displayName: String
    let xp: Int
    let level: Int
    let location: String
    let avatarURL: String?
    let lastUpdated: Date
    let monthYear: String // "2025-01" format
    
    init(userId: String, username: String, displayName: String, xp: Int, level: Int, location: String = "", avatarURL: String? = nil) {
        self.id = userId
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.xp = xp
        self.level = level
        self.location = location
        self.avatarURL = avatarURL
        self.lastUpdated = Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.monthYear = formatter.string(from: Date())
    }
    
    var rank: Int = 0 // Will be set when loading leaderboard
}

// MARK: - Leaderboard Timeframe
enum LeaderboardTimeframe: String, CaseIterable {
    case thisWeek = "week"
    case thisMonth = "month"
    case allTime = "all_time"
    
    var title: String {
        switch self {
        case .thisWeek:
            return "This Week"
        case .thisMonth:
            return "This Month"
        case .allTime:
            return "All Time"
        }
    }
}

// MARK: - Enhanced Mission System Models

// Mission concept from AI before real places are added
struct MissionConcept: Codable {
    let title: String
    let prompt: String
    let xpReward: Int
    let vibeTag: String
    let locationType: String
    let placeSearchQuery: String
    let targetPlaceCount: Int
    let userId: String
    
    init(title: String, prompt: String, xpReward: Int, vibeTag: String, locationType: String, placeSearchQuery: String, targetPlaceCount: Int, userId: String) {
        self.title = title
        self.prompt = prompt
        self.xpReward = xpReward
        self.vibeTag = vibeTag
        self.locationType = locationType
        self.placeSearchQuery = placeSearchQuery
        self.targetPlaceCount = targetPlaceCount
        self.userId = userId
    }
}

// MARK: - Google Places Models
struct GooglePlace: Codable, Identifiable {
    let place_id: String
    let name: String
    let rating: Double?
    let user_ratings_total: Int?
    let price_level: Int?
    let vicinity: String?
    let types: [String]?
    let geometry: Geometry?
    let photos: [Photo]?
    let opening_hours: OpeningHours?
    let formatted_address: String?
    
    var id: String { place_id }
    
    // MARK: - Nested Types
    struct Geometry: Codable {
        let location: Location
        
        struct Location: Codable {
            let lat: Double
            let lng: Double
        }
    }
    
    struct Photo: Codable {
        let photo_reference: String
        let height: Int
        let width: Int
        let html_attributions: [String]
    }
    
    struct OpeningHours: Codable {
        let open_now: Bool?
        let periods: [Period]?
        let weekday_text: [String]?
        
        struct Period: Codable {
            let close: TimeInfo?
            let open: TimeInfo?
            
            struct TimeInfo: Codable {
                let day: Int
                let time: String
            }
        }
    }
}

// MARK: - Behavior Metrics
struct BehaviorMetrics: Codable, Equatable {
    var sessionCount: Int
    var totalPlaceViews: Int
    var totalThumbsUp: Int
    var totalThumbsDown: Int
    var tagAffinities: [String: Int]
    
    init() {
        self.sessionCount = 0
        self.totalPlaceViews = 0
        self.totalThumbsUp = 0
        self.totalThumbsDown = 0
        self.tagAffinities = [:]
    }
}

// MARK: - Psychological Nudging System
enum NudgeType: String, CaseIterable, Codable {
    case socialProof = "social_proof"        // "123 people love this place!"
    case scarcity = "scarcity"              // "Only 2 tables left!"
    case progress = "progress"              // "Complete 3 more quests to level up!"
    case curiosity = "curiosity"            // "What's behind this hidden gem?"
    case authority = "authority"            // "Top-rated by food critics"
    case commitment = "commitment"          // "You're 80% to your weekly goal!"
    
    var displayName: String {
        switch self {
        case .socialProof: return "Social Proof"
        case .scarcity: return "Scarcity"
        case .progress: return "Progress"
        case .curiosity: return "Curiosity"
        case .authority: return "Authority"
        case .commitment: return "Commitment"
        }
    }
    
    var iconName: String {
        switch self {
        case .socialProof: return "person.2"
        case .scarcity: return "timer"
        case .progress: return "chart.bar.fill"
        case .curiosity: return "eye"
        case .authority: return "star.fill"
        case .commitment: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .socialProof: return .blue
        case .scarcity: return .orange
        case .progress: return .green
        case .curiosity: return .purple
        case .authority: return .yellow
        case .commitment: return .pink
        }
    }
}

// MARK: - Enhanced Tab Items with Psychology
enum TabItem: String, CaseIterable {
    case explore = "Discover"  // Changed to more exciting language
    case parties = "Parties"   // NEW: Party discovery and RSVP
    case missions = "Quests"   // Gamification language
    case friends = "Friends"   // Social connection language
    case favorites = "Favorites" // Added favorites tab
    case profile = "Profile"   // Personal connection
    
    var iconName: String {
        switch self {
        case .explore: return "safari.fill"
        case .parties: return "party.popper"
        case .missions: return "target"
        case .friends: return "person.2.fill"
        case .favorites: return "heart.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
    
    var iconNameUnselected: String {
        switch self {
        case .explore: return "safari"
        case .parties: return "party.popper"
        case .missions: return "scope"
        case .friends: return "person.2"
        case .favorites: return "heart"
        case .profile: return "person.crop.circle"
        }
    }
    
    var psychologyColor: [Color] {
        switch self {
        case .explore: return [Color(hex: "#667eea"), Color(hex: "#764ba2")]  // Discovery colors
        case .parties: return [Color(hex: "#FF6B6B"), Color(hex: "#FF8E8E")] // Party/celebration colors
        case .missions: return [Color(hex: "#f093fb"), Color(hex: "#f5576c")] // Achievement colors
        case .friends: return [Color(hex: "#4facfe"), Color(hex: "#00f2fe")]  // Social colors
        case .favorites: return [Color(hex: "#FF6B9D"), Color(hex: "#C44569")] // Love colors
        case .profile: return [Color(hex: "#43e97b"), Color(hex: "#38f9d7")]  // Personal growth colors
        }
    }
    
    var gradientColors: [Color] {
        return psychologyColor // Alias for compatibility
    }
    
    var emotionalPrompt: String {
        switch self {
        case .explore: return "Ready to uncover hidden gems? ✨"
        case .parties: return "Ready to party and connect? 🎉"
        case .missions: return "Challenge accepted? 🎯"
        case .friends: return "Your tribe awaits! 👥"
        case .favorites: return "Your saved treasures! 💖"
        case .profile: return "You're becoming legendary! 🌟"
        }
    }
}

// MARK: - AI Place Category (for PerformanceOptimizationService)
struct AIPlaceCategory: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let emoji: String
    let placeCount: Int
    let queryTerms: [String]
    
    init(title: String, description: String, emoji: String, placeCount: Int, queryTerms: [String]) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.emoji = emoji
        self.placeCount = placeCount
        self.queryTerms = queryTerms
    }
}

// MARK: - Detailed Recommendation (for RecommendationEngine)
struct DetailedRecommendation: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let psychologyScore: Double
    let persuasionAngle: String
    let motivationalHook: String
    let socialProofElement: String
    let timingOptimization: String
    let noveltyBalance: String
    let moodAlignment: String
    let behavioralNudge: String
    let confidenceScore: Double
    let reasoningChain: String
    
    init(
        name: String,
        category: String,
        psychologyScore: Double = 7.0,
        persuasionAngle: String = "",
        motivationalHook: String = "",
        socialProofElement: String = "",
        timingOptimization: String = "",
        noveltyBalance: String = "",
        moodAlignment: String = "",
        behavioralNudge: String = "",
        confidenceScore: Double = 0.8,
        reasoningChain: String = ""
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.category = category
        self.psychologyScore = psychologyScore
        self.persuasionAngle = persuasionAngle
        self.motivationalHook = motivationalHook
        self.socialProofElement = socialProofElement
        self.timingOptimization = timingOptimization
        self.noveltyBalance = noveltyBalance
        self.moodAlignment = moodAlignment
        self.behavioralNudge = behavioralNudge
        self.confidenceScore = confidenceScore
        self.reasoningChain = reasoningChain
    }
}

// MARK: - Real Time Factors (for RecommendationEngine)
struct RealTimeFactors: Codable {
    let currentPopularity: Double
    let waitTime: String?
    let weatherSuitability: Double
    let transitConditions: String?
    let eventImpact: String?
    let priceFluctuation: Double?
    let crowdLevel: String
    let availabilityStatus: String
    
    init(
        currentPopularity: Double = 5.0,
        waitTime: String? = nil,
        weatherSuitability: Double = 8.0,
        transitConditions: String? = nil,
        eventImpact: String? = nil,
        priceFluctuation: Double? = nil,
        crowdLevel: String = "moderate",
        availabilityStatus: String = "open"
    ) {
        self.currentPopularity = currentPopularity
        self.waitTime = waitTime
        self.weatherSuitability = weatherSuitability
        self.transitConditions = transitConditions
        self.eventImpact = eventImpact
        self.priceFluctuation = priceFluctuation
        self.crowdLevel = crowdLevel
        self.availabilityStatus = availabilityStatus
    }
}

// MARK: - Intelligent Recommendation (enhanced recommendation type)
struct IntelligentRecommendation: Identifiable, Codable {
    let id: String
    let aiRecommendation: DetailedRecommendation
    let googlePlace: GooglePlaceDetails?
    let psychologyScore: Double
    let personalizedReasoning: String
    let behavioralNudges: [String]
    let realTimeFactors: RealTimeFactors
    var evolutionScore: Double = 0.0
    var temporalFitScore: Double = 0.0
    var socialRelevanceScore: Double = 0.0
    var moodOptimizationScore: Double = 0.0
    var finalIntelligenceScore: Double = 0.0
    let confidenceScore: Double
    
    init(
        aiRecommendation: DetailedRecommendation,
        googlePlace: GooglePlaceDetails? = nil,
        psychologyScore: Double = 7.0,
        personalizedReasoning: String = "",
        behavioralNudges: [String] = [],
        realTimeFactors: RealTimeFactors = RealTimeFactors(),
        confidenceScore: Double = 0.8
    ) {
        self.id = UUID().uuidString
        self.aiRecommendation = aiRecommendation
        self.googlePlace = googlePlace
        self.psychologyScore = psychologyScore
        self.personalizedReasoning = personalizedReasoning
        self.behavioralNudges = behavioralNudges
        self.realTimeFactors = realTimeFactors
        self.confidenceScore = confidenceScore
    }
}

// MARK: - Dynamic Category (for recommendations)
struct DynamicCategory: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let reasoning: String
    let searchQuery: String
    let category: PlaceCategory
    var places: [Place]
    let confidence: Double
    let personalizedEmoji: String
    let vibeDescription: String
    let socialProofText: String?
    let psychologyHook: String?
    
    var displayTitle: String {
        "\(personalizedEmoji) \(title)"
    }
    
    init(
        id: String,
        title: String,
        subtitle: String,
        reasoning: String,
        searchQuery: String,
        category: PlaceCategory,
        places: [Place] = [],
        confidence: Double = 0.8,
        personalizedEmoji: String = "🎯",
        vibeDescription: String = "",
        socialProofText: String? = nil,
        psychologyHook: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.reasoning = reasoning
        self.searchQuery = searchQuery
        self.category = category
        self.places = places
        self.confidence = confidence
        self.personalizedEmoji = personalizedEmoji
        self.vibeDescription = vibeDescription
        self.socialProofText = socialProofText
        self.psychologyHook = psychologyHook
    }
}

// MARK: - User Interaction (for behavioral tracking)
struct UserInteraction: Codable {
    let interactionType: String
    let targetId: String
    let timestamp: Date
    let context: [String: Any]
    let sessionId: String
    
    init(interactionType: String, targetId: String, context: [String: Any] = [:], sessionId: String = UUID().uuidString) {
        self.interactionType = interactionType
        self.targetId = targetId
        self.timestamp = Date()
        self.context = context
        self.sessionId = sessionId
    }
    
    enum CodingKeys: String, CodingKey {
        case interactionType, targetId, timestamp, sessionId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        interactionType = try container.decode(String.self, forKey: .interactionType)
        targetId = try container.decode(String.self, forKey: .targetId)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        context = [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(interactionType, forKey: .interactionType)
        try container.encode(targetId, forKey: .targetId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(sessionId, forKey: .sessionId)
    }
}

// MARK: - Recommendation Insights
struct RecommendationInsights: Codable {
    let generationTimestamp: Date
    let recommendationCount: Int
    let averagePsychologyScore: Double
    let personalizedCategoryCount: Int
    let adaptationLevel: Double
    let confidenceScore: Double
    let diversityScore: Double
    let noveltyBalance: Double
    
    init(
        generationTimestamp: Date = Date(),
        recommendationCount: Int = 0,
        averagePsychologyScore: Double = 0.0,
        personalizedCategoryCount: Int = 0,
        adaptationLevel: Double = 0.0,
        confidenceScore: Double = 0.0,
        diversityScore: Double = 0.0,
        noveltyBalance: Double = 0.0
    ) {
        self.generationTimestamp = generationTimestamp
        self.recommendationCount = recommendationCount
        self.averagePsychologyScore = averagePsychologyScore
        self.personalizedCategoryCount = personalizedCategoryCount
        self.adaptationLevel = adaptationLevel
        self.confidenceScore = confidenceScore
        self.diversityScore = diversityScore
        self.noveltyBalance = noveltyBalance
    }
}

// MARK: - Cached Recommendation
struct CachedRecommendation {
    let recommendations: [IntelligentRecommendation]
    let timestamp: Date
    
    init(recommendations: [IntelligentRecommendation], timestamp: Date = Date()) {
        self.recommendations = recommendations
        self.timestamp = timestamp
    }
}

// MARK: - Enhanced Recommendation Context Types

struct EnrichedRecommendationContext {
    let location: CLLocation
    let fingerprint: UserFingerprint?
    let weather: WeatherData?
    let timeContext: TimeContext
    let behavioralContext: BehavioralContext
    let socialContext: SocialContext
    let providedContext: RecommendationContext?
    let geminiContext: GeminiAIService.RecommendationContext
}

struct TimeContext {
    let timeOfDay: String
    let dayOfWeek: String
    let isWeekend: Bool
    let season: String
    
    init(timeOfDay: String = "unknown", dayOfWeek: String = "unknown", isWeekend: Bool = false, season: String = "unknown") {
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.isWeekend = isWeekend
        self.season = season
    }
}

struct BehavioralContext {
    let currentSessionDuration: Double
    let recentInteractionVelocity: Double
    let preferencePattern: String
    let explorationTendency: Double
    
    init(currentSessionDuration: Double = 0, recentInteractionVelocity: Double = 0, preferencePattern: String = "balanced", explorationTendency: Double = 0.5) {
        self.currentSessionDuration = currentSessionDuration
        self.recentInteractionVelocity = recentInteractionVelocity
        self.preferencePattern = preferencePattern
        self.explorationTendency = explorationTendency
    }
}

// SocialContext is defined in Models/UserFingerprint.swift

// MARK: - User Behavioral Profile Types
struct UserBehavioralProfile {
    let email: String
    let displayName: String
    let totalThumbsUp: Int
    let totalThumbsDown: Int
    let likes: [String]
    let dislikes: [String]
    let categoryAffinities: [String: Int]
    let categoryAvoidance: [String: Int]
    let touchAnalytics: [String: Any]
    let realtimeMetrics: [String: Any]
    let behavioralProfile: [String: Any]
    let deviceProfile: [String: Any]
    let currentSession: [String: Any]
    let totalInteractions: Int
    let detailedInteractions: [[String: Any]]
    let lastInteractionAt: Date
    let memberSince: Date
    
    init(
        email: String = "",
        displayName: String = "",
        totalThumbsUp: Int = 0,
        totalThumbsDown: Int = 0,
        likes: [String] = [],
        dislikes: [String] = [],
        categoryAffinities: [String: Int] = [:],
        categoryAvoidance: [String: Int] = [:],
        touchAnalytics: [String: Any] = [:],
        realtimeMetrics: [String: Any] = [:],
        behavioralProfile: [String: Any] = [:],
        deviceProfile: [String: Any] = [:],
        currentSession: [String: Any] = [:],
        totalInteractions: Int = 0,
        detailedInteractions: [[String: Any]] = [],
        lastInteractionAt: Date = Date(),
        memberSince: Date = Date()
    ) {
        self.email = email
        self.displayName = displayName
        self.totalThumbsUp = totalThumbsUp
        self.totalThumbsDown = totalThumbsDown
        self.likes = likes
        self.dislikes = dislikes
        self.categoryAffinities = categoryAffinities
        self.categoryAvoidance = categoryAvoidance
        self.touchAnalytics = touchAnalytics
        self.realtimeMetrics = realtimeMetrics
        self.behavioralProfile = behavioralProfile
        self.deviceProfile = deviceProfile
        self.currentSession = currentSession
        self.totalInteractions = totalInteractions
        self.detailedInteractions = detailedInteractions
        self.lastInteractionAt = lastInteractionAt
        self.memberSince = memberSince
    }
}

struct DeviceAnalytics {
    let model: String
    let systemVersion: String
    let batteryLevel: Float
    let batteryState: Int
    let orientation: Int
    let screenBrightness: CGFloat
    let thermalState: Int
    let lowPowerMode: Bool
    let memoryUsage: Double
    let usagePattern: String
    
    init(
        model: String = UIDevice.current.model,
        systemVersion: String = UIDevice.current.systemVersion,
        batteryLevel: Float = UIDevice.current.batteryLevel,
        batteryState: Int = UIDevice.current.batteryState.rawValue,
        orientation: Int = UIDevice.current.orientation.rawValue,
        screenBrightness: CGFloat = UIScreen.main.brightness,
        thermalState: Int = ProcessInfo.processInfo.thermalState.rawValue,
        lowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled,
        memoryUsage: Double = 0.0,
        usagePattern: String = "normal"
    ) {
        self.model = model
        self.systemVersion = systemVersion
        self.batteryLevel = batteryLevel
        self.batteryState = batteryState
        self.orientation = orientation
        self.screenBrightness = screenBrightness
        self.thermalState = thermalState
        self.lowPowerMode = lowPowerMode
        self.memoryUsage = memoryUsage
        self.usagePattern = usagePattern
    }
}

struct InteractionHistory {
    let recentInteractions: [[String: Any]]
    let totalSessions: Int
    let averageSessionDuration: Double
    let mostActiveTimeOfDay: String
    let preferredCategories: [String]
    let interactionVelocity: Double
    let engagementTrends: [String: Any]
    
    init(
        recentInteractions: [[String: Any]] = [],
        totalSessions: Int = 0,
        averageSessionDuration: Double = 0,
        mostActiveTimeOfDay: String = "unknown",
        preferredCategories: [String] = [],
        interactionVelocity: Double = 0,
        engagementTrends: [String: Any] = [:]
    ) {
        self.recentInteractions = recentInteractions
        self.totalSessions = totalSessions
        self.averageSessionDuration = averageSessionDuration
        self.mostActiveTimeOfDay = mostActiveTimeOfDay
        self.preferredCategories = preferredCategories
        self.interactionVelocity = interactionVelocity
        self.engagementTrends = engagementTrends
    }
}

struct MoodAnalysis {
    let primaryMood: String
    let moodScore: Double
    let energyLevel: String
    let personalityType: String
    let confidenceLevel: Double
    let recommendations: [String]
    
    init(
        primaryMood: String = "neutral",
        moodScore: Double = 5.0,
        energyLevel: String = "moderate",
        personalityType: String = "balanced",
        confidenceLevel: Double = 0.5,
        recommendations: [String] = []
    ) {
        self.primaryMood = primaryMood
        self.moodScore = moodScore
        self.energyLevel = energyLevel
        self.personalityType = personalityType
        self.confidenceLevel = confidenceLevel
        self.recommendations = recommendations
    }
}

struct ContextualData {
    let timeOfDay: String
    let dayOfWeek: String
    let isWeekend: Bool
    let season: String
    let weather: String
    let locationContext: String
    let socialContext: String
    let economicContext: String
    
    init(
        timeOfDay: String = "unknown",
        dayOfWeek: String = "unknown",
        isWeekend: Bool = false,
        season: String = "unknown",
        weather: String = "unknown",
        locationContext: String = "unknown",
        socialContext: String = "unknown",
        economicContext: String = "unknown"
    ) {
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.isWeekend = isWeekend
        self.season = season
        self.weather = weather
        self.locationContext = locationContext
        self.socialContext = socialContext
        self.economicContext = economicContext
    }
}

// WeatherData is defined in WeatherService.swift

// MARK: - Haptic Manager (missing class)
class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    private init() {}
    
    func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    func successFeedback() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func errorFeedback() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    func warningFeedback() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Party System Models

/// Party model for event hosting and management
struct Party: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let hostId: String
    let hostName: String
    let location: PartyLocation
    let startDate: Date
    let endDate: Date
    let ticketTiers: [TicketTier]
    let guestCap: Int
    let currentAttendees: Int
    let isPublic: Bool
    let tags: [String]
    let flyerImageURL: String?
    let landingPageURL: String?
    let perks: [String]
    let status: PartyStatus
    let createdAt: Date
    let updatedAt: Date
    let analytics: PartyAnalytics?
    
    enum PartyStatus: String, Codable, CaseIterable {
        case upcoming = "upcoming"
        case live = "live"
        case ended = "ended"
        case cancelled = "cancelled"
    }
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        hostId: String,
        hostName: String,
        location: PartyLocation,
        startDate: Date,
        endDate: Date,
        ticketTiers: [TicketTier] = [],
        guestCap: Int,
        currentAttendees: Int = 0,
        isPublic: Bool = true,
        tags: [String] = [],
        flyerImageURL: String? = nil,
        landingPageURL: String? = nil,
        perks: [String] = [],
        status: PartyStatus = .upcoming,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        analytics: PartyAnalytics? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.hostId = hostId
        self.hostName = hostName
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.ticketTiers = ticketTiers
        self.guestCap = guestCap
        self.currentAttendees = currentAttendees
        self.isPublic = isPublic
        self.tags = tags
        self.flyerImageURL = flyerImageURL
        self.landingPageURL = landingPageURL
        self.perks = perks
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.analytics = analytics
    }
}

/// Party location with detailed address information
struct PartyLocation: Codable, Equatable {
    let name: String // venue name
    let address: String
    let city: String
    let state: String
    let zipCode: String
    let latitude: Double
    let longitude: Double
    let placeId: String?
    
    var fullAddress: String {
        return "\(address), \(city), \(state) \(zipCode)"
    }
}

/// Ticket tier pricing and information
struct TicketTier: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let price: Double
    let description: String
    let maxQuantity: Int
    let currentSold: Int
    let soldCount: Int
    let perks: [String]
    let isAvailable: Bool
    
    init(
        id: String = UUID().uuidString,
        name: String,
        price: Double,
        description: String,
        maxQuantity: Int,
        currentSold: Int = 0,
        soldCount: Int = 0,
        perks: [String] = [],
        isAvailable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.description = description
        self.maxQuantity = maxQuantity
        self.currentSold = currentSold
        self.soldCount = soldCount
        self.perks = perks
        self.isAvailable = isAvailable
    }
}

/// RSVP model for party attendance tracking
struct RSVP: Identifiable, Codable, Equatable {
    let id: String
    let partyId: String
    let userId: String
    let userName: String
    let userEmail: String
    let ticketTierId: String?
    let quantity: Int
    let status: RSVPStatus
    let rsvpDate: Date
    let checkInDate: Date?
    let userData: RSVPUserData
    
    enum RSVPStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case confirmed = "confirmed"
        case checkedIn = "checkedIn"
        case cancelled = "cancelled"
        case noShow = "noShow"
    }
    
    init(
        id: String = UUID().uuidString,
        partyId: String,
        userId: String,
        userName: String,
        userEmail: String,
        ticketTierId: String? = nil,
        quantity: Int = 1,
        status: RSVPStatus = .pending,
        rsvpDate: Date = Date(),
        checkInDate: Date? = nil,
        userData: RSVPUserData
    ) {
        self.id = id
        self.partyId = partyId
        self.userId = userId
        self.userName = userName
        self.userEmail = userEmail
        self.ticketTierId = ticketTierId
        self.quantity = quantity
        self.status = status
        self.rsvpDate = rsvpDate
        self.checkInDate = checkInDate
        self.userData = userData
    }
}

/// Additional user data captured during RSVP
struct RSVPUserData: Codable, Equatable {
    let profileImageURL: String?
    let interests: [String]
    let partyExperience: String? // first-timer, regular, vip, etc.
    let groupSize: Int
    let specialRequests: String?
    let emergencyContact: String?
    let dietaryRestrictions: [String]
    let ageGroup: String
    let socialMediaHandle: String?
}

/// Analytics for party hosts
struct PartyAnalytics: Codable, Equatable {
    let totalViews: Int
    let uniqueViews: Int
    let rsvpRate: Double
    let checkinRate: Double
    let cancelationRate: Double
    let avgGroupSize: Double
    let topAgeGroups: [String]
    let topInterests: [String]
    let peakRSVPTimes: [String]
    let revenueData: PartyRevenue?
    let userDemographics: UserDemographics
    let engagementMetrics: EngagementMetrics
    
    init(
        totalViews: Int = 0,
        uniqueViews: Int = 0,
        rsvpRate: Double = 0.0,
        checkinRate: Double = 0.0,
        cancelationRate: Double = 0.0,
        avgGroupSize: Double = 1.0,
        topAgeGroups: [String] = [],
        topInterests: [String] = [],
        peakRSVPTimes: [String] = [],
        revenueData: PartyRevenue? = nil,
        userDemographics: UserDemographics = UserDemographics(),
        engagementMetrics: EngagementMetrics = EngagementMetrics()
    ) {
        self.totalViews = totalViews
        self.uniqueViews = uniqueViews
        self.rsvpRate = rsvpRate
        self.checkinRate = checkinRate
        self.cancelationRate = cancelationRate
        self.avgGroupSize = avgGroupSize
        self.topAgeGroups = topAgeGroups
        self.topInterests = topInterests
        self.peakRSVPTimes = peakRSVPTimes
        self.revenueData = revenueData
        self.userDemographics = userDemographics
        self.engagementMetrics = engagementMetrics
    }
}

struct PartyRevenue: Codable, Equatable {
    let totalRevenue: Double
    let revenueByTier: [String: Double]
    let averageTicketPrice: Double
    let projectedRevenue: Double
    let commission: Double
}

struct UserDemographics: Codable, Equatable {
    let ageDistribution: [String: Int]
    let genderDistribution: [String: Int]
    let locationDistribution: [String: Int]
    let interestDistribution: [String: Int]
    
    init(
        ageDistribution: [String: Int] = [:],
        genderDistribution: [String: Int] = [:],
        locationDistribution: [String: Int] = [:],
        interestDistribution: [String: Int] = [:]
    ) {
        self.ageDistribution = ageDistribution
        self.genderDistribution = genderDistribution
        self.locationDistribution = locationDistribution
        self.interestDistribution = interestDistribution
    }
}

struct EngagementMetrics: Codable, Equatable {
    let averageViewDuration: Double
    let shareCount: Int
    let saveCount: Int
    let conversionFunnel: [String: Int]
    let dropOffPoints: [String: Double]
    
    init(
        averageViewDuration: Double = 0.0,
        shareCount: Int = 0,
        saveCount: Int = 0,
        conversionFunnel: [String: Int] = [:],
        dropOffPoints: [String: Double] = [:]
    ) {
        self.averageViewDuration = averageViewDuration
        self.shareCount = shareCount
        self.saveCount = saveCount
        self.conversionFunnel = conversionFunnel
        self.dropOffPoints = dropOffPoints
    }
}

/// Party host profile for business users
struct PartyHost: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let businessName: String
    let contactEmail: String
    let phoneNumber: String
    let businessType: String
    let verified: Bool
    let rating: Double
    let totalPartiesHosted: Int
    let totalAttendees: Int
    let averageAttendance: Double
    let joinDate: Date
    let subscription: HostSubscription
    let analytics: HostAnalytics?
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        businessName: String,
        contactEmail: String,
        phoneNumber: String,
        businessType: String,
        verified: Bool = false,
        rating: Double = 0.0,
        totalPartiesHosted: Int = 0,
        totalAttendees: Int = 0,
        averageAttendance: Double = 0.0,
        joinDate: Date = Date(),
        subscription: HostSubscription = HostSubscription(),
        analytics: HostAnalytics? = nil
    ) {
        self.id = id
        self.userId = userId
        self.businessName = businessName
        self.contactEmail = contactEmail
        self.phoneNumber = phoneNumber
        self.businessType = businessType
        self.verified = verified
        self.rating = rating
        self.totalPartiesHosted = totalPartiesHosted
        self.totalAttendees = totalAttendees
        self.averageAttendance = averageAttendance
        self.joinDate = joinDate
        self.subscription = subscription
        self.analytics = analytics
    }
}

struct HostSubscription: Codable, Equatable {
    let plan: HostPlan
    let isActive: Bool
    let startDate: Date
    let endDate: Date?
    let autoRenew: Bool
    
    enum HostPlan: String, Codable, CaseIterable {
        case free = "free"
        case basic = "basic"
        case premium = "premium"
        case enterprise = "enterprise"
    }
    
    init(
        plan: HostPlan = .free,
        isActive: Bool = true,
        startDate: Date = Date(),
        endDate: Date? = nil,
        autoRenew: Bool = false
    ) {
        self.plan = plan
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
        self.autoRenew = autoRenew
    }
}

struct HostAnalytics: Codable, Equatable {
    let monthlyViews: [String: Int]
    let monthlyRSVPs: [String: Int]
    let monthlyRevenue: [String: Double]
    let topPerformingParties: [String]
    let audienceGrowth: [String: Int]
    let repeatAttendeeRate: Double
    
    init(
        monthlyViews: [String: Int] = [:],
        monthlyRSVPs: [String: Int] = [:],
        monthlyRevenue: [String: Double] = [:],
        topPerformingParties: [String] = [],
        audienceGrowth: [String: Int] = [:],
        repeatAttendeeRate: Double = 0.0
    ) {
        self.monthlyViews = monthlyViews
        self.monthlyRSVPs = monthlyRSVPs
        self.monthlyRevenue = monthlyRevenue
        self.topPerformingParties = topPerformingParties
        self.audienceGrowth = audienceGrowth
        self.repeatAttendeeRate = repeatAttendeeRate
    }
}

/// Host statistics model for profile display
struct HostStats: Identifiable, Codable {
    var id = UUID()
    let hostId: String
    let totalParties: Int
    let totalAttendees: Int
    let averageRating: Double
    let averageAttendance: Double
    let memberSince: Date
    let revenue: Double
    let upcomingParties: Int
    let completedParties: Int
        
    init(
        hostId: String,
        totalParties: Int = 0,
        totalAttendees: Int = 0,
        averageRating: Double = 0.0,
        averageAttendance: Double = 0.0,
        memberSince: Date = Date(),
        revenue: Double = 0.0,
        upcomingParties: Int = 0,
        completedParties: Int = 0
    ) {
        self.hostId = hostId
        self.totalParties = totalParties
        self.totalAttendees = totalAttendees
        self.averageRating = averageRating
        self.averageAttendance = averageAttendance
        self.memberSince = memberSince
        self.revenue = revenue
        self.upcomingParties = upcomingParties
        self.completedParties = completedParties
    }
}

/// Party host profile for business users
 
