import Foundation
import CoreLocation

extension GooglePlace {
    func toAppPlace() -> Place {
        // Map Google types to PlaceCategory (enhanced mapping)
        let category: PlaceCategory = {
            let typeList = types?.map { $0.lowercased() } ?? []
            
            if typeList.contains("restaurant") || typeList.contains("food") || typeList.contains("meal_takeaway") {
                return .restaurants
            }
            if typeList.contains("cafe") || typeList.contains("bakery") {
                return .cafes
            }
            if typeList.contains("bar") || typeList.contains("night_club") || typeList.contains("liquor_store") {
                return .bars
            }
            if typeList.contains("shopping_mall") || typeList.contains("store") || typeList.contains("clothing_store") {
                return .shopping
            }
            if typeList.contains("tourist_attraction") || typeList.contains("amusement_park") || typeList.contains("museum") {
                return .venues
            }
            
            // Default fallback
            return .restaurants
        }()

        let coord = Coordinates(
            latitude: geometry?.location.lat ?? 0.0,
            longitude: geometry?.location.lng ?? 0.0
        )
        
        // Extract photo references for proper image loading
        let imageReferences: [String] = {
            if let firstPhoto = photos?.first?.photo_reference {
                return [firstPhoto]
            } else {
                // Use default image for category if no photos available
                return [getDefaultImageForCategory(category)]
            }
        }()

        let address = formatted_address ?? vicinity ?? ""

        return Place(
            id: UUID(),
            name: name,
            description: address.isEmpty ? generateVibeDescription(for: name, category: category) : address,
            category: category,
            rating: rating ?? 0.0,
            reviewCount: user_ratings_total ?? 0,
            priceRange: getPriceRangeString(from: price_level),
            images: imageReferences,
            location: address,
            hours: getBusinessHoursString(),
            detailedHours: nil,
            phone: "",
            website: nil,
            menuItems: [],
            reviews: [],
            googlePlaceId: place_id,
            sentiment: nil,
            isCurrentlyOpen: opening_hours?.open_now ?? true,
            hasActualMenu: false,
            coordinates: coord
        )
    }
    
    // Helper methods
    private func getPriceRangeString(from priceLevel: Int?) -> String {
        guard let level = priceLevel else { return "$$" }
        switch level {
        case 0: return "$"
        case 1: return "$"
        case 2: return "$$"
        case 3: return "$$$"
        case 4: return "$$$$"
        default: return "$$"
        }
    }
    
    private func getBusinessHoursString() -> String {
        return "Hours available • Tap for details"
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
    
    private func generateVibeDescription(for name: String, category: PlaceCategory) -> String {
        let vibeWords: [String] = {
            switch category {
            case .restaurants:
                return ["DELICIOUS", "AUTHENTIC", "COZY", "GOURMET", "FRESH"]
            case .cafes:
                return ["ARTISANAL", "RELAXING", "AROMATIC", "COZY", "VIBRANT"]
            case .bars:
                return ["LIVELY", "TRENDY", "CRAFT", "INTIMATE", "ENERGETIC"]
            case .venues:
                return ["CULTURAL", "INSPIRING", "HISTORIC", "INTERACTIVE", "UNIQUE"]
            case .shopping:
                return ["TRENDY", "DIVERSE", "BOUTIQUE", "LUXURY", "LOCAL"]
            }
        }()
        
        let typeWords: [String] = {
            switch category {
            case .restaurants:
                return ["DINING", "CUISINE", "FLAVORS"]
            case .cafes:
                return ["COFFEE", "ATMOSPHERE", "BRUNCH"]
            case .bars:
                return ["COCKTAILS", "NIGHTLIFE", "SOCIAL"]
            case .venues:
                return ["CULTURE", "EXPERIENCE", "ART"]
            case .shopping:
                return ["FASHION", "RETAIL", "STYLE"]
            }
        }()
        
        // Pick 2-3 random tags
        let selectedVibes = vibeWords.shuffled().prefix(2)
                    let selectedType = typeWords.randomElement() ?? typeWords.first ?? "place"
        
        return "\(selectedVibes.joined(separator: " • ")) • \(selectedType)"
    }
} 