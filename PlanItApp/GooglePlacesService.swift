import Foundation
import CoreLocation
import UIKit

// MARK: - Google Places Error Types
enum GooglePlacesError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case apiKeyMissing
    case networkError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL for Google Places API"
        case .invalidResponse:
            return "Invalid response from Google Places API"
        case .httpError(let code):
            return "HTTP error \(code) from Google Places API"
        case .decodingError:
            return "Failed to decode Google Places response"
        case .apiKeyMissing:
            return "Google Places API key is missing"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

class GooglePlacesService: ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var selectedLocationName: String = "Current Location"
    @Published var isLoading = false
    
    private let apiKey = "AIzaSyBHEFxePy12kmEl2TjwDNe-K7FOnqDq8SI"
    private let baseURL = "https://maps.googleapis.com/maps/api/place"
    
    // Photo cache to avoid re-fetching
    private var photoCache: [String: UIImage] = [:]
    private var photoMetadataCache: [String: [GooglePhotoMetadata]] = [:]
    
    struct PlacesResult {
        let places: [GooglePlace]
        let nextPageToken: String?
    }
    
    func searchPlaces(for category: PlaceCategory, location: CLLocation, radius: Int = 1500, pageToken: String? = nil, completion: @escaping (PlacesResult) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ API Key not configured")
            completion(PlacesResult(places: [], nextPageToken: nil))
            return
        }
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let type = mapCategoryToGoogleType(category)
        
        var urlString = "\(baseURL)/nearbysearch/json?location=\(latitude),\(longitude)&radius=\(radius)&type=\(type)&key=\(apiKey)"
        
        // Add pagination token if available
        if let pageToken = pageToken {
            urlString += "&pagetoken=\(pageToken)"
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            completion(PlacesResult(places: [], nextPageToken: nil))
            return
        }
        
        isLoading = true
        
        // Create request with timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ Error fetching places: \(error.localizedDescription)")
                    if (error as NSError).code == NSURLErrorTimedOut {
                        print("⏰ Request timed out - Google Places API might be slow")
                    }
                    completion(PlacesResult(places: [], nextPageToken: nil))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("❌ HTTP Error: \(httpResponse.statusCode)")
                        if httpResponse.statusCode == 429 {
                            print("⚠️ Rate limit exceeded - too many requests")
                        } else if httpResponse.statusCode == 403 {
                            print("⚠️ API key invalid or quota exceeded")
                        }
                        completion(PlacesResult(places: [], nextPageToken: nil))
                        return
                    }
                }
                
                guard let data = data else {
                    print("❌ No data received")
                    completion(PlacesResult(places: [], nextPageToken: nil))
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
                    print("✅ Found \(result.results.count) places for \(category.rawValue)")
                    print("📍 API Status: \(result.status)")
                    
                    if result.status != "OK" {
                        print("❌ API Error: \(result.status)")
                        if let errorMessage = result.error_message {
                            print("📄 Error details: \(errorMessage)")
                        }
                        if result.status == "REQUEST_DENIED" {
                            print("❌ API Key might be invalid or doesn't have Places API enabled")
                        } else if result.status == "OVER_QUERY_LIMIT" {
                            print("❌ API quota exceeded")
                        } else if result.status == "ZERO_RESULTS" {
                            print("ℹ️ No places found for this category and location")
                        }
                        completion(PlacesResult(places: [], nextPageToken: nil))
                        return
                    }
                    
                    // Use all results since we don't have business_status in our simplified model
                    let activePlaces = result.results
                    
                    print("✅ \(activePlaces.count) active places after filtering")
                    
                    // If we have a next page token, we need to wait before using it
                    if let nextPageToken = result.next_page_token {
                        // Wait for 2 seconds before allowing the next page request
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            completion(PlacesResult(places: activePlaces, nextPageToken: nextPageToken))
                        }
                    } else {
                        completion(PlacesResult(places: activePlaces, nextPageToken: nil))
                    }
                } catch {
                    print("❌ Error decoding response: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📄 Raw response: \(jsonString)")
                    }
                    completion(PlacesResult(places: [], nextPageToken: nil))
                }
            }
        }.resume()
    }
    
    func getPlaceDetails(placeId: String, completion: @escaping (GooglePlaceDetails?) -> Void) {
        let fields = "place_id,name,rating,user_ratings_total,price_level,photos,opening_hours,formatted_phone_number,website,reviews,geometry,formatted_address,types"
        let urlString = "\(baseURL)/details/json?place_id=\(placeId)&fields=\(fields)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for place details")
            completion(nil)
            return
        }
        
        print("🔍 Fetching details for place: \(placeId)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching place details: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received for place details")
                    completion(nil)
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(GooglePlaceDetailsResponse.self, from: data)
                    print("✅ Got details for: \(result.result.name)")
                    completion(result.result)
                } catch {
                    print("❌ Error decoding place details: \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    // MARK: - New Google Places Photo API Implementation (Following Official Documentation)
    
    /// Fetch photo metadata for a place according to Google's documentation
    func fetchPhotoMetadata(for placeId: String, completion: @escaping ([GooglePhotoMetadata]) -> Void) {
        // Check cache first
        if let cached = photoMetadataCache[placeId] {
            print("📸 Using cached photo metadata for \(placeId)")
            completion(cached)
            return
        }
        
        // Use place details to get photo metadata (as per Google documentation)
        getPlaceDetails(placeId: placeId) { [weak self] details in
            guard let details = details,
                  let photos = details.photos else {
                print("❌ No photos found for place \(placeId)")
                completion([])
                return
            }
            
            let metadata = photos.map { photo in
                GooglePhotoMetadata(
                    photoReference: photo.photo_reference,
                    height: photo.height,
                    width: photo.width,
                    htmlAttributions: []
                )
            }
            
            print("📸 Found \(metadata.count) photos for place")
            
            // Cache the metadata
            self?.photoMetadataCache[placeId] = metadata
            completion(metadata)
        }
    }
    
    /// Fetch actual photo using Google Places Photo API (Following official documentation)
    func fetchPhoto(metadata: GooglePhotoMetadata, maxSize: CGSize = CGSize(width: 1200, height: 800), completion: @escaping (UIImage?) -> Void) {
        let cacheKey = "\(metadata.photoReference)_\(Int(maxSize.width))x\(Int(maxSize.height))"
        
        // Check cache first
        if let cachedImage = photoCache[cacheKey] {
            print("📸 Using cached photo")
            completion(cachedImage)
            return
        }
        
        let maxWidth = Int(maxSize.width)
        let photoURL = "\(baseURL)/photo?maxwidth=\(maxWidth)&photoreference=\(metadata.photoReference)&key=\(apiKey)"
        
        guard let url = URL(string: photoURL) else {
            print("❌ Invalid photo URL")
            completion(nil)
            return
        }
        
        print("📸 Fetching HIGH-QUALITY photo from Google Places API (size: \(maxWidth)px)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching photo: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let data = data,
                      let image = UIImage(data: data) else {
                    print("❌ Invalid photo data")
                    completion(nil)
                    return
                }
                
                print("✅ Successfully fetched HIGH-QUALITY photo (\(data.count) bytes, \(image.size.width)x\(image.size.height))")
                
                // Cache the image
                self?.photoCache[cacheKey] = image
                
                // Limit cache size to prevent memory issues
                if let strongSelf = self, strongSelf.photoCache.count > 50 {
                    // Remove oldest entries
                    let keysToRemove = Array(strongSelf.photoCache.keys).prefix(10)
                    keysToRemove.forEach { strongSelf.photoCache.removeValue(forKey: $0) }
                }
                
                completion(image)
            }
        }.resume()
    }
    
    /// Convenient method to get the first (main) photo for a place with HIGH QUALITY
    func fetchMainPhoto(for placeId: String, completion: @escaping (UIImage?) -> Void) {
        fetchPhotoMetadata(for: placeId) { [weak self] metadata in
            guard let firstPhoto = metadata.first else {
                print("❌ No photos available for place")
                completion(nil)
                return
            }
            
            // Fetch high-quality main photo for carousel and detail views
            self?.fetchPhoto(metadata: firstPhoto, maxSize: CGSize(width: 1200, height: 800)) { image in
                completion(image)
            }
        }
    }
    
    /// Get high-quality photo for list/card views
    func fetchCardPhoto(for placeId: String, completion: @escaping (UIImage?) -> Void) {
        fetchPhotoMetadata(for: placeId) { [weak self] metadata in
            guard let firstPhoto = metadata.first else {
                print("❌ No photos available for place")
                completion(nil)
                return
            }
            
            // Fetch medium-quality photo for cards (still high enough to look good)
            self?.fetchPhoto(metadata: firstPhoto, maxSize: CGSize(width: 800, height: 600)) { image in
                completion(image)
            }
        }
    }
    
    /// Legacy method kept for backward compatibility - now properly implemented with HIGH QUALITY
    func getPhotoURL(photoReference: String, maxWidth: Int = 1200) -> String {
        return "\(baseURL)/photo?maxwidth=\(maxWidth)&photoreference=\(photoReference)&key=\(apiKey)"
    }
    
    private func mapCategoryToGoogleType(_ category: PlaceCategory) -> String {
        switch category {
        case .restaurants:
            return "restaurant"
        case .cafes:
            return "cafe"
        case .bars:
            return "bar"
        case .venues:
            return "night_club"
        case .shopping:
            return "shopping_mall"
        }
    }
    
    // MARK: - Mission Support - Search Nearby Places
    func searchNearbyPlaces(location: CLLocation, types: [String], radius: Int = 10000, completion: @escaping ([GooglePlace]) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ API Key not configured")
            completion([])
            return
        }
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let typesString = types.joined(separator: "|")
        
        let urlString = "\(baseURL)/nearbysearch/json?location=\(latitude),\(longitude)&radius=\(radius)&type=\(typesString)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            completion([])
            return
        }
        
        print("🔍 Searching nearby places for mission generation")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching nearby places: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received")
                    completion([])
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
                    print("✅ Found \(result.results.count) nearby places for mission")
                    
                    if result.status != "OK" {
                        print("❌ API Error: \(result.status)")
                        completion([])
                        return
                    }
                    
                    // Sort by rating (highest first)
                    let activePlaces = result.results
                        .sorted { place1, place2 in
                            let rating1 = place1.rating ?? 0.0
                            let rating2 = place2.rating ?? 0.0
                            return rating1 > rating2
                        }
                    
                    completion(activePlaces)
                } catch {
                    print("❌ Error decoding response: \(error)")
                    completion([])
                }
            }
        }.resume()
    }

    // MARK: - Async Methods for RecommendationEngine
    
    func searchNearby(
        location: CLLocation,
        radius: Double,
        type: String,
        keyword: String
    ) async throws -> [GooglePlaceDetails] {
        return await withCheckedContinuation { continuation in
            // Use the existing searchPlacesByText method for keyword searches
            searchPlacesByText(query: keyword, location: location, radius: Int(radius * 1000)) { places in
                // Filter places by type if specified
                let filteredPlaces = places.filter { place in
                    if type.isEmpty { return true }
                    return place.types?.contains { $0.lowercased().contains(type.lowercased()) } ?? false
                }
                
                // Convert GooglePlace to GooglePlaceDetails
                let placeDetails = filteredPlaces.compactMap { place in
                    // Convert photo objects if available
                    let convertedPhotos: [GooglePhoto]? = place.photos?.map { p in
                        GooglePhoto(
                            photo_reference: p.photo_reference,
                            height: p.height,
                            width: p.width,
                            html_attributions: p.html_attributions
                        )
                    }

                    // Convert geometry (unwrap with fallback 0 to avoid optionals)
                    let geo: GoogleGeometry = {
                        if let g = place.geometry {
                            return GoogleGeometry(location: GoogleLocation(lat: g.location.lat, lng: g.location.lng))
                        } else {
                            return GoogleGeometry(location: GoogleLocation(lat: 0.0, lng: 0.0))
                        }
                    }()

                    return GooglePlaceDetails(
                        place_id: place.place_id,
                        name: place.name,
                        rating: place.rating,
                        user_ratings_total: place.user_ratings_total,
                        price_level: place.price_level,
                        photos: convertedPhotos,
                        opening_hours: nil, // Not available in search results
                        formatted_phone_number: nil,
                        website: nil,
                        reviews: nil,
                        geometry: geo,
                        formatted_address: place.vicinity ?? "",
                        types: place.types
                    )
                }
                
                continuation.resume(returning: placeDetails)
            }
        }
    }
    
    // MARK: - Text Search Functionality
    func searchPlacesByText(query: String, location: CLLocation, radius: Int = 5000, completion: @escaping ([GooglePlace]) -> Void) {
        guard !apiKey.isEmpty, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ API Key not configured or empty query")
            completion([])
            return
        }
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "\(baseURL)/textsearch/json?query=\(encodedQuery)&location=\(latitude),\(longitude)&radius=\(radius)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid search URL")
            completion([])
            return
        }
        
        print("🔍 Searching places with query: '\(query)' near \(latitude), \(longitude)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Search error: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let data = data else {
                    print("❌ No search data received")
                    completion([])
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
                    print("✅ Found \(result.results.count) places for query: '\(query)'")
                    
                    if result.status != "OK" {
                        print("❌ Search API Error: \(result.status)")
                        completion([])
                        return
                    }
                    
                    // Sort results by distance from user location
                    let sortedResults = result.results.sorted { place1, place2 in
                        let location1 = CLLocation(
                            latitude: place1.geometry?.location.lat ?? 0.0,
                            longitude: place1.geometry?.location.lng ?? 0.0
                        )
                        let location2 = CLLocation(
                            latitude: place2.geometry?.location.lat ?? 0.0,
                            longitude: place2.geometry?.location.lng ?? 0.0
                        )
                        
                        let distance1 = location.distance(from: location1)
                        let distance2 = location.distance(from: location2)
                        
                        return distance1 < distance2
                    }
                    
                    completion(sortedResults)
                } catch {
                    print("❌ Error decoding search response: \(error)")
                    completion([])
                }
            }
        }.resume()
    }

    // MARK: - Enhanced Search Methods for RecommendationEngine
    
    /// Search for nearby places using type and keyword (for RecommendationEngine)
    func searchNearby(
        location: CLLocation,
        radius: Double,
        type: String,
        keyword: String
    ) async throws -> [GooglePlace] {
        let radiusInMeters = Int(radius * 1609.34) // Convert miles to meters
        
        var urlComponents = URLComponents(string: "https://maps.googleapis.com/maps/api/place/nearbysearch/json")!
        urlComponents.queryItems = [
            URLQueryItem(name: "location", value: "\(location.coordinate.latitude),\(location.coordinate.longitude)"),
            URLQueryItem(name: "radius", value: "\(radiusInMeters)"),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "keyword", value: keyword),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = urlComponents.url else {
            throw GooglePlacesError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GooglePlacesError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GooglePlacesError.httpError(httpResponse.statusCode)
        }
        
        do {
            let searchResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
            
            if searchResponse.status != "OK" && searchResponse.status != "ZERO_RESULTS" {
                print("⚠️ Google Places API warning: \(searchResponse.status)")
            }
            
            return searchResponse.results ?? []
        } catch {
            print("❌ Error decoding Google Places response: \(error)")
            throw GooglePlacesError.decodingError
        }
    }
}

// MARK: - Enhanced Google Places API Models

struct GooglePhotoMetadata {
    let photoReference: String
    let height: Int
    let width: Int
    let htmlAttributions: [String]
    
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }
    
    var isLandscape: Bool {
        return width > height
    }
}

struct GooglePlacesResponse: Codable {
    let results: [GooglePlace]
    let status: String
    let error_message: String?
    let next_page_token: String?
}

struct GooglePlaceDetailsResponse: Codable {
    let result: GooglePlaceDetails
    let status: String
    let error_message: String?
}

// MARK: - Missing Google Places Types
struct GooglePhoto: Codable {
    let photo_reference: String
    let height: Int
    let width: Int
    let html_attributions: [String]
}

struct GoogleGeometry: Codable {
    let location: GoogleLocation
}

struct GoogleLocation: Codable {
    let lat: Double
    let lng: Double
}

struct GooglePlaceDetails: Codable {
    let place_id: String
    let name: String
    let rating: Double?
    let user_ratings_total: Int?
    let price_level: Int?
    let photos: [GooglePhoto]?
    let opening_hours: GoogleOpeningHours?
    let formatted_phone_number: String?
    let website: String?
    let reviews: [GoogleReview]?
    let geometry: GoogleGeometry
    let formatted_address: String?
    let types: [String]?
}

struct GoogleOpeningHours: Codable {
    let open_now: Bool?
    let weekday_text: [String]?
    let periods: [GooglePeriod]?
}

struct GooglePeriod: Codable {
    let open: GoogleTime?
    let close: GoogleTime?
}

struct GoogleTime: Codable {
    let day: Int
    let time: String
}

struct GoogleReview: Codable {
    let author_name: String
    let rating: Int
    let text: String
    let time: Int
    let relative_time_description: String?
} 
