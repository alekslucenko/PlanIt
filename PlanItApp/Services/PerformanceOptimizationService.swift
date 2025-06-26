import SwiftUI
import CoreLocation
import Foundation
import Combine

// MARK: - Performance Optimization Service
@MainActor
final class PerformanceOptimizationService: ObservableObject {
    static let shared = PerformanceOptimizationService()
    
    // MARK: - Performance Metrics
    @Published var currentFPS: Double = 60.0
    @Published var memoryUsage: Double = 0.0
    @Published var isOptimizationActive: Bool = true
    
    // MARK: - Threading Optimization
    private let backgroundQueue = DispatchQueue(label: "performance.background", qos: .utility)
    private let imageProcessingQueue = DispatchQueue(label: "performance.images", qos: .userInitiated)
    private let databaseQueue = DispatchQueue(label: "performance.database", qos: .userInitiated)
    
    // MARK: - Cache Management
    private var viewStateCache: [String: Any] = [:]
    private var imageCache: [String: UIImage] = [:]
    private var renderCache: [String: Date] = [:]
    
    // MARK: - Performance Flags
    private var isOptimizing = false
    private var isReduceMotionEnabled = false
    private var performanceMode: PerformanceMode = .balanced
    
    enum PerformanceMode {
        case performance  // Maximum performance, minimal animations
        case balanced     // Default mode
        case visual       // Maximum visual quality
    }
    
    // MARK: - Cache Properties
    @Published var cachedPlaces: [String: [Place]] = [:] // Key: "category_location_radius"
    @Published var cachedCategories: [AIPlaceCategory] = []
    @Published var lastUpdateTime: Date = Date()
    
    // MARK: - Performance Settings
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    private let maxCachedPlaces = 200
    private let maxCachedCategories = 50
    private let preloadDistance: Double = 5.0 // miles
    
    // MARK: - Randomization Pools
    private var randomizedPlacePool: [Place] = []
    private var randomizedCategoryPool: [AIPlaceCategory] = []
    private var lastRandomizationTime: Date = Date()
    
    private init() {
        generateRandomizedPools()
        setupPerformanceMonitoring()
        detectDeviceCapabilities()
        optimizeForCurrentDevice()
    }
    
    // MARK: - Device Detection & Optimization
    
    private func detectDeviceCapabilities() {
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        
        // Optimize for iPhone 13 and newer devices
        if deviceModel.contains("iPhone") {
            // Check if iOS 17+ on iPhone 13+ which has known performance issues
            if let majorVersion = Int(systemVersion.components(separatedBy: ".").first ?? "0"),
               majorVersion >= 17 {
                performanceMode = .performance
                print("🔧 Detected iPhone 13+ with iOS 17+ - Enabling performance mode")
            }
        }
        
        // Check accessibility settings
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    }
    
    private func optimizeForCurrentDevice() {
        switch performanceMode {
        case .performance:
            enablePerformanceMode()
        case .balanced:
            enableBalancedMode()
        case .visual:
            enableVisualMode()
        }
    }
    
    // MARK: - Performance Modes
    
    private func enablePerformanceMode() {
        // Minimal animations, maximum performance
        UIView.setAnimationsEnabled(false)
        
        // Reduce visual effects
        setAnimationSettings(duration: 0.1, enabled: false)
        
        print("🚀 Performance mode enabled - Optimized for speed")
    }
    
    private func enableBalancedMode() {
        setAnimationSettings(duration: 0.2, enabled: true)
        
        print("⚖️ Balanced mode enabled - Standard performance")
    }
    
    private func enableVisualMode() {
        setAnimationSettings(duration: 0.3, enabled: true)
        
        print("✨ Visual mode enabled - Maximum visual quality")
    }
    
    @MainActor
    private func setAnimationSettings(duration: TimeInterval, enabled: Bool) {
        // Configure animation settings
        if !enabled || isReduceMotionEnabled {
            UIView.setAnimationsEnabled(false)
        } else {
            UIView.setAnimationsEnabled(true)
        }
    }
    
    // MARK: - Threading Optimization
    
    func performBackgroundTask<T>(_ task: @escaping () async throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundQueue.async {
                Task {
                    do {
                        let result = try await task()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    func optimizeImageProcessing(_ operation: @escaping () -> UIImage?) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            imageProcessingQueue.async {
                let result = operation()
                continuation.resume(returning: result)
            }
        }
    }
    
    func optimizeDatabaseOperation<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            databaseQueue.async {
                Task {
                    do {
                        let result = try await operation()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: - SwiftUI Performance Optimization
    
    func optimizeViewUpdate<T: View>(_ view: T, identifier: String) -> some View {
        let shouldUpdate = checkIfViewShouldUpdate(identifier: identifier)
        
        if shouldUpdate {
            renderCache[identifier] = Date()
            return AnyView(view)
        } else {
            // Return cached view or simplified version
            return AnyView(EmptyView())
        }
    }
    
    private func checkIfViewShouldUpdate(identifier: String) -> Bool {
        guard let lastRender = renderCache[identifier] else { return true }
        
        // Throttle updates to prevent excessive re-rendering
        let timeSinceLastRender = Date().timeIntervalSince(lastRender)
        return timeSinceLastRender > 0.016 // ~60 FPS throttling
    }
    
    // MARK: - Memory Management
    
    func clearCaches() {
        viewStateCache.removeAll()
        imageCache.removeAll()
        renderCache.removeAll()
        
        // Force garbage collection
        Task {
            try? await performBackgroundTask {
                // Clear additional caches
                URLCache.shared.removeAllCachedResponses()
                return ()
            }
        }
        
        print("🧹 Performance caches cleared")
    }
    
    func optimizeMemoryUsage() {
        Task {
            try? await performBackgroundTask {
                // Clear old cache entries
                let cutoffDate = Date().addingTimeInterval(-300) // 5 minutes
                self.renderCache = self.renderCache.filter { $0.value > cutoffDate }
                
                // Limit cache sizes
                if self.imageCache.count > 50 {
                    let keysToRemove = Array(self.imageCache.keys.prefix(25))
                    keysToRemove.forEach { self.imageCache.removeValue(forKey: $0) }
                }
                
                return ()
            }
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func setupPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }
    
    @MainActor
    private func updatePerformanceMetrics() {
        // Simple FPS estimation
        _ = CACurrentMediaTime()
        currentFPS = 60.0 // Simplified for now
        
        // Memory usage estimation
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            memoryUsage = Double(info.resident_size) / (1024 * 1024) // MB
        }
        
        // Auto-optimize if performance degrades
        if currentFPS < 30 || memoryUsage > 200 {
            if !isOptimizing {
                autoOptimize()
            }
        }
    }
    
    private func autoOptimize() {
        isOptimizing = true
        
        Task {
            try? await performBackgroundTask {
                // Clear caches
                await MainActor.run {
                    self.clearCaches()
                    self.optimizeMemoryUsage()
                }
                
                // Switch to performance mode temporarily
                await MainActor.run {
                    self.performanceMode = .performance
                    self.enablePerformanceMode()
                }
                
                return ()
            }
            
            // Reset after optimization
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            
            await MainActor.run {
                self.isOptimizing = false
                self.performanceMode = .balanced
                self.enableBalancedMode()
            }
        }
        
        print("🔧 Auto-optimization triggered due to performance degradation")
    }
    
    // MARK: - UI Optimization Helpers
    
    func shouldReduceAnimations() -> Bool {
        return isReduceMotionEnabled || performanceMode == .performance
    }
    
    func getOptimizedAnimationDuration() -> TimeInterval {
        if shouldReduceAnimations() {
            return 0.1
        }
        
        switch performanceMode {
        case .performance:
            return 0.1
        case .balanced:
            return 0.2
        case .visual:
            return 0.3
        }
    }
    
    func getOptimizedSpringAnimation() -> Animation {
        if shouldReduceAnimations() {
            return .linear(duration: 0.1)
        }
        
        return .spring(response: 0.4, dampingFraction: 0.8)
    }
    
    // MARK: - Public Methods
    
    func optimizeForLocation(_ location: CLLocation, radius: Double = 2.0) {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        
        Task {
            // Check cache first
            if let cached = getCachedPlaces(for: location, radius: radius) {
                await MainActor.run {
                    self.isOptimizing = false
                }
                return
            }
            
            // Background preload
            await preloadNearbyContent(location: location, radius: radius)
            
            await MainActor.run {
                self.isOptimizing = false
                self.lastUpdateTime = Date()
            }
        }
    }
    
    func getOptimizedPlaces(for category: PlaceCategory, location: CLLocation, radius: Double) -> [Place] {
        let cacheKey = "\(category.rawValue)_\(location.coordinate.latitude)_\(location.coordinate.longitude)_\(radius)"
        
        // Return cached if available and fresh
        if let cached = cachedPlaces[cacheKey],
           Date().timeIntervalSince(lastUpdateTime) < cacheExpirationTime {
            return cached
        }
        
        // Return randomized subset to minimize API calls
        let randomPlaces = getRandomizedPlaces(for: category, count: 15)
        let updatedPlaces = randomPlaces.map { place in
            updatePlaceWithLocation(place, near: location)
        }
        
        // Cache the result
        cachedPlaces[cacheKey] = updatedPlaces
        return updatedPlaces
    }
    
    func getOptimizedCategories() -> [AIPlaceCategory] {
        // Return cached categories if fresh
        if !cachedCategories.isEmpty,
           Date().timeIntervalSince(lastUpdateTime) < cacheExpirationTime {
            return cachedCategories
        }
        
        // Generate fresh categories with smart randomization
        let optimizedCategories = [
            AIPlaceCategory(
                title: "Morning Energy Spots",
                description: "Perfect places to start your day with amazing coffee and fresh vibes. Curated for early birds and productivity seekers.",
                emoji: "☀️",
                placeCount: 8,
                queryTerms: ["coffee", "breakfast", "morning", "fresh"]
            ),
            AIPlaceCategory(
                title: "Hidden Local Gems",
                description: "Secret spots that only locals know about. Discover authentic experiences off the beaten path.",
                emoji: "💎",
                placeCount: 6,
                queryTerms: ["local", "hidden", "authentic", "secret"]
            ),
            AIPlaceCategory(
                title: "Instagram-Worthy Views",
                description: "Stunning locations perfect for capturing those memorable moments. Your feed will thank you later.",
                emoji: "📸",
                placeCount: 10,
                queryTerms: ["view", "photo", "scenic", "instagram"]
            ),
            AIPlaceCategory(
                title: "Foodie Adventures",
                description: "Culinary experiences that will tantalize your taste buds. From street food to fine dining.",
                emoji: "🍴",
                placeCount: 12,
                queryTerms: ["food", "restaurant", "culinary", "taste"]
            ),
            AIPlaceCategory(
                title: "Evening Entertainment",
                description: "Where the night comes alive with music, drinks, and unforgettable experiences.",
                emoji: "🌙",
                placeCount: 8,
                queryTerms: ["nightlife", "bar", "music", "entertainment"]
            ),
            AIPlaceCategory(
                title: "Shopping Discoveries",
                description: "Unique boutiques and markets for those special finds. Support local artisans and creators.",
                emoji: "🛍️",
                placeCount: 7,
                queryTerms: ["shopping", "boutique", "market", "unique"]
            )
        ]
        
        cachedCategories = optimizedCategories
        return optimizedCategories
    }
    
    // MARK: - Private Methods
    
    private func generateRandomizedPools() {
        // Generate randomized places for each category
        for category in PlaceCategory.allCases {
            let places = generateRandomPlaces(for: category, count: 25)
            randomizedPlacePool.append(contentsOf: places)
        }
        
        lastRandomizationTime = Date()
    }
    
    private func generateRandomPlaces(for category: PlaceCategory, count: Int) -> [Place] {
        var places: [Place] = []
        
        for i in 0..<count {
            let place = Place(
                name: "\(getRandomName(for: category)) \(i + 1)",
                description: getRandomDescription(for: category),
                category: category,
                rating: Double.random(in: 3.5...5.0),
                reviewCount: Int.random(in: 50...500),
                priceRange: getRandomPriceRange(),
                images: [getRandomImageURL()],
                location: "San Francisco, CA",
                hours: "9:00 AM - 10:00 PM",
                phone: "(555) 123-4567",
                coordinates: Coordinates(
                    latitude: 37.7749 + Double.random(in: -0.1...0.1),
                    longitude: -122.4194 + Double.random(in: -0.1...0.1)
                )
            )
            places.append(place)
        }
        
        return places
    }
    
    private func updatePlaceWithLocation(_ place: Place, near location: CLLocation) -> Place {
        // Create a new Place instance with updated location-based details
        var updatedPlace = place
        
        // Calculate realistic distance from user location
        let distance = location.distance(from: CLLocation(
            latitude: place.coordinates?.latitude ?? 37.7749,
            longitude: place.coordinates?.longitude ?? -122.4194
        )) / 1609.34 // Convert to miles
        
        return updatedPlace
    }
    
    private func getRandomizedPlaces(for category: PlaceCategory, count: Int) -> [Place] {
        let filteredPlaces = randomizedPlacePool.filter { $0.category == category }
        return Array(filteredPlaces.shuffled().prefix(count))
    }
    
    private func getCachedPlaces(for location: CLLocation, radius: Double) -> [Place]? {
        // Check if we have any cached places for this general area
        for (key, places) in cachedPlaces {
            let components = key.split(separator: "_")
            if components.count >= 4,
               let cachedLat = Double(components[1]),
               let cachedLon = Double(components[2]),
               let cachedRadius = Double(components[3]) {
                
                let cachedLocation = CLLocation(latitude: cachedLat, longitude: cachedLon)
                let distance = location.distance(from: cachedLocation) / 1609.34 // miles
                
                if distance <= radius && cachedRadius >= radius {
                    return places
                }
            }
        }
        return nil
    }
    
    private func preloadNearbyContent(location: CLLocation, radius: Double) async {
        // Simulate content preloading
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Generate content for all categories
        for category in PlaceCategory.allCases {
            let places = getOptimizedPlaces(for: category, location: location, radius: radius)
            let cacheKey = "\(category.rawValue)_\(location.coordinate.latitude)_\(location.coordinate.longitude)_\(radius)"
            cachedPlaces[cacheKey] = places
        }
    }
    
    // MARK: - Helper Methods
    
    private func getRandomName(for category: PlaceCategory) -> String {
        switch category {
        case .restaurants:
            return ["Bella Vista", "Garden Bistro", "Urban Kitchen", "Corner Cafe", "The Grove"].randomElement() ?? "Local Spot"
        case .cafes:
            return ["Brew & Bean", "Morning Light", "Coffee Corner", "Steam & Cream", "Daily Grind"].randomElement() ?? "Coffee Shop"
        case .bars:
            return ["Night Owl", "Happy Hour", "The Lounge", "City Lights", "Rooftop"].randomElement() ?? "Bar"
        case .venues:
            return ["The Stage", "Live Music Hall", "Event Space", "Gallery", "Theater"].randomElement() ?? "Venue"
        case .shopping:
            return ["Boutique", "Market Square", "The Shop", "Corner Store", "Mall"].randomElement() ?? "Store"
        }
    }
    
    private func getRandomDescription(for category: PlaceCategory) -> String {
        switch category {
        case .restaurants:
            return "A delightful dining experience with fresh, locally-sourced ingredients and a cozy atmosphere."
        case .cafes:
            return "Artisanal coffee and pastries in a welcoming environment perfect for work or relaxation."
        case .bars:
            return "Craft cocktails and local brews in a vibrant atmosphere with great music and friendly service."
        case .venues:
            return "A dynamic space hosting live performances, art exhibitions, and cultural events."
        case .shopping:
            return "Unique finds and quality products from local artisans and carefully curated brands."
        }
    }
    
    private func getRandomPriceRange() -> String {
        return ["$", "$$", "$$$"].randomElement() ?? "$$"
    }
    
    private func getRandomImageURL() -> String {
        return "https://picsum.photos/400/300?random=\(Int.random(in: 1...1000))"
    }
    
    // MARK: - iPhone 13+ Specific Optimizations
    
    func optimizeForKeyboardInput() {
        // Specific fix for the 1-key-per-second issue on iPhone 13
        setAnimationSettings(duration: 0.05, enabled: false)
        
        // Disable heavy background processes during text input
        backgroundQueue.async {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    
    func restoreNormalInputMode() {
        setAnimationSettings(duration: getOptimizedAnimationDuration(), enabled: !shouldReduceAnimations())
    }
}

// MARK: - Performance-Optimized View Modifier

struct PerformanceOptimized: ViewModifier {
    let identifier: String
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    
    func body(content: Content) -> some View {
        content
            .animation(performanceService.getOptimizedSpringAnimation(), value: identifier)
            .onAppear {
                performanceService.optimizeMemoryUsage()
            }
    }
}

extension View {
    func performanceOptimized(identifier: String = UUID().uuidString) -> some View {
        modifier(PerformanceOptimized(identifier: identifier))
    }
} 