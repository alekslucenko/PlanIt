import Foundation
import CoreLocation

struct DistanceCalculator {
    
    /// Calculate distance between two coordinates in miles
    static func distanceInMiles(from location1: CLLocation, to location2: CLLocation) -> Double {
        let distanceInMeters = location1.distance(from: location2)
        let distanceInMiles = distanceInMeters * 0.000621371 // Convert meters to miles
        return distanceInMiles
    }
    
    /// Calculate distance between two coordinates in kilometers
    static func distanceInKilometers(from location1: CLLocation, to location2: CLLocation) -> Double {
        let distanceInMeters = location1.distance(from: location2)
        return distanceInMeters / 1000.0
    }
    
    /// Check if a place is within the specified radius (in miles)
    static func isWithinRadius(userLocation: CLLocation, placeLocation: CLLocation, radiusMiles: Double) -> Bool {
        let distance = distanceInMiles(from: userLocation, to: placeLocation)
        return distance <= radiusMiles
    }
    
    /// Filter places within radius
    static func filterPlacesWithinRadius(places: [Place], userLocation: CLLocation, radiusMiles: Double) -> [Place] {
        return places.filter { place in
            guard let coordinates = place.coordinates else { return false }
            let placeLocation = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
            return isWithinRadius(userLocation: userLocation, placeLocation: placeLocation, radiusMiles: radiusMiles)
        }
    }
    
    /// Format distance for display
    static func formatDistance(_ distance: Double) -> String {
        if distance < 0.1 {
            return String(format: "%.0f ft", distance * 5280)
        } else if distance < 1.0 {
            return String(format: "%.1f mi", distance)
        } else {
            return String(format: "%.1f mi", distance)
        }
    }
}

// MARK: - Place Extension for Distance
extension Place {
    func distanceFromUser(userLocation: CLLocation) -> Double? {
        guard let coordinates = self.coordinates else { return nil }
        let placeLocation = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        return DistanceCalculator.distanceInMiles(from: userLocation, to: placeLocation)
    }
    
    func formattedDistance(from userLocation: CLLocation) -> String {
        guard let distance = distanceFromUser(userLocation: userLocation) else {
            return "Unknown distance"
        }
        return DistanceCalculator.formatDistance(distance)
    }
    
    // Note: distanceFrom method is now defined in AppModels.swift to avoid duplication
} 