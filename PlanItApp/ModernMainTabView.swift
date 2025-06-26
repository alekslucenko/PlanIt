import SwiftUI
import CoreLocation

// MARK: - Professional Main Tab View
struct ModernMainTabView: View, Equatable {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var missionManager = MissionManager()
    @StateObject private var xpManager = XPManager()
    @StateObject private var partyManager = PartyManager.shared
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var selectedTab: TabItem = .explore
    @State private var selectedHostTab: HostTabItem = .dashboard
    @State private var showTabBar = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var refreshID = UUID()
    @State private var showingProfile = false
    
    // Performance optimization
    @State private var isTransitioning = false
    
    static func == (lhs: ModernMainTabView, rhs: ModernMainTabView) -> Bool {
        // Compare only the essential properties for performance
        return lhs.selectedTab == rhs.selectedTab &&
               lhs.selectedHostTab == rhs.selectedHostTab &&
               lhs.partyManager.isHostMode == rhs.partyManager.isHostMode
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic themed background
                themeManager.backgroundGradient
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.0), value: themeManager.isDarkMode)
                
                // CONDITIONAL CONTENT BASED ON HOST MODE
                if partyManager.isHostMode {
                    hostModeContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    regularUserContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
                
                // Floating notification overlay
                if notificationManager.showInAppNotification,
                   let notification = notificationManager.currentInAppNotification {
                    VStack {
                        InAppNotificationView(
                            notification: notification,
                            onTap: { handleNotificationTap(notification) },
                            onDismiss: { notificationManager.hideInAppNotification() }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: notificationManager.showInAppNotification)
                        
                        Spacer()
                    }
                    .zIndex(1000)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingProfile = true
                    }) {
                        HStack(spacing: 8) {
                            if !authService.userPhotoURL.isEmpty, let url = URL(string: authService.userPhotoURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(themeManager.isDarkMode ? themeManager.neonPurple : themeManager.accentBlue)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                        )
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            partyManager.isHostMode ? themeManager.accentGold : themeManager.accentBlue,
                                            lineWidth: 2
                                        )
                                )
                            } else {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: partyManager.isHostMode ? 
                                            [themeManager.accentGold, themeManager.accentGold.opacity(0.8)] :
                                            [themeManager.isDarkMode ? themeManager.neonPurple : themeManager.accentBlue, 
                                             themeManager.isDarkMode ? themeManager.neonPink : themeManager.accentBlue.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(authService.userDisplayName.isEmpty ? "U" : String(authService.userDisplayName.prefix(1)).uppercased())
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .shadow(
                                        color: partyManager.isHostMode ? 
                                        themeManager.accentGold.opacity(0.4) : 
                                        themeManager.isDarkMode ? themeManager.neonPurple.opacity(0.4) : themeManager.accentBlue.opacity(0.4),
                                        radius: 8,
                                        x: 0,
                                        y: 4
                                    )
                            }
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: partyManager.isHostMode)
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileViewWrapper()
                    .environmentObject(authService)
                    .environmentObject(locationManager)
                    .environmentObject(partyManager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(themeManager.colorScheme)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            print("🔄 ModernMainTabView appeared - checking host mode")
            Task {
                await partyManager.checkHostMode()
            }
        }
        .onReceive(partyManager.$isHostMode) { isHost in
            handleHostModeChange(isHost)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HostModeChanged"))) { notification in
            if let isHost = notification.object as? Bool {
                print("🔄 Received HostModeChanged notification: \(isHost)")
                handleHostModeChange(isHost)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceAppRefresh"))) { notification in
            // Force complete app refresh when host mode changes
            print("🔄 Received ForceAppRefresh notification")
            Task {
                // Handle mode switching with profile preservation
                if let userInfo = notification.userInfo,
                   let hostMode = userInfo["hostMode"] as? Bool,
                   let keepProfile = userInfo["keepProfile"] as? Bool,
                   keepProfile {
                    // Switch mode without affecting host profile
                    if hostMode {
                        await partyManager.switchToBusinessMode()
                    } else {
                        await partyManager.switchToNormalMode()
                    }
                } else {
                    // Normal host mode check
                    await partyManager.checkHostMode()
                }
                
                await MainActor.run {
                    refreshID = UUID()
                    
                    if let userInfo = notification.userInfo,
                       let hostMode = userInfo["hostMode"] as? Bool {
                        print("🔄 Force refresh with host mode: \(hostMode)")
                        handleHostModeChange(hostMode)
                    }
                    
                    print("🔄 Complete app refresh triggered by host mode change")
                }
            }
        }
        .performanceOptimized(identifier: "MainTabView")
    }
    
    // MARK: - Host Mode Content
    
    private var hostModeContent: some View {
        VStack(spacing: 0) {
            // HOST MODE NAVIGATION
            TabView(selection: $selectedHostTab) {
                // Host Dashboard
                HostAnalyticsView()
                    .tag(HostTabItem.dashboard)
                
                // Business Analytics
                HostAnalyticsView()
                    .tag(HostTabItem.analytics)
                
                // Party Management
                HostPartiesView()
                    .tag(HostTabItem.parties)
                
                // Celebrity Booking
                CelebrityBookingView()
                    .tag(HostTabItem.celebrity)
                
                // Security Booking
                SecurityBookingView()
                    .tag(HostTabItem.security)
                
                // Concierge Services
                ConciergeServicesView()
                    .tag(HostTabItem.concierge)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .id("host_\(selectedHostTab.rawValue)_\(refreshID)")
            
            // Host Tab Bar with Neon Glow
            if showTabBar {
                HostTabBar(selectedTab: $selectedHostTab, showTabBar: $showTabBar)
                    .animation(performanceService.getOptimizedSpringAnimation(), value: showTabBar)
            }
        }
    }
    
    // MARK: - Regular User Content
    
    private var regularUserContent: some View {
        VStack(spacing: 0) {
            // REGULAR USER NAVIGATION - REMOVED PROFILE TAB
            TabView(selection: $selectedTab) {
                // Discover Tab - Enhanced Main Screen
                ModernMainScreen(locationManager: locationManager)
                    .tag(TabItem.explore)
                
                // Parties Tab - PROPERLY FIXED NAVIGATION
                PartiesView()
                    .onAppear {
                        print("🎉 PartiesView appeared via navigation")
                    }
                    .tag(TabItem.parties)
                
                // Quests Tab
                MissionsView(missionManager: missionManager, xpManager: xpManager)
                    .tag(TabItem.missions)
                
                // Friends Tab
                ModernFriendsView()
                    .tag(TabItem.friends)
                
                // Favorites Tab - Comprehensive FavoritesView
                ModernFavoritesView()
                    .tag(TabItem.favorites)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .id("userTab_\(selectedTab.rawValue)_\(refreshID)")
            .animation(performanceService.shouldReduceAnimations() ? .none : .easeInOut(duration: 0.2), value: selectedTab)
            .onAppear {
                print("🔄 Regular user content appeared with selected tab: \(selectedTab.rawValue)")
            }
            .onChange(of: selectedTab) { _, newTab in
                print("🔄 Tab changed to: \(newTab.rawValue)")
                if newTab == .parties {
                    print("🎉 Navigating to parties view!")
                    // Force refresh parties data when navigating to parties
                    Task {
                        await partyManager.checkHostMode()
                    }
                }
            }
            
            // Futuristic Tab Bar with Neon Glow (without profile)
            if showTabBar {
                FuturisticTabBarWithoutProfile(selectedTab: $selectedTab, showTabBar: $showTabBar)
                    .animation(performanceService.getOptimizedSpringAnimation(), value: showTabBar)
            }
        }
    }
    
    // MARK: - ENHANCED Host Mode Change Handler
    
    private func handleHostModeChange(_ isHost: Bool) {
        guard !isTransitioning else { 
            print("⚠️ Host mode change ignored - transition in progress")
            return 
        }
        
        isTransitioning = true
        
        print("🔄 Host mode changed to: \(isHost)")
        
        // Use performance-optimized animation with immediate UI update
        withAnimation(performanceService.getOptimizedSpringAnimation()) {
            if isHost {
                selectedHostTab = .dashboard
                print("✅ Switched to host mode - Dashboard tab selected")
            } else {
                selectedTab = .explore
                print("✅ Switched to user mode - Explore tab selected")
            }
            
            // Force UI refresh with new ID
            refreshID = UUID()
        }
        
        // IMMEDIATE state update without waiting for animation
        DispatchQueue.main.async {
            // Additional refresh to ensure UI updates
            self.refreshID = UUID()
        }
        
        // Reset transition flag after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + performanceService.getOptimizedAnimationDuration()) {
            self.isTransitioning = false
            print("✅ Host mode transition completed")
        }
    }
    
    // MARK: - Notification Handler
    
    private func handleNotificationTap(_ notification: AppNotification) {
        switch notification.type {
        case "party_invite":
            // Navigate to parties tab
            if !partyManager.isHostMode {
                selectedTab = .parties
            }
        case "friend_request":
            // Navigate to friends tab
            if !partyManager.isHostMode {
                selectedTab = .friends
            }
        case "mission_complete":
            // Navigate to missions tab
            if !partyManager.isHostMode {
                selectedTab = .missions
            }
        default:
            break
        }
        
        notificationManager.hideInAppNotification()
    }
}

// MARK: - Professional Placeholder Views (if needed)
struct ProfessionalMissionsWrapper: View {
    let missionManager: MissionManager
    let xpManager: XPManager
    
    var body: some View {
        // Use existing MissionsView or create a wrapper if needed
        MissionsView(missionManager: missionManager, xpManager: xpManager)
    }
}

struct ProfessionalFriendsWrapper: View {
    var body: some View {
        // Use existing FriendsView
        FriendsView()
    }
}

// MARK: - Scroll Offset Tracking (Enhanced)
extension View {
    func onScrollOffsetChanged(_ action: @escaping (CGFloat) -> Void) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        action(geometry.frame(in: .global).minY)
                    }
                    .onChange(of: geometry.frame(in: .global).minY) { _, newValue in
                        action(newValue)
                    }
            }
        )
    }
}

// MARK: - Professional Enhanced Components
struct ProfessionalPlaceCard: View {
    let place: Place
    let userLocation: CLLocation?
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var reactionManager = ReactionManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageSection
            infoSection
        }
        .frame(width: 280)
        .background(cardBackground)
        .shadow(
            color: cardShadow.color,
            radius: cardShadow.radius,
            x: cardShadow.x,
            y: cardShadow.y
        )
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                PlaceDetailView(place: place)
            }
        }
    }
    
    private var imageSection: some View {
        ZStack(alignment: .topTrailing) {
            placeImage
            favoriteButton
        }
    }
    
    private var placeImage: some View {
        AsyncImage(url: URL(string: place.images.first ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            imagePlaceholder
        }
        .frame(width: 280, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var imagePlaceholder: some View {
        Rectangle()
            .fill(themeManager.cardBackground)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: place.category.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color(hex: place.category.color))
                    
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Color(hex: place.category.color))
                }
            )
    }
    
    private var favoriteButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                favoritesManager.toggleFavorite(place)
            }
        }) {
            Image(systemName: favoritesManager.isFavorite(place) ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(favoritesManager.isFavorite(place) ? themeManager.travelPink : .white)
                .frame(width: 32, height: 32)
                .background(favoriteButtonBackground)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .padding(12)
        .scaleEffect(favoritesManager.isFavorite(place) ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: favoritesManager.isFavorite(place))
    }
    
    private var favoriteButtonBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            addressSection
            actionsSection
        }
        .padding(16)
    }
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            nameAndRatingSection
            Spacer()
            distanceBadge
        }
    }
    
    private var nameAndRatingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name)
                .font(.system(size: 16, weight: .bold))
                .themedText(.primary)
                .lineLimit(2)
            
            ratingSection
        }
    }
    
    private var ratingSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundColor(.yellow)
            
            Text(String(format: "%.1f", place.rating))
                .font(.system(size: 13, weight: .semibold))
                .themedText(.secondary)
            
            Text("•")
                .font(.system(size: 13, weight: .medium))
                .themedText(.tertiary)
            
            Text(place.priceRange)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.colorForCategory(place.category.rawValue))
        }
    }
    
    private var distanceBadge: some View {
        Group {
            if !place.distanceFrom(userLocation).isEmpty {
                Text(place.distanceFrom(userLocation))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.travelBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(distanceBadgeBackground)
            }
        }
    }
    
    private var distanceBadgeBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(themeManager.travelBlue.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.travelBlue.opacity(0.3), lineWidth: 1)
            )
    }
    
    private var addressSection: some View {
        Text(place.location)
            .font(.system(size: 13, weight: .regular))
            .themedText(.tertiary)
            .lineLimit(2)
    }
    
    private var actionsSection: some View {
        HStack(spacing: 16) {
            reactionButtons
            Spacer()
            detailsButton
        }
    }
    
    private var reactionButtons: some View {
        HStack(spacing: 16) {
            ProfessionalReactionButton(
                icon: "hand.thumbsup.fill",
                count: reactionManager.reaction(for: place.id.uuidString) == .liked ? 1 : 0,
                isActive: reactionManager.reaction(for: place.id.uuidString) == .liked,
                color: themeManager.travelGreen
            ) {
                let placeIdString = place.id.uuidString
                let currentReaction = reactionManager.reaction(for: placeIdString)
                if currentReaction == .liked {
                    reactionManager.setReaction(nil, for: placeIdString, place: place)
                } else {
                    reactionManager.setReaction(.liked, for: placeIdString, place: place)
                }
                
                // Track this interaction for analytics
                Task {
                    await UserTrackingService.shared.recordTapEvent(
                        targetId: "modern_tab_thumbs_up",
                        targetType: "place_reaction",
                        coordinates: CGPoint(x: 0, y: 0)
                    )
                }
            }
            
            ProfessionalReactionButton(
                icon: "hand.thumbsdown.fill",
                count: reactionManager.reaction(for: place.id.uuidString) == .disliked ? 1 : 0,
                isActive: reactionManager.reaction(for: place.id.uuidString) == .disliked,
                color: themeManager.travelRed
            ) {
                let placeIdString = place.id.uuidString
                let currentReaction = reactionManager.reaction(for: placeIdString)
                if currentReaction == .disliked {
                    reactionManager.setReaction(nil, for: placeIdString, place: place)
                } else {
                    reactionManager.setReaction(.disliked, for: placeIdString, place: place)
                }
                
                // Track this interaction for analytics
                Task {
                    await UserTrackingService.shared.recordTapEvent(
                        targetId: "modern_tab_thumbs_down",
                        targetType: "place_reaction",
                        coordinates: CGPoint(x: 0, y: 0)
                    )
                }
            }
        }
    }
    
    private var detailsButton: some View {
        Button("Details") {
            showingDetail = true
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(themeManager.travelBlue)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(detailsButtonBackground)
    }
    
    private var detailsButtonBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(themeManager.travelBlue.opacity(0.3), lineWidth: 1)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(themeManager.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
            )
    }
    
    private var cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            color: themeManager.isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

// MARK: - Professional Reaction Button
struct ProfessionalReactionButton: View {
    let icon: String
    let count: Int
    let isActive: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isActive ? color : .gray)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isActive ? color : .gray)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? color.opacity(0.15) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isActive ? color.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

// MARK: - Modern Main Screen Wrapper
struct ModernMainScreenWrapper: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var themeManager = ThemeManager.shared
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ScrollViewReader { proxy in
            ModernMainScreen(locationManager: locationManager)
                .themedBackground()
        }
    }
}

// MARK: - Tab Item Enums
// TabItem enum is defined in AppModels.swift to avoid conflicts

enum HostTabItem: String, CaseIterable {
    case dashboard = "Dashboard"
    case analytics = "Analytics"
    case parties = "Parties"
    case celebrity = "Celebrity"
    case security = "Security"
    case concierge = "Concierge"
    
    var iconName: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .parties: return "party.popper"
        case .celebrity: return "star.fill"
        case .security: return "shield.fill"
        case .concierge: return "bell.fill"
        }
    }
    
    var iconNameUnselected: String {
        switch self {
        case .dashboard: return "chart.bar"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .parties: return "party.popper"
        case .celebrity: return "star"
        case .security: return "shield"
        case .concierge: return "bell"
        }
    }
}

// MARK: - ENHANCED Host Tab Bar with Neon Glow
struct HostTabBar: View {
    @Binding var selectedTab: HostTabItem
    @Binding var showTabBar: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(HostTabItem.allCases, id: \.self) { tab in
                HostTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: {
                        withAnimation(performanceService.getOptimizedSpringAnimation()) {
                            selectedTab = tab
                        }
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.accentGold.opacity(0.1),
                            themeManager.accentGold.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: themeManager.isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.1),
            radius: 12,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - ENHANCED Host Tab Button with Neon Glow
struct HostTabButton: View {
    let tab: HostTabItem
    let isSelected: Bool
    let action: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // NEON GLOW BACKGROUND - Host Mode Style
                    if isSelected {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        themeManager.accentGold.opacity(0.8),
                                        themeManager.accentGold.opacity(0.4),
                                        themeManager.accentGold.opacity(0.1)
                                    ],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                            .blur(radius: 2)
                            .animation(.easeInOut(duration: 0.3), value: isSelected)
                    }
                    
                    // Enhanced icon
                    Image(systemName: isSelected ? tab.iconName : tab.iconNameUnselected)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(
                            isSelected ? 
                            .white : 
                            themeManager.tabBarInactiveText
                        )
                        .scaleEffect(isPressed ? 0.9 : (isSelected ? 1.1 : 1.0))
                        .animation(performanceService.shouldReduceAnimations() ? .none : .easeInOut(duration: 0.15), value: isPressed)
                        .animation(performanceService.getOptimizedSpringAnimation(), value: isSelected)
                        .shadow(
                            color: isSelected ? themeManager.accentGold.opacity(0.8) : .clear,
                            radius: isSelected ? 8 : 0,
                            x: 0,
                            y: 0
                        )
                }
                
                // Enhanced tab label
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(
                        isSelected ? 
                        themeManager.accentGold : 
                        themeManager.tabBarInactiveText
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .shadow(
                        color: isSelected ? themeManager.accentGold.opacity(0.6) : .clear,
                        radius: isSelected ? 4 : 0,
                        x: 0,
                        y: 0
                    )
            }
            .frame(minWidth: 56)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(performanceService.shouldReduceAnimations() ? .none : .easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .animation(performanceService.getOptimizedSpringAnimation(), value: isSelected)
    }
}

// MARK: - Host Parties View
struct HostPartiesView: View {
    @StateObject private var partyManager = PartyManager.shared
    @State private var showingCreateParty = false
    
    var body: some View {
        NavigationView {
            VStack {
                if partyManager.hostParties.isEmpty {
                    // Empty state
                    VStack(spacing: 24) {
                        Image(systemName: "party.popper")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        
                        Text("No Parties Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Create your first party to get started with hosting!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Create Party") {
                            showingCreateParty = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    // Party list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(partyManager.hostParties) { party in
                                HostPartyManagementCard(party: party)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("🎉 My Parties")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateParty = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateParty) {
            PartyCreationView()
        }
        .sheet(isPresented: $partyManager.showingPartyCreation) {
            PartyCreationView()
        }
    }
}

// MARK: - Host Party Management Card
struct HostPartyManagementCard: View {
    let party: Party
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.title)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(party.location.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                Text(party.status.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
            
            // Metrics
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(party.currentAttendees)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("RSVPs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(party.guestCap)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Capacity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(Int((Double(party.currentAttendees) / Double(party.guestCap)) * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Full")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text(formatDate(party.startDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Manage") {
                    showingDetails = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .sheet(isPresented: $showingDetails) {
            PartyDetailView(party: party)
        }
    }
    
    private var statusColor: Color {
        switch party.status {
        case .upcoming: return .blue
        case .live: return .green
        case .ended: return .gray
        case .cancelled: return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Host Analytics View is now implemented in HostDashboardViews.swift

// MARK: - Placeholder Views for other tabs
struct ModernExploreView: View {
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

struct ModernFavoritesView: View {
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

struct ModernProfileView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var authService: AuthenticationService
    @State private var showingPreferences = false
    @State private var showingLogin = false
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
            if authService.isAuthenticated {
                // Authenticated user profile
                VStack(spacing: 16) {
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
                        
                        // Profile photo or initials
                        if let photoURL = authService.user?.photoURL {
                            AsyncImage(url: photoURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .scaleEffect(animateProfile ? 1.0 : 0.8)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateProfile)
                    
                    VStack(spacing: 8) {
                        Text(authService.user?.displayName ?? "Welcome!")
                            .font(.system(size: 28, weight: .bold))
                            .themedText(.primary)
                        
                        if let email = authService.user?.email {
                            Text(email)
                                .font(.system(size: 16))
                                .themedText(.secondary)
                        }
                    }
                    .opacity(animateProfile ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateProfile)
                }
            } else {
                // Not authenticated - show login prompt
                VStack(spacing: 20) {
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
                        
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(animateProfile ? 1.0 : 0.8)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateProfile)
                    
                    VStack(spacing: 8) {
                        Text("Sign In to PlanIt")
                            .font(.system(size: 28, weight: .bold))
                            .themedText(.primary)
                        
                        Text("Sync your preferences across devices")
                            .font(.system(size: 16))
                            .themedText(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(animateProfile ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateProfile)
                    
                    // Sign In Button
                    Button(action: {
                        showingLogin = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill.checkmark")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Sign In")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: themeManager.isDarkMode ? [
                                    themeManager.neonPurple,
                                    themeManager.neonPink
                                ] : [
                                    themeManager.accentBlue,
                                    Color.cyan
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(
                            color: themeManager.isDarkMode ? 
                            themeManager.neonPurple.opacity(0.4) : 
                            themeManager.accentBlue.opacity(0.3),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                    }
                    .opacity(animateProfile ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.6).delay(0.6), value: animateProfile)
                }
            }
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
                ProfileSettingsRow(
                    icon: "gear.circle.fill",
                    title: "Advanced Settings",
                    subtitle: "More theme and preference options",
                    iconColor: themeManager.isDarkMode ? themeManager.neonGreen : themeManager.accentGreen,
                    action: { showingPreferences = true }
                )
                
                ProfileSettingsRow(
                    icon: "bell.circle.fill",
                    title: "Notifications",
                    subtitle: "Manage your notifications",
                    iconColor: themeManager.isDarkMode ? themeManager.neonYellow : themeManager.accentOrange,
                    action: {}
                )
                
                ProfileSettingsRow(
                    icon: "location.circle.fill", 
                    title: "Location Services",
                    subtitle: "Control location access",
                    iconColor: themeManager.isDarkMode ? themeManager.neonBlue : themeManager.accentBlue,
                    action: {}
                )
                
                ProfileSettingsRow(
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

// MARK: - Profile Settings Row Component
struct ProfileSettingsRow: View {
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

// MARK: - Modern Friends View Wrapper
struct ModernFriendsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            // Themed background
            themeManager.backgroundGradient
                .ignoresSafeArea()
            
            FriendsView()
                .environmentObject(authService)
        }
    }
}

// MARK: - Host Mode Views
// NOTE: Host views are defined in HostDashboardViews.swift to avoid redeclaration errors

#Preview {
    ModernMainTabView(locationManager: LocationManager.shared)
        .environmentObject(NotificationManager.shared)
        .environmentObject(AuthenticationService.shared)
}

// MARK: - Profile View Wrapper
struct ProfileViewWrapper: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var partyManager: PartyManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ProfileViewWithModeSwitch()
                .environmentObject(authService)
                .environmentObject(locationManager)
                .environmentObject(partyManager)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.primary)
                    }
                }
        }
    }
}

// MARK: - Profile View with Mode Switch
struct ProfileViewWithModeSwitch: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var partyManager: PartyManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Mode Switch Button at the top
            VStack(spacing: 16) {
                if partyManager.hostProfile != nil {
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            if partyManager.isHostMode {
                                // Switch back to normal app
                                switchToNormalMode()
                            } else {
                                // Switch to business mode
                                switchToBusinessMode()
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: partyManager.isHostMode ? "person.fill" : "building.2.fill")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text(partyManager.isHostMode ? "SWITCH BACK TO NORMAL APP" : "SWITCH TO BUSINESS MODE")
                                .font(.system(size: 16, weight: .bold))
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: partyManager.isHostMode ? 
                                [themeManager.accentBlue, themeManager.accentBlue.opacity(0.8)] :
                                [themeManager.accentGold, themeManager.accentGold.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(
                            color: partyManager.isHostMode ? 
                            themeManager.accentBlue.opacity(0.4) : 
                            themeManager.accentGold.opacity(0.4),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .scaleEffect(partyManager.isHostMode ? 1.0 : 1.02)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: partyManager.isHostMode)
                }
            }
            
            // Original Profile View Content
            UpdatedProfileView()
                .environmentObject(authService)
                .environmentObject(locationManager)
        }
        .background(themeManager.backgroundGradient)
    }
    
    private func switchToNormalMode() {
        Task {
            await partyManager.switchToNormalMode()
            await MainActor.run {
                // Dismiss profile and refresh main view
                dismiss()
                NotificationCenter.default.post(
                    name: NSNotification.Name("ForceAppRefresh"),
                    object: nil,
                    userInfo: ["hostMode": false, "keepProfile": true]
                )
            }
        }
    }
    
    private func switchToBusinessMode() {
        Task {
            await partyManager.switchToBusinessMode()
            await MainActor.run {
                // Dismiss profile and refresh main view
                dismiss()
                NotificationCenter.default.post(
                    name: NSNotification.Name("ForceAppRefresh"),
                    object: nil,
                    userInfo: ["hostMode": true, "keepProfile": true]
                )
            }
        }
    }
}

// MARK: - Futuristic Tab Bar Without Profile
struct FuturisticTabBarWithoutProfile: View {
    @Binding var selectedTab: TabItem
    @Binding var showTabBar: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var hapticManager = HapticManager.shared
    
    // Tab items without profile
    private var tabItems: [TabItem] {
        [.explore, .parties, .missions, .friends, .favorites]
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabItems.enumerated()), id: \.element) { index, tab in
                ProfessionalTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                        hapticManager.lightImpact()
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            // IMPROVED Main background with better contrast
            RoundedRectangle(cornerRadius: 28)
                .fill(themeManager.professionalTabBarGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            themeManager.isDarkMode ? 
                            Color.white.opacity(0.15) : 
                            Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: themeManager.isDarkMode ? Color.black.opacity(0.4) : Color.black.opacity(0.15),
            radius: themeManager.isDarkMode ? 16 : 8,
            x: 0,
            y: themeManager.isDarkMode ? 8 : 4
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

 