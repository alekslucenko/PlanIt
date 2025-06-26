import SwiftUI
import CoreLocation

struct FavoritesView: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: PlaceCategory?
    @State private var showingEmptyState = false
    
    private var filteredFavorites: [PlaceCategory: [Place]] {
        let categorizedFavorites = favoritesManager.getFavoritesByCategory()
        
        if searchText.isEmpty && selectedCategory == nil {
            return categorizedFavorites
        }
        
        var filtered: [PlaceCategory: [Place]] = [:]
        
        for (category, places) in categorizedFavorites {
            // Filter by category if selected
            if let selectedCategory = selectedCategory, category != selectedCategory {
                continue
            }
            
            // Filter by search text
            let matchingPlaces = places.filter { place in
                searchText.isEmpty || 
                place.name.localizedCaseInsensitiveContains(searchText) ||
                place.location.localizedCaseInsensitiveContains(searchText) ||
                category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
            
            if !matchingPlaces.isEmpty {
                filtered[category] = matchingPlaces
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundGradient
                    .ignoresSafeArea()
                
                if favoritesManager.favoriteCount == 0 {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        // Header and Search
                        headerSection
                        
                        // Category Filter
                        categoryFilterSection
                        
                        // Favorites Content
                        if filteredFavorites.isEmpty {
                            noResultsView
                        } else {
                            favoritesContent
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Favorites")
                        .font(.system(size: 28, weight: .bold))
                        .themedText(.primary)
                    
                    Text("\(favoritesManager.favoriteCount) saved places")
                        .font(.system(size: 16, weight: .medium))
                        .themedText(.secondary)
                }
                
                Spacer()
                
                // Sort/Filter Menu
                Menu {
                    Button("All Categories") {
                        selectedCategory = nil
                    }
                    
                    Divider()
                    
                    ForEach(PlaceCategory.allCases, id: \.self) { category in
                        Button(category.rawValue.capitalized) {
                            selectedCategory = category
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(themeManager.travelBlue)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(themeManager.cardBackground)
                                .overlay(
                                    Circle()
                                        .stroke(themeManager.travelBlue.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            // Search Bar
            searchBarSection
        }
    }
    
    private var searchBarSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeManager.tertiaryText)
            
            TextField("Search favorites...", text: $searchText)
                .font(.system(size: 16, weight: .medium))
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.tertiaryText)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All Categories Button
                categoryFilterButton(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    color: themeManager.travelBlue
                ) {
                    selectedCategory = nil
                }
                
                ForEach(PlaceCategory.allCases, id: \.self) { category in
                    if favoritesManager.getFavoritesByCategory()[category]?.isEmpty == false {
                        categoryFilterButton(
                            title: category.rawValue.capitalized,
                            isSelected: selectedCategory == category,
                            color: Color(hex: category.color)
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    
    private func categoryFilterButton(title: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? color : color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                        )
                )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var favoritesContent: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(Array(filteredFavorites.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { category in
                    if let places = filteredFavorites[category], !places.isEmpty {
                        FavoritesCategorySection(
                            category: category,
                            places: places,
                            locationManager: locationManager
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(themeManager.travelPink.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(themeManager.travelPink)
                }
                
                VStack(spacing: 12) {
                    Text("No Favorites Yet")
                        .font(.system(size: 24, weight: .bold))
                        .themedText(.primary)
                    
                    Text("Start exploring and tap the heart icon\non places you love to save them here")
                        .font(.system(size: 16, weight: .medium))
                        .themedText(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            VStack(spacing: 16) {
                // Tips
                FavoritesTipRow(
                    icon: "heart.circle.fill",
                    title: "Tap hearts to save places",
                    color: themeManager.travelPink
                )
                
                FavoritesTipRow(
                    icon: "square.grid.2x2.fill",
                    title: "Organize by categories",
                    color: themeManager.travelBlue
                )
                
                FavoritesTipRow(
                    icon: "magnifyingglass.circle.fill",
                    title: "Search your saved places",
                    color: themeManager.travelGreen
                )
            }
        }
        .padding(.horizontal, 40)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(themeManager.tertiaryText)
            
            VStack(spacing: 8) {
                Text("No matching favorites")
                    .font(.system(size: 18, weight: .semibold))
                    .themedText(.primary)
                
                Text(searchText.isEmpty ? "No favorites in this category" : "Try a different search term")
                    .font(.system(size: 14, weight: .medium))
                    .themedText(.secondary)
            }
            
            Button("Clear Filters") {
                searchText = ""
                selectedCategory = nil
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(themeManager.travelBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Favorites Category Section
struct FavoritesCategorySection: View {
    let category: PlaceCategory
    let places: [Place]
    let locationManager: LocationManager
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: category.color))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color(hex: category.color).opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue.capitalized)
                            .font(.system(size: 18, weight: .bold))
                            .themedText(.primary)
                        
                        Text("\(places.count) place\(places.count == 1 ? "" : "s")")
                            .font(.system(size: 14, weight: .medium))
                            .themedText(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Places Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(places, id: \.id) { place in
                    FavoritePlaceCard(
                        place: place,
                        userLocation: locationManager.selectedLocation
                    )
                }
            }
        }
    }
}

// MARK: - Favorite Place Card
struct FavoritePlaceCard: View {
    let place: Place
    let userLocation: CLLocation?
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var reactionManager = ReactionManager.shared
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            imageSection
            infoSection
        }
        .background(cardBackground)
        .shadow(
            color: themeManager.isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.1),
            radius: 6,
            x: 0,
            y: 3
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
            PlaceImageView(place: place, width: 160, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            favoriteButton
        }
    }
    
    private var favoriteButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                favoritesManager.toggleFavorite(place)
            }
        }) {
            Image(systemName: "heart.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.travelPink)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .padding(8)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(place.name)
                .font(.system(size: 14, weight: .semibold))
                .themedText(.primary)
                .lineLimit(2)
            
            ratingAndDistanceRow
            
            Text(place.location)
                .font(.system(size: 11, weight: .regular))
                .themedText(.tertiary)
                .lineLimit(2)
            
            reactionButtonsRow
        }
        .padding(.horizontal, 4)
    }
    
    private var ratingAndDistanceRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
                
                Text(String(format: "%.1f", place.rating))
                    .font(.system(size: 12, weight: .medium))
                    .themedText(.secondary)
            }
            
            Spacer()
            
            if !place.distanceFrom(userLocation).isEmpty {
                Text(place.distanceFrom(userLocation))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.travelBlue)
            }
        }
    }
    
    private var reactionButtonsRow: some View {
        HStack(spacing: 16) {
            ReactionButton(
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
                        targetId: "favorites_thumbs_up",
                        targetType: "place_reaction",
                        coordinates: CGPoint(x: 0, y: 0)
                    )
                }
            }
            
            ReactionButton(
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
                        targetId: "favorites_thumbs_down",
                        targetType: "place_reaction",
                        coordinates: CGPoint(x: 0, y: 0)
                    )
                }
            }
            
            Spacer()
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(themeManager.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
            )
    }
    

}

// MARK: - Reaction Button
struct ReactionButton: View {
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
                    .fill(isActive ? color.opacity(0.1) : Color.gray.opacity(0.1))
            )
        }
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

// MARK: - Place Image View
struct PlaceImageView: View {
    let place: Place
    let width: CGFloat
    let height: CGFloat
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        VStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(Color(hex: place.category.color))
                            } else {
                                Image(systemName: place.category.iconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: place.category.color))
                            }
                        }
                    )
                    .frame(width: width, height: height)
            }
        }
        .onAppear {
            loadImageIfNeeded()
        }
    }
    
    private func loadImageIfNeeded() {
        guard let imageUrl = place.images.first, !imageUrl.isEmpty else {
            isLoading = false
            return
        }
        
        // Simple image loading (in production, use proper caching)
        if imageUrl.hasPrefix("http"), let url = URL(string: imageUrl) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                DispatchQueue.main.async {
                    if let data = data, let image = UIImage(data: data) {
                        self.loadedImage = image
                    }
                    self.isLoading = false
                }
            }.resume()
        } else {
            isLoading = false
        }
    }
}

// MARK: - Favorites Tip Row
struct FavoritesTipRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .themedText(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
} 