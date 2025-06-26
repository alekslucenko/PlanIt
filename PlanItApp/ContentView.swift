import SwiftUI
import CoreLocation

enum AppState {
    case initial
    case onboarding 
    case authenticated
}

struct ContentView: View {
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var authService = AuthenticationService()
    @StateObject private var locationManager = LocationManager()
    @State private var appState: AppState = .initial
    @State private var isProcessingOnboardingCompletion = false
    
    var body: some View {
        Group {
            switch appState {
            case .initial:
                InitialWelcomeView(
                    onStartOnboarding: {
                        appState = .onboarding
                    },
                    onExistingUserLogin: {
                        // Show login for existing users
                        Task {
                            // This will be handled by the login view
                        }
                    }
                )
                .environmentObject(authService)
                
            case .onboarding:
                EnhancedOnboardingView()
                    .environmentObject(onboardingManager)
                    .environmentObject(authService)
                    .environmentObject(locationManager)
                
            case .authenticated:
                ModernMainTabView(locationManager: locationManager)
                    .environmentObject(authService)
                    .environmentObject(NotificationManager.shared)
                    .environmentObject(UserFingerprintManager.shared)
            }
        }
        .onAppear {
            FirebaseConfig.configure()
            determineInitialState()
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // Only transition if we're not in the middle of onboarding completion
                if !isProcessingOnboardingCompletion {
                    // Check if we have completed onboarding
                    if onboardingManager.hasCompletedOnboarding {
                        appState = .authenticated
                        initializeUserFingerprint()
                    }
                    // If onboarding not completed but authenticated, stay in onboarding
                    // This handles cases where user signs in but hasn't completed onboarding
                }
            } else if !isAuthenticated && appState == .authenticated {
                // User logged out, return to welcome screen
                appState = .initial
                isProcessingOnboardingCompletion = false
            }
        }
        .onChange(of: onboardingManager.hasCompletedOnboarding) { _, completed in
            if completed && authService.isAuthenticated {
                // Both onboarding and authentication are complete
                print("🎯 ContentView: Onboarding completed, transitioning to main app")
                appState = .authenticated
                initializeUserFingerprint()
                isProcessingOnboardingCompletion = false
            }
        }
    }
    
    private func determineInitialState() {
        print("🎯 ContentView: Determining initial state...")
        print("🎯 ContentView: Onboarding completed: \(onboardingManager.hasCompletedOnboarding)")
        print("🎯 ContentView: User authenticated: \(authService.isAuthenticated)")
        
        // If onboarding has never been completed locally → always start with onboarding (regardless of auth status)
        guard onboardingManager.hasCompletedOnboarding else {
            print("🎯 ContentView: Starting onboarding - not completed")
            appState = .onboarding
            return
        }

        // User completed onboarding previously
        if authService.isAuthenticated {
            print("🎯 ContentView: User is authenticated, going to main app")
            appState = .authenticated
            initializeUserFingerprint()
        } else {
            print("🎯 ContentView: User not authenticated, showing welcome")
            appState = .initial
        }
    }
    
    private func initializeUserFingerprint() {
        // Initialize user fingerprint manager for recommendation engine
        Task {
            await UserFingerprintManager.shared.startListening()
            await UserFingerprintManager.shared.incrementSessionCount()
            print("🧬 User fingerprint tracking initialized")
        }
    }
}

// MARK: - Main Tab View with Real MainScreen.swift Integration
struct MainTabViewWithRealMainScreen: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var authService: AuthenticationService
    @State private var selectedTab: MainTabItem = .home
    @State private var showTabBar = true
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Dynamic themed background
            themeManager.backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.0), value: themeManager.isDarkMode)
            
            // Main content
            TabView(selection: $selectedTab) {
                // Home Tab - Modern MainScreen
                ModernMainScreen(locationManager: locationManager)
                    .tag(MainTabItem.home)
                
                // Friends Tab - REAL FriendsView.swift
                FriendsView()
                    .tag(MainTabItem.friends)
                
                // Favorites Tab
                FavoritesTabView()
                    .tag(MainTabItem.favorites)
                
                // Profile Tab - Enhanced with username/email/signout
                EnhancedProfileView()
                    .environmentObject(authService)
                    .environmentObject(locationManager)
                    .tag(MainTabItem.profile)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Custom Modern Tab Bar
            if showTabBar {
                EnhancedTabBar(selectedTab: $selectedTab, showTabBar: $showTabBar)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showTabBar)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - Tab Items
enum MainTabItem: String, CaseIterable {
    case home = "Home"
    case friends = "Friends"  
    case favorites = "Favorites"
    case profile = "Profile"
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .friends: return "person.2.fill"
        case .favorites: return "heart.fill"
        case .profile: return "person.fill"
        }
    }
    
    var iconNameUnselected: String {
        switch self {
        case .home: return "house"
        case .friends: return "person.2"
        case .favorites: return "heart"
        case .profile: return "person"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .home: return [Color(hex: "#FF6B6B"), Color(hex: "#FF8E88")]
        case .friends: return [Color(hex: "#4ECDC4"), Color(hex: "#44A08D")]
        case .favorites: return [Color(hex: "#FF6B9D"), Color(hex: "#C44569")]
        case .profile: return [Color(hex: "#A8E6CF"), Color(hex: "#88D8A3")]
        }
    }
}

// MARK: - Enhanced Tab Bar
struct EnhancedTabBar: View {
    @Binding var selectedTab: MainTabItem
    @Binding var showTabBar: Bool
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTabItem.allCases, id: \.self) { tab in
                EnhancedTabBarButton(
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

// MARK: - Enhanced Tab Bar Button
struct EnhancedTabBarButton: View {
    let tab: MainTabItem
    let isSelected: Bool
    let action: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: themeManager.isDarkMode ? [
                                        themeManager.neonPink,
                                        themeManager.neonPurple
                                    ] : tab.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(
                                color: themeManager.isDarkMode ? 
                                themeManager.neonPink.opacity(0.6) : 
                                tab.gradientColors.first?.opacity(0.4) ?? .clear,
                                radius: themeManager.isDarkMode ? 12 : 8,
                                x: 0,
                                y: themeManager.isDarkMode ? 6 : 4
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    Image(systemName: isSelected ? tab.iconName : tab.iconNameUnselected)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .white : themeManager.secondaryText)
                        .scaleEffect(isPressed ? 0.85 : 1.0)
                }
                
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(
                        isSelected ? 
                        (themeManager.isDarkMode ? themeManager.neonPink : tab.gradientColors.first ?? .blue) : 
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
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Tab Views Implementation
struct ExploreTabView: View {
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
                
                // Coming soon indicator
                Text("Coming Soon")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [themeManager.accentBlue, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
        }
    }
}

struct FavoritesTabView: View {
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
                                        colors: [Color.pink, Color.red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            } else {
                // Show favorites
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(favoritesManager.favoriteItems), id: \.self) { placeId in
                            Text("Favorite: \(placeId)")
                                .font(.system(size: 16))
                                .themedText(.primary)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                }
            }
        }
    }
}

struct EnhancedProfileView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var xpManager = XPManager()
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingPreferences = false
    @State private var showingLogin = false
    @State private var showingLanguageSelection = false
    @State private var animateProfile = false
    @State private var showingDeveloperJSON = false
    @State private var onboardingJSONContent: String = ""
    @State private var showingDeveloperTools = false
    
    var body: some View {
        ZStack {
            themeManager.backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.0), value: themeManager.isDarkMode)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Profile Header
                    profileHeader
                    
                    // XP Level Bar Section (only show if authenticated)
                    if authService.isAuthenticated {
                        xpLevelSection
                    }
                    
                    // Theme Toggle Section
                    themeToggleSection
                    
                    // Settings Options
                    settingsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
            }
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $showingDeveloperJSON) {
            JSONContentView(jsonContent: onboardingJSONContent)
                .environmentObject(locationManager)
        }
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView()
        }
        .sheet(isPresented: $showingDeveloperTools) {
            DeveloperScreenView()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateProfile = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            // Force view refresh when language changes
            animateProfile = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                animateProfile = true
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 20) {
            if authService.isAuthenticated {
                // Authenticated user profile with username and email
                VStack(spacing: 16) {
                    // Profile Avatar
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
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(authService.currentUser?.email?.prefix(1).uppercased() ?? "U")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .scaleEffect(animateProfile ? 1 : 0.5)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateProfile)
                    
                    // User Information
                    VStack(spacing: 8) {
                        if let username = authService.currentUser?.displayName, !username.isEmpty {
                            Text(username)
                                .font(.system(size: 24, weight: .bold))
                                .themedText(.primary)
                        }
                        
                        if let email = authService.currentUser?.email {
                            Text(email)
                                .font(.system(size: 16, weight: .medium))
                                .themedText(.secondary)
                        }
                    }
                    .opacity(animateProfile ? 1 : 0)
                    .offset(y: animateProfile ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.3), value: animateProfile)
                    
                    // Sign Out Button
                    Button(action: {
                        Task {
                            await authService.signOut()
                        }
                    }) {
                        Text("sign_out".localized)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .padding(.top, 12)
                }
            } else {
                // Not authenticated
                VStack(spacing: 16) {
                    Text("👤")
                        .font(.system(size: 60))
                    
                    Text("profile".localized)
                        .font(.system(size: 32, weight: .bold))
                        .themedText(.primary)
                    
                    Button("sign_in".localized) {
                        showingLogin = true
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [themeManager.accentBlue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
        .sheet(isPresented: $showingLogin) {
            LoginView(
                onboardingData: nil,
                userName: "",
                onAuthComplete: {}
            )
                .environmentObject(authService)
        }
    }
    
    private var themeToggleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("appearance".localized)
                .font(.system(size: 20, weight: .bold))
                .themedText(.primary)
            
            HStack {
                Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 20))
                    .foregroundColor(themeManager.isDarkMode ? themeManager.neonPurple : .orange)
                
                Text(themeManager.isDarkMode ? "dark_mode".localized : "light_mode".localized)
                    .font(.system(size: 16, weight: .medium))
                    .themedText(.primary)
                
                Spacer()
                
                Toggle("", isOn: $themeManager.isDarkMode)
                    .toggleStyle(SwitchToggleStyle(tint: themeManager.accentBlue))
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings".localized)
                .font(.system(size: 20, weight: .bold))
                .themedText(.primary)
            
            VStack(spacing: 12) {
                SettingsRow(
                    icon: "globe",
                    title: "language".localized,
                    subtitle: localizationManager.currentLanguage.displayName,
                    action: { showingLanguageSelection = true }
                )
                
                SettingsRow(
                    icon: "gearshape.fill",
                    title: "advanced_settings".localized,
                    action: { showingPreferences = true }
                )
                
                // Developer JSON data view
                SettingsRow(
                    icon: "chevron.left.slash.chevron.right",
                    title: "Developer JSON",
                    action: {
                        onboardingJSONContent = loadOnboardingJSON()
                        showingDeveloperJSON = true
                    }
                )
                
                // Developer Tools row
                SettingsRow(
                    icon: "hammer.circle.fill",
                    title: "Developer Tools",
                    subtitle: "AI & cache viewer",
                    action: {
                        showingDeveloperTools = true
                    }
                )
                
                SettingsRow(
                    icon: "location.fill",
                    title: "location_services".localized,
                    subtitle: locationManager.selectedLocationName
                )
                
                SettingsRow(
                    icon: "bell.fill",
                    title: "notifications".localized
                )
            }
        }
    }
    
    // MARK: - XP Level Section
    private var xpLevelSection: some View {
        VStack(spacing: 0) {
            XPRingView(xpManager: xpManager)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
        }
    }
    
    // MARK: - Helper to load onboarding JSON
    private func loadOnboardingJSON() -> String {
        let fileName = "onboarding_data.json"
        do {
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("❌ Could not get documents directory")
                return "Error: Could not access documents directory"
            }
            let fileURL = documentsURL.appendingPathComponent(fileName)
            let data = try Data(contentsOf: fileURL)
            return String(data: data, encoding: .utf8) ?? "Error decoding JSON"
        } catch {
            return "Error reading JSON: \(error.localizedDescription)"
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .themedText(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .themedText(.secondary)
                    }
                }
                
                Spacer()
                
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .themedText(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}

// MARK: - Initial Welcome Screen
struct InitialWelcomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showingLogin = false
    let onStartOnboarding: () -> Void
    let onExistingUserLogin: () -> Void
    
    var body: some View {
        ZStack {
            // Animated Background
            PremiumBackgroundView()
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo/Title
                VStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    
                    Text("PlanIt")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Discover amazing places\ntailored just for you")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // New User Button
                    Button(action: onStartOnboarding) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                            Text("Get Started")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "667eea"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    
                    // Existing User Button  
                    Button(action: { showingLogin = true }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 20))
                            Text("I Already Have an Account")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showingLogin) {
            LoginView(
                onboardingData: nil,
                userName: "",
                onAuthComplete: {}
            )
                .environmentObject(authService)
        }
    }
}

#Preview {
    ContentView()
} 