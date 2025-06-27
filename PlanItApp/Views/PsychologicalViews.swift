import SwiftUI
import CoreLocation
import Combine

// MARK: - Enhanced In-App Notification View
struct EnhancedInAppNotificationView: View {
    let notification: AppNotification
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isPressed = false
    
    var body: some View {
        notificationContentView
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .offset(y: dragOffset)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }, perform: {})
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height < 0 {
                            dragOffset = value.translation.height * 0.5
                        }
                    }
                    .onEnded { value in
                        if value.translation.height < -50 {
                            onDismiss()
                        } else {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
    }
    
    private var notificationContentView: some View {
        HStack(spacing: 16) {
            // Notification icon with glow effect
            notificationIconView
            
            // Notification content
            notificationTextView
            
            Spacer()
            
            // Dismiss button
            dismissButtonView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(notificationBackgroundView)
    }
    
    private var notificationIconView: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.8),
                            Color.blue.opacity(0.4)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 25
                    )
                )
                .frame(width: 44, height: 44)
            
            Image(systemName: "bell.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var notificationTextView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notification.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(notification.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if let timeAgo = notification.timeAgoString {
                Text(timeAgo)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dismissButtonView: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
        }
    }
    
    private var notificationBackgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Enhanced Explore View
struct ExploreView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var recommendationEngine = RecommendationEngine.shared
    @StateObject private var fingerprintManager = UserFingerprintManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    @State private var showingLocationPicker = false
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            mainContentView
        }
        .refreshable {
            await refreshRecommendations()
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationSelectorView(locationManager: locationManager, locationSearch: LocationSearchService())
        }
        .onAppear {
            Task {
                // Activate heavy services while this view is on screen
                PlaceDataService.shared.activate()
                DynamicCategoryManager.shared.activate()
                await loadInitialData()
            }
        }
        .onDisappear {
            PlaceDataService.shared.deactivate()
            DynamicCategoryManager.shared.deactivate()
        }
    }
    
    private var mainContentView: some View {
        VStack(spacing: 24) {
            // Header with location and search
            headerSectionView
            
            // Dynamic categories
            if !recommendationEngine.personalizedCategories.isEmpty {
                PsychologicalCategoryGrid(
                    categories: recommendationEngine.personalizedCategories,
                    selectedCategory: $selectedCategory
                )
            }
            
            // AI-powered recommendations
            if !recommendationEngine.lastRecommendations.isEmpty {
                PsychologicalRecommendationsView(
                    recommendations: recommendationEngine.lastRecommendations
                )
            }
            
            // Loading state
            if recommendationEngine.isGeneratingRecommendations {
                loadingStateView
            }
            
            Spacer(minLength: 100) // Account for tab bar
        }
    }
    
    private var headerSectionView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discover")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let location = locationManager.selectedLocation {
                        Text("📍 Current Location")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { showingLocationPicker = true }) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(themeManager.accentBlue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Search bar with psychological design
            searchBarView
        }
        .padding(.bottom, 8)
    }
    
    private var searchBarView: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("What kind of magic are you seeking?", text: $searchText)
                .font(.system(size: 16, weight: .medium))
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    private var loadingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(themeManager.accentBlue)
            
            Text("✨ Crafting personalized discoveries...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
    
    private func refreshRecommendations() async {
        guard let location = locationManager.selectedLocation else { return }
        
        do {
            let context = RecommendationContext(
                userId: "demo_user",
                location: location,
                currentTime: Date(),
                weatherCondition: "clear",
                userFingerprint: fingerprintManager.fingerprint,
                previousRecommendations: []
            )
            _ = try await recommendationEngine.generateIntelligentRecommendations(
                context: context
            )
        } catch {
            print("❌ Failed to refresh recommendations: \(error)")
        }
    }
    
    private func loadInitialData() async {
        guard let location = locationManager.selectedLocation else { return }
        
        do {
            // Simplified recommendation generation for demo
            let simpleContext = RecommendationContext(
                userId: "demo_user",
                location: location,
                currentTime: Date(),
                weatherCondition: "clear",
                userFingerprint: fingerprintManager.fingerprint,
                previousRecommendations: []
            )
            
            let generatedRecommendations = await RecommendationEngine.shared.generateIntelligentRecommendations(context: simpleContext)
            
            // Use DynamicCategoryManager for category generation
            await DynamicCategoryManager.shared.generateDynamicCategories(location: location)
            let categories = DynamicCategoryManager.shared.dynamicCategories
            
            // Generate recommendations if needed
            if recommendationEngine.lastRecommendations.isEmpty {
                _ = try await recommendationEngine.generateIntelligentRecommendations(
                    context: simpleContext
                )
            }
        } catch {
            print("❌ Failed to load initial data: \(error)")
        }
    }
    
    private func triggerEnhancedPsychologicalAnalysis() {
        // Simplified for demo
        print("Enhanced psychological analysis triggered")
    }
}

// MARK: - Supporting Extensions and Types

extension AppNotification {
    var timeAgoString: String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp.dateValue(), relativeTo: Date())
    }
}

// AppNotificationCategory extension moved to where the type is defined

// NudgeType extension moved to AppModels.swift to avoid duplication

// MARK: - Placeholder Types for Compilation

// UserFingerprintManager extensions moved to main UserFingerprintManager file 