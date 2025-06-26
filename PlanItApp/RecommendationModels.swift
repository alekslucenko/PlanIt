import Foundation
import CoreLocation
import FirebaseFirestore

// MARK: - Time of Day
enum TimeOfDay: String, Codable, CaseIterable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
    
    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }
}

// MARK: - Day of Week
enum DayOfWeek: String, Codable, CaseIterable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    
    static var current: DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: Date())
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }
}

// MARK: - Accessibility Needs
struct AccessibilityNeeds: Codable {
    let wheelchairAccessible: Bool
    let hearingImpaired: Bool
    let visuallyImpaired: Bool
}

// MARK: - User Activity
struct UserActivity: Codable {
    let type: ActivityType
    let placeId: String
    let timestamp: Date
    let duration: TimeInterval?
}

// MARK: - Activity Type
enum ActivityType: String, Codable {
    case visit, like, dislike, share, review, bookmark
}

// MARK: - Recommendation Request
struct RecommendationRequest {
    let location: CLLocation
    let radius: Double
    let maxResults: Int
    let categories: [PlaceCategory]?
    let priceRange: PriceRange?
    let userPreferences: UserPreferences?
}

// MARK: - Recommendation Pipeline Models
struct RecommendationQuery: Codable, Identifiable, Hashable {
    var id: String { category + query }
    let category: String  // "restaurants", etc.
    let query: String     // free-text search string
    let vibeTag: String   // comma-separated vibes
}

struct RankedPlace: Identifiable, Hashable {
    let id: String  // Google placeId
    let place: GooglePlace
    let relevanceScore: Double
    let groupTitle: String

    static func == (lhs: RankedPlace, rhs: RankedPlace) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 