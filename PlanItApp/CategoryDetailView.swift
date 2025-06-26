import SwiftUI
import CoreLocation
import UIKit

enum SortOption: String, CaseIterable {
    case trending = "Trending"
    case distance = "Distance"
    case price = "Price"
    case rating = "Rating"
    
    var icon: String {
        switch self {
        case .trending: return "flame.fill"
        case .distance: return "location.fill"
        case .price: return "dollarsign.circle.fill"
        case .rating: return "star.fill"
        }
    }
}

enum PriceRange: String, CaseIterable {
    case budget = "$"
    case moderate = "$$"
    case expensive = "$$$"
    case luxury = "$$$$"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Enhanced Category Detail View
struct EnhancedCategoryDetailView: View {
    let category: PlaceCategory
    let locationManager: LocationManager
    let selectedRadius: Double
    
    @StateObject private var placeDataService = PlaceDataService.shared
    @StateObject private var cacheManager = PlaceDetailCacheManager.shared
    @State private var places: [Place] = []
    @State private var filteredPlaces: [Place] = []
    @State private var cachedPlaces: [Place] = []
    @State private var isInitialLoad = true
    @State private var lastLoadTime = Date()
    @State private var searchText = ""
    @State private var selectedSort: SortOption = .trending
    @State private var showingFilters = false
    @State private var priceFilter: PriceRange? = nil
    @State private var ratingFilter: Double = 0.0
    
    // Grid configuration
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        mainContentView
            .navigationTitle(category.rawValue.capitalized)
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshPlaces()
            }
            .onAppear {
                if isInitialLoad {
                    loadInitialPlaces()
                    isInitialLoad = false
                }
            }
            .onReceive(placeDataService.$placesByCategory) { newPlacesByCategory in
                updatePlaces(from: newPlacesByCategory)
            }
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Enhanced Header with Stats
            headerSection
            
            // Search and Filter Section
            searchAndFilterSection
            
            // Places Grid with Infinite Scroll
            placesGridSection
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(filteredPlaces.count) Places Found")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Within \(String(format: "%.1f", selectedRadius)) miles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Category Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: category.color),
                                    Color(hex: category.color).opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: category.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                .shadow(color: Color(hex: category.color).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // Quick Stats Row
            if !places.isEmpty {
                quickStatsSection
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#F8F9FA"),
                    Color(hex: "#FFFFFF")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var quickStatsSection: some View {
        HStack(spacing: 16) {
            CategoryStatCard(
                title: "Avg Rating",
                value: String(format: "%.1f", averageRating),
                icon: "star.fill",
                color: Color.yellow
            )
            
            CategoryStatCard(
                title: "Price Range",
                value: mostCommonPriceRange,
                icon: "dollarsign.circle.fill",
                color: Color.green
            )
            
            CategoryStatCard(
                title: "Cached",
                value: "\(cachedPlaces.count)",
                icon: "checkmark.circle.fill",
                color: Color.blue
            )
        }
    }
    
    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    TextField("Search \(category.rawValue.lowercased())...", text: $searchText)
                        .font(.system(size: 16))
                        .onChange(of: searchText) { _, newValue in
                            filterAndSortPlaces()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showingFilters.toggle()
                    }
                }) {
                    Image(systemName: showingFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 24))
                        .foregroundColor(showingFilters ? Color(hex: category.color) : .secondary)
                }
            }
            .padding(.horizontal, 20)
            
            // Sort Options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        SortButton(
                            option: option,
                            isSelected: selectedSort == option,
                            category: category
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSort = option
                                filterAndSortPlaces()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Filters (when expanded)
            if showingFilters {
                filtersSection
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .padding(.bottom, 12)
        .background(Color.white)
    }
    
    private var filtersSection: some View {
        VStack(spacing: 16) {
            // Price Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Price Range")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterButton(
                            title: "Any",
                            isSelected: priceFilter == nil,
                            category: category
                        ) {
                            priceFilter = nil
                            filterAndSortPlaces()
                        }
                        
                        ForEach(PriceRange.allCases, id: \.self) { price in
                            FilterButton(
                                title: price.displayName,
                                isSelected: priceFilter == price,
                                category: category
                            ) {
                                priceFilter = price
                                filterAndSortPlaces()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Rating Filter
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Minimum Rating")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(ratingFilter == 0 ? "Any" : "\(String(format: "%.1f", ratingFilter))+")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $ratingFilter, in: 0...5, step: 0.5) {
                    Text("Rating")
                } onEditingChanged: { _ in
                    filterAndSortPlaces()
                }
                .tint(Color(hex: category.color))
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Places Grid Section
    private var placesGridSection: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                // Cached places first (with badge)
                ForEach(Array(filteredPlaces.enumerated()), id: \.element.id) { index, place in
                    EnhancedCategoryPlaceCard(
                        place: place,
                        userLocation: locationManager.selectedLocation,
                        category: category,
                        isCached: cachedPlaces.contains { $0.id == place.id }
                    )
                    .onAppear {
                        // Cache every viewed place
                        cacheManager.cacheViewedPlace(place, for: category)
                        
                        // Advanced pagination with predictive loading
                        handlePagination(for: index)
                    }
                }
                
                // Advanced loading states
                loadingFooterView
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
    }
    
    @ViewBuilder
    private var loadingFooterView: some View {
        if placeDataService.isLoadingMore[category] == true {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(Color(hex: category.color))
                
                Text("Loading more \(category.rawValue.lowercased())...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else if placeDataService.hasMorePlaces[category] == false && !places.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
                
                Text("All \(category.rawValue.lowercased()) loaded!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialPlaces() {
        guard let location = locationManager.selectedLocation else { return }
        
        // Load cached places first for instant display
        loadCachedPlacesFirst()
        
        // Then load fresh data
        placeDataService.loadPlacesForAllCategories(at: location, radius: selectedRadius, initialLoad: true)
    }
    
    private func loadCachedPlacesFirst() {
        cachedPlaces = cacheManager.getCachedPlaces(for: category)
        if !cachedPlaces.isEmpty {
            places = cachedPlaces
            filterAndSortPlaces()
            print("🗂️ Loaded \(cachedPlaces.count) cached places for \(category.rawValue)")
        }
    }
    
    private func updatePlaces(from placesByCategory: [PlaceCategory: [Place]]) {
        let newPlaces = placesByCategory[category] ?? []
        
        // Merge with cached places, avoiding duplicates
        var allPlaces = cachedPlaces
        for place in newPlaces {
            if !allPlaces.contains(where: { $0.googlePlaceId == place.googlePlaceId }) {
                allPlaces.append(place)
            }
        }
        
        places = allPlaces
        filterAndSortPlaces()
        
        // Update cached places
        cachedPlaces = cacheManager.getCachedPlaces(for: category)
    }
    
    private func filterAndSortPlaces() {
        var filtered = places
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { place in
                place.name.localizedCaseInsensitiveContains(searchText) ||
                place.location.localizedCaseInsensitiveContains(searchText) ||
                place.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply price filter
        if let priceFilter = priceFilter {
            filtered = filtered.filter { $0.priceRange == priceFilter.displayName }
        }
        
        // Apply rating filter
        if ratingFilter > 0 {
            filtered = filtered.filter { $0.rating >= ratingFilter }
        }
        
        // Sort places
        switch selectedSort {
        case .trending:
            // Cached places first, then by rating
            filtered.sort { place1, place2 in
                let isCached1 = cachedPlaces.contains { $0.id == place1.id }
                let isCached2 = cachedPlaces.contains { $0.id == place2.id }
                
                if isCached1 && !isCached2 { return true }
                if !isCached1 && isCached2 { return false }
                
                return place1.rating > place2.rating
            }
        case .distance:
            if let userLocation = locationManager.selectedLocation {
                filtered.sort { place1, place2 in
                    guard let coords1Data = place1.coordinates,
                          let coords2Data = place2.coordinates else {
                        return false // Keep original order if coordinates are missing
                    }
                    
                    let coords1 = CLLocation(latitude: coords1Data.latitude, longitude: coords1Data.longitude)
                    let coords2 = CLLocation(latitude: coords2Data.latitude, longitude: coords2Data.longitude)
                    
                    let distance1 = userLocation.distance(from: coords1)
                    let distance2 = userLocation.distance(from: coords2)
                    
                    return distance1 < distance2
                }
            }
        case .price:
            filtered.sort { place1, place2 in
                let price1 = priceRangeToNumber(place1.priceRange)
                let price2 = priceRangeToNumber(place2.priceRange)
                return price1 < price2
            }
        case .rating:
            filtered.sort { $0.rating > $1.rating }
        }
        
        filteredPlaces = filtered
    }
    
    private func handlePagination(for index: Int) {
        // Predictive loading when user is near the end
        if index >= filteredPlaces.count - 5 {
            loadMorePlacesIfNeeded()
        }
    }
    
    private func loadMorePlacesIfNeeded() {
        guard let location = locationManager.selectedLocation,
              placeDataService.hasMorePlaces[category] == true,
              placeDataService.isLoadingMore[category] != true else { return }
        
        print("📡 Loading more places for \(category.rawValue)")
        placeDataService.loadMorePlaces(for: category, location: location, radius: selectedRadius)
    }
    
    private func refreshPlaces() async {
        guard let location = locationManager.selectedLocation else { return }
        
        // Clear current data and reload
        places = []
        cachedPlaces = []
        placeDataService.placesByCategory[category] = []
        
        // Reload with fresh data
        placeDataService.loadPlacesForAllCategories(at: location, radius: selectedRadius, initialLoad: true)
        
        // Wait for new data
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }
    
    // MARK: - Computed Properties
    
    private var averageRating: Double {
        guard !filteredPlaces.isEmpty else { return 0 }
        let sum = filteredPlaces.reduce(0) { $0 + $1.rating }
        return sum / Double(filteredPlaces.count)
    }
    
    private var mostCommonPriceRange: String {
        guard !filteredPlaces.isEmpty else { return "N/A" }
        
        let priceRanges = filteredPlaces.map { $0.priceRange }
        let grouped = Dictionary(grouping: priceRanges) { $0 }
        let mostCommon = grouped.max { $0.value.count < $1.value.count }
        
        return mostCommon?.key ?? "N/A"
    }
    
    private func priceRangeToNumber(_ priceRange: String) -> Int {
        switch priceRange {
        case "$": return 1
        case "$$": return 2
        case "$$$": return 3
        case "$$$$": return 4
        default: return 0
        }
    }
}

// MARK: - Supporting Views

struct SortButton: View {
    let option: SortOption
    let isSelected: Bool
    let category: PlaceCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(option.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : Color(hex: category.color))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color(hex: category.color) : Color(hex: category.color).opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let category: PlaceCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color(hex: category.color) : .gray.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Category Place Card
struct EnhancedCategoryPlaceCard: View {
    let place: Place
    let userLocation: CLLocation?
    let category: PlaceCategory
    let isCached: Bool
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var cacheManager = PlaceDetailCacheManager.shared
    @StateObject private var dynamicCategoryManager = DynamicCategoryManager.shared
    @State private var showingDetail = false
    @State private var userReaction: UserReaction?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            imageSection
            placeInfoSection
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
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
            ZStack(alignment: .topLeading) {
                placeImageView
                cachedBadge
            }
            favoriteButton
        }
    }
    
    private var placeImageView: some View {
        CachedGooglePlacesPhotoView(
            place: place,
            width: UIScreen.main.bounds.width / 2 - 30,
            height: 140,
            onImageLoaded: { image in
                let cacheKey = "\(place.id)_category_image"
                cacheManager.cacheImage(image, for: cacheKey)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    @ViewBuilder
    private var cachedBadge: some View {
        if isCached {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                
                Text("CACHED")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.green)
            )
            .padding(8)
        }
    }
    
    private var favoriteButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                favoritesManager.toggleFavorite(place)
            }
        }) {
            Image(systemName: favoritesManager.isFavorite(place) ? "heart.fill" : "heart")
                .font(.caption)
                .foregroundColor(favoritesManager.isFavorite(place) ? .pink : .white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        }
        .padding(8)
        .zIndex(1)
    }
    
    private var placeInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            placeTitleView
            ratingAndPriceRow
            locationRow
            reactionButtons
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    
    private var placeTitleView: some View {
        Text(place.name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
    
    private var ratingAndPriceRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            
            Text(String(format: "%.1f", place.rating))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("(\(place.reviewCount))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))
            
            Spacer()
            
            Text(place.priceRange)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: category.color))
        }
    }
    
    private var locationRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.system(size: 10))
                .foregroundColor(.blue)
            
            Text(place.location)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            if !place.distanceFrom(userLocation).isEmpty {
                Text(place.distanceFrom(userLocation))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var reactionButtons: some View {
        HStack {
            Spacer()
            
            thumbsUpButton
            thumbsDownButton
        }
    }
    
    private var thumbsUpButton: some View {
        Button(action: {
            Task {
                userReaction = .liked
                await dynamicCategoryManager.recordPlaceInteraction(place: place, interaction: .liked)
            }
        }) {
            Image(systemName: userReaction == .liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(userReaction == .liked ? .green : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var thumbsDownButton: some View {
        Button(action: {
            Task {
                userReaction = .disliked
                await dynamicCategoryManager.recordPlaceInteraction(place: place, interaction: .disliked)
            }
        }) {
            Image(systemName: userReaction == .disliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(userReaction == .disliked ? .red : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isCached ? .green.opacity(0.3) : Color.white.opacity(0.4), lineWidth: isCached ? 1.5 : 1)
            )
    }
}

// MARK: - Category Stat Card
struct CategoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    EnhancedCategoryDetailView(category: .restaurants, locationManager: LocationManager(), selectedRadius: 2.0)
} 