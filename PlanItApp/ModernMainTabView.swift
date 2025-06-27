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
    
    // Prevent premature loading of user Explore view before we know host mode
    @State private var hostModeInitialized = false
    
    static func == (lhs: ModernMainTabView, rhs: ModernMainTabView) -> Bool {
        // Compare only the essential properties for performance
        return lhs.selectedTab == rhs.selectedTab &&
               lhs.selectedHostTab == rhs.selectedHostTab &&
               lhs.partyManager.isHostMode == rhs.partyManager.isHostMode
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Block UI with background until hostModeInitialized to avoid premature view creation
                if !hostModeInitialized {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.accentBlue))
                        .scaleEffect(1.4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(themeManager.businessBackground.ignoresSafeArea())
                } else {
                    // Dynamic themed background
                    themeManager.businessBackground
                        .ignoresSafeArea(.all)
                    
                    VStack(spacing: 0) {
                        // CONDITIONAL CONTENT BASED ON HOST MODE
                        if partyManager.isHostMode {
                            hostModeContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        } else {
                            regularUserContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        }
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
                            .padding(.top, geometry.safeAreaInsets.top)
                            
                            Spacer()
                        }
                        .zIndex(1000)
                    }
                }
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
        .preferredColorScheme(themeManager.colorScheme)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            #if DEBUG
            print("🔄 ModernMainTabView appeared - checking host mode")
            #endif
            // Initialize services only when needed
            PlaceDataService.shared.deactivate()
            DynamicCategoryManager.shared.deactivate()
            
            // Initialize FriendsManager with proper service references
            let friendsManager = FriendsManager()
            friendsManager.setAuthService(authService)
            friendsManager.setNotificationManager(notificationManager)

            Task {
                await partyManager.checkHostMode()
                await MainActor.run {
                    hostModeInitialized = true
                    
                    print("🔍 Host mode check completed: isHostMode = \(partyManager.isHostMode)")
                    print("🔍 Will show: \(partyManager.isHostMode ? "BUSINESS" : "USER") interface")
                    
                    // Start friends listeners only after host mode is determined and for regular users
                    if !partyManager.isHostMode {
                        print("👥 Starting friends listeners for user mode")
                        friendsManager.startRealtimeListeners()
                        
                        // Ensure correct tab is selected for users
                        selectedTab = .explore
                        showTabBar = true
                    } else {
                        print("🏢 User is in host mode - showing business interface")
                        selectedHostTab = .dashboard
                    }
                }
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
    
    // MARK: - Host Mode Content (FIXED LAYOUT)
    private var hostModeContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // HOST MODE NAVIGATION
                TabView(selection: $selectedHostTab) {
                    // Host Dashboard - CONSOLIDATED ANALYTICS
                    HostAnalyticsView()
                        .tag(HostTabItem.dashboard)
                    
                    // Party Management
                    HostPartiesView()
                        .environmentObject(partyManager)
                        .tag(HostTabItem.parties)
                    
                    // Celebrity Booking
                    CelebrityBookingView()
                        .tag(HostTabItem.celebrity)
                    
                    // Security Booking
                    SecurityBookingView()
                        .tag(HostTabItem.security)
                    
                    // Profile
                    UpdatedProfileView()
                        .environmentObject(authService)
                        .environmentObject(locationManager)
                        .tag(HostTabItem.profile)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: geometry.size.height - 100) // Leave space for tab bar
                .id("host_\(selectedHostTab.rawValue)_\(refreshID)")
                
                // Host Tab Bar with Neon Glow - LOCKED AT BOTTOM
                if showTabBar {
                    EnhancedHostTabBar(selectedTab: $selectedHostTab, showTabBar: $showTabBar)
                        .frame(height: 100)
                        .background(
                            Rectangle()
                                .fill(themeManager.businessBackground)
                                .ignoresSafeArea(.all, edges: .bottom)
                        )
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
    
    // MARK: - Regular User Content (FIXED LAYOUT)
    private var regularUserContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // REGULAR USER NAVIGATION
                TabView(selection: $selectedTab) {
                    // Discover Tab - Enhanced Main Screen
                    ModernMainScreen(locationManager: locationManager)
                        .tag(TabItem.explore)
                    
                    // Parties Tab - User-focused view for browsing parties
                    UserPartiesView()
                        .environmentObject(partyManager)
                        .tag(TabItem.parties)
                    
                    // Quests Tab
                    MissionsView(missionManager: missionManager, xpManager: xpManager)
                        .tag(TabItem.missions)
                    
                    // Friends Tab
                    ModernFriendsView()
                        .tag(TabItem.friends)
                    
                    // Favorites Tab
                    ModernFavoritesView()
                        .tag(TabItem.favorites)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: geometry.size.height - 100) // Leave space for tab bar
                .id("userTab_\(selectedTab.rawValue)_\(refreshID)")
                .animation(performanceService.shouldReduceAnimations() ? .none : .easeInOut(duration: 0.2), value: selectedTab)
                
                // USER TAB BAR - ALWAYS VISIBLE IN USER MODE
                if showTabBar {
                    FuturisticTabBar(selectedTab: $selectedTab, showTabBar: $showTabBar)
                        .frame(height: 100)
                        .background(
                            Rectangle()
                                .fill(themeManager.primaryBackground)
                                .ignoresSafeArea(.all, edges: .bottom)
                        )
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .onAppear {
                #if DEBUG
                print("🔄 Regular user content appeared with selected tab: \(selectedTab.rawValue)")
                #endif
                // CRITICAL: Always ensure tab bar is visible in user mode
                showTabBar = true
                print("🔧 User mode: Tab bar forced to visible")
            }
            .onChange(of: selectedTab) { _, newTab in
                #if DEBUG
                print("🔄 Tab changed to: \(newTab.rawValue)")
                #endif
                // Always keep tab bar visible in user mode
                showTabBar = true
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
                // Deactivate heavy user-facing services and friends listeners
                PlaceDataService.shared.deactivate()
                DynamicCategoryManager.shared.deactivate()
                
                // Stop friends listeners in host mode to save resources
                let friendsManager = FriendsManager()
                friendsManager.stopAllListeners()
                
                selectedHostTab = .dashboard
                print("✅ Switched to host mode - Dashboard tab selected")
            } else {
                // Reactivate services for user mode
                selectedTab = .explore
                showTabBar = true
                print("✅ Switched to user mode - Explore tab selected")
                PlaceDataService.shared.activate()
                DynamicCategoryManager.shared.activate()
                
                // Restart friends listeners for user mode
                let friendsManager = FriendsManager()
                friendsManager.setAuthService(authService)
                friendsManager.setNotificationManager(notificationManager)
                friendsManager.startRealtimeListeners()
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
    case parties = "Parties"
    case celebrity = "Celebrity"
    case security = "Security"
    case profile = "Profile"
    
    var iconName: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .parties: return "party.popper"
        case .celebrity: return "star.fill"
        case .security: return "shield.fill"
        case .profile: return "person.fill"
        }
    }
    
    var iconNameUnselected: String {
        switch self {
        case .dashboard: return "chart.bar"
        case .parties: return "party.popper"
        case .celebrity: return "star"
        case .security: return "shield"
        case .profile: return "person"
        }
    }
}

// MARK: - Enhanced Host Tab Bar (Exact Image Match)
struct EnhancedHostTabBar: View {
    @Binding var selectedTab: HostTabItem
    @Binding var showTabBar: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var partyManager = PartyManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar Background
            HStack(spacing: 0) {
                ForEach(HostTabItem.allCases, id: \.self) { tab in
                    hostTabButton(tab: tab)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5),
                        alignment: .top
                    )
            )
        }
    }
    
    private func hostTabButton(tab: HostTabItem) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: selectedTab == tab ? tab.iconName : tab.iconNameUnselected)
                    .font(.inter(20, weight: selectedTab == tab ? .semibold : .medium))
                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.5))
                
                Text(tab.rawValue)
                    .font(.inter(10, weight: selectedTab == tab ? .semibold : .medium))
                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ENHANCED Host Parties View (FIXED LAYOUT)
struct HostPartiesView: View {
    @EnvironmentObject var partyManager: PartyManager
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingCreateParty = false
    @State private var selectedParty: Party?
    @State private var searchText = ""
    @State private var selectedFilter = PartyFilter.all
    @State private var animateCards = false
    
    enum PartyFilter: String, CaseIterable {
        case all = "All Events"
        case upcoming = "Upcoming"
        case live = "Live"
        case completed = "Completed"
        case cancelled = "Cancelled"
        
        var iconName: String {
            switch self {
            case .all: return "calendar"
            case .upcoming: return "clock"
            case .live: return "dot.radiowaves.left.and.right"
            case .completed: return "checkmark.circle"
            case .cancelled: return "xmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .blue
            case .upcoming: return .orange
            case .live: return .green
            case .completed: return .gray
            case .cancelled: return .red
            }
        }
    }
    
    var filteredParties: [Party] {
        var parties = partyManager.hostParties
        
        // Apply search filter
        if !searchText.isEmpty {
            parties = parties.filter { party in
                party.title.localizedCaseInsensitiveContains(searchText) ||
                party.description.localizedCaseInsensitiveContains(searchText) ||
                party.location.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .upcoming:
            parties = parties.filter { $0.status == .upcoming }
        case .live:
            parties = parties.filter { $0.status == .live }
        case .completed:
            parties = parties.filter { $0.status == .ended }
        case .cancelled:
            parties = parties.filter { $0.status == .cancelled }
        }
        
        return parties.sorted { $0.startDate > $1.startDate }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                themeManager.businessBackground
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header Section with proper safe area
                    headerSection
                        .padding(.top, geometry.safeAreaInsets.top + 10)
                    
                    // Filter Section
                    filterSection
                        .padding(.top, 16)
                    
                    // Content Area
                    if filteredParties.isEmpty {
                        emptyStateView
                    } else {
                        partiesListView
                    }
                    
                    // Bottom spacer for tab bar
                    Spacer(minLength: 100)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $showingCreateParty) {
            PartyCreationView()
        }
        .sheet(item: $selectedParty) { party in
            PartyDetailView(party: party)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateCards = true
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Event Management")
                        .font(.geist(28, weight: .bold))
                        .foregroundColor(themeManager.businessText)
                    
                    Text("Manage your hosted events and track performance")
                        .font(.geist(14, weight: .medium))
                        .foregroundColor(themeManager.businessSecondaryText)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 10)
                
                Button(action: { showingCreateParty = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Create Event")
                    }
                    .font(.geist(12, weight: .semibold))
                }
                .buttonStyle(GlassButtonStyle(tint: themeManager.businessAccent))
            }
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.businessSecondaryText)
                    .font(.system(size: 14, weight: .medium))
                
                TextField("Search events...", text: $searchText)
                    .font(.geist(14, weight: .medium))
                    .foregroundColor(themeManager.businessText)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(themeManager.businessSecondaryText)
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.businessCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.businessBorder, lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PartyFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        icon: filter.iconName,
                        color: filter.color,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var partiesListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(Array(filteredParties.enumerated()), id: \.element.id) { index, party in
                    HostPartyCard(party: party) {
                        selectedParty = party
                    }
                    .scaleEffect(animateCards ? 1.0 : 0.8)
                    .opacity(animateCards ? 1.0 : 0)
                    .animation(.easeOut(duration: 0.6).delay(Double(index) * 0.1), value: animateCards)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(themeManager.businessPrimary)
            
            VStack(spacing: 6) {
                Text("No Events Found")
                    .font(.geist(20, weight: .bold))
                    .foregroundColor(themeManager.businessText)
                
                Text(searchText.isEmpty ? "Start hosting amazing events" : "Try adjusting your search criteria")
                    .font(.geist(14, weight: .medium))
                    .foregroundColor(themeManager.businessSecondaryText)
                    .multilineTextAlignment(.center)
            }
            
            if searchText.isEmpty {
                Button(action: {
                    showingCreateParty = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Create Your First Event")
                            .font(.geist(14, weight: .semibold))
                    }
                    .foregroundColor(themeManager.businessAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.businessPrimary)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 40)
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(title)
                    .font(.geist(14, weight: .medium))
            }
            .foregroundColor(isSelected ? themeManager.businessAccent : themeManager.businessSecondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color : themeManager.businessCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? color : themeManager.businessBorder, lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Host Party Card Component  
struct HostPartyCard: View {
    let party: Party
    let onTap: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.title)
                        .font(.geist(20, weight: .bold))
                        .foregroundColor(themeManager.businessText)
                        .lineLimit(2)
                    
                    Text(party.location.name)
                        .font(.geist(14, weight: .medium))
                        .foregroundColor(themeManager.businessSecondaryText)
                }
                
                Spacer()
                
                StatusBadge(status: party.status)
            }
            
            // Event details
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(themeManager.businessPrimary)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(formatDate(party.startDate))
                            .font(.geist(14, weight: .medium))
                            .foregroundColor(themeManager.businessText)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .foregroundColor(themeManager.businessInfo)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("\(party.currentAttendees)/\(party.guestCap)")
                            .font(.geist(14, weight: .medium))
                            .foregroundColor(themeManager.businessText)
                    }
                }
                
                if !party.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(party.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.geist(12, weight: .medium))
                                    .foregroundColor(themeManager.businessSecondaryText)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(themeManager.businessPrimary.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("View Details") {
                    onTap()
                }
                .font(.geist(14, weight: .semibold))
                .foregroundColor(themeManager.businessText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.businessCardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.businessBorder, lineWidth: 1)
                        )
                )
                
                Spacer()
                
                if party.status == .upcoming {
                    Button("Edit") {
                        // TODO: Navigate to edit view
                    }
                    .font(.geist(14, weight: .semibold))
                    .foregroundColor(themeManager.businessAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.businessPrimary)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.businessCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.businessBorder, lineWidth: 1)
                )
        )
        .shadow(
            color: themeManager.businessShadow.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
        .onTapGesture {
            onTap()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Status Badge Component
struct StatusBadge: View {
    let status: Party.PartyStatus
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var statusConfig: (color: Color, icon: String, text: String) {
        switch status {
        case .upcoming:
            return (themeManager.businessWarning, "clock", "Upcoming")
        case .live:
            return (themeManager.businessSuccess, "dot.radiowaves.left.and.right", "Live")
        case .ended:
            return (themeManager.businessSecondaryText, "checkmark.circle", "Ended")
        case .cancelled:
            return (themeManager.businessDanger, "xmark.circle", "Cancelled")
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusConfig.icon)
                .font(.system(size: 12, weight: .medium))
            
            Text(statusConfig.text)
                .font(.geist(12, weight: .semibold))
        }
        .foregroundColor(statusConfig.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusConfig.color.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(statusConfig.color.opacity(0.3), lineWidth: 1)
                )
        )
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

 