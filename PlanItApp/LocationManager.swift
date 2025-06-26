import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var selectedLocation: CLLocation?
    @Published var selectedLocationName: String = "Select Location"
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var isLoading = false
    @Published var lastLocationAccuracy: Double?
    
    override init() {
        super.init()
        print("🏗️ Initializing LocationManager")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Only update when user moves 10 meters
        
        // Set initial authorization status
        authorizationStatus = locationManager.authorizationStatus
        print("📍 Initial authorization status: \(authorizationStatus.description)")
        
        // For iOS 18 compatibility, ensure we handle the permission properly
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        // Configure for iOS 18+
        switch authorizationStatus {
        case .notDetermined:
            // Don't provide default location yet, let user choose
            print("📍 Location permission not determined yet")
        case .denied, .restricted:
            print("📍 Location access denied, using default location")
            provideDefaultLocation()
        case .authorizedWhenInUse, .authorizedAlways:
            getCurrentLocation()
        @unknown default:
            print("⚠️ Unknown authorization status")
            provideDefaultLocation()
        }
    }
    
    func requestLocationPermission() {
        print("🔒 Requesting location permission")
        
        // Check if location services are enabled
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = "Location services are disabled on this device. Please enable them in Settings."
            provideDefaultLocation()
            return
        }
        
        switch authorizationStatus {
        case .notDetermined:
            // This will trigger the native iOS location permission prompt
            DispatchQueue.main.async {
                self.locationManager.requestWhenInUseAuthorization()
                // Kick-off a location request immediately so iOS shows the dialog on some edge cases (iOS 14+)
                self.locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                // Prompt user to open Settings if access is denied
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            locationError = "Location access is required to find places near you. Please enable location access in Settings."
            print("❌ Location access denied or restricted – opened Settings")
            provideDefaultLocation()
        case .authorizedWhenInUse, .authorizedAlways:
            getCurrentLocation()
        @unknown default:
            print("⚠️ Unknown authorization status")
            provideDefaultLocation()
        }
    }
    
    func getCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ Cannot get location - not authorized")
            locationError = "Location permission required"
            provideDefaultLocation()
            return
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            print("❌ Location services disabled")
            locationError = "Location services are disabled"
            provideDefaultLocation()
            return
        }
        
        print("📍 Requesting current location")
        DispatchQueue.main.async {
            self.isLoading = true
            self.locationError = nil
        }
        
        // Move location request to background queue to avoid UI blocking
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                self.locationManager.requestLocation()
            }
        }
    }
    
    func selectLocation(_ location: CLLocation, name: String) {
        print("📍 Selected location: \(name) at \(location.coordinate)")
        selectedLocation = location
        selectedLocationName = name
        locationError = nil
        
        // Get precise city and zipcode
        reverseGeocodeLocation(location)
    }
    
    func useCurrentLocation() {
        print("📍 Using current location")
        if let currentLocation = currentLocation {
            selectedLocation = currentLocation
            selectedLocationName = "Current Location"
            locationError = nil
        } else {
            getCurrentLocation()
        }
    }
    
    private func provideDefaultLocation() {
        print("📍 Providing default location (NYC)")
        let fallbackLocation = CLLocation(latitude: 40.7128, longitude: -74.0060) // NYC
        selectLocation(fallbackLocation, name: "New York City 10001")
    }
    
    private func reverseGeocodeLocation(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Reverse geocoding failed: \(error.localizedDescription)")
                return
            }
            
            guard let placemark = placemarks?.first else {
                print("❌ No placemark found")
                return
            }
            
            DispatchQueue.main.async {
                // Format as "City, Zipcode" or "City, State Zipcode"
                var locationName = ""
                
                if let city = placemark.locality {
                    locationName = city
                }
                
                if let zipcode = placemark.postalCode {
                    if !locationName.isEmpty {
                        locationName += " \(zipcode)"
                    } else {
                        locationName = zipcode
                    }
                }
                
                // Fallback to administrative area if city not available
                if locationName.isEmpty, let state = placemark.administrativeArea {
                    locationName = state
                    if let zipcode = placemark.postalCode {
                        locationName += " \(zipcode)"
                    }
                }
                
                // Final fallback
                if locationName.isEmpty {
                    locationName = "Current Location"
                }
                
                self.selectedLocationName = locationName
                print("📍 Updated location name to: \(locationName)")
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLoading = false
        guard let location = locations.last else { 
            print("❌ No location in update")
            return 
        }
        
        print("✅ Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        currentLocation = location
        lastLocationAccuracy = location.horizontalAccuracy
        
        // If no location is selected yet, use current location
        if selectedLocation == nil {
            selectedLocation = location
            selectedLocationName = "Current Location"
            print("📍 Auto-selected current location")
            
            // Get precise city and zipcode
            reverseGeocodeLocation(location)
        }
        
        locationError = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = "Location access denied. Using default location."
                print("❌ Location access denied")
            case .locationUnknown:
                locationError = "Unable to determine location. Using default location."
                print("❌ Location unknown")
            case .network:
                locationError = "Network error getting location. Using default location."
                print("❌ Network error")
            default:
                locationError = "Location error: \(error.localizedDescription)"
                print("❌ Location error: \(error.localizedDescription)")
            }
        } else {
            locationError = "Unable to get your location: \(error.localizedDescription)"
            print("❌ Location error: \(error.localizedDescription)")
        }
        
        // Always provide a fallback location
        if selectedLocation == nil {
            provideDefaultLocation()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("🔒 Authorization changed to: \(manager.authorizationStatus.description)")
        
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            switch self.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationError = nil
                // 🔍 Request precise location if we only have reduced accuracy (iOS 14+)
                if #available(iOS 14.0, *) {
                    if manager.accuracyAuthorization == .reducedAccuracy {
                        print("🔎 Requesting temporary full-accuracy authorization…")
                        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "PreciseLocation")
                    }
                }
                self.getCurrentLocation()
            case .denied, .restricted:
                self.locationError = "Location access is required to find places near you. Please enable it in Settings."
                self.provideDefaultLocation()
            case .notDetermined:
                self.locationError = nil
            @unknown default:
                print("⚠️ Unknown authorization status in delegate")
                self.provideDefaultLocation()
            }
        }
    }
}

// MARK: - Helper Extension for Authorization Status Description
extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        @unknown default:
            return "unknown"
        }
    }
}

 