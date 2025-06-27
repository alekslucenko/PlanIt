import SwiftUI

struct UpdatedProfileView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingPreferences = false
    @State private var showingLogin = false
    @State private var showingLanguageSelection = false
    @State private var animateProfile = false
    @State private var showingDeveloperTools = false
    
    // New settings view states
    @State private var showingNotificationSettings = false
    @State private var showingLocationSettings = false
    @State private var showingDataPrivacySettings = false
    @State private var showingVisibilitySettings = false
    @State private var showingSecuritySettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Enhanced background
                LinearGradient(
                    colors: [
                        Color(hex: "667eea").opacity(0.1),
                        Color(hex: "764ba2").opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Profile Header
                        profileHeader
                        
                        // XP Level Section (if authenticated)
                        if authService.isAuthenticated {
                            xpLevelSection
                        }
                        
                        // Host Mode Switcher Section (if user has host profile)
                        if authService.isAuthenticated {
                            hostModeSwitcherSection
                        }
                        
                        // Theme Toggle Section
                        themeToggleSection
                        
                        // Settings Sections
                        generalSettingsSection
                        privacySettingsSection
                        developerSettingsSection
                        
                        // Account Section
                        if authService.isAuthenticated {
                            accountSection
                        } else {
                            unauthenticatedSection
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $showingLogin) {
            LoginView(
                onboardingData: nil,
                userName: authService.userDisplayName.isEmpty ? "User" : authService.userDisplayName,
                onAuthComplete: { showingLogin = false },
                isForExistingUser: true
            )
            .environmentObject(authService)
        }
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView()
        }
        .sheet(isPresented: $showingDeveloperTools) {
            DeveloperScreenView()
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
        .sheet(isPresented: $showingLocationSettings) {
            LocationSettingsView()
                .environmentObject(locationManager)
        }
        .sheet(isPresented: $showingDataPrivacySettings) {
            DataPrivacySettingsView()
        }
        .sheet(isPresented: $showingVisibilitySettings) {
            VisibilitySettingsView()
        }
        .sheet(isPresented: $showingSecuritySettings) {
            SecuritySettingsView()
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
            // Profile Image
            Group {
                if !authService.userPhotoURL.isEmpty, let url = URL(string: authService.userPhotoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text(getUserInitials())
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
            }
            
            VStack(spacing: 8) {
                Text(authService.userDisplayName.isEmpty ? "welcome".localized : authService.userDisplayName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                // Display username#1234 with copy functionality
                if let appUser = authService.currentAppUser {
                    Button(action: {
                        copyToClipboard(appUser.fullUsername)
                    }) {
                        HStack(spacing: 4) {
                            Text(appUser.fullUsername)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .scaleEffect(animateProfile ? 1.0 : 0.9)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: animateProfile)
                }
                
                if let user = authService.user {
                    Text(user.email ?? "no_email".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Member since
                if let user = authService.user {
                    Text("member_since".localized(with: memberSinceText(from: user.metadata.creationDate ?? Date())))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - XP Level Section
    private var xpLevelSection: some View {
        VStack(spacing: 16) {
            // XP Progress Card
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    // XP Ring
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#00d4ff"), Color(hex: "#a8e6cf")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 6
                            )
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: 0.7) // Example progress
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#00d4ff"), Color(hex: "#a8e6cf")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text("15") // Example level
                                .font(.system(size: 20, weight: .bold))
                                .themedText(.primary)
                            Text("LVL")
                                .font(.system(size: 10, weight: .semibold))
                                .themedText(.secondary)
                        }
                    }
                    
                    // XP Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🌟 Seasoned Explorer")
                            .font(.system(size: 16, weight: .bold))
                            .themedText(.primary)
                        
                        Text("2,450 XP")
                            .font(.system(size: 14, weight: .medium))
                            .themedText(.secondary)
                        
                        Text("550 XP to next level")
                            .font(.system(size: 12, weight: .medium))
                            .themedText(.tertiary)
                    }
                    
                    Spacer()
                }
                
                // Quick Stats
                HStack(spacing: 16) {
                    StatBadge(title: "Places", value: "127", color: .blue)
                    StatBadge(title: "Missions", value: "23", color: .green)
                    StatBadge(title: "Streak", value: "7d", color: .orange)
                }
            }
            .padding(20)
            .themedCard()
        }
        .opacity(animateProfile ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateProfile)
    }
    
    // MARK: - Host Mode Switcher Section
    private var hostModeSwitcherSection: some View {
        HostModeSwitcherCard()
            .opacity(animateProfile ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.6).delay(0.5), value: animateProfile)
    }
    
    private var themeToggleSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("appearance".localized)
                    .font(.system(size: 20, weight: .semibold))
                    .themedText(.primary)
                Spacer()
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    themeManager.isDarkMode.toggle()
                }
            }) {
                HStack {
                    Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(themeManager.isDarkMode ? themeManager.neonYellow : .orange)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(themeManager.isDarkMode ? "dark_mode".localized : "light_mode".localized)
                            .font(.system(size: 16, weight: .semibold))
                            .themedText(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Tap to switch theme")
                            .font(.system(size: 14))
                            .themedText(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Spacer()
                    
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
    
    // MARK: - General Settings Section
    private var generalSettingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("general_settings".localized)
                    .font(.system(size: 20, weight: .semibold))
                    .themedText(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ProfileSettingsRow(
                    icon: "globe",
                    title: "language".localized,
                    subtitle: localizationManager.currentLanguage.displayName,
                    iconColor: themeManager.isDarkMode ? themeManager.neonPurple : themeManager.accentPurple,
                    action: { showingLanguageSelection = true }
                )
                
                ProfileSettingsRow(
                    icon: "bell.circle.fill",
                    title: "notifications".localized,
                    subtitle: "notifications_description".localized,
                    iconColor: themeManager.isDarkMode ? themeManager.neonYellow : themeManager.accentOrange,
                    action: { showingNotificationSettings = true }
                )
                
                ProfileSettingsRow(
                    icon: "location.circle.fill",
                    title: "location_services".localized,
                    subtitle: locationPermissionSubtitle,
                    iconColor: locationPermissionColor,
                    action: { showingLocationSettings = true }
                )
                
                ProfileSettingsRow(
                    icon: "gear.circle.fill",
                    title: "advanced_settings".localized,
                    subtitle: "advanced_settings_description".localized,
                    iconColor: themeManager.isDarkMode ? themeManager.neonGreen : themeManager.accentGreen,
                    action: { showingPreferences = true }
                )
            }
        }
        .opacity(animateProfile ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.6), value: animateProfile)
    }
    
    // MARK: - Privacy Settings Section
    private var privacySettingsSection: some View {
        VStack(spacing: 12) {
            ProfileSettingsRow(
                icon: "shield.fill",
                title: "Data Privacy",
                subtitle: "Manage your data and privacy preferences",
                iconColor: .blue,
                action: { showingDataPrivacySettings = true }
            )
            
            ProfileSettingsRow(
                icon: "eye.slash.fill",
                title: "Profile Visibility",
                subtitle: "Control who can see your profile",
                iconColor: .purple,
                action: { showingVisibilitySettings = true }
            )
            
            ProfileSettingsRow(
                icon: "lock.fill",
                title: "Security & Privacy",
                subtitle: "Account security and privacy settings",
                iconColor: .red,
                action: { showingSecuritySettings = true }
            )
        }
        .opacity(animateProfile ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.8), value: animateProfile)
    }
    
    // MARK: - Developer Settings Section
    private var developerSettingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("developer_tools".localized)
                    .font(.system(size: 20, weight: .semibold))
                    .themedText(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ProfileSettingsRow(
                    icon: "chevron.left.slash.chevron.right",
                    title: "AI Backend Insights",
                    subtitle: "View Gemini fingerprint & logs",
                    iconColor: themeManager.isDarkMode ? themeManager.neonBlue : themeManager.accentBlue,
                    action: { showingDeveloperTools = true }
                )
                
                ProfileSettingsRow(
                    icon: "brain.head.profile",
                    title: "AI Training Data",
                    subtitle: "View your recommendation training data",
                    iconColor: .orange,
                    action: {}
                )
                
                ProfileSettingsRow(
                    icon: "chart.bar.xaxis",
                    title: "Usage Analytics",
                    subtitle: "View app usage and performance data",
                    iconColor: .teal,
                    action: {}
                )
            }
        }
        .opacity(animateProfile ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(1.0), value: animateProfile)
    }
    
    private var accountSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("account".localized)
                    .font(.system(size: 20, weight: .semibold))
                    .themedText(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ProfileSettingsRow(
                    icon: "person.crop.circle.fill",
                    title: "account_info".localized,
                    subtitle: authService.user?.email ?? "no_email".localized,
                    iconColor: themeManager.isDarkMode ? themeManager.neonBlue : themeManager.accentBlue,
                    action: {}
                )
                
                ProfileSettingsRow(
                    icon: "icloud.fill",
                    title: "sync_status".localized,
                    subtitle: "data_synced_to_cloud".localized,
                    iconColor: themeManager.isDarkMode ? themeManager.neonGreen : themeManager.accentGreen,
                    action: {}
                )
                
                ProfileSettingsRow(
                    icon: "rectangle.portrait.and.arrow.right.fill",
                    title: "sign_out".localized,
                    subtitle: "sign_out_description".localized,
                    iconColor: themeManager.isDarkMode ? themeManager.neonPink : Color.red,
                    action: {
                        Task {
                            await authService.signOut()
                        }
                    }
                )
            }
        }
        .opacity(animateProfile ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.8), value: animateProfile)
    }
    
    private var unauthenticatedSection: some View {
        VStack(spacing: 24) {
            Text("you_are_not_signed_in".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)

            Button(action: {
                showingLogin = true
            }) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 20))
                    Text("sign_in_or_create_account".localized)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(28)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
        }
        .padding()
    }
    
    private func memberSinceText(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
    
    private var locationPermissionSubtitle: String {
        switch locationManager.authorizationStatus {
        case .authorized, .authorizedAlways, .authorizedWhenInUse:
            return "location_access_granted".localized
        case .denied:
            return "location_access_denied".localized
        case .notDetermined:
            return "tap_to_enable_location".localized
        case .restricted:
            return "location_access_restricted".localized
        @unknown default:
            return "unknown_location_status".localized
        }
    }
    
    private var locationPermissionColor: Color {
        switch locationManager.authorizationStatus {
        case .authorized, .authorizedAlways, .authorizedWhenInUse:
            return themeManager.isDarkMode ? themeManager.neonGreen : themeManager.accentGreen
        case .denied, .restricted:
            return themeManager.isDarkMode ? themeManager.neonPink : Color.red
        case .notDetermined:
            return themeManager.isDarkMode ? themeManager.neonBlue : themeManager.accentBlue
        @unknown default:
            return themeManager.isDarkMode ? themeManager.neonYellow : themeManager.accentOrange
        }
    }
    
    private func getUserInitials() -> String {
        let name = authService.userDisplayName
        if name.isEmpty { return "?" }
        
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else {
            return String(name.prefix(2))
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        print("📋 " + "copied_to_clipboard".localized + ": \(text)")
    }
}

// MARK: - Stat Badge Component
struct StatBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    UpdatedProfileView()
        .environmentObject(AuthenticationService.shared)
        .environmentObject(LocationManager.shared)
}

// MARK: - Host Mode Switcher Card Component
struct HostModeSwitcherCard: View {
    @StateObject private var partyManager = PartyManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var currentViewMode: ViewMode = .normalApp
    @State private var showingBusinessView = false
    @State private var isAnimating = false
    
    enum ViewMode: String, CaseIterable {
        case normalApp = "Normal App"
        case businessView = "Business View"
        
        var icon: String {
            switch self {
            case .normalApp: return "person.fill"
            case .businessView: return "building.2.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .normalApp: return .blue
            case .businessView: return .orange
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("App Mode")
                    .font(.system(size: 20, weight: .semibold))
                    .themedText(.primary)
                
                if partyManager.hostProfile != nil {
                    Text("Switch between user and business experiences")
                        .font(.system(size: 14, weight: .medium))
                        .themedText(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Enable host mode to access business features")
                        .font(.system(size: 14, weight: .medium))
                        .themedText(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if partyManager.hostProfile != nil {
                // Mode Switcher (only show if user is a host)
                modeSwitcherButtons
                
                // Business View Button
                if currentViewMode == .businessView {
                    businessViewButton
                }
            } else {
                // Enable Host Mode Button
                enableHostModeButton
            }
        }
        .padding(20)
        .themedCard()
        .onAppear {
            // Initialize current view mode based on PartyManager state
            currentViewMode = partyManager.isHostMode ? .businessView : .normalApp
        }
        .onReceive(partyManager.$isHostMode) { isHostMode in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentViewMode = isHostMode ? .businessView : .normalApp
            }
        }
    }
    
    private var modeSwitcherButtons: some View {
        HStack(spacing: 16) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    switchToMode(mode)
                }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    currentViewMode == mode ?
                                    mode.color.opacity(0.2) :
                                    themeManager.cardBackground
                                )
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            currentViewMode == mode ?
                                            mode.color :
                                            themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1),
                                            lineWidth: 2
                                        )
                                )
                            
                            // Neon glow for selected mode
                            if currentViewMode == mode {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                mode.color.opacity(0.6),
                                                mode.color.opacity(0.3),
                                                mode.color.opacity(0.1)
                                            ],
                                            center: .center,
                                            startRadius: 5,
                                            endRadius: 30
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                    .blur(radius: 3)
                            }
                            
                            Image(systemName: mode.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(
                                    currentViewMode == mode ?
                                    mode.color :
                                    themeManager.secondaryText
                                )
                        }
                        
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(
                                currentViewMode == mode ?
                                mode.color :
                                themeManager.secondaryText
                            )
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isAnimating && currentViewMode == mode ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentViewMode)
            }
        }
    }
    
    private var businessViewButton: some View {
        Button(action: {
            showingBusinessView = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Open Business Dashboard")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [themeManager.accentGold, themeManager.accentGold.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(
                color: themeManager.accentGold.opacity(0.4),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingBusinessView) {
            HostAnalyticsView()
        }
    }
    
    private var enableHostModeButton: some View {
        NavigationLink(destination: HostModeSetupView()) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Enable Host Mode")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [themeManager.accentBlue, themeManager.accentBlue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(
                color: themeManager.accentBlue.opacity(0.4),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func switchToMode(_ mode: ViewMode) {
        guard currentViewMode != mode else { return }
        
        isAnimating = true
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentViewMode = mode
        }
        
        // Trigger app mode change through PartyManager
        Task {
            switch mode {
            case .normalApp:
                // Switch to normal app without disabling host profile
                await MainActor.run {
                    // Force UI to normal mode while keeping host profile
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ForceAppRefresh"),
                        object: nil,
                        userInfo: ["hostMode": false, "keepProfile": true]
                    )
                }
            case .businessView:
                // Switch to business view
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ForceAppRefresh"),
                        object: nil,
                        userInfo: ["hostMode": true, "keepProfile": true]
                    )
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
    }
} 