import SwiftUI
import MapKit
import CoreLocation

// MARK: - Modern Place Card
struct ModernPlaceCard: View {
    let place: Place
    let onTap: () -> Void
    let onFavorite: () -> Void
    let isFavorite: Bool
    @ObservedObject var locationManager: LocationManager
    
    @State private var imageLoadError = false
    @State private var isImageLoading = true
    @State private var showingDetail = false
    @State private var userReaction: PlaceReaction?
    @StateObject private var dynamicCategoryManager = DynamicCategoryManager.shared
    @State private var resolvedAddress: String?
    
    @State private var hasInteracted = false
    @State private var lastInteraction: PlaceInteraction?
    @State private var showingInteractionFeedback = false
    
    @StateObject private var reactionManager = ReactionManager.shared
    
    var body: some View {
        ModernCard(shadowEnabled: true) {
            VStack(spacing: 0) {
                // Image Section with Overlay
                imageSection
                
                // Content Section
                contentSection
            }
        }
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                PlaceDetailView(place: place)
            }
        }
        .onAppear {
            resolveAddressIfNeeded()
            userReaction = reactionManager.reaction(for: place.googlePlaceId ?? place.id.uuidString)
        }
    }
    
    private var imageSection: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    ModernSocialTheme.Colors.primaryPink.opacity(0.3),
                    ModernSocialTheme.Colors.primaryBlue.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            
            // Enhanced Place Image Loading
            EnhancedPlaceImageView(
                place: place,
                width: 280,
                height: 180
            )
            
            // Overlay gradients and controls
            VStack {
                // Top overlay with favorite button
                HStack {
                    Spacer()
                    
                    Button(action: onFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(isFavorite ? ModernSocialTheme.Colors.primaryPink : .white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .scaleEffect(isFavorite ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFavorite)
                }
                .padding(ModernSocialTheme.Spacing.md)
                
                Spacer()
                
                // Bottom overlay with rating and status
                HStack {
                    // Rating badge
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ModernSocialTheme.Colors.warningOrange)
                        
                        Text(String(format: "%.1f", place.rating))
                            .font(ModernSocialTheme.Typography.caption)
                            .fontWeight(.bold)
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
                    
                    Spacer()
                    
                    // Open status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(place.isCurrentlyOpen ? ModernSocialTheme.Colors.successGreen : ModernSocialTheme.Colors.errorRed)
                            .frame(width: 6, height: 6)
                        
                        Text(place.isCurrentlyOpen ? "Open" : "Closed")
                            .font(ModernSocialTheme.Typography.caption)
                            .fontWeight(.medium)
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
                }
                .padding(ModernSocialTheme.Spacing.md)
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.large)
                .corners([.topLeft, .topRight])
        )
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: ModernSocialTheme.Spacing.sm) {
            // Title and category
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(ModernSocialTheme.Typography.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.adaptivePrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(place.category.displayName)
                        .font(ModernSocialTheme.Typography.caption)
                        .foregroundColor(ModernSocialTheme.Colors.primaryPink)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                // Price indicator
                if !place.priceRange.isEmpty {
                    Text(place.priceRange)
                        .font(ModernSocialTheme.Typography.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(ModernSocialTheme.Colors.successGreen)
                }
            }
            
            // Location and reviews
            HStack(spacing: ModernSocialTheme.Spacing.sm) {
                // Location icon
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                
                Text(resolvedAddress ?? place.location)
                    .font(ModernSocialTheme.Typography.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Review count
                if place.reviewCount > 0 {
                    Text("\(place.reviewCount) reviews")
                        .font(ModernSocialTheme.Typography.caption)
                        .foregroundColor(.adaptiveSecondary)
                }
            }
            
            // AI-Generated Descriptive Tags
            AIDescriptiveTagsView(place: place)
            
            // Distance with green dot
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                
                if let userLocation = locationManager.selectedLocation ?? locationManager.currentLocation {
                    Text(place.formattedDistance(from: userLocation))
                        .font(.caption)
                        .foregroundColor(.white)
                } else {
                    Text("Distance unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Thumbs up/down buttons
                reactionButtons
            }
        }
        .padding(ModernSocialTheme.Spacing.md)
    }
    
    private var reactionButtons: some View {
        HStack(spacing: 8) {
            // Thumbs Up
            Button(action: {
                toggleReaction(.liked)
            }) {
                Image(systemName: userReaction == .liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(userReaction == .liked ? .green : .white)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Thumbs Down
            Button(action: {
                toggleReaction(.disliked)
            }) {
                Image(systemName: userReaction == .disliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(userReaction == .disliked ? .red : .white)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func toggleReaction(_ newReaction: PlaceReaction) {
        let placeKey = place.googlePlaceId ?? place.id.uuidString
        if userReaction == newReaction {
            // remove reaction
            reactionManager.setReaction(nil, for: placeKey, place: place)
            userReaction = nil
        } else {
            reactionManager.setReaction(newReaction, for: placeKey, place: place)
            userReaction = newReaction
        }
        
        // Track the interaction for analytics
        Task {
            await UserTrackingService.shared.recordTapEvent(
                targetId: "reaction_button_\(newReaction.rawValue)",
                targetType: "place_reaction",
                coordinates: CGPoint(x: 0, y: 0) // Could be improved with actual coordinates
            )
        }
    }
    
    private func resolveAddressIfNeeded() {
        guard (place.location.isEmpty || place.location.contains("Address not available")),
              let coords = place.coordinates else { return }
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: coords.latitude, longitude: coords.longitude)) { placemarks, error in
            if let placemark = placemarks?.first {
                var parts: [String] = []
                if let subThoroughfare = placemark.subThoroughfare { parts.append(subThoroughfare) }
                if let thoroughfare = placemark.thoroughfare { parts.append(thoroughfare) }
                if let locality = placemark.locality { parts.append(locality) }
                resolvedAddress = parts.joined(separator: " ")
            }
        }
    }
}

// MARK: - Horizontal Place Card for Feeds
struct ModernHorizontalPlaceCard: View {
    let place: Place
    let onTap: () -> Void
    let onFavorite: () -> Void
    let isFavorite: Bool
    
    @State private var imageLoadError = false
    @State private var isImageLoading = true
    @State private var showingDetail = false
    
    var body: some View {
        ModernCard(shadowEnabled: false) {
            HStack(spacing: ModernSocialTheme.Spacing.md) {
                // Image section
                imageSection
                
                // Content section
                contentSection
                
                // Action section
                actionSection
            }
            .padding(ModernSocialTheme.Spacing.md)
        }
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
        EnhancedPlaceImageView(
            place: place,
            width: 80,
            height: 80
        )
        .clipShape(RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium))
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title and category
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(ModernSocialTheme.Typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.adaptivePrimary)
                    .lineLimit(2)
                
                Text(place.category.displayName)
                    .font(ModernSocialTheme.Typography.caption)
                    .foregroundColor(ModernSocialTheme.Colors.primaryPink)
                    .fontWeight(.medium)
            }
            
            Spacer(minLength: 0)
            
            // Location and status
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                
                Text(place.location)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Open status
                HStack(spacing: 2) {
                    Circle()
                        .fill(place.isCurrentlyOpen ? ModernSocialTheme.Colors.successGreen : ModernSocialTheme.Colors.errorRed)
                        .frame(width: 4, height: 4)
                    
                    Text(place.isCurrentlyOpen ? "Open" : "Closed")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(place.isCurrentlyOpen ? ModernSocialTheme.Colors.successGreen : ModernSocialTheme.Colors.errorRed)
                }
            }
            
            // Price and reviews
            HStack {
                if !place.priceRange.isEmpty {
                    Text(place.priceRange)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ModernSocialTheme.Colors.successGreen)
                }
                
                Spacer()
                
                if place.reviewCount > 0 {
                    Text("\(place.reviewCount)")
                        .font(.system(size: 10))
                        .foregroundColor(.adaptiveSecondary)
                    
                    Image(systemName: "text.bubble")
                        .font(.system(size: 8))
                        .foregroundColor(.adaptiveSecondary)
                }
            }
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: ModernSocialTheme.Spacing.sm) {
            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isFavorite ? ModernSocialTheme.Colors.primaryPink : .adaptiveSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.adaptiveSecondary)
                            .overlay(
                                Circle()
                                    .stroke(Color.adaptiveBorder, lineWidth: 1)
                            )
                    )
            }
            .scaleEffect(isFavorite ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFavorite)
            
            Spacer()
        }
    }
}

// MARK: - Corner Radius Extension
extension RoundedRectangle {
    func corners(_ corners: UIRectCorner) -> some Shape {
        return UnevenRoundedRectangle(
            topLeadingRadius: corners.contains(.topLeft) ? cornerRadius : 0,
            bottomLeadingRadius: corners.contains(.bottomLeft) ? cornerRadius : 0,
            bottomTrailingRadius: corners.contains(.bottomRight) ? cornerRadius : 0,
            topTrailingRadius: corners.contains(.topRight) ? cornerRadius : 0
        )
    }
    
    private var cornerRadius: CGFloat {
        // Extract corner radius from RoundedRectangle if possible
        return ModernSocialTheme.CornerRadius.large
    }
}

// MARK: - Enhanced Place Image View for Reliable Loading
struct EnhancedPlaceImageView: View {
    let place: Place
    let width: CGFloat
    let height: CGFloat
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
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
            } else if isLoading && !loadFailed {
                loadingView
            } else {
                placeholderView
            }
        }
        .frame(width: width, height: height)
        .onAppear {
            loadImageIfNeeded()
        }
    }
    
    private var loadingView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ModernSocialTheme.Colors.primaryPink.opacity(0.3),
                    ModernSocialTheme.Colors.primaryBlue.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                ModernLoadingView(size: 25)
                
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: place.category.color).opacity(0.4),
                    Color(hex: place.category.color).opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                Image(systemName: place.category.iconName)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white)
                
                if loadFailed {
                    Button("Tap to retry") {
                        loadFailed = false
                        isLoading = true
                        loadImageIfNeeded()
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                }
            }
        }
        .onTapGesture {
            if loadFailed {
                loadFailed = false
                isLoading = true
                loadImageIfNeeded()
            }
        }
    }
    
    private func loadImageIfNeeded() {
        // Check cache first
        let cacheKey = "\(place.id)_modern_card_\(Int(width))x\(Int(height))"
        if let cachedImage = cacheManager.getCachedImage(for: cacheKey) {
            loadedImage = cachedImage
            isLoading = false
            return
        }
        
        guard let firstImage = place.images.first, !firstImage.isEmpty else {
            isLoading = false
            loadFailed = true
            return
        }
        
        isLoading = true
        loadFailed = false
        
        if firstImage.hasPrefix("http") {
            // Direct URL
            loadFromURL(firstImage, cacheKey: cacheKey)
        } else {
            // Google Places photo reference
            loadFromGooglePlaces(firstImage, cacheKey: cacheKey)
        }
    }
    
    private func loadFromURL(_ urlString: String, cacheKey: String) {
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
                    cacheManager.cacheImage(image, for: cacheKey)
                    print("✅ Loaded image from URL for \(place.name)")
                } else {
                    loadFailed = true
                    print("❌ Failed to load image from URL for \(place.name)")
                }
            }
        }.resume()
    }
    
    private func loadFromGooglePlaces(_ photoReference: String, cacheKey: String) {
        guard place.googlePlaceId != nil else {
            print("❌ No Google Place ID available for photo loading")
            isLoading = false
            loadFailed = true
            return
        }
        
        let metadata = GooglePhotoMetadata(
            photoReference: photoReference,
            height: Int(height * 2), // Higher quality
            width: Int(width * 2),   // Higher quality
            htmlAttributions: []
        )
        
        googlePlacesService.fetchPhoto(metadata: metadata, maxSize: CGSize(width: width * 2, height: height * 2)) { image in
            DispatchQueue.main.async {
                isLoading = false
                
                if let image = image {
                    loadedImage = image
                    cacheManager.cacheImage(image, for: cacheKey)
                    print("✅ Loaded Google Places photo for \(place.name)")
                } else {
                    loadFailed = true
                    print("❌ Failed to load Google Places photo for \(place.name) - falling back to default")
                    // Try to load default image as fallback
                    self.loadFromURL(self.getDefaultImageForCategory(place.category), cacheKey: cacheKey)
                }
            }
        }
    }
    
    private func getDefaultImageForCategory(_ category: PlaceCategory) -> String {
        switch category {
        case .restaurants:
            return "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&h=600&fit=crop"
        case .cafes:
            return "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800&h=600&fit=crop"
        case .bars:
            return "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800&h=600&fit=crop"
        case .venues:
            return "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800&h=600&fit=crop"
        case .shopping:
            return "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800&h=600&fit=crop"
        }
    }
}

// MARK: - AI Descriptive Tags View
struct AIDescriptiveTagsView: View {
    let place: Place
    @State private var tags: [String] = []
    @State private var isLoading = false
    @StateObject private var geminiService = GeminiAIService.shared
    
    private let maxTags = 4 // Limit to 3-4 tags as requested
    
    var body: some View {
        // Use a flexible flowing layout that stacks vertically when needed
        FlowLayout(alignment: .leading, spacing: ModernSocialTheme.Spacing.md) {
            if isLoading {
                // Loading state
                ForEach(0..<3, id: \.self) { _ in
                    Text("Loading...")
                        .font(ModernSocialTheme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                        .redacted(reason: .placeholder)
                }
            } else if !tags.isEmpty {
                // Display AI-generated tags (limited to maxTags)
                ForEach(Array(tags.prefix(maxTags)), id: \.self) { tag in
                    Text(tag)
                        .font(ModernSocialTheme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ModernSocialTheme.Colors.primaryPurple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(ModernSocialTheme.Colors.primaryPurple.opacity(0.1))
                        )
                        .lineLimit(1)
                }
            } else {
                // Fallback tags if AI generation fails (limited to maxTags)
                ForEach(Array(generateFallbackTags().prefix(maxTags)), id: \.self) { tag in
                    Text(tag)
                        .font(ModernSocialTheme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ModernSocialTheme.Colors.primaryPurple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(ModernSocialTheme.Colors.primaryPurple.opacity(0.1))
                        )
                        .lineLimit(1)
                }
            }
        }
        .onAppear {
            loadDescriptiveTags()
        }
    }
    
    private func loadDescriptiveTags() {
        // Check if we already have cached tags
        if let existingTags = place.descriptiveTags, !existingTags.isEmpty {
            tags = Array(existingTags.prefix(maxTags))
            return
        }
        
        // Generate new tags with AI
        isLoading = true
        GeminiAIService.shared.sendGeminiRequest(prompt: "Generate descriptive tags for: \(place.name)") { generatedTags in
            DispatchQueue.main.async {
                isLoading = false
                tags = generatedTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.prefix(maxTags).map(String.init)
                // In a real app, you'd cache these tags back to the place object
            }
        }
    }
    
    private func generateFallbackTags() -> [String] {
        var fallbackTags: [String] = []
        
        // Add category-based tag
        switch place.category {
        case .restaurants:
            fallbackTags.append("Dining")
        case .cafes:
            fallbackTags.append("Coffee")
        case .bars:
            fallbackTags.append("Drinks")
        case .venues:
            fallbackTags.append("Events")
        case .shopping:
            fallbackTags.append("Shopping")
        }
        
        // Add rating-based tag
        if place.rating >= 4.5 {
            fallbackTags.append("Top Rated")
        } else if place.rating >= 4.0 {
            fallbackTags.append("Well Rated")
        } else {
            fallbackTags.append("Local Spot")
        }
        
        // Add price-based tag
        switch place.priceRange {
        case "$":
            fallbackTags.append("Budget Friendly")
        case "$$":
            fallbackTags.append("Moderate")
        case "$$$":
            fallbackTags.append("Upscale")
        case "$$$$":
            fallbackTags.append("Luxury")
        default:
            fallbackTags.append("Great Value")
        }
        
        return Array(fallbackTags.prefix(maxTags))
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var alignment: Alignment = .center
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions(),
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        )
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions(),
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        )
        for row in result.rows {
            let rowXOffset = (bounds.width - row.frame.width) * alignment.horizontal.alignmentPercent
            for index in row.range {
                let xPos = bounds.minX + row.frame.minX + rowXOffset + result.sizes[index].xOffset
                let yPos = bounds.minY + row.frame.minY
                subviews[index].place(at: CGPoint(x: xPos, y: yPos), proposal: ProposedViewSize(result.sizes[index].size))
            }
        }
    }
}

struct FlowResult {
    var bounds = CGSize.zero
    var rows: [Row] = []
    var sizes: [Size] = []
    
    struct Row {
        var range: Range<Int>
        var frame: CGRect
    }
    
    struct Size {
        var size: CGSize
        var xOffset: CGFloat
    }
    
    init(in bounds: CGSize, subviews: LayoutSubviews, alignment: Alignment, spacing: CGFloat) {
        var sizes: [Size] = []
        var rows: [Row] = []
        var currentRow = 0..<0
        var remainingWidth = bounds.width
        var rowMinY = 0.0
        var rowHeight = 0.0
        var currentRowX: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            
            if remainingWidth >= size.width || currentRow.isEmpty {
                // Fits in current row or first item in row
                sizes.append(Size(size: size, xOffset: currentRowX))
                
                if !currentRow.isEmpty {
                    remainingWidth -= spacing
                    currentRowX += spacing
                }
                remainingWidth -= size.width
                currentRow = currentRow.lowerBound..<(index + 1)
                rowHeight = max(rowHeight, size.height)
                currentRowX += size.width
            } else {
                // Start a new row
                rows.append(Row(
                    range: currentRow,
                    frame: CGRect(x: 0, y: rowMinY, width: bounds.width - remainingWidth, height: rowHeight)
                ))
                
                rowMinY += rowHeight + spacing
                remainingWidth = bounds.width - size.width
                rowHeight = size.height
                currentRow = index..<(index + 1)
                sizes.append(Size(size: size, xOffset: 0))
                currentRowX = size.width
            }
        }
        
        if !currentRow.isEmpty {
            rows.append(Row(
                range: currentRow,
                frame: CGRect(x: 0, y: rowMinY, width: bounds.width - remainingWidth, height: rowHeight)
            ))
        }
        
        self.sizes = sizes
        self.rows = rows
        self.bounds = CGSize(width: bounds.width, height: rowMinY + rowHeight)
    }
}

extension HorizontalAlignment {
    var alignmentPercent: Double {
        switch self {
        case .leading: return 0
        case .center: return 0.5
        case .trailing: return 1
        default: return 0.5
        }
    }
}

// Preview
#Preview {
    let samplePlace = Place(
        id: UUID(),
        name: "The Modern Cafe",
        description: "Artisanal coffee cozy atmosphere",
        category: .cafes,
        rating: 4.5,
        reviewCount: 127,
                        priceRange: "$$",
        images: ["https://example.com/image.jpg"],
        location: "123 Main St, Downtown",
        hours: "8AM - 6PM",
        detailedHours: nil,
        phone: "(555) 123-4567",
        website: nil,
        menuItems: [],
        reviews: [],
        googlePlaceId: "sample_id",
        sentiment: nil,
        isCurrentlyOpen: true,
        hasActualMenu: false,
        coordinates: Coordinates(latitude: 40.7128, longitude: -74.0060)
    )
    
    VStack(spacing: 20) {
        ModernPlaceCard(
            place: samplePlace,
            onTap: {},
            onFavorite: {},
            isFavorite: false,
            locationManager: LocationManager()
        )
        .frame(width: 300)
        
        ModernHorizontalPlaceCard(
            place: samplePlace,
            onTap: {},
            onFavorite: {},
            isFavorite: true
        )
    }
    .padding()
    .background(Color.adaptiveBackground)
} 