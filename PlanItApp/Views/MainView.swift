import SwiftUI
import CoreLocation

struct MainView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var missionManager = MissionManager()
    @StateObject private var xpManager = XPManager()
    @StateObject private var fingerprintManager = UserFingerprintManager.shared
    @StateObject private var recommendationEngine = RecommendationEngine.shared
    @StateObject private var hapticManager = HapticManager.shared
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var authenticationService: AuthenticationService
    
    @State private var selectedTab: TabItem = .explore
    @State private var showTabBar = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var showDiscoveryAnimation = false
    @State private var dailyDiscoveryUnlocked = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Dynamic ambient background with mood sync
            LinearGradient(
                colors: [themeManager.primaryBackground, themeManager.secondaryBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()
                .animation(Animation.easeInOut(duration: 2.0), value: themeManager.primaryBackground)
            
            // Main content with liquid glass effects
            TabView(selection: $selectedTab) {
                ModernMainScreen(locationManager: locationManager)
                    .tag(TabItem.explore)
                
                MissionsView(missionManager: missionManager, xpManager: xpManager, locationManager: locationManager)
                    .tag(TabItem.missions)
                
                FriendsView()
                    .tag(TabItem.friends)
                
                FavoritesView()
                    .tag(TabItem.favorites)
                
                UpdatedProfileView()
                    .environmentObject(authenticationService)
                    .environmentObject(locationManager)
                    .tag(TabItem.profile)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Enhanced Tab Bar with haptic feedback
            if showTabBar {
                FuturisticTabBar(selectedTab: $selectedTab, showTabBar: $showTabBar)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: showTabBar)
            }
            
            // Curiosity Loop: Daily Discovery Notification
            if dailyDiscoveryUnlocked && showDiscoveryAnimation {
                VStack {
                    Text("Daily Discovery Unlocked!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.8))
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                    
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showDiscoveryAnimation)
            }
            
            // Progress completion animations
            if xpManager.showXPAnimation {
                VStack {
                    Text("XP Gained!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.green.opacity(0.8))
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: xpManager.showXPAnimation)
            }
            
            // In-app notifications with enhanced design
            if notificationManager.showInAppNotification,
               let notification = notificationManager.currentInAppNotification {
                VStack {
                    EnhancedInAppNotificationView(
                        notification: notification,
                        onTap: { handleNotificationTap(notification) },
                        onDismiss: { notificationManager.hideInAppNotification() }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: notificationManager.showInAppNotification)
                .zIndex(1000)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            setupPsychologicalHooks()
        }
        .onChange(of: selectedTab) { _, newTab in
            hapticManager.mediumImpact()
            trackTabInteraction(newTab)
        }
    }
    
    // MARK: - UX Psychology Integration
    
    private func setupPsychologicalHooks() {
        // Start behavioral tracking
        fingerprintManager.startNewSession()
        
        // Check for daily discovery unlock (Novelty + Curiosity Gap)
        checkDailyDiscoveryStatus()
        
        // Ambient mood detection
        themeManager.updateMoodBasedOnTime()
        
        // Progress bias setup
        xpManager.checkProgressMilestones()
    }
    
    private func checkDailyDiscoveryStatus() {
        let lastDiscovery = UserDefaults.standard.object(forKey: "lastDailyDiscovery") as? Date
        let today = Calendar.current.startOfDay(for: Date())
        
        if lastDiscovery == nil || Calendar.current.startOfDay(for: lastDiscovery!) < today {
            // Unlock daily discovery with curiosity gap
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                    dailyDiscoveryUnlocked = true
                    showDiscoveryAnimation = true
                }
                
                // hapticManager.successFeedback() // TODO: Implement haptic feedback
                
                // Hide after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showDiscoveryAnimation = false
                    }
                }
            }
        }
    }
    
    private func trackTabInteraction(_ tab: TabItem) {
        // Advanced behavioral tracking
        Task {
            await fingerprintManager.recordTabInteraction(
                tab: tab.rawValue,
                timeSpent: Date().timeIntervalSince(fingerprintManager.lastTabSwitchTime),
                context: getCurrentUsageContext()
            )
        }
    }
    
    private func getCurrentUsageContext() -> [String: Any] {
        return [
            "timeOfDay": fingerprintManager.getCurrentTimeOfDay(),
            "batteryLevel": UIDevice.current.batteryLevel,
            "locationAccuracy": locationManager.lastLocationAccuracy ?? 0,
            "sessionDuration": fingerprintManager.getSessionDuration(),
            "weatherCondition": themeManager.currentWeatherMood ?? "unknown"
        ]
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        notificationManager.hideInAppNotification()
        hapticManager.mediumImpact()
        
        let navigation = notificationManager.handleNotificationTap(notification)
        
        switch navigation.screen {
        case "friends":
            selectedTab = .friends
        case "missions":
            selectedTab = .missions
        case "favorites":
            selectedTab = .favorites
        default:
            selectedTab = .explore
        }
        
        // Track notification engagement
        Task {
            await fingerprintManager.recordNotificationInteraction(
                notificationType: notification.type,
                action: "tapped",
                context: getCurrentUsageContext()
            )
        }
    }
}

