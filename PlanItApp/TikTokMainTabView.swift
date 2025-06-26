import SwiftUI
import CoreLocation

// MARK: - TikTok Style Main Tab View
struct TikTokMainTabView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedTab: TikTokTabItem = .home
    @State private var showTabBar = true
    @State private var lastScrollOffset: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Dynamic themed background
            themeManager.backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.0), value: themeManager.isDarkMode)
            
            // Main content with tab view
            TabView(selection: $selectedTab) {
                // Home Tab - Main Screen
                NavigationView {
                    TikTokMainScreen(locationManager: locationManager)
                        .navigationBarHidden(true)
                }
                .tag(TikTokTabItem.home)
                
                // Explore Tab  
                NavigationView {
                    TikTokExploreView(locationManager: locationManager)
                        .navigationBarHidden(true)
                }
                .tag(TikTokTabItem.explore)
                
                // Favorites Tab
                NavigationView {
                    TikTokFavoritesView()
                        .navigationBarHidden(true)
                }
                .tag(TikTokTabItem.favorites)
                
                // Profile Tab
                NavigationView {
                    TikTokProfileView()
                        .navigationBarHidden(true)
                }
                .tag(TikTokTabItem.profile)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // TikTok-style floating tab bar
            if showTabBar {
                TikTokTabBar(selectedTab: $selectedTab, showTabBar: $showTabBar)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showTabBar)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - TikTok Tab Items
enum TikTokTabItem: String, CaseIterable {
    case home = "Home"
    case explore = "Explore" 
    case favorites = "Favorites"
    case profile = "Profile"
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .explore: return "safari.fill"
        case .favorites: return "heart.fill"
        case .profile: return "person.fill"
        }
    }
    
    var iconNameUnselected: String {
        switch self {
        case .home: return "house"
        case .explore: return "safari"
        case .favorites: return "heart"
        case .profile: return "person"
        }
    }
}

// MARK: - TikTok Style Tab Bar
struct TikTokTabBar: View {
    @Binding var selectedTab: TikTokTabItem
    @Binding var showTabBar: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TikTokTabItem.allCases, id: \.self) { tab in
                TikTokTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            // Modern glassmorphic background with theme support
            RoundedRectangle(cornerRadius: 30)
                .fill(themeManager.isDarkMode ? .ultraThinMaterial : .thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(
                            themeManager.isDarkMode ? 
                            themeManager.neonPurple.opacity(0.3) : 
                            Color.white.opacity(0.4), 
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: themeManager.isDarkMode ? 
                    Color.black.opacity(0.4) : 
                    Color.black.opacity(0.1), 
                    radius: themeManager.isDarkMode ? 20 : 10, 
                    x: 0, 
                    y: themeManager.isDarkMode ? 10 : 5
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - TikTok Tab Button
struct TikTokTabButton: View {
    let tab: TikTokTabItem
    let isSelected: Bool
    let action: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Background indicator with theme colors
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: themeManager.isDarkMode ? [
                                        themeManager.neonPink,
                                        themeManager.neonPurple
                                    ] : [
                                        themeManager.accentBlue,
                                        Color.cyan
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(
                                color: themeManager.isDarkMode ? 
                                themeManager.neonPink.opacity(0.6) : 
                                themeManager.accentBlue.opacity(0.4),
                                radius: themeManager.isDarkMode ? 12 : 8,
                                x: 0,
                                y: themeManager.isDarkMode ? 6 : 4
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Icon
                    Image(systemName: isSelected ? tab.iconName : tab.iconNameUnselected)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .white : themeManager.secondaryText)
                        .scaleEffect(isPressed ? 0.85 : 1.0)
                }
                
                // Label with theme colors
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(
                        isSelected ? 
                        (themeManager.isDarkMode ? themeManager.neonPink : themeManager.accentBlue) : 
                        themeManager.secondaryText
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
        .animation(.easeInOut(duration: 0.6), value: themeManager.isDarkMode)
    }
}

// MARK: - TikTok Main Screen Wrapper
struct TikTokMainScreen: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ModernMainScreen(locationManager: locationManager)
            .themedBackground()
    }
}

// MARK: - TikTok Explore View
struct TikTokExploreView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            themeManager.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Text("🗺️")
                        .font(.system(size: 60))
                    
                    Text("Explore")
                        .font(.system(size: 32, weight: .bold))
                        .themedText(.primary)
                    
                    Text("Discover trending spots\nand hidden gems")
                        .font(.system(size: 16))
                        .themedText(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Coming soon indicator with theme support
                Text("Coming Soon")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: themeManager.isDarkMode ? [
                                        themeManager.neonBlue,
                                        themeManager.neonPurple
                                    ] : [
                                        themeManager.accentBlue,
                                        Color.cyan
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(
                                color: themeManager.isDarkMode ? 
                                themeManager.neonBlue.opacity(0.4) : 
                                themeManager.accentBlue.opacity(0.3),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                    )
            }
        }
    }
}

// MARK: - TikTok Favorites View
struct TikTokFavoritesView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    var body: some View {
        ZStack {
            themeManager.backgroundGradient
                .ignoresSafeArea()
            
            if favoritesManager.favoriteItems.isEmpty {
                // Empty state
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Text("💖")
                            .font(.system(size: 60))
                        
                        Text("Favorites")
                            .font(.system(size: 32, weight: .bold))
                            .themedText(.primary)
                        
                        Text("Your saved places\nand wish list")
                            .font(.system(size: 16))
                            .themedText(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("No favorites yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: themeManager.isDarkMode ? [
                                            themeManager.neonPink,
                                            Color.pink
                                        ] : [
                                            Color.pink,
                                            Color.red
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(
                                    color: Color.pink.opacity(0.4),
                                    radius: 12,
                                    x: 0,
                                    y: 6
                                )
                        )
                }
            } else {
                // Show favorites - use existing FavoritesView
                FavoritesView()
                    .themedBackground()
            }
        }
    }
}

// MARK: - TikTok Profile View with Theme Toggle
struct TikTokProfileView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingPreferences = false
    @State private var animateProfile = false
    
    var body: some View {
        ZStack {
            themeManager.backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.0), value: themeManager.isDarkMode)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Profile Header
                    profileHeader
                    
                    // Theme Toggle Section
                    themeToggleSection
                    
                    // Settings Options
                    settingsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateProfile = true
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 20) {
            // Profile Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: themeManager.isDarkMode ? [
                                themeManager.neonPurple,
                                themeManager.neonPink
                            ] : [
                                themeManager.accentBlue,
                                Color.cyan
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(
                        color: themeManager.isDarkMode ? 
                        themeManager.neonPurple.opacity(0.6) : 
                        themeManager.accentBlue.opacity(0.4),
                        radius: themeManager.isDarkMode ? 25 : 15,
                        x: 0,
                        y: themeManager.isDarkMode ? 12 : 8
                    )
                
                Image(systemName: "person.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(animateProfile ? 1.0 : 0.8)
            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateProfile)
            
            VStack(spacing: 8) {
                Text("Welcome back!")
                    .font(.system(size: 28, weight: .bold))
                    .themedText(.primary)
                
                Text("Customize your PlanIt experience")
                    .font(.system(size: 16))
                    .themedText(.secondary)
            }
            .opacity(animateProfile ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateProfile)
        }
    }
    
    private var themeToggleSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("App Theme")
                    .font(.system(size: 20, weight: .semibold))
                    .themedText(.primary)
                
                Spacer()
            }
            
            // Quick theme toggle
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    themeManager.toggleTheme()
                }
            }) {
                HStack(spacing: 16) {
                    // Theme icon
                    ZStack {
                        Circle()
                            .fill(themeManager.isDarkMode ? themeManager.neonPurple.opacity(0.2) : themeManager.accentBlue.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: themeManager.isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(themeManager.isDarkMode ? themeManager.neonPurple : themeManager.accentBlue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(themeManager.isDarkMode ? "Dark Mode" : "Light Mode")
                            .font(.system(size: 16, weight: .semibold))
                            .themedText(.primary)
                        
                        Text("Tap to switch theme")
                            .font(.system(size: 14))
                            .themedText(.secondary)
                    }
                    
                    Spacer()
                    
                    // Toggle indicator
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeManager.isDarkMode ? themeManager.neonPurple.opacity(0.3) : themeManager.accentBlue.opacity(0.3))
                            .frame(width: 50, height: 28)
                        
                        Circle()
                            .fill(.white)
                            .frame(width: 24, height: 24)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .offset(x: themeManager.isDarkMode ? 11 : -11)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .themedCard()
            }
            .buttonStyle(PlainButtonStyle())
        }
        .opacity(animateProfile ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.6), value: animateProfile)
    }
    
    private var settingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .themedText(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                TikTokSettingsRow(
                    icon: "gear.circle.fill",
                    title: "Advanced Settings",
                    subtitle: "More theme and preference options",
                    iconColor: themeManager.isDarkMode ? themeManager.neonGreen : themeManager.accentGreen,
                    action: { showingPreferences = true }
                )
                
                TikTokSettingsRow(
                    icon: "bell.circle.fill",
                    title: "Notifications",
                    subtitle: "Manage your notifications",
                    iconColor: themeManager.isDarkMode ? themeManager.neonYellow : themeManager.accentOrange,
                    action: {}
                )
                
                TikTokSettingsRow(
                    icon: "location.circle.fill", 
                    title: "Location Services",
                    subtitle: "Control location access",
                    iconColor: themeManager.isDarkMode ? themeManager.neonBlue : themeManager.accentBlue,
                    action: {}
                )
                
                TikTokSettingsRow(
                    icon: "heart.circle.fill",
                    title: "Favorites Sync",
                    subtitle: "Sync across devices",
                    iconColor: themeManager.isDarkMode ? themeManager.neonPink : themeManager.accentPink,
                    action: {}
                )
            }
        }
        .opacity(animateProfile ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.8), value: animateProfile)
    }
}

// MARK: - Settings Row Component
struct TikTokSettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    let action: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .themedText(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .themedText(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .themedText(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .themedCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TikTokMainTabView(locationManager: LocationManager())
} 