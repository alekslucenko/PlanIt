import SwiftUI
import Combine
import Foundation

// MARK: - Professional Travel App Theme Manager
// Color hex extension is now in AppModels.swift to avoid duplication

// MARK: - Professional Travel App Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var isDarkMode = true // Default to dark mode for professional look
    @Published var primaryColor = Color.blue
    @Published var accentColor = Color.green
    
    // MARK: - Professional Travel App Color Palette
    // Primary brand colors - inspired by Airbnb, Booking.com, Instagram
    var brandPrimary: Color {
        Color(hex: "#FF5A5F") // Travel red-coral
    }
    
    var brandSecondary: Color {
        Color(hex: "#00A699") // Travel teal
    }
    
    var brandAccent: Color {
        Color(hex: "#FC642D") // Travel orange
    }
    
    // Dark theme colors (primary interface) - IMPROVED CONTRAST
    var primaryBackground: Color {
        isDarkMode ? Color(hex: "#000000") : Color(hex: "#FFFFFF") // Pure black/white for better contrast
    }
    
    var secondaryBackground: Color {
        isDarkMode ? Color(hex: "#1A1A1A") : Color(hex: "#F8F9FA") // Better contrast
    }
    
    var tertiaryBackground: Color {
        isDarkMode ? Color(hex: "#2D2D2D") : Color(hex: "#FFFFFF") // Improved contrast
    }
    
    var cardBackground: Color {
        isDarkMode ? Color(hex: "#1A1A1A") : Color.white
    }
    
    // ENHANCED TOOLBAR BACKGROUND - MAJOR FIX
    var toolbarBackground: Color {
        isDarkMode ? Color(hex: "#0D0D0D") : Color(hex: "#FFFFFF")
    }
    
    var tabBarBackground: Color {
        isDarkMode ? Color(hex: "#0D0D0D").opacity(0.95) : Color(hex: "#FFFFFF").opacity(0.95)
    }
    
    // IMPROVED TEXT COLORS FOR BETTER CONTRAST
    var primaryText: Color {
        isDarkMode ? Color(hex: "#FFFFFF") : Color(hex: "#000000")
    }
    
    var secondaryText: Color {
        isDarkMode ? Color(hex: "#B0B0B0") : Color(hex: "#666666") // Better contrast
    }
    
    var tertiaryText: Color {
        isDarkMode ? Color(hex: "#808080") : Color(hex: "#999999") // Improved readability
    }
    
    // TAB BAR TEXT COLORS - MAJOR FIX
    var tabBarActiveText: Color {
        isDarkMode ? Color(hex: "#FFFFFF") : Color(hex: "#000000")
    }
    
    var tabBarInactiveText: Color {
        isDarkMode ? Color(hex: "#808080") : Color(hex: "#666666")
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
    var accentGold: Color { travelYellow }
    var neonBlue: Color { travelBlue }
    var neonGreen: Color { travelGreen }
    var neonPink: Color { travelPink }
    var neonPurple: Color { travelPurple }
    var neonYellow: Color { travelYellow }
    
    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }
    
    // MARK: - Mood-based theming (now professional)
    @Published var currentMoodColor: Color = Color(hex: "#007AFF")
    @Published var currentWeatherMood: String? = nil
    
    func updateMoodBasedOnTime() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:
            currentMoodColor = travelOrange // Morning energy
        case 12..<17:
            currentMoodColor = travelBlue // Afternoon focus
        case 17..<21:
            currentMoodColor = travelPurple // Evening relaxation
        default:
            currentMoodColor = travelIndigo // Night calm
        }
        
        currentWeatherMood = hour < 18 ? "bright" : "cozy"
    }
    
    // MARK: - Palette Bridge
    var currentPalette: Palette {
        isDarkMode ? .zenNight : .zenLight
    }
    
    // MARK: - Business Theme Colors (Green/Black/White Money Vibe)
    var businessPrimary: Color {
        isDarkMode ? Color(red: 0.12, green: 0.94, blue: 0.57) : Color(red: 0.06, green: 0.67, blue: 0.39) // Bright/Dark Green
    }
    
    var businessSecondary: Color {
        isDarkMode ? Color(red: 0.09, green: 0.09, blue: 0.09) : Color(red: 0.05, green: 0.05, blue: 0.05) // Near Black
    }
    
    var businessAccent: Color {
        isDarkMode ? Color(red: 0.98, green: 0.98, blue: 0.98) : Color.white // Pure White
    }
    
    var businessBackground: Color {
        isDarkMode ? Color(red: 0.08, green: 0.08, blue: 0.08) : Color(red: 0.98, green: 0.98, blue: 0.98) // Dark/Light Background
    }
    
    var businessCardBackground: Color {
        isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color.white
    }
    
    var businessText: Color {
        isDarkMode ? Color(red: 0.95, green: 0.95, blue: 0.95) : Color(red: 0.1, green: 0.1, blue: 0.1)
    }
    
    var businessSecondaryText: Color {
        isDarkMode ? Color(red: 0.7, green: 0.7, blue: 0.7) : Color(red: 0.5, green: 0.5, blue: 0.5)
    }
    
    var businessSuccess: Color {
        Color(red: 0.16, green: 0.8, blue: 0.33) // Success Green
    }
    
    var businessDanger: Color {
        Color(red: 0.9, green: 0.27, blue: 0.27) // Error Red
    }
    
    var businessWarning: Color {
        Color(red: 1.0, green: 0.73, blue: 0.0) // Warning Orange
    }
    
    var businessInfo: Color {
        Color(red: 0.2, green: 0.6, blue: 1.0) // Info Blue
    }
    
    var businessBorder: Color {
        isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color(red: 0.9, green: 0.9, blue: 0.9)
    }
    
    var businessShadow: Color {
        isDarkMode ? Color.black.opacity(0.5) : Color.black.opacity(0.1)
    }
    
    private init() {
        // Default to dark mode for professional travel app look
        if UserDefaults.standard.object(forKey: "isDarkMode") == nil {
            self.isDarkMode = true
            UserDefaults.standard.set(true, forKey: "isDarkMode")
            print("🎨 First time launch - setting professional dark mode")
        } else {
            self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        }
        print("🎨 ThemeManager initialized - Professional Mode: \(isDarkMode ? "Dark" : "Light")")
    }
    
    // MARK: - IMPROVED Professional Gradients
    var backgroundGradient: LinearGradient {
        if isDarkMode {
            return LinearGradient(
                colors: [
                    Color(hex: "#000000"),
                    Color(hex: "#1A1A1A"),
                    Color(hex: "#000000")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(hex: "#FFFFFF"),
                    Color(hex: "#F8F9FA"),
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
                    Color(hex: "#1A1A1A"),
                    Color(hex: "#2D2D2D").opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white,
                    Color(hex: "#F8F9FA").opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // ENHANCED TOOLBAR GRADIENT - MAJOR FIX
    var professionalTabBarGradient: LinearGradient {
        if isDarkMode {
            return LinearGradient(
                colors: [
                    Color(hex: "#0D0D0D").opacity(0.98),
                    Color(hex: "#1A1A1A").opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.98),
                    Color(hex: "#F8F9FA").opacity(0.95)
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
                            .stroke(theme.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
                    )
            )
            .shadow(
                color: theme.isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.1),
                radius: theme.isDarkMode ? 8 : 4,
                x: 0,
                y: theme.isDarkMode ? 4 : 2
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
            color = theme.travelBlue
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