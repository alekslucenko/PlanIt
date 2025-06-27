import SwiftUI
import CoreLocation
import Combine

struct ModernMainScreen: View {
    @State private var selectedCategory: PlaceCategory? = nil
    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var showLocationPermissionAlert = false
    @State private var selectedRadius: Double = 2.0 // Default 2 miles
    @State private var selectedPlace: Place?
    @State private var showingPlaceDetail = false
    @State private var refreshTrigger = false
    @State private var showSkeleton = true
    @State private var cancellables = Set<AnyCancellable>()
    
    @ObservedObject var locationManager: LocationManager
    @StateObject private var locationSearch = LocationSearchService()
    @StateObject private var placeDataService = PlaceDataService.shared
    @StateObject private var weatherService = WeatherService()
    @StateObject private var searchDebouncer = SearchDebouncer()
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var dynamicCategoryManager = DynamicCategoryManager.shared
    @EnvironmentObject var fingerprintManager: UserFingerprintManager
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var geminiService = GeminiAIService.shared
    @StateObject private var reactionManager = ReactionManager.shared
    @StateObject private var partyManager = PartyManager.shared
    @State private var aiGeneratedCategories: [DynamicCategory] = []
    @State private var isGeneratingCategories = false
    
    // Beautiful loading screen state
    @State private var loadingPhase: LoadingPhase = .initializing
    @State private var loadingProgress: Double = 0.0
    @State private var loadingMessage: String = "Starting up..."
    @State private var isInitialLoadComplete = false
    @State private var hasInitiallyLoaded = false
    @State private var showMainContent = false
    @State private var showingLocationPicker = false
    @StateObject private var hapticManager = HapticManager.shared
    
    enum LoadingPhase: String, CaseIterable {
        case initializing = "Initializing"
        case loadingCache = "Loading your favorites"
        case fetchingLocation = "Finding your location"
        case loadingPlaces = "Discovering amazing places"
        case enhancingRecommendations = "Personalizing your experience"
        case complete = "Ready to explore!"
        
        var icon: String {
            switch self {
            case .initializing: return "sparkles"
            case .loadingCache: return "heart.fill"
            case .fetchingLocation: return "location.fill"
            case .loadingPlaces: return "map.fill"
            case .enhancingRecommendations: return "brain.head.profile"
            case .complete: return "checkmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .initializing: return .blue
            case .loadingCache: return .pink
            case .fetchingLocation: return .green
            case .loadingPlaces: return .orange
            case .enhancingRecommendations: return .purple
            case .complete: return .green
            }
        }
    }
    
    // Explicit initializer to accept LocationManager
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                theme.backgroundGradient
                    .ignoresSafeArea()
                
                if !isInitialLoadComplete {
                    // Beautiful Loading Screen
                    beautifulLoadingScreen
                } else {
                    // Main Content
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            headerSection
                            locationStatusSection
                            searchSection
                            distanceSelector
                            
                            if !dynamicCategoryManager.dynamicCategories.isEmpty {
                                dynamicCategoriesSection
                            }
                            
                            traditionCategoriesSection
                            infiniteScrollPlaceSections
                            
                            Spacer(minLength: 120) // Always ensure tab bar space
                        }
                    }
                    .refreshable {
                        await refreshContent()
                    }
                    .opacity(showMainContent ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5), value: showMainContent)
                }
            }
        }
        .sheet(isPresented: $showingPlaceDetail) {
            if let place = selectedPlace {
                NavigationView {
                    PlaceDetailView(place: place)
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationSelectorView(locationManager: locationManager, locationSearch: LocationSearchService())
        }
        .onAppear {
            if !hasInitiallyLoaded {
                hasInitiallyLoaded = true
                startEnhancedLoadingSequence()
            }
        }
        .onDisappear {
            // Deactivate heavy services when view disappears to save resources
            PlaceDataService.shared.deactivate()
            DynamicCategoryManager.shared.deactivate()
        }
        .onChange(of: locationManager.selectedLocation) { _, newLocation in
            if let location = newLocation, newLocation != nil {
                // Location changed, reload places
                Task {
                    await loadPlacesAndUpdateUI(for: location)
                }
            }
        }
    }
    
    // MARK: - Beautiful Loading Screen
    private var beautifulLoadingScreen: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated Logo/Icon
            ZStack {
                Circle()
                    .fill(loadingPhase.color.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(loadingProgress > 0 ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: loadingProgress)
                
                Image(systemName: loadingPhase.icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(loadingPhase.color)
                    .rotationEffect(.degrees(loadingProgress * 360))
                    .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: loadingProgress)
            }
            
            // Progress Section
            VStack(spacing: 20) {
                // Phase Title
                Text(loadingPhase.rawValue)
                    .font(.inter(24, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.opacity.combined(with: .scale))
                
                // Loading Message
                Text(loadingMessage)
                    .font(.inter(16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: loadingMessage)
                
                // Progress Bar
                VStack(spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.inter(12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Text("\(Int(loadingProgress * 100))%")
                            .font(.inter(12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    ProgressView(value: loadingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: loadingPhase.color))
                        .scaleEffect(y: 2.0)
                        .animation(.easeInOut(duration: 0.5), value: loadingProgress)
                }
                .padding(.horizontal, 40)
                
                // Phase Indicators
                HStack(spacing: 8) {
                    ForEach(Array(LoadingPhase.allCases.enumerated()), id: \.offset) { index, phase in
                        Circle()
                            .fill(index <= LoadingPhase.allCases.firstIndex(of: loadingPhase) ?? 0 ? phase.color : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(phase == loadingPhase ? 1.5 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: loadingPhase)
                    }
                }
            }
            
            Spacer()
            
            // Fun Loading Tips
            VStack(spacing: 8) {
                Text("💡 Did you know?")
                    .font(.inter(14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(getRandomLoadingTip())
                    .font(.inter(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
    
    // MARK: - Enhanced Loading Sequence
    private func startEnhancedLoadingSequence() {
        Task {
            // Phase 1: Initializing
            await updateLoadingPhase(.initializing, progress: 0.1, message: "Warming up the engines...")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Phase 2: Loading Cache
            await updateLoadingPhase(.loadingCache, progress: 0.2, message: "Loading your saved places...")
            await loadCacheData()
            await updateLoadingPhase(.loadingCache, progress: 0.35, message: "Found \(getTotalCachedPlaces()) cached places!")
            
            // Phase 3: Location
            await updateLoadingPhase(.fetchingLocation, progress: 0.45, message: "Getting your location...")
            await ensureLocation()
            
            // Phase 4: Loading Places
            await updateLoadingPhase(.loadingPlaces, progress: 0.6, message: "Discovering nearby restaurants...")
            await loadPlacesInBackground()
            
            // Phase 5: AI Enhancement
            await updateLoadingPhase(.enhancingRecommendations, progress: 0.8, message: "Creating your personalized feed...")
            await generateAIRecommendations()
            
            // Phase 6: Complete
            await updateLoadingPhase(.complete, progress: 1.0, message: "Ready to explore amazing places!")
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            
            // Show main content
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.8)) {
                    isInitialLoadComplete = true
                    showMainContent = true
                }
                
                // Ensure services are active
                PlaceDataService.shared.activate()
                DynamicCategoryManager.shared.activate()
            }
        }
    }
    
    @MainActor
    private func updateLoadingPhase(_ phase: LoadingPhase, progress: Double, message: String) async {
        withAnimation(.easeInOut(duration: 0.5)) {
            loadingPhase = phase
            loadingProgress = progress
            loadingMessage = message
        }
        
        // Add haptic feedback for phase changes
        if phase != loadingPhase {
            hapticManager.lightImpact()
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000) // Small delay for animation
    }
    
    private func loadCacheData() async {
        // Load cached places immediately for instant display
        if let location = locationManager.selectedLocation {
            let locationKey = generateLocationKey(for: location, radius: selectedRadius)
            placeDataService.loadCachedPlacesFirst(for: locationKey)
        }
        
        // Load cached AI categories
        await DynamicCategoryManager.shared.loadCachedCategories()
        
        await MainActor.run {
            aiGeneratedCategories = DynamicCategoryManager.shared.dynamicCategories
        }
    }
    
    private func ensureLocation() async {
        guard locationManager.selectedLocation == nil else { return }
        
        await MainActor.run {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestLocationPermission()
            } else if [.authorizedWhenInUse, .authorizedAlways].contains(locationManager.authorizationStatus) {
                locationManager.getCurrentLocation()
            }
        }
        
        // Wait for location with timeout
        var attempts = 0
        while locationManager.selectedLocation == nil && attempts < 10 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            attempts += 1
        }
    }
    
    private func loadPlacesInBackground() async {
        guard let location = locationManager.selectedLocation else { return }
        
        // Activate services
        await MainActor.run {
            PlaceDataService.shared.activate()
            DynamicCategoryManager.shared.activate()
        }
        
        // Load places with progress updates
        await loadPlacesAndUpdateUI(for: location, showProgress: true)
    }
    
    private func generateAIRecommendations() async {
        guard let location = locationManager.selectedLocation else { return }
        
        // Generate AI categories if needed
        if dynamicCategoryManager.dynamicCategories.isEmpty {
            await DynamicCategoryManager.shared.generateDynamicCategories(location: location)
            
            await MainActor.run {
                aiGeneratedCategories = DynamicCategoryManager.shared.dynamicCategories
            }
        }
        
        // Fetch weather
        await MainActor.run {
            weatherService.fetchWeather(for: location)
        }
    }
    
    private func loadPlacesAndUpdateUI(for location: CLLocation, showProgress: Bool = false) async {
        placeDataService.loadPlacesForAllCategories(at: location, radius: selectedRadius, initialLoad: true)
        
        if showProgress {
            // Simulate progress updates for places loading
            await updateLoadingPhase(.loadingPlaces, progress: 0.65, message: "Finding coffee shops...")
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            await updateLoadingPhase(.loadingPlaces, progress: 0.72, message: "Discovering bars and nightlife...")
            try? await Task.sleep(nanoseconds: 600_000_000)
            
            await updateLoadingPhase(.loadingPlaces, progress: 0.78, message: "Locating entertainment venues...")
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
    
    private func refreshContent() async {
        guard let location = locationManager.selectedLocation else { return }
        
        // Clear and reload
        await MainActor.run {
            placeDataService.clearAllPlacesData()
            dynamicCategoryManager.dynamicCategories = []
            aiGeneratedCategories = []
        }
        
        // Reload everything
        await loadPlacesAndUpdateUI(for: location)
        await generateAIRecommendations()
    }
    
    // MARK: - Helper Functions
    private func getTotalCachedPlaces() -> Int {
        return placeDataService.placesByCategory.values.reduce(0) { $0 + $1.count }
    }
    
    private func generateLocationKey(for location: CLLocation, radius: Double) -> String {
        return "\(String(format: "%.4f", location.coordinate.latitude)),\(String(format: "%.4f", location.coordinate.longitude))_\(radius)"
    }
    
    private func getRandomLoadingTip() -> String {
        let tips = [
            "Tap ❤️ on places you love to get better recommendations",
            "Use the search radius to find places exactly how far you want to travel",
            "Swipe through categories to discover new types of experiences",
            "Pull down to refresh and get new personalized recommendations",
            "Your location helps us find the most relevant nearby places"
        ]
        return tips.randomElement() ?? tips[0]
    }
    
    // MARK: - Main Content Sections (Existing UI code stays the same)
    // Keep all existing sections but remove modernEmptyStateView
    
    // MARK: - Dynamic Categories Section (Enhanced)
    private var dynamicCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("✨ Curated Just for You")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("AI-powered recommendations updated in real-time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await refreshAIRecommendations()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            // Dynamic Category Rows
            ForEach(aiGeneratedCategories, id: \.id) { category in
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(generateShortCategoryTitle(category))
                            .font(.system(size: 18, weight: .bold))
                            .themedText(.primary)
                        
                        Spacer()
                        
                        Text("\(category.places.count) places")
                            .font(.system(size: 14, weight: .medium))
                            .themedText(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    if !category.places.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(category.places, id: \.id) { place in
                                    ModernPlaceCard(
                                        place: place,
                                        onTap: {
                                            selectedPlace = place
                                            showingPlaceDetail = true
                                        },
                                        onFavorite: {
                                            favoritesManager.toggleFavorite(place)
                                        },
                                        isFavorite: favoritesManager.isFavorite(place),
                                        locationManager: locationManager
                                    )
                                    .frame(width: 280)
                                }
                                
                                // Load more button if available
                                if category.places.count >= 10 {
                                    Button(action: {
                                        Task {
                                            await loadMorePlacesForCategory(category.id)
                                        }
                                    }) {
                                        VStack {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            Text("Load More")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                        .frame(width: 100, height: 120)
                                        .background(Color.secondary.opacity(0.3))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
    }
    
    private func refreshAIRecommendations() async {
        guard let location = locationManager.selectedLocation else { return }
        
        await MainActor.run {
            isGeneratingCategories = true
        }
        
        // Regenerate AI categories
        await DynamicCategoryManager.shared.generateDynamicCategories(location: location)
        
        await MainActor.run {
            aiGeneratedCategories = DynamicCategoryManager.shared.dynamicCategories
            isGeneratingCategories = false
        }
    }
    
    private func loadMorePlacesForCategory(_ categoryId: String) async {
        // Implementation for loading more places in a specific AI category
        // This would extend the current category with more places
        guard let location = locationManager.selectedLocation else { return }
        
        // Find the category and load more places for it
        if let categoryIndex = aiGeneratedCategories.firstIndex(where: { $0.id == categoryId }) {
            let category = aiGeneratedCategories[categoryIndex]
            
            // Load more places for this specific category using PlaceDataService
            placeDataService.loadMorePlaces(for: category.category, location: location, radius: selectedRadius)
            
            // The UI will automatically update when placeDataService.placesByCategory changes
            print("✅ Loading more places for category: \(category.title)")
        }
    }
    
    // MARK: - UI Sections
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Discover")
                    .font(.system(size: 32, weight: .bold))
                    .themedText(.primary)
                
                Text("AI-curated experiences near you")
                    .font(.system(size: 16, weight: .medium))
                    .themedText(.secondary)
            }
            
            Spacer()
            
            NavigationLink(destination: DeveloperScreenView()) {
                Circle()
                    .fill(theme.travelBlue.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "gear")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(theme.travelBlue)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
    
    private var locationStatusSection: some View {
        HStack(spacing: 16) {
            // Location Status
            HStack(spacing: 8) {
                Circle()
                    .fill(locationStatusColor)
                    .frame(width: 8, height: 8)
                
                Text(weatherService.currentWeather?.cityName ?? locationStatusText)
                    .font(.system(size: 16, weight: .semibold))
                    .themedText(.primary)
            }
            
            Spacer()
            
            // Weather Info
            if let weather = weatherService.currentWeather {
                HStack(spacing: 8) {
                    Image(systemName: weather.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.travelOrange)
                    
                    Text("\(weather.temperature)°F")
                        .font(.system(size: 16, weight: .semibold))
                        .themedText(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var searchSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(theme.tertiaryText)
            
            TextField("Discover amazing places...", text: $searchText)
                .font(.system(size: 16, weight: .medium))
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.tertiaryText)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(theme.travelBlue.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    private var distanceSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Search Radius")
                    .font(.system(size: 18, weight: .semibold))
                    .themedText(.primary)
                
                Spacer()
                
                Text("\(String(format: "%.1f", selectedRadius)) mi")
                    .font(.system(size: 16, weight: .medium))
                    .themedText(.secondary)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([0.5, 1.0, 2.0, 3.0, 5.0], id: \.self) { radius in
                        radiusButton(for: radius)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func radiusButton(for radius: Double) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedRadius = radius
            }
        }) {
            Text("\(String(format: "%.1f", radius))mi")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selectedRadius == radius ? .white : theme.travelBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selectedRadius == radius ? theme.travelBlue : theme.travelBlue.opacity(0.1))
                )
        }
        .scaleEffect(selectedRadius == radius ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedRadius)
    }
    
    private var traditionCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Browse Categories")
                    .font(.system(size: 20, weight: .bold))
                    .themedText(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(PlaceCategory.allCases, id: \.self) { category in
                        TraditionalCategoryButton(category: category, locationManager: locationManager, selectedRadius: selectedRadius)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var infiniteScrollPlaceSections: some View {
        VStack(spacing: 32) {
            ForEach(PlaceCategory.allCases, id: \.self) { category in
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(category.displayName)
                            .font(.system(size: 20, weight: .bold))
                            .themedText(.primary)
                        
                        Spacer()
                        
                        Text("\((placeDataService.placesByCategory[category] ?? []).count) places")
                            .font(.system(size: 14, weight: .medium))
                            .themedText(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(placeDataService.placesByCategory[category] ?? [], id: \.id) { place in
                                ModernPlaceCard(
                                    place: place,
                                    onTap: {
                                        selectedPlace = place
                                        showingPlaceDetail = true
                                    },
                                    onFavorite: {
                                        favoritesManager.toggleFavorite(place)
                                    },
                                    isFavorite: favoritesManager.isFavorite(place),
                                    locationManager: locationManager
                                )
                                .frame(width: 280)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var locationStatusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return theme.travelGreen
        default:
            return theme.travelRed
        }
    }
    
    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return locationManager.selectedLocationName
        default:
            return "Location access needed"
        }
    }
    
    private var locationPermissionView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 20) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 80, weight: .medium))
                    .foregroundColor(theme.travelBlue)
                
                VStack(spacing: 12) {
                    Text("Location Access Required")
                        .font(.system(size: 24, weight: .bold))
                        .themedText(.primary)
                    
                    Text("PlanIt needs access to your location to discover amazing places near you.")
                        .font(.system(size: 16, weight: .medium))
                        .themedText(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Button("Enable Location") {
                locationManager.requestLocationPermission()
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.travelBlue)
            )
            .padding(.horizontal, 40)
        }
        .padding(.horizontal, 40)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(theme.travelBlue)
            
            Text("Discovering amazing places...")
                .font(.system(size: 16, weight: .medium))
                .themedText(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.travelOrange)
            
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .themedText(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                if let location = locationManager.selectedLocation {
                    loadPlacesAndGenerateCategories(for: location)
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.travelBlue)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func handleInitialSetup() {
        print("🎯 Handle Initial Setup - Authorization: \(locationManager.authorizationStatus)")
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestLocationPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = locationManager.selectedLocation {
                print("🚀 Location available, loading places immediately")
                loadPlacesAndGenerateCategories(for: location)
            } else {
                print("🔍 Getting current location")
                locationManager.getCurrentLocation()
            }
        case .denied, .restricted:
            // For demo purposes, show content without location
            print("⚠️ Location denied/restricted - showing demo content")
            Task {
                // Generate sample categories without location
                await DynamicCategoryManager.shared.generateSampleCategories()
            }
        @unknown default:
            break
        }
    }
    
    private func loadPlacesAndGenerateCategories(for location: CLLocation) {
        // Load places for all categories
        placeDataService.loadPlacesForAllCategories(at: location, radius: selectedRadius)
        
        // Fetch weather
        weatherService.fetchWeather(for: location)
        
        // Generate AI categories
        generateAICategories()
    }
    
    private func generateAICategories() {
        guard !isGeneratingCategories else { return }
        
        isGeneratingCategories = true
        
        Task {
            if let location = locationManager.selectedLocation {
                await DynamicCategoryManager.shared.generateDynamicCategories(location: location)
                
                await MainActor.run {
                    self.aiGeneratedCategories = DynamicCategoryManager.shared.dynamicCategories
                    self.isGeneratingCategories = false
                }
            } else {
                await MainActor.run {
                    self.isGeneratingCategories = false
                }
            }
        }
    }
    
    private func getTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
    
    private func getUserPreferences() -> [String] {
        // Return user preferences based on favorites and past interactions
        let favorites = FavoritesManager.shared.getFavoritesByCategory()
        return favorites.keys.map { $0.rawValue }
    }
    
    private func generateShortCategoryTitle(_ category: DynamicCategory) -> String {
        // Use the AI-generated personalized title with emoji if available
        if !category.title.isEmpty {
            return "\(category.personalizedEmoji) \(category.title)"
        }
        
        // Fallback to category-specific titles with emojis
        switch category.category {
        case .restaurants:
            return "🍽️ Let's Dine Out"
        case .cafes:
            return "☕ Coffee Break Time"
        case .bars:
            return "🍸 Night Out Plans"
        case .venues:
            return "🎭 Entertainment Tonight"
        case .shopping:
            return "🛍️ Shopping Adventures"
        }
    }
    
    private func generatePersonalizedSubtitle(_ category: DynamicCategory) -> String {
        // First, try to use the AI-generated reasoning for why this category was selected
        if !category.reasoning.isEmpty {
            // Make the reasoning more conversational and truncated to fit properly
            let cleanReasoning = category.reasoning
                .replacingOccurrences(of: "Based on your", with: "Because you")
                .replacingOccurrences(of: "based on your", with: "because you")
                .replacingOccurrences(of: "You", with: "you")
            
            // Ensure it fits on the page - limit to 50 characters to be safe
            if cleanReasoning.count <= 50 {
                return cleanReasoning
            } else {
                // Find a good breaking point near word boundaries
                let truncated = String(cleanReasoning.prefix(47))
                if let lastSpace = truncated.lastIndex(of: " ") {
                    return String(truncated[..<lastSpace]) + "..."
                } else {
                    return String(cleanReasoning.prefix(47)) + "..."
                }
            }
        }
        
        // Secondary: Use user fingerprint data for personalization
        let userLikes = fingerprintManager.fingerprint?.likes ?? []
        let userInteractionLogs = fingerprintManager.fingerprint?.interactionLogs ?? []
        
        if !userLikes.isEmpty {
            let randomLike = userLikes.randomElement() ?? ""
            if !randomLike.isEmpty && randomLike.count <= 35 {
                return "Because you liked \(randomLike)"
            }
        }
        
        if !userInteractionLogs.isEmpty {
            // Extract place names from interaction logs
            let recentPlaces = userInteractionLogs.compactMap { log in
                log["placeName"]?.value as? String
            }.prefix(3)
            
            if let recentPlace = recentPlaces.randomElement() {
                let truncatedPlace = recentPlace.count > 25 ? String(recentPlace.prefix(25)) + "..." : recentPlace
                return "Because you visited \(truncatedPlace)"
            }
        }
        
        // Ultimate fallback with more specific and engaging descriptions
        switch category.category {
        case .restaurants:
            return "Curated dining for your taste"
        case .cafes:
            return "Perfect coffee moments await"
        case .bars:
            return "Nightlife that matches your vibe"
        case .venues:
            return "Entertainment picked just for you"
        case .shopping:
            return "Unique finds for your style"
        }
    }
    
    // MARK: - Skeleton Placeholder
    private var skeletonView: some View {
        VStack(spacing: 24) {
            ForEach(0..<5, id: \..self) { idx in
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .frame(height: idx == 0 ? 40 : 180) // first placeholder like header, others like cards
                    .redacted(reason: .placeholder)
                    .shimmer()
                    .padding(.horizontal, 20)
            }
            Spacer()
        }
        .padding(.top, 120)
        .allowsHitTesting(false)
    }
    
    private func setupCacheObservation() {
        // hide skeleton when data arrives
        placeDataService.$placesByCategory
            .receive(on: DispatchQueue.main)
            .sink { dict in
                if !dict.isEmpty { showSkeleton = false }
            }
            .store(in: &cancellables)
    }
}

#Preview {
    ModernMainScreen(locationManager: LocationManager())
} 