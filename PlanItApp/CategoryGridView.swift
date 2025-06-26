//


//  CategoryGridView.swift
//  PlanIt
//
//  Created by Assistant on 6/12/25.
//

import SwiftUI
import CoreLocation

struct CategoryGridView: View {
    let category: PlaceCategory
    let locationManager: LocationManager
    let selectedRadius: Double
    
    @StateObject private var placeDataService = PlaceDataService.shared
    @StateObject private var cacheManager = PlaceDetailCacheManager.shared
    @State private var places: [Place] = []
    @State private var cachedPlaces: [Place] = []
    @State private var isInitialLoad = true
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var selectedSort: SortOption = .trending
    
    // Grid configuration
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // Filtered by search
    private var filteredPlaces: [Place] {
        if searchText.isEmpty {
            return places
        } else {
            return places.filter { place in
                place.name.localizedCaseInsensitiveContains(searchText) ||
                place.location.localizedCaseInsensitiveContains(searchText) ||
                place.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Sorted according to selected option
    private var sortedPlaces: [Place] {
        let list = filteredPlaces
        switch selectedSort {
        case .trending:
            return list
        case .rating:
            return list.sorted { $0.rating > $1.rating }
        case .distance:
            guard let user = locationManager.selectedLocation else { return list }
            return list.sorted {
                distance(to: $0, user: user) < distance(to: $1, user: user)
            }
        case .price:
            return list.sorted { $0.priceRange.count < $1.priceRange.count }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            searchSection
            
            // Sort bar
            sortSection
            
            // Places Grid with Infinite Scroll
            placesGridSection
        }
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
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("Search \(category.rawValue.lowercased())...", text: $searchText)
                    .font(.system(size: 16, weight: .medium))
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Sort Section
    
    private var sortSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedSort = option
                        }
                    }) {
                        Text(option.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selectedSort == option ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedSort == option ? Color.blue : Color.gray.opacity(0.2))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Places Grid Section
    
    private var placesGridSection: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                // Display places with cache indication
                ForEach(Array(sortedPlaces.enumerated()), id: \.element.id) { index, place in
                    CategoryGridPlaceCard(
                        place: place,
                        userLocation: locationManager.selectedLocation,
                        category: category,
                        isCached: cachedPlaces.contains { $0.id == place.id }
                    )
                    .onAppear {
                        // Cache every viewed place
                        cacheManager.cacheViewedPlace(place, for: category)
                        
                        // Load more places when approaching the end
                        if index >= sortedPlaces.count - 4 {
                            loadMorePlaces()
                        }
                    }
                }
                
                // Loading footer
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
        } else if placeDataService.hasMorePlaces[category] == false && !sortedPlaces.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
                
                Text("All \(category.rawValue.lowercased()) loaded!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(sortedPlaces.count) places found")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else if sortedPlaces.isEmpty && !placeDataService.isLoading {
            VStack(spacing: 12) {
                Image(systemName: category.iconName)
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: category.color).opacity(0.5))
                
                Text("No \(category.rawValue.lowercased()) found")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                if !searchText.isEmpty {
                    Text("Try adjusting your search")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
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
            print("🗂️ Loaded \(cachedPlaces.count) cached places for \(category.rawValue)")
        }
    }
    
    private func updatePlaces(from placesByCategory: [PlaceCategory: [Place]]) {
        if let categoryPlaces = placesByCategory[category] {
            var seen = Set<String>()
            var unique: [Place] = []
            for p in categoryPlaces {
                let key = p.googlePlaceId ?? p.name.lowercased()
                if !seen.contains(key) {
                    seen.insert(key)
                    unique.append(p)
                }
            }
            places = unique
        }
    }
    
    private func loadMorePlaces() {
        guard let location = locationManager.selectedLocation else { return }
        placeDataService.loadMorePlaces(for: category, location: location, radius: selectedRadius)
    }
    
    private func refreshPlaces() async {
        guard let location = locationManager.selectedLocation else { return }
        
        isRefreshing = true
        
        // Clear current data and reload
        places = []
        cachedPlaces = []
        placeDataService.placesByCategory[category] = []
        
        // Reload with fresh data
        placeDataService.loadPlacesForAllCategories(at: location, radius: selectedRadius, initialLoad: true)
        
        // Wait for new data
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        isRefreshing = false
    }
    
    // Helper for distance sorting
    private func distance(to place: Place, user: CLLocation) -> Double {
        guard let coords = place.coordinates else { return Double.infinity }
        let location = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
        return user.distance(from: location)
    }
}

// MARK: - Category Grid Place Card
struct CategoryGridPlaceCard: View {
    let place: Place
    let userLocation: CLLocation?
    let category: PlaceCategory
    let isCached: Bool
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var cacheManager = PlaceDetailCacheManager.shared
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .topLeading) {
                    CachedGooglePlacesPhotoView(
                        place: place,
                        width: 160,
                        height: 120,
                        onImageLoaded: { image in
                            let cacheKey = "\(place.id)_grid_image"
                            cacheManager.cacheImage(image, for: cacheKey)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Cache indicator
                    if isCached {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                            
                            Text("Cached")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue.opacity(0.8))
                        )
                        .padding(8)
                    }
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        favoritesManager.toggleFavorite(place)
                    }
                }) {
                    Image(systemName: favoritesManager.isFavorite(place) ? "heart.fill" : "heart")
                        .font(.system(size: 14))
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
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                }
                .padding(8)
                .zIndex(1)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(place.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        
                        Text(String(format: "%.1f", place.rating))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("(\(place.reviewCount))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Spacer()
                    
                    Text(place.priceRange)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: category.color))
                }
                
                Text(place.location)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Distance
                if !place.distanceFrom(userLocation).isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        
                        Text(place.distanceFrom(userLocation))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .scaleEffect(1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: favoritesManager.favoriteItems.contains(place.id))
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                PlaceDetailView(place: place)
            }
        }
    }
}

#Preview {
    NavigationView {
        CategoryGridView(
            category: .restaurants, 
            locationManager: LocationManager(), 
            selectedRadius: 2.0
        )
    }
} 