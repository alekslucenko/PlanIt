import SwiftUI

/// A cached photo view that loads images for Place objects with intelligent caching
struct CachedGooglePlacesPhotoView: View {
    let place: Place
    let width: CGFloat
    let height: CGFloat
    let onImageLoaded: ((UIImage) -> Void)?
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var shouldLoad = false
    @State private var hasAppeared = false
    @StateObject private var googlePlacesService = GooglePlacesService()
    @StateObject private var cacheManager = PlaceDetailCacheManager.shared
    
    init(place: Place, width: CGFloat, height: CGFloat, onImageLoaded: ((UIImage) -> Void)? = nil) {
        self.place = place
        self.width = width
        self.height = height
        self.onImageLoaded = onImageLoaded
    }
    
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
                            
                            Image(systemName: place.category.iconName)
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
                            Image(systemName: place.category.iconName)
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: place.category.color).opacity(0.6))
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
            // Check cache first using place ID
            let cacheKey = "\(place.id)_\(Int(width))x\(Int(height))"
            if let cachedImage = cacheManager.getCachedImage(for: cacheKey) {
                loadedImage = cachedImage
                return
            }
            
            hasAppeared = true
            // Auto-load for smaller images
            if width < 300 {
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
        
        // Try to load from place images
        if let firstImageUrl = place.images.first, !firstImageUrl.isEmpty {
            if firstImageUrl.hasPrefix("http") {
                // This is a direct URL
                loadFromURL(firstImageUrl)
            } else {
                // This is a Google Places photo reference
                loadFromGooglePlaces(photoReference: firstImageUrl)
            }
        } else {
            // No images available, show placeholder
            print("❌ No images available for place: \(place.name)")
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
                    let cacheKey = "\(place.id)_\(Int(width))x\(Int(height))"
                    cacheManager.cacheImage(image, for: cacheKey)
                    onImageLoaded?(image)
                    print("✅ Loaded image from URL for \(place.name)")
                }
            }
        }.resume()
    }
    
    private func loadFromGooglePlaces(photoReference: String) {
        guard let placeId = place.googlePlaceId else {
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
                    let cacheKey = "\(place.id)_\(Int(width))x\(Int(height))"
                    cacheManager.cacheImage(image, for: cacheKey)
                    onImageLoaded?(image)
                    print("✅ Loaded Google Places photo for \(place.name)")
                } else {
                    print("❌ Failed to load Google Places photo for \(place.name)")
                }
            }
        }
    }
} 