import SwiftUI

enum MetricType: String, CaseIterable, Codable {
    case revenue
    case customers
    case events
    case attendees
    case conversion
    case clicks

    // MARK: - Presentation Helpers
    var title: String {
        switch self {
        case .revenue: return "Total Revenue"
        case .customers: return "New Customers"
        case .events: return "Active Events"
        case .attendees: return "Total Attendees"
        case .conversion: return "Conversion Rate"
        case .clicks: return "Event Clicks"
        }
    }

    var subtitle: String {
        switch self {
        case .revenue: return "from ticket sales"
        case .customers: return "unique buyers"
        case .events: return "happening this month"
        case .attendees: return "confirmed RSVPs"
        case .conversion: return "views to purchases"
        case .clicks: return "total interactions"
        }
    }

    /// The SF Symbol name representing the metric (alias for compatibility)
    var iconName: String {
        switch self {
        case .revenue: return "dollarsign.circle.fill"
        case .customers: return "person.3.fill"
        case .events: return "calendar.circle.fill"
        case .attendees: return "person.2.circle.fill"
        case .conversion: return "arrow.up.right.circle.fill"
        case .clicks: return "hand.tap.fill"
        }
    }

    /// Alias used in some files (kept for backward-compatibility)
    var icon: String { iconName }

    /// Primary color associated with the metric
    var color: Color {
        switch self {
        case .revenue: return Color(red: 34/255, green: 197/255, blue: 94/255) // emerald
        case .customers: return Color(red: 59/255, green: 130/255, blue: 246/255) // blue
        case .events: return Color(red: 139/255, green: 92/255, blue: 246/255) // purple
        case .attendees: return Color(red: 251/255, green: 146/255, blue: 60/255) // orange
        case .conversion: return Color(red: 244/255, green: 114/255, blue: 182/255) // pink
        case .clicks: return Color(red: 34/255, green: 211/255, blue: 238/255) // cyan
        }
    }

    /// Alias for `color` maintained to satisfy earlier references
    var iconColor: Color { color }

    /// Extra descriptive blurb shown in some cards
    var extraInfo: String {
        switch self {
        case .revenue: return "💰 +15% vs last week"
        case .customers: return "👥 +32 this week"
        case .events: return "🎉 3 sold out"
        case .attendees: return "🎊 92% attendance rate"
        case .conversion: return "📈 +5.2% improvement"
        case .clicks: return "🖱️ 2.1k unique visitors"
        }
    }
}

/// A small wrapper containing the presentation-ready, already-formatted metric values that the UI renders.
struct MetricData: Equatable {
    let value: String
    let trend: String
    let isLoading: Bool
    let hasError: Bool
    let hasInsufficientData: Bool

    init(value: String, trend: String, isLoading: Bool, hasError: Bool, hasInsufficientData: Bool = false) {
        self.value = value
        self.trend = trend
        self.isLoading = isLoading
        self.hasError = hasError
        self.hasInsufficientData = hasInsufficientData
    }

    /// Convenience placeholder while loading network data
    static let placeholder = MetricData(value: "--", trend: "Loading…", isLoading: true, hasError: false)
} 