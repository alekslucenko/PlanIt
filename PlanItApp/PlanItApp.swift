//
//  PlanItApp.swift
//  PlanIt
//
//  Created by Aleks Lucenko on 6/10/25.
//

import SwiftUI
import FirebaseCore
import CoreLocation

@main
struct PlanItApp: App {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var weatherService = WeatherService()
    @StateObject private var geminiService = GeminiAIService.shared
    @StateObject private var recommendationManager = RecommendationManager.shared
    @StateObject private var userFingerprintManager = UserFingerprintManager.shared
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var authenticationService = AuthenticationService()
    @StateObject private var friendsManager = FriendsManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var chatManager = ChatManager()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        print("🔥 Firebase configured successfully")
    }
    
    var body: some Scene {
        WindowGroup {
            GeometryReader { geometry in
                ZStack {
                    if onboardingManager.hasCompletedOnboarding && authenticationService.isAuthenticated {
                        // Main app with simplified initialization
                        ModernMainTabView(locationManager: locationManager)
                            .environmentObject(onboardingManager)
                            .environmentObject(authenticationService)
                            .environmentObject(locationManager)
                            .environmentObject(friendsManager)
                            .environmentObject(notificationManager)
                            .environmentObject(chatManager)
                            .environmentObject(userFingerprintManager)
                            .environmentObject(weatherService)
                            .environmentObject(geminiService)
                            .environmentObject(recommendationManager)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .onAppear {
                                // Simplified initialization with timeout
                                Task {
                                    await initializeServicesWithTimeout()
                                }
                            }
                    } else {
                        // Onboarding or login flow
                        EnhancedOnboardingView()
                            .environmentObject(onboardingManager)
                            .environmentObject(authenticationService)
                            .environmentObject(locationManager)
                            .environmentObject(userFingerprintManager)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    }
                }
                .ignoresSafeArea(.container, edges: [.top, .bottom])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .preferredColorScheme(.dark)
            .onChange(of: scenePhase) {
                handleScenePhaseChange(scenePhase)
            }
        }
    }
    
    // MARK: - Simplified Service Initialization with Timeout
    
    private func initializeServicesWithTimeout() async {
        print("🚀 Initializing PlanIt App Services with timeout...")
        
        // Use Task with timeout to prevent hanging
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
            print("⚠️ Service initialization timed out")
        }
        
        let initTask = Task {
            await initializeServicesQuickly()
        }
        
        // Race between timeout and initialization
        await Task.yield()
        _ = await [timeoutTask.result, initTask.result]
        
        print("✅ Service initialization completed")
    }
    
    private func initializeServicesQuickly() async {
        // Basic location setup (non-blocking)
        if locationManager.authorizationStatus == .authorizedWhenInUse || 
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.getCurrentLocation()
        }
        
        // Request notification permission (non-blocking)
        Task {
            await notificationManager.requestNotificationPermission()
        }
        
        // Start user fingerprint if authenticated (non-blocking)
        if authenticationService.isAuthenticated {
            userFingerprintManager.startListening()
        }
        
        print("✅ Basic services initialized")
    }
    
    // MARK: - App Lifecycle Handling
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if authenticationService.isAuthenticated {
                print("🔄 App became active - restarting listeners")
                // Non-blocking listener restart
                Task {
                    friendsManager.startRealtimeListeners()
                    if let userId = authenticationService.currentUser?.uid {
                        notificationManager.startListeningForNotifications(userId: userId)
                    }
                }
            }
        case .inactive:
            print("⏸️ App became inactive")
        case .background:
            print("🌙 App entered background")
        @unknown default:
            break
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    var body: some View {
        GeometryReader { geometry in
            TabView {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                
                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                
                FavoritesView()
                    .tabItem {
                        Image(systemName: "heart.fill")
                        Text("Favorites")
                    }
                
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
}

// MARK: - Placeholder Views
struct HomeView: View {
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text("Welcome to PlanIt!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .padding(.top, geometry.safeAreaInsets.top + 20)
                
                Spacer()
                
                Text("Your personalized place discovery app")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }
}

struct SearchView: View {
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text("Search Places")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .padding(.top, geometry.safeAreaInsets.top + 20)
                
                Spacer()
                
                Text("Discover amazing places near you")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.teal.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }
}

// FavoritesView is now implemented in FavoritesView.swift to avoid duplication

struct ProfileView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var authenticationService: AuthenticationService
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 30) {
                Text("Profile")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .padding(.top, geometry.safeAreaInsets.top + 20)
                
                Spacer()
                
                VStack(spacing: 30) {
                    // User Information Card
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(authenticationService.userDisplayName.isEmpty ? "U" : String(authenticationService.userDisplayName.prefix(1)).uppercased())
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(spacing: 8) {
                            Text(authenticationService.userDisplayName.isEmpty ? "User" : authenticationService.userDisplayName)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            
                            if let user = authenticationService.user {
                                Text(user.email ?? "No email")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Authentication Status
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Authenticated")
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                        
                        if authenticationService.user?.providerData.first?.providerID == "google.com" {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.blue)
                                Text("Google Account")
                                    .foregroundColor(.white.opacity(0.9))
                                Spacer()
                            }
                            .padding(.horizontal, 40)
                        } else {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.blue)
                                Text("Email Account")
                                    .foregroundColor(.white.opacity(0.9))
                                Spacer()
                            }
                            .padding(.horizontal, 40)
                        }
                    }
                    
                    Button("Sign Out") {
                        Task {
                            await authenticationService.signOut()
                        }
                        onboardingManager.resetOnboarding()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: 200, height: 50)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(0.8), Color.mint.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }
}

#Preview {
    ContentView()
        .environmentObject(OnboardingManager())
}
