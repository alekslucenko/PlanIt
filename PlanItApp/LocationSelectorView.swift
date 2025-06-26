import SwiftUI
import CoreLocation

struct LocationSelectorView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var locationSearch: LocationSearchService
    @State private var isShowingSearch = false
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Location selector button
            Button(action: {
                isShowingSearch.toggle()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "location.circle.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Location")
                            .font(.interCaptionMedium)
                            .foregroundColor(.secondary)
                        
                        Text(locationManager.selectedLocationName)
                            .font(.interBodyMedium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isShowingSearch ? 180 : 0))
                        .animation(.spring(response: 0.3), value: isShowingSearch)
                    
                    if locationManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Search dropdown
            if isShowingSearch {
                VStack(spacing: 0) {
                    // Search field
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.interBodyMedium)
                            .foregroundColor(.secondary)
                        
                        TextField("Search for a location...", text: $searchText)
                            .font(.interBodyRegular)
                            .onChange(of: searchText) { oldValue, newValue in
                                locationSearch.searchLocations(query: newValue)
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: { 
                                searchText = ""
                                locationSearch.searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.interBodyMedium)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Current location option
                    Button(action: {
                        locationManager.useCurrentLocation()
                        isShowingSearch = false
                        searchText = ""
                        locationSearch.searchResults = []
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .font(.interBodyMedium)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use Current Location")
                                    .font(.interBodyMedium)
                                    .foregroundColor(.primary)
                                
                                Text("Find places nearby")
                                    .font(.interCaptionRegular)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16)
                    
                    // Search results
                    if locationSearch.isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.interCaptionRegular)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 16)
                    } else if !locationSearch.searchResults.isEmpty {
                        LazyVStack(spacing: 0) {
                            ForEach(locationSearch.searchResults, id: \.self) { mapItem in
                                Button(action: {
                                    locationSearch.selectLocation(mapItem) { location, name in
                                        locationManager.selectLocation(location, name: name)
                                        isShowingSearch = false
                                        searchText = ""
                                        locationSearch.searchResults = []
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.interBodyMedium)
                                            .foregroundColor(.orange)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(mapItem.name ?? "Unknown Location")
                                                .font(.interBodyMedium)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            if let placemark = mapItem.placemark.title {
                                                Text(placemark)
                                                    .font(.interCaptionRegular)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.clear)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Error message
                    if let error = locationManager.locationError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text(error)
                                .font(.interCaptionRegular)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    
                    Spacer(minLength: 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
                .padding(.top, 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowingSearch)
            }
        }
        .onAppear {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestLocationPermission()
            }
        }
    }
} 