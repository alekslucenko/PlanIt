import Foundation
import CoreLocation
import MapKit

class LocationSearchService: NSObject, ObservableObject {
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching = false
    
    private let searchCompleter = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
    }
    
    func searchLocations(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // Use MKLocalSearch for more complete results
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                
                if let error = error {
                    print("Search error: \(error.localizedDescription)")
                    self?.searchResults = []
                    return
                }
                
                self?.searchResults = response?.mapItems ?? []
            }
        }
    }
    
    func selectLocation(_ mapItem: MKMapItem, completion: @escaping (CLLocation, String) -> Void) {
        let location = CLLocation(
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude
        )
        
        let name = mapItem.name ?? mapItem.placemark.title ?? "Selected Location"
        completion(location, name)
    }
    
    func getCurrentLocationName(for location: CLLocation, completion: @escaping (String) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Reverse geocoding error: \(error.localizedDescription)")
                    completion("Current Location")
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    completion("Current Location")
                    return
                }
                
                let components = [
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.country
                ].compactMap { $0 }
                
                let locationName = components.joined(separator: ", ")
                completion(locationName.isEmpty ? "Current Location" : locationName)
            }
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension LocationSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // This is used for auto-completion, but we're using MKLocalSearch for full results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
} 