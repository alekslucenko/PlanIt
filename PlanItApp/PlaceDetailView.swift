//
//  PlaceDetailView.swift
//  PlanIt
//
//  Created by Aleks Lucenko on 6/10/25.
//

import SwiftUI
import CoreLocation
import UIKit

// MARK: - Favorites Manager
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    @Published var favoriteItems: Set<UUID> = []
    @Published var favoritePlaces: [Place] = []
    
    private init() {
        loadFavorites()
    }
    
    func toggleFavorite(_ place: Place) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            if favoriteItems.contains(place.id) {
                favoriteItems.remove(place.id)
                favoritePlaces.removeAll { $0.id == place.id }
            } else {
                favoriteItems.insert(place.id)
                favoritePlaces.append(place)
            }
            saveFavorites()
        }
    }
    
    func isFavorite(_ place: Place) -> Bool {
        return favoriteItems.contains(place.id)
    }
    
    func getFavoritesByCategory() -> [PlaceCategory: [Place]] {
        var categorizedFavorites: [PlaceCategory: [Place]] = [:]
        
        for place in favoritePlaces {
            if categorizedFavorites[place.category] == nil {
                categorizedFavorites[place.category] = []
            }
            categorizedFavorites[place.category]?.append(place)
        }
        
        return categorizedFavorites
    }
    
    var favoriteCount: Int {
        return favoritePlaces.count
    }
    
    private func saveFavorites() {
        // For now, we'll just keep them in memory
        // In a real app, you'd save to UserDefaults or Core Data
        print("💾 Saved \(favoriteItems.count) favorites")
    }
    
    private func loadFavorites() {
        // Load from persistent storage if needed
        print("📂 Loaded favorites")
    }
}

// MARK: - Persistent Cache Manager
class PlaceDetailCacheManager: ObservableObject {
    static let shared = PlaceDetailCacheManager()
    
    @Published private var detailedPlacesCache: [String: CachedPlaceData] = [:]
    @Published private var imageCache: [String: UIImage] = [:]
    @Published private var categoryPlacesCache: [String: [Place]] = [:]
    @Published private var viewedPlacesCache: [PlaceCategory: Set<UUID>] = [:] // Track viewed places
    
    private init() {
        loadCachedData()
        setupAppLifecycleObservers()
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.saveAllCacheData()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.saveAllCacheData()
        }
    }
    
    struct CachedPlaceData: Codable {
        let detailedPlace: Place
        let reviews: [EnhancedReview]
        let sentimentAnalysis: CustomerSentiment?
        let advancedSentimentAnalysis: AdvancedSentimentAnalysisData?
        let cacheDate: Date
        
        var isExpired: Bool {
            Date().timeIntervalSince(cacheDate) > 3600 // 1 hour expiry
        }
    }
    
    struct AdvancedSentimentAnalysisData: Codable {
        let overallScore: Double
        let totalReviews: Int
        let categories: [SentimentCategoryData]
        let summary: String
        let lastUpdated: Date
    }
    
    struct SentimentCategoryData: Codable {
        let name: String
        let score: Double
        let description: String
        let color: String
    }
    
    // MARK: - Viewed Places Caching
    
    func cacheViewedPlace(_ place: Place, for category: PlaceCategory) {
        if viewedPlacesCache[category] == nil {
            viewedPlacesCache[category] = Set<UUID>()
        }
        
        if !viewedPlacesCache[category]!.contains(place.id) {
            viewedPlacesCache[category]!.insert(place.id)
            
            // Cache the place in category cache as well
            var existingPlaces = categoryPlacesCache[category.rawValue] ?? []
            if !existingPlaces.contains(where: { $0.id == place.id }) {
                existingPlaces.append(place)
                categoryPlacesCache[category.rawValue] = existingPlaces
            }
            
            print("👁️ Cached viewed place: \(place.name) in category: \(category.rawValue)")
        }
    }
    
    func isPlaceViewed(_ place: Place, in category: PlaceCategory) -> Bool {
        return viewedPlacesCache[category]?.contains(place.id) ?? false
    }
    
    func getViewedPlacesCount(for category: PlaceCategory) -> Int {
        return viewedPlacesCache[category]?.count ?? 0
    }
    
    func getCachedPlaces(for category: PlaceCategory) -> [Place] {
        return categoryPlacesCache[category.rawValue] ?? []
    }
    
    func getCachedData(for placeId: String) -> CachedPlaceData? {
        guard let cached = detailedPlacesCache[placeId], !cached.isExpired else {
            if detailedPlacesCache[placeId] != nil {
                detailedPlacesCache.removeValue(forKey: placeId)
                saveCachedData()
            }
            return nil
        }
        return cached
    }
    
    func cacheData(placeId: String, detailedPlace: Place, reviews: [EnhancedReview], sentimentAnalysis: CustomerSentiment?, advancedSentiment: AdvancedSentimentService.PlaceSentimentAnalysis?) {
        let advancedSentimentData = advancedSentiment.map { analysis in
            AdvancedSentimentAnalysisData(
                overallScore: analysis.overallScore,
                totalReviews: analysis.totalReviews,
                categories: analysis.categories.map { category in
                    SentimentCategoryData(
                        name: category.name,
                        score: category.score,
                        description: category.description,
                        color: category.color
                    )
                },
                summary: analysis.summary,
                lastUpdated: analysis.lastUpdated
            )
        }
        
        let cachedData = CachedPlaceData(
            detailedPlace: detailedPlace,
            reviews: reviews,
            sentimentAnalysis: sentimentAnalysis,
            advancedSentimentAnalysis: advancedSentimentData,
            cacheDate: Date()
        )
        detailedPlacesCache[placeId] = cachedData
        saveCachedData()
        print("💾 Cached data for place: \(detailedPlace.name)")
    }
    
    func getCachedImage(for url: String) -> UIImage? {
        return imageCache[url]
    }
    
    func cacheImage(_ image: UIImage, for url: String) {
        imageCache[url] = image
        // Limit cache size
        if imageCache.count > 200 {
            let oldestKeys = Array(imageCache.keys).prefix(50)
            oldestKeys.forEach { imageCache.removeValue(forKey: $0) }
        }
        print("🖼️ Cached image for key: \(url)")
    }
    
    func cachePlaces(_ places: [Place], for category: PlaceCategory) {
        categoryPlacesCache[category.rawValue] = places
        saveCachedData()
    }
    
    func setCachedPlaces(_ places: [Place], for category: PlaceCategory) {
        categoryPlacesCache[category.rawValue] = places
        saveCachedData()
        print("📝 Set \(places.count) places for \(category.rawValue) cache")
    }
    
    func appendCachedPlaces(_ newPlaces: [Place], for category: PlaceCategory) {
        var existingPlaces = categoryPlacesCache[category.rawValue] ?? []
        
        // Avoid duplicates
        let uniqueNewPlaces = newPlaces.filter { newPlace in
            !existingPlaces.contains { $0.id == newPlace.id }
        }
        
        existingPlaces.append(contentsOf: uniqueNewPlaces)
        categoryPlacesCache[category.rawValue] = existingPlaces
        saveCachedData()
        
        print("📝 Appended \(uniqueNewPlaces.count) new places to \(category.rawValue) cache")
    }
    
    func clearCachedPlaces(for category: PlaceCategory) {
        categoryPlacesCache.removeValue(forKey: category.rawValue)
        viewedPlacesCache.removeValue(forKey: category)
        saveCachedData()
        print("🗑️ Cleared cached places for \(category.rawValue)")
    }
    
    func clearAllCache() {
        detailedPlacesCache.removeAll()
        categoryPlacesCache.removeAll()
        viewedPlacesCache.removeAll()
        imageCache.removeAll()
        saveCachedData()
        saveImageCacheMetadata()
        print("🗑️ Cleared all cache data")
    }
    
    private func saveAllCacheData() {
        saveCachedData()
        saveImageCacheMetadata()
        print("💾 Saved all cache data on app lifecycle event")
    }
    
    private func saveCachedData() {
        if let encoded = try? JSONEncoder().encode(detailedPlacesCache) {
            UserDefaults.standard.set(encoded, forKey: "PlaceDetailCache")
        }
        
        if let encoded = try? JSONEncoder().encode(categoryPlacesCache) {
            UserDefaults.standard.set(encoded, forKey: "CategoryPlacesCache")
        }
        
        // Save viewed places
        let viewedPlacesDict = viewedPlacesCache.mapValues { Array($0) }
        if let encoded = try? JSONEncoder().encode(viewedPlacesDict) {
            UserDefaults.standard.set(encoded, forKey: "ViewedPlacesCache")
        }
    }
    
    private func saveImageCacheMetadata() {
        // Save image cache metadata (not actual images due to size)
        let imageCacheKeys = Array(imageCache.keys)
        UserDefaults.standard.set(imageCacheKeys, forKey: "ImageCacheKeys")
    }
    
    private func loadCachedData() {
        if let data = UserDefaults.standard.data(forKey: "PlaceDetailCache"),
           let decoded = try? JSONDecoder().decode([String: CachedPlaceData].self, from: data) {
            detailedPlacesCache = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: "CategoryPlacesCache"),
           let decoded = try? JSONDecoder().decode([String: [Place]].self, from: data) {
            categoryPlacesCache = decoded
        }
        
        // Load viewed places
        if let data = UserDefaults.standard.data(forKey: "ViewedPlacesCache"),
           let decoded = try? JSONDecoder().decode([PlaceCategory: [UUID]].self, from: data) {
            viewedPlacesCache = decoded.mapValues { Set($0) }
        }
        
        print("📂 Loaded cache data - Categories: \(categoryPlacesCache.keys.count), Viewed: \(viewedPlacesCache.values.reduce(0) { $0 + $1.count })")
    }
    
    func clearExpiredCache() {
        let expiredKeys = detailedPlacesCache.compactMap { key, value in
            value.isExpired ? key : nil
        }
        expiredKeys.forEach { detailedPlacesCache.removeValue(forKey: $0) }
        if !expiredKeys.isEmpty {
            saveCachedData()
        }
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStatistics() -> String {
        let totalCachedPlaces = categoryPlacesCache.values.reduce(0) { $0 + $1.count }
        let totalViewedPlaces = viewedPlacesCache.values.reduce(0) { $0 + $1.count }
        let totalImages = imageCache.count
        
        return "Places: \(totalCachedPlaces), Viewed: \(totalViewedPlaces), Images: \(totalImages)"
    }
}

// MARK: - Simplified Photo Loading View with On-Demand Loading
struct SimplePlacePhotoView: View {
    let photoReference: String
    let placeId: String?
    let width: CGFloat
    let height: CGFloat
    let category: PlaceCategory
    let autoLoad: Bool // Whether to load immediately or wait for tap
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false
    @StateObject private var googlePlacesService = GooglePlacesService()
    @StateObject private var cacheManager = PlaceDetailCacheManager.shared
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else if isLoading {
                loadingView
            } else if loadFailed {
                errorView
            } else {
                placeholderView
            }
        }
        .onAppear {
            checkCacheAndLoad()
        }
    }
    
    private var loadingView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .overlay(
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color(hex: category.color))
                    
                    Text("Loading photo...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            )
            .frame(width: width, height: height)
    }
    
    private var errorView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.05))
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("Photo unavailable")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            )
            .frame(width: width, height: height)
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [
                    Color(hex: category.color).opacity(0.1),
                    Color(hex: category.color).opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: category.color).opacity(0.6))
                    
                    Text("Tap to load photo")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
            )
            .frame(width: width, height: height)
            .onTapGesture {
                loadPhoto()
            }
    }
    
    private func checkCacheAndLoad() {
        let cacheKey = "\(photoReference)_\(Int(width))x\(Int(height))"
        if let cachedImage = cacheManager.getCachedImage(for: cacheKey) {
            loadedImage = cachedImage
            return
        }
        
        if autoLoad {
            loadPhoto()
        }
    }
    
    private func loadPhoto() {
        guard !isLoading, loadedImage == nil else { return }
        
        isLoading = true
        loadFailed = false
        
        // Handle both photo references and default URLs
        if photoReference.hasPrefix("http") {
            loadFromURL(photoReference)
        } else {
            loadFromGooglePlaces()
        }
    }
    
    private func loadFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            isLoading = false
            loadFailed = true
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data, let image = UIImage(data: data) {
                    loadedImage = image
                    let cacheKey = "\(photoReference)_\(Int(width))x\(Int(height))"
                    cacheManager.cacheImage(image, for: cacheKey)
                    print("✅ Loaded URL image")
                } else {
                    loadFailed = true
                    print("❌ Failed to load URL image")
                }
            }
        }.resume()
    }
    
    private func loadFromGooglePlaces() {
        guard let placeId = placeId else {
            print("❌ No place ID available for photo loading")
            isLoading = false
            loadFailed = true
            return
        }
        
        let metadata = GooglePhotoMetadata(
            photoReference: photoReference,
            height: Int(height),
            width: Int(width),
            htmlAttributions: []
        )
        
        googlePlacesService.fetchPhoto(metadata: metadata, maxSize: CGSize(width: width, height: height)) { image in
            DispatchQueue.main.async {
                isLoading = false
                
                if let image = image {
                    loadedImage = image
                    let cacheKey = "\(photoReference)_\(Int(width))x\(Int(height))"
                    cacheManager.cacheImage(image, for: cacheKey)
                    print("✅ Loaded Google Places photo")
                } else {
                    loadFailed = true
                    print("❌ Failed to load Google Places photo")
                }
            }
        }
    }
}

// MARK: - Google Places Photo Loading Image View
struct GooglePlacesPhotoView: View {
    let photoReference: String
    let placeId: String?
    let width: CGFloat
    let height: CGFloat
    let category: PlaceCategory
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var shouldLoad = false
    @State private var hasAppeared = false
    @StateObject private var googlePlacesService = GooglePlacesService()
    @StateObject private var cacheManager = PlaceDetailCacheManager.shared
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(Color(hex: category.color))
                            
                            Image(systemName: category.iconName)
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            
                            Text("Loading photo...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    )
                    .frame(width: width, height: height)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: category.color).opacity(0.6))
                            Text("Tap to load image")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    )
                    .frame(width: width, height: height)
                    .onTapGesture {
                        loadPhoto()
                    }
            }
        }
        .onAppear {
            // Check cache first
            let cacheKey = "\(photoReference)_\(Int(width))x\(Int(height))"
            if let cachedImage = cacheManager.getCachedImage(for: cacheKey) {
                loadedImage = cachedImage
                return
            }
            
            hasAppeared = true
            // For main images, auto-load. For slideshow images, wait for user interaction
            if width < 300 { // Main card images
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    loadPhoto()
                }
            }
        }
        .onChange(of: shouldLoad) { _, newValue in
            if newValue && loadedImage == nil {
                loadPhoto()
            }
        }
    }
    
    private func loadPhoto() {
        guard !isLoading, loadedImage == nil else { return }
        
        // Handle both photo references and default URLs
        if photoReference.hasPrefix("http") {
            // This is a default image URL
            loadFromURL(photoReference)
        } else {
            // This is a Google Places photo reference
            loadFromGooglePlaces()
        }
    }
    
    private func loadFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data, let image = UIImage(data: data) {
                    loadedImage = image
                    let cacheKey = "\(photoReference)_\(Int(width))x\(Int(height))"
                    cacheManager.cacheImage(image, for: cacheKey)
                    print("✅ Loaded default image")
                }
            }
        }.resume()
    }
    
    private func loadFromGooglePlaces() {
        guard let placeId = placeId else {
            print("❌ No place ID available for photo loading")
            return
        }
        
        isLoading = true
        
        // Create metadata from photo reference
        let metadata = GooglePhotoMetadata(
            photoReference: photoReference,
            height: Int(height),
            width: Int(width),
            htmlAttributions: []
        )
        
        googlePlacesService.fetchPhoto(metadata: metadata, maxSize: CGSize(width: width, height: height)) { [self] image in
            DispatchQueue.main.async {
                isLoading = false
                
                if let image = image {
                    loadedImage = image
                    let cacheKey = "\(photoReference)_\(Int(width))x\(Int(height))"
                    cacheManager.cacheImage(image, for: cacheKey)
                    print("✅ Loaded Google Places photo")
                } else {
                    print("❌ Failed to load Google Places photo")
                }
            }
        }
    }
}

// MARK: - Lazy Loading Image View (Legacy - kept for fallback)
struct LazyLoadingAsyncImage: View {
    let url: String
    let width: CGFloat
    let height: CGFloat
    @StateObject private var cacheManager = PlaceDetailCacheManager.shared
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var shouldLoad = false
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        ProgressView()
                            .tint(.blue)
                    )
                    .frame(width: width, height: height)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("Tap to load")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    )
                    .frame(width: width, height: height)
                    .onTapGesture {
                        shouldLoad = true
                    }
            }
        }
        .onAppear {
            // Check cache first
            if let cachedImage = cacheManager.getCachedImage(for: url) {
                loadedImage = cachedImage
            }
        }
        .onChange(of: shouldLoad) { _, newValue in
            if newValue && loadedImage == nil {
                loadImage()
            }
        }
    }
    
    private func loadImage() {
        guard !isLoading, let imageUrl = URL(string: url) else { return }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: imageUrl) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data, let image = UIImage(data: data) {
                    loadedImage = image
                    cacheManager.cacheImage(image, for: url)
                }
            }
        }.resume()
    }
}

struct PlaceDetailView: View {
    let place: Place
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var reviewAggregator = ReviewAggregatorService()
    @StateObject private var placeDataService = PlaceDataService.shared
    @StateObject private var advancedSentimentService = AdvancedSentimentService()
    @StateObject private var cacheManager = PlaceDetailCacheManager.shared
    @StateObject private var geminiAIService = GeminiAIService.shared
    @StateObject private var xpManager = XPManager()
    @State private var detailedPlace: Place?
    @State private var isLoadingDetails = false
    @State private var selectedImageIndex = 0
    @State private var showingAllHours = false
    @State private var showingAllReviews = false
    @State private var currentImageIndex = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var showBackButton = true
    @State private var whyRecommendedText: String = ""
    @State private var isGeneratingExplanation = false
    @State private var hasVisited = false
    @State private var showingVisitAnimation = false
    @State private var showingXPGained = false
    @State private var xpGained = 0
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main background - consistent with app theme
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if isLoadingDetails {
                    loadingView
                } else {
                    mainContent
                }
                
                // Floating back button
                VStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        .padding(.leading, 20)
                        .padding(.top, 60)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAllReviews) {
            AllReviewsView(place: place, reviewAggregator: reviewAggregator)
        }
        .onAppear {
            loadDetailedPlaceInfo()
            loadVisitStatus()
            
            // Load real reviews and perform sentiment analysis
            Task {
                await reviewAggregator.loadReviews(for: currentPlace, initialLoad: true)
                
                // Trigger advanced sentiment analysis once reviews are loaded
                if !reviewAggregator.reviews.isEmpty {
                    await advancedSentimentService.analyzePlaceSentiment(
                        for: currentPlace, 
                        reviews: reviewAggregator.reviews
                    )
                }
                
                // Generate AI recommendation explanation
                await generateWhyRecommended()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color(hex: place.category.color))
            
            Text("Loading place details...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(place.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Image Section with improved styling
                mainImageSection
                
                // Main Content with proper spacing and background
                VStack(spacing: 24) {
                    // Name & Rating Section
                    nameAndRatingSection
                    
                    // Why AI Recommended Section
                    whyRecommendedSection
                    
                    // Status & Basic Info Row
                    statusAndBasicInfoSection
                    
                    // Address & Phone Section
                    addressAndPhoneSection
                    
                    // Visit Button Section
                    visitButtonSection
                    
                    // About Section
                    aboutSection
                    
                    // Enhanced Customer Sentiment Section
                    enhancedCustomerSentimentSection
                    
                    // Reviews Section
                    reviewsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
                .background(Color(.systemBackground))
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - ENHANCED LOADING FUNCTION WITH CACHING
    
    private func loadDetailedPlaceInfo() {
        guard let placeId = place.googlePlaceId else { return }
        
        print("🔍 Loading detailed info for place: \(place.name)")
        
        // Check cache first
        if let cachedData = cacheManager.getCachedData(for: placeId) {
            print("📦 Loading from cache: \(place.name)")
            DispatchQueue.main.async {
                self.detailedPlace = cachedData.detailedPlace
                self.reviewAggregator.reviews = cachedData.reviews
                
                // Restore advanced sentiment analysis if available
                if let advancedData = cachedData.advancedSentimentAnalysis {
                    let categories = advancedData.categories.map { categoryData in
                        AdvancedSentimentService.SentimentCategory(
                            name: categoryData.name,
                            score: categoryData.score,
                            description: categoryData.description,
                            color: categoryData.color
                        )
                    }
                    
                    self.advancedSentimentService.sentimentAnalysis = AdvancedSentimentService.PlaceSentimentAnalysis(
                        overallScore: advancedData.overallScore,
                        totalReviews: advancedData.totalReviews,
                        categories: categories,
                        summary: advancedData.summary,
                        lastUpdated: advancedData.lastUpdated
                    )
                }
                
                self.isLoadingDetails = false
            }
            return
        }
        
        // Load from API if not cached
        isLoadingDetails = true
        
        placeDataService.loadDetailedPlace(for: place) { [self] detailedPlaceResult in
            DispatchQueue.main.async {
                self.detailedPlace = detailedPlaceResult
                self.isLoadingDetails = false
                
                // Cache the detailed place info
                if let detailedPlace = detailedPlaceResult {
                    self.cacheManager.cacheData(
                        placeId: placeId,
                        detailedPlace: detailedPlace,
                        reviews: [],
                        sentimentAnalysis: nil,
                        advancedSentiment: nil
                    )
                }
            }
        }
    }
    
    // Helper to get the current place (detailed if available, otherwise basic)
    private var currentPlace: Place {
        return detailedPlace ?? place
    }
    
    // MARK: - Image Section Components
    
    private var mainImageSection: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .bottomTrailing) {
                    // Single high-quality main image
                    SingleHighQualityPhotoView(
                        place: place,
                        width: geometry.size.width,
                        height: 360,
                        autoLoad: true
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                    
                    // Image overlay with gradient
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Photo count badge (if place has multiple images)
                    if place.images.count > 1 {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                            
                            Text("\(place.images.count)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .frame(height: 360)
        }
    }
    
    // MARK: - UI Sections
    
    private var nameAndRatingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(currentPlace.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            HStack(spacing: 12) {
                // Rating with stars
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(currentPlace.rating) ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                    
                    Text(String(format: "%.1f", currentPlace.rating))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                // Price range
                Text(currentPlace.priceRange)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: currentPlace.category.color))
                
                Spacer()
                
                // Category badge
                Text(currentPlace.category.rawValue.capitalized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: currentPlace.category.color))
                    )
            }
        }
    }
    
    private var statusAndBasicInfoSection: some View {
        HStack(spacing: 16) {
            // Open/Closed status
            HStack(spacing: 6) {
                Circle()
                    .fill(currentPlace.isCurrentlyOpen ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(currentPlace.isCurrentlyOpen ? "Open Now" : "Closed")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(currentPlace.isCurrentlyOpen ? .green : .red)
            }
            
            Spacer()
            
            // Review count
            if currentPlace.reviewCount > 0 {
                Text("\(currentPlace.reviewCount) reviews")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    private var addressAndPhoneSection: some View {
        VStack(spacing: 12) {
            // Address
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(currentPlace.location)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button("Directions") {
                    openDirections()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }
            
            // Phone number
            if !currentPlace.phone.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text(currentPlace.phone)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Call") {
                        callPlace()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            if !currentPlace.description.isEmpty {
                Text(currentPlace.description)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            } else {
                Text("A great \(currentPlace.category.rawValue.lowercased()) in \(currentPlace.location)")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    private var menuHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Menu Highlights")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(Array(currentPlace.menuItems.prefix(4)), id: \.id) { item in
                    Text(item.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: currentPlace.category.color).opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: currentPlace.category.color).opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
        }
    }
    
    private var enhancedCustomerSentimentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                Text("Customer Sentiment Analysis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if advancedSentimentService.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let analysis = advancedSentimentService.sentimentAnalysis {
                VStack(alignment: .leading, spacing: 16) {
                    // Overall score with visual indicator
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Overall Sentiment")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                Text(String(format: "%.1f", analysis.overallScore))
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(sentimentColor(for: analysis.overallScore))
                                
                                Text("/ 10.0")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Based on \(analysis.totalReviews) reviews")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Text(sentimentLabel(for: analysis.overallScore))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(sentimentColor(for: analysis.overallScore))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(sentimentColor(for: analysis.overallScore).opacity(0.1))
                                )
                        }
                    }
                    
                    // Category breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category Breakdown")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(analysis.categories.prefix(6), id: \.name) { category in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(category.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Text(String(format: "%.1f", category.score))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color(hex: category.color))
                                    }
                                    
                                    ProgressView(value: category.score, total: 10.0)
                                        .tint(Color(hex: category.color))
                                        .scaleEffect(y: 0.8)
                                    
                                    Text(category.description)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(hex: category.color).opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    
                    // Summary text
                    if !analysis.summary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI Summary")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(analysis.summary)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.05))
                        )
                    }
                }
            } else if reviewAggregator.reviews.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No reviews available for sentiment analysis")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Analyzing customer sentiment...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Customer Reviews")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if !reviewAggregator.reviews.isEmpty {
                        Text("Real reviews from Google Business Profile")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if reviewAggregator.reviews.count > 3 {
                    Button("See All") {
                        showingAllReviews = true
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                }
            }
            
            if reviewAggregator.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Loading real customer reviews...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if reviewAggregator.reviews.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No reviews found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("This place may not have Google Business reviews yet")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 16) {
                    // Display note about real reviews
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                        
                        Text("These are real Google reviews used for sentiment analysis")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.green.opacity(0.1))
                    )
                    
                    // Display reviews with enhanced formatting
                    VStack(spacing: 12) {
                        ForEach(Array(reviewAggregator.reviews.prefix(3).enumerated()), id: \.element.id) { index, review in
                            EnhancedRealReviewCard(review: review, place: place)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var whyRecommendedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text("Why AI Recommended")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isGeneratingExplanation {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if whyRecommendedText.isEmpty && !isGeneratingExplanation {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    
                    Text("Generating personalized explanation...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if !whyRecommendedText.isEmpty {
                Text(whyRecommendedText)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Visit Button Section
    private var visitButtonSection: some View {
        VStack(spacing: 16) {
            if hasVisited {
                // Visited state
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visited!")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("Thanks for exploring this place")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if showingXPGained {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.yellow)
                            
                            Text("+\(xpGained) XP")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                        .scaleEffect(showingXPGained ? 1.2 : 1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showingXPGained)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.green.opacity(0.4), lineWidth: 2)
                        )
                        .shadow(color: .green.opacity(0.2), radius: 8, x: 0, y: 4)
                )
            } else {
                // Visit button - Enhanced for better visibility
                Button(action: {
                    Task {
                        await markAsVisited()
                    }
                }) {
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Mark as Visited")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Earn XP and track your exploration journey")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                        }
                        
                        // XP reward badge
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.yellow)
                                
                                Text("Earn +\(calculateVisitXP()) XP")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.yellow.opacity(0.2))
                                    .overlay(
                                        Capsule()
                                            .stroke(.yellow.opacity(0.5), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#00d4ff"), Color(hex: "#0099cc")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color(hex: "#00d4ff").opacity(0.4), radius: 16, x: 0, y: 8)
                    )
                }
                .scaleEffect(showingVisitAnimation ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: showingVisitAnimation)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Visit Functionality
    private func markAsVisited() async {
        guard !hasVisited else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showingVisitAnimation = true
        }
        
        // Calculate XP for this visit
        let earnedXP = calculateVisitXP()
        xpGained = earnedXP
        
        // Check if this is user's first visit to this place
        let isFirstVisit = !hasUserVisitedBefore()
        
        // Award XP through XPManager
        await xpManager.awardPlaceVisitXP(
            placeId: place.googlePlaceId ?? place.id.uuidString,
            placeName: place.name,
            isFirstVisit: isFirstVisit
        )
        
        // Mark as visited and show success state
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            hasVisited = true
            showingVisitAnimation = false
        }
        
        // Show XP animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                showingXPGained = true
            }
            
            // Hide XP animation after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showingXPGained = false
                }
            }
        }
        
        // Cache the visit status
        UserDefaults.standard.set(true, forKey: "visited_\(place.id.uuidString)")
        
        print("✅ Marked \(place.name) as visited and awarded \(earnedXP) XP")
    }
    
    private func calculateVisitXP() -> Int {
        // Base XP for visiting a place
        var baseXP = 50
        
        // Bonus XP based on place rating
        if place.rating >= 4.5 {
            baseXP += 25 // Highly rated places give bonus XP
        } else if place.rating >= 4.0 {
            baseXP += 15
        }
        
        // Bonus XP for first visit
        if !hasUserVisitedBefore() {
            baseXP += 25
        }
        
        // Bonus XP based on place category
        switch place.category {
        case .restaurants:
            baseXP += 10
        case .venues:
            baseXP += 15
        case .shopping:
            baseXP += 5
        default:
            break
        }
        
        return baseXP
    }
    
    private func hasUserVisitedBefore() -> Bool {
        return UserDefaults.standard.bool(forKey: "visited_\(place.id.uuidString)")
    }
    
    // Load visit status on appear
    private func loadVisitStatus() {
        hasVisited = hasUserVisitedBefore()
    }
    
    // MARK: - Helper Methods
    
    private func sentimentColor(for score: Double) -> Color {
        switch score {
        case 8.0...10.0:
            return .green
        case 6.0..<8.0:
            return .orange
        case 4.0..<6.0:
            return .yellow
        default:
            return .red
        }
    }
    
    private func sentimentLabel(for score: Double) -> String {
        switch score {
        case 8.5...10.0:
            return "Excellent"
        case 7.0..<8.5:
            return "Very Good"
        case 6.0..<7.0:
            return "Good"
        case 4.0..<6.0:
            return "Fair"
        default:
            return "Poor"
        }
    }
    
    private func openDirections() {
        guard let coordinates = currentPlace.coordinates else { return }
        let url = URL(string: "http://maps.apple.com/?daddr=\(coordinates.latitude),\(coordinates.longitude)")
        if let url = url {
            UIApplication.shared.open(url)
        }
    }
    
    private func callPlace() {
        let phoneNumber = currentPlace.phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel://\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func generateWhyRecommended() async {
        isGeneratingExplanation = true
        
        let prompt = """
        Analyze why this place was recommended to the user based on their profile and preferences.
        
        Place Details:
        - Name: \(place.name)
        - Category: \(place.category.rawValue)
        - Rating: \(place.rating)/5 (\(place.reviewCount) reviews)
        - Price Range: \(place.priceRange)
        - Location: \(place.location)
        - Description: \(place.description)
        
        User Context:
        \(UserFingerprintManager.shared.buildGeminiPrompt())
        
        Write a compelling 2-3 sentence explanation of why this specific place was chosen for this user. Focus on:
        1. How the place matches their onboarding preferences
        2. Why it fits their taste profile from liked/disliked places
        3. What specific aspects (atmosphere, cuisine, price point, location) make it perfect for them
        4. How it aligns with their behavioral patterns and interests
        
        Be specific and personal - make the user feel like this recommendation was handpicked just for them.
        Return only the explanation text, no extra formatting.
        """
        
        await withCheckedContinuation { continuation in
            geminiAIService.sendGeminiRequest(prompt: prompt) { response in
                DispatchQueue.main.async {
                    self.whyRecommendedText = response.isEmpty ? "This place was personally selected based on your preferences and past activity." : response
                    self.isGeneratingExplanation = false
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Single High Quality Photo View
struct SingleHighQualityPhotoView: View {
    let place: Place
    let width: CGFloat
    let height: CGFloat
    let autoLoad: Bool
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @StateObject private var cacheManager = PlaceDetailCacheManager.shared
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(Color(hex: place.category.color))
                            
                            Text("Loading high-quality image...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    )
                    .frame(width: width, height: height)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: place.category.iconName)
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: place.category.color).opacity(0.6))
                            
                            Text("Tap to load image")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    )
                    .frame(width: width, height: height)
                    .onTapGesture {
                        loadImageIfNeeded()
                    }
            }
        }
        .onAppear {
            if autoLoad {
                loadImageIfNeeded()
            }
        }
    }
    
    private func loadImageIfNeeded() {
        // Check cache first
        let cacheKey = "\(place.id)_hq_\(Int(width))x\(Int(height))"
        if let cachedImage = cacheManager.getCachedImage(for: cacheKey) {
            loadedImage = cachedImage
            return
        }
        
        guard !isLoading, let photoReference = place.images.first else { return }
        
        isLoading = true
        
        // Load ultra-high quality image (1200x800)
        if photoReference.hasPrefix("http") {
            loadFromURL(photoReference, cacheKey: cacheKey)
        } else {
            loadFromGooglePlaces(photoReference, cacheKey: cacheKey)
        }
    }
    
    private func loadFromURL(_ urlString: String, cacheKey: String) {
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let data = data, let image = UIImage(data: data) {
                    self.loadedImage = image
                    self.cacheManager.cacheImage(image, for: cacheKey)
                    print("✅ Loaded ultra-high quality image for \(self.place.name)")
                }
            }
        }.resume()
    }
    
    private func loadFromGooglePlaces(_ photoReference: String, cacheKey: String) {
        let googleService = GooglePlacesService()
        let metadata = GooglePhotoMetadata(
            photoReference: photoReference,
            height: Int(height),
            width: Int(width),
            htmlAttributions: []
        )
        
        // Use ULTRA HIGH QUALITY for detail view
        let targetSize = CGSize(width: 1200, height: 800)
        
        googleService.fetchPhoto(metadata: metadata, maxSize: targetSize) { image in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let image = image {
                    self.loadedImage = image
                    self.cacheManager.cacheImage(image, for: cacheKey)
                    print("✅ Loaded ULTRA-HIGH quality Google image for \(self.place.name)")
                }
            }
        }
    }
}

// MARK: - Enhanced Real Review Card Component
struct EnhancedRealReviewCard: View {
    let review: EnhancedReview
    let place: Place
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Reviewer Header
            HStack {
                // Profile Picture or Initial
                if let authorPhotoUrl = review.authorPhotoUrl, !authorPhotoUrl.isEmpty {
                    AsyncImage(url: URL(string: authorPhotoUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .overlay(
                                Text(String(review.author.prefix(1)).uppercased())
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    // Fallback to initial circle
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(review.author.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(review.author)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if review.isVerified {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        // Star Rating
                        HStack(spacing: 1) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(review.rating) ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text(review.timeAgo)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 2) {
                            Image(systemName: review.source.iconName)
                                .font(.system(size: 8))
                                .foregroundColor(Color(hex: review.source.color))
                            
                            Text(review.source.rawValue)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(hex: review.source.color))
                        }
                    }
                }
                
                Spacer()
                
                // Review rating badge
                Text(String(format: "%.1f", review.rating))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(ratingColor(for: review.rating))
                    )
            }
            
            // Review Text
            Text(review.text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            
            // Helpful count and sentiment indicator
            HStack {
                if let helpfulCount = review.helpfulCount, helpfulCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text("\(helpfulCount) helpful")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Sentiment emoji
                Text(review.sentiment.emoji)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func ratingColor(for rating: Double) -> Color {
        switch rating {
        case 4.5...5.0:
            return .green
        case 3.5..<4.5:
            return .orange
        case 2.5..<3.5:
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - CustomerSentiment removed - now using AppModels version








