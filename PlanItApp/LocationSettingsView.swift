import SwiftUI
import CoreLocation

// MARK: - Location Settings View
// Complies with Apple App Store Guidelines Section 5.1.5 - Location Services
struct LocationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    @State private var preciseLocationEnabled = false
    @State private var backgroundLocationEnabled = false
    @State private var locationSharingEnabled = true
    @State private var showingLocationAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Location Services")
                                    .font(.headline)
                                
                                Text("Control how PlanIt uses your location to help you discover places")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("About Location Services")
                        .textCase(nil)
                }
                
                Section {
                    LocationStatusRow()
                    
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iOS Location Settings")
                                .font(.body)
                            
                            Text("Manage location permissions in Settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Open Settings") {
                            openLocationSettings()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Current Status")
                        .textCase(nil)
                }
                
                Section {
                    SettingsToggleRow(
                        icon: "location.circle.fill",
                        title: "Place Discovery",
                        subtitle: "Use location to find nearby places and recommendations",
                        isOn: $locationSharingEnabled,
                        color: .blue
                    )
                    
                    if locationManager.authorizationStatus == .authorizedWhenInUse || 
                       locationManager.authorizationStatus == .authorizedAlways {
                        SettingsToggleRow(
                            icon: "location.north.line.fill",
                            title: "Precise Location",
                            subtitle: "Get exact location for better recommendations",
                            isOn: $preciseLocationEnabled,
                            color: .green
                        )
                    }
                } header: {
                    Text("Location Features")
                        .textCase(nil)
                } footer: {
                    Text("PlanIt uses location data only to enhance your experience by finding relevant places nearby. Your location is never shared with third parties without your explicit consent.")
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Privacy Protection")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("Location data is processed securely and used only for core app functionality. We follow Apple's strict privacy guidelines.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Data Usage")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("• Find nearby places and attractions\n• Provide location-based recommendations\n• Calculate distances and directions\n• Enhance search results")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("What We Don't Do")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("• Track your location in the background\n• Share location with advertisers\n• Store precise location history\n• Use location for marketing purposes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Privacy Information")
                        .textCase(nil)
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            loadLocationSettings()
        }
        .onChange(of: locationSharingEnabled) { _, newValue in
            saveLocationSettings()
        }
        .onChange(of: preciseLocationEnabled) { _, newValue in
            saveLocationSettings()
        }
    }
    
    private func openLocationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func loadLocationSettings() {
        let defaults = UserDefaults.standard
        locationSharingEnabled = defaults.bool(forKey: "location_sharing_enabled")
        preciseLocationEnabled = defaults.bool(forKey: "precise_location_enabled")
    }
    
    private func saveLocationSettings() {
        let defaults = UserDefaults.standard
        defaults.set(locationSharingEnabled, forKey: "location_sharing_enabled")
        defaults.set(preciseLocationEnabled, forKey: "precise_location_enabled")
    }
}

// MARK: - Location Status Row
struct LocationStatusRow: View {
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Location Access")
                    .font(.body)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if locationManager.authorizationStatus == .notDetermined {
                Button("Enable") {
                    locationManager.requestLocationPermission()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            } else {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.headline)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var statusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse:
            return "Allowed while using app"
        case .authorizedAlways:
            return "Always allowed"
        case .denied:
            return "Access denied"
        case .restricted:
            return "Access restricted"
        case .notDetermined:
            return "Permission not requested"
        @unknown default:
            return "Unknown status"
        }
    }
} 