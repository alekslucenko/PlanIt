import Foundation

// MARK: - Convenience helpers for Google Places models used throughout the codebase

extension GooglePlace {
    /// Legacy camel-case alias mapping to `place_id` in Google responses.
    var placeId: String { place_id }
    /// Best-effort human readable address combining formatted address and vicinity.
    var address: String {
        formatted_address ?? vicinity ?? ""
    }
}

extension GooglePlaceDetails {
    /// Legacy camel-case alias mapping to `place_id` in Google responses.
    var placeId: String { place_id }
    /// Convenience computed address using formatted or empty string fallback.
    var address: String {
        formatted_address ?? ""
    }
} 