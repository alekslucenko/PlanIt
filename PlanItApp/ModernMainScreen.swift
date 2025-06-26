import SwiftUI
import CoreLocation

struct ModernMainScreen: View {
    @State private var selectedCategory: PlaceCategory? = nil
    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var showLocationPermissionAlert = false
    @State private var selectedRadius: Double = 2.0 // Default 2 miles
    @State private var selectedPlace: Place?
    @State private var showingPlaceDetail = false
    @State private var refreshTrigger = false
    
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
    @State private var aiGeneratedCategories: [DynamicCategory] = []
    @State private var isGeneratingCategories = false
    
    // Explicit initializer to accept LocationManager
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()
            
            if locationManager.authorizationStatus == .denied || 
               locationManager.authorizationStatus == .restricted || 
               locationManager.authorizationStatus == .notDetermined {
                locationPermissionView
            } else if dynamicCategoryManager.isGeneratingCategories {
                modernCategoryLoadingView
            } else if dynamicCategoryManager.dynamicCategories.isEmpty {
                modernEmptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        headerSection
                        
                        // Location & Weather Status
                        locationStatusSection
                        
                        // Search Bar
                        searchSection
                        
                        // Distance Selector
                        distanceSelector
                        
                        // AI Generated Categories
                        if !aiGeneratedCategories.isEmpty {
                            aiCategoriesSection
                        }
                        
                        // Traditional Categories
                        traditionCategoriesSection
                        
                        // Infinite Scroll Place Sections
                        if placeDataService.isLoading {
                            loadingView
                        } else if let errorMessage = placeDataService.errorMessage {
                            errorView(errorMessage)
                        } else {
                            infiniteScrollPlaceSections
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
        }
        .onChange(of: locationManager.selectedLocation) { oldLocation, newLocation in
            if let location = newLocation {
                loadPlacesAndGenerateCategories(for: location)
            }
        }
        .onChange(of: selectedRadius) { oldRadius, newRadius in
            if let location = locationManager.selectedLocation {
                loadPlacesAndGenerateCategories(for: location)
            }
        }
        .onChange(of: fingerprintManager.fingerprint) { oldFingerprint, newFingerprint in
            if newFingerprint != nil, let location = locationManager.selectedLocation {
                print("🧬 Fingerprint updated, refreshing categories...")
                Task {
                    // Force refresh categories with new fingerprint
                    await DynamicCategoryManager.shared.generateDynamicCategories(location: location)
                }
            }
        }
        .onAppear {
            print("👁️ MainScreen appeared")
            handleInitialSetup()
        }
        .task {
            // Ensure we load data even if location is already available
            if let location = locationManager.selectedLocation, dynamicCategoryManager.dynamicCategories.isEmpty {
                print("🚀 Loading places and categories on task startup")
                loadPlacesAndGenerateCategories(for: location)
            }
        }
        .sheet(isPresented: $showingPlaceDetail) {
            if let place = selectedPlace {
                ModernPlaceDetailView(place: place)
            }
        }
    }
    
    // MARK: - Dynamic Categories Section
    private var dynamicCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("✨ Curated Just for You")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("AI-powered recommendations that update each time you open the app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        dynamicCategoryManager.isGeneratingCategories = true
                        dynamicCategoryManager.dynamicCategories = []
                        if let location = locationManager.selectedLocation {
                            loadPlacesAndGenerateCategories(for: location)
                        }
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
            ForEach(dynamicCategoryManager.dynamicCategories, id: \.id) { category in
                VStack(alignment: .leading, spacing: 12) {
                    // Category Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(generateShortCategoryTitle(category))
                                .font(.headline.bold())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Text(generatePersonalizedSubtitle(category))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Category Horizontal Scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            // Show existing places
                            ForEach(category.places) { place in
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
                            
                            // Load more button if there are more places available
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
    
    // MARK: - Loading and Empty States
    private var modernCategoryLoadingView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("🤖 AI is analyzing your preferences...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        // Category title placeholder
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.thinMaterial)
                            .frame(height: 20)
                            .frame(maxWidth: 250)
                        
                        // Places row placeholder
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(0..<3, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.thinMaterial)
                                        .frame(width: 280, height: 200)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .redacted(reason: .placeholder)
        .onAppear {
            // Auto-generate categories if location is available
            if let location = locationManager.selectedLocation {
                Task {
                    generateAICategories()
                }
            }
        }
    }
    
    private var modernEmptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Ready to discover amazing places?")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Our AI will create personalized recommendations based on your preferences")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    // Clear existing categories first to show loading state
                    dynamicCategoryManager.isGeneratingCategories = true
                    dynamicCategoryManager.dynamicCategories = []
                    
                    if let location = locationManager.selectedLocation {
                        loadPlacesAndGenerateCategories(for: location)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if dynamicCategoryManager.isGeneratingCategories {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(dynamicCategoryManager.isGeneratingCategories ? "Generating..." : "Generate My Recommendations")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.blue)
                .cornerRadius(12)
                .opacity(dynamicCategoryManager.isGeneratingCategories ? 0.8 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(dynamicCategoryManager.isGeneratingCategories)
        }
        .padding(40)
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
    
    private var aiCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(theme.travelYellow)
                    
                    Text("AI Curated for You")
                        .font(.system(size: 20, weight: .bold))
                        .themedText(.primary)
                }
                
                Spacer()
                
                if isGeneratingCategories {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(theme.travelYellow)
                }
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(aiGeneratedCategories, id: \.id) { category in
                        AICategoryCard(category: category.category)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
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
    
    private func loadMorePlaces(for category: PlaceCategory) {
        guard let location = locationManager.selectedLocation else { return }
        placeDataService.loadMorePlaces(for: category, location: location, radius: selectedRadius)
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
    
    private func loadMorePlacesForCategory(_ categoryId: String) async {
        guard let currentLocation = locationManager.currentLocation else { return }
        
        let newPlaces = await dynamicCategoryManager.fetchMorePlacesForCategory(
            categoryId, 
            location: currentLocation
        )
        
        // Update the category with new places
        if let categoryIndex = dynamicCategoryManager.dynamicCategories.firstIndex(where: { $0.id == categoryId }) {
            await MainActor.run {
                dynamicCategoryManager.dynamicCategories[categoryIndex].places.append(contentsOf: newPlaces)
            }
        }
    }
}

#Preview {
    ModernMainScreen(locationManager: LocationManager())
} 