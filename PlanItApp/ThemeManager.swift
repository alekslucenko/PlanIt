import SwiftUI
import Combine
import Foundation

// MARK: - Professional Business Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var isDarkMode = true // Default to dark mode for business professional look
    @Published var primaryColor = Color.blue
    @Published var accentColor = Color.green
    
    // MARK: - Professional Business Color Palette
    // Primary brand colors - Business professional dark theme
    var brandPrimary: Color {
        Color(hex: "#1EF0A0") // Bright business green
    }
    
    var brandSecondary: Color {
        Color(hex: "#10B981") // Darker business green
    }
    
    var brandAccent: Color {
        Color(hex: "#FFD700") // Gold accent for highlights
    }
    
    // Dark theme colors (primary interface) - BUSINESS PROFESSIONAL
    var primaryBackground: Color {
        isDarkMode ? Color(hex: "#0F0F0F") : Color(hex: "#FFFFFF") // Almost black for professional look
    }
    
    var secondaryBackground: Color {
        isDarkMode ? Color(hex: "#1C1C1E") : Color(hex: "#F2F2F7") // Dark gray
    }
    
    var tertiaryBackground: Color {
        isDarkMode ? Color(hex: "#2C2C2E") : Color(hex: "#FFFFFF") // Medium gray
    }
    
    var cardBackground: Color {
        isDarkMode ? Color(hex: "#1C1C1E") : Color.white
    }
    
    // ENHANCED TOOLBAR BACKGROUND - BUSINESS STYLE
    var toolbarBackground: Color {
        isDarkMode ? Color(hex: "#000000") : Color(hex: "#FFFFFF")
    }
    
    var tabBarBackground: Color {
        isDarkMode ? Color(hex: "#000000").opacity(0.98) : Color(hex: "#FFFFFF").opacity(0.98)
    }
    
    // HIGH CONTRAST TEXT COLORS FOR BUSINESS
    var primaryText: Color {
        isDarkMode ? Color(hex: "#FFFFFF") : Color(hex: "#000000")
    }
    
    var secondaryText: Color {
        isDarkMode ? Color(hex: "#D1D1D6") : Color(hex: "#3C3C43") // Much better contrast
    }
    
    var tertiaryText: Color {
        isDarkMode ? Color(hex: "#8E8E93") : Color(hex: "#8E8E93") // Subtle but readable
    }
    
    // TAB BAR TEXT COLORS - HIGH CONTRAST
    var tabBarActiveText: Color {
        isDarkMode ? brandAccent : Color(hex: "#000000")
    }
    
    var tabBarInactiveText: Color {
        isDarkMode ? Color(hex: "#8E8E93") : Color(hex: "#8E8E93")
    }
    
    // Professional accent colors for categories
    var travelBlue: Color {
        Color(hex: "#007AFF") // iOS system blue
    }
    
    var travelGreen: Color {
        Color(hex: "#34C759") // iOS system green
    }
    
    var travelOrange: Color {
        Color(hex: "#FF9500") // iOS system orange
    }
    
    var travelPink: Color {
        Color(hex: "#FF2D92") // iOS system pink
    }
    
    var travelPurple: Color {
        Color(hex: "#AF52DE") // iOS system purple
    }
    
    var travelIndigo: Color {
        Color(hex: "#5856D6") // iOS system indigo
    }
    
    var travelYellow: Color {
        Color(hex: "#FFCC00") // iOS system yellow
    }
    
    var travelRed: Color {
        Color(hex: "#FF3B30") // iOS system red
    }
    
    // Legacy compatibility (redirects to professional colors)
    var accentBlue: Color { travelBlue }
    var accentGreen: Color { travelGreen }
    var accentPink: Color { travelPink }
    var accentPurple: Color { travelPurple }
    var accentOrange: Color { travelOrange }
    var accentGold: Color { brandAccent } // Gold neon highlight
    var neonBlue: Color { travelBlue }
    var neonGreen: Color { brandPrimary }
    var neonPink: Color { travelPink }
    var neonPurple: Color { travelPurple }
    var neonYellow: Color { brandAccent }
    
    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }
    
    // MARK: - Mood-based theming (now professional)
    @Published var currentMoodColor: Color = Color(hex: "#1EF0A0")
    @Published var currentWeatherMood: String? = nil
    
    func updateMoodBasedOnTime() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:
            currentMoodColor = brandPrimary // Morning energy
        case 12..<17:
            currentMoodColor = travelBlue // Afternoon focus
        case 17..<21:
            currentMoodColor = brandAccent // Evening relaxation
        default:
            currentMoodColor = travelIndigo // Night calm
        }
        
        currentWeatherMood = hour < 18 ? "bright" : "cozy"
    }
    
    // MARK: - Palette Bridge
    var currentPalette: Palette {
        isDarkMode ? .zenNight : .zenLight
    }
    
    // MARK: - Business Theme Colors (Professional Dark/Light)
    var businessPrimary: Color {
        isDarkMode ? brandPrimary : brandSecondary // Bright green in dark, darker in light
    }
    
    var businessSecondary: Color {
        isDarkMode ? Color(hex: "#1C1C1E") : Color(hex: "#F2F2F7") // Dark gray backgrounds
    }
    
    var businessAccent: Color {
        isDarkMode ? brandAccent : Color(hex: "#B8860B") // Gold accents
    }
    
    var businessBackground: Color {
        isDarkMode ? Color(hex: "#0F0F0F") : Color(hex: "#FFFFFF") // Deep black / pure white
    }
    
    var businessCardBackground: Color {
        isDarkMode ? Color(hex: "#1C1C1E") : Color(hex: "#FFFFFF")
    }
    
    var businessText: Color {
        isDarkMode ? Color(hex: "#FFFFFF") : Color(hex: "#000000")
    }
    
    var businessSecondaryText: Color {
        isDarkMode ? Color(hex: "#D1D1D6") : Color(hex: "#3C3C43")
    }
    
    var businessSuccess: Color {
        Color(hex: "#34C759") // Success Green
    }
    
    var businessDanger: Color {
        Color(hex: "#FF3B30") // Error Red
    }
    
    var businessWarning: Color {
        Color(hex: "#FF9500") // Warning Orange
    }
    
    var businessInfo: Color {
        Color(hex: "#007AFF") // Info Blue
    }
    
    var businessBorder: Color {
        isDarkMode ? Color(hex: "#38383A") : Color(hex: "#C6C6C8")
    }
    
    var businessShadow: Color {
        isDarkMode ? Color.black.opacity(0.6) : Color.black.opacity(0.15)
    }
    
    private init() {
        // Force dark mode for business professional look
        self.isDarkMode = true
        UserDefaults.standard.set(true, forKey: "isDarkMode")
        print("🎨 ThemeManager initialized - Business Dark Mode: \(isDarkMode)")
    }
    
    // MARK: - Professional Dark Gradients
    var backgroundGradient: LinearGradient {
        if isDarkMode {
            return LinearGradient(
                colors: [
                    Color(hex: "#0F0F0F"),
                    Color(hex: "#1C1C1E"),
                    Color(hex: "#0F0F0F")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(hex: "#FFFFFF"),
                    Color(hex: "#F2F2F7"),
                    Color(hex: "#FFFFFF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var cardGradient: LinearGradient {
        if isDarkMode {
            return LinearGradient(
                colors: [
                    Color(hex: "#1C1C1E"),
                    Color(hex: "#2C2C2E").opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white,
                    Color(hex: "#F2F2F7").opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // PROFESSIONAL TAB BAR GRADIENT
    var professionalTabBarGradient: LinearGradient {
        if isDarkMode {
            return LinearGradient(
                colors: [
                    Color(hex: "#000000").opacity(0.98),
                    Color(hex: "#1C1C1E").opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.98),
                    Color(hex: "#F2F2F7").opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // MARK: - Theme Toggle Methods
    func toggleTheme() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isDarkMode.toggle()
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    // MARK: - Category Colors (Professional)
    func colorForCategory(_ category: String) -> Color {
        switch category.lowercased() {
        case "restaurant", "food", "dining":
            return travelOrange
        case "attraction", "tourist", "landmark":
            return travelBlue
        case "accommodation", "hotel", "lodging":
            return travelPurple
        case "entertainment", "nightlife":
            return travelPink
        case "shopping", "retail":
            return travelGreen
        case "transport", "parking":
            return travelIndigo
        case "health", "hospital":
            return travelRed
        case "nature", "park":
            return travelGreen
        case "parties":
            return travelPink
        case "discover", "explore":
            return travelBlue
        case "quests", "missions":
            return travelPurple
        case "friends":
            return travelIndigo
        case "favorites":
            return travelRed
        case "profile":
            return travelGreen
        default:
            return travelBlue
        }
    }
}

// MARK: - Theme-aware ViewModifiers
struct ThemedBackground: ViewModifier {
    @ObservedObject var theme = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .background(theme.backgroundGradient.ignoresSafeArea())
    }
}

struct ThemedCard: ViewModifier {
    @ObservedObject var theme = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.businessBorder, lineWidth: 1)
                    )
            )
            .shadow(
                color: theme.businessShadow,
                radius: theme.isDarkMode ? 12 : 8,
                x: 0,
                y: theme.isDarkMode ? 6 : 4
            )
    }
}

struct ThemedText: ViewModifier {
    let style: TextStyle
    @ObservedObject var theme = ThemeManager.shared
    
    enum TextStyle {
        case primary, secondary, tertiary, accent
    }
    
    func body(content: Content) -> some View {
        let color: Color
        switch style {
        case .primary:
            color = theme.primaryText
        case .secondary:
            color = theme.secondaryText
        case .tertiary:
            color = theme.tertiaryText
        case .accent:
            color = theme.businessPrimary
        }
        
        return content
            .foregroundColor(color)
    }
}

// MARK: - View Extensions
extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }
    
    func themedCard() -> some View {
        modifier(ThemedCard())
    }
    
    func themedText(_ style: ThemedText.TextStyle = .primary) -> some View {
        modifier(ThemedText(style: style))
    }
} 