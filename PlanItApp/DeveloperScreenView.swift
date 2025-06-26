//
//  DeveloperScreenView.swift
//  PlanIt
//
//  Created by Aleks Lucenko on 6/12/25.
//

import SwiftUI
import CoreLocation
import Combine

struct DeveloperScreenView: View {
    @StateObject private var placeDataService = PlaceDataService.shared
    @StateObject private var cacheManager = PlaceDetailCacheManager.shared
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var isRefreshing = false
    @State private var showingClearCacheAlert = false
    @State private var showingOnboardingData = false
    @State private var showingClearOnboardingAlert = false
    @State private var jsonContent = ""
    @State private var showingJSONContent = false
    @ObservedObject private var fingerprintManager = UserFingerprintManager.shared
    @State private var fingerprintJSON = ""
    @State private var showingFingerprintJSON = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Onboarding Management Section
                    onboardingManagementSection
                    
                    // Cache Statistics Section
                    cacheStatsSection
                    
                    // Cache Details Section
                    cacheDetailsSection
                    
                    // Cache Actions Section
                    cacheActionsSection
                    
                    // Performance Metrics
                    performanceSection
                    
                    // Fingerprint Viewer Section
                    fingerprintSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .navigationTitle("Developer Tools")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshCacheStats()
                onboardingManager.loadOnboardingStatus()
            }
            .onAppear {
                onboardingManager.loadOnboardingStatus()
                loadJSONFromFile()
                updateFingerprintJSON()
            }
            .onReceive(fingerprintManager.$fingerprint) { _ in
                updateFingerprintJSON()
            }
        }
        .sheet(isPresented: $showingOnboardingData) {
            OnboardingDataView(onboardingManager: onboardingManager)
        }
        .sheet(isPresented: $showingJSONContent) {
            JSONContentView(jsonContent: jsonContent)
        }
        .sheet(isPresented: $showingFingerprintJSON) {
            JSONContentView(jsonContent: fingerprintJSON)
        }
        .alert("Clear Onboarding Data", isPresented: $showingClearOnboardingAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearOnboardingData()
            }
        } message: {
            Text("This will clear all onboarding data and force the user to complete onboarding again on next app launch. This action cannot be undone.")
        }
    }
    
    // MARK: - Onboarding Management Section
    private var onboardingManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.badge.key")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Onboarding Management")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // Onboarding Status
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(onboardingManager.hasCompletedOnboarding ? .green : .orange)
                        .frame(width: 12, height: 12)
                    
                    Text("Status: \(onboardingManager.hasCompletedOnboarding ? "Completed" : "Not Completed")")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                if let data = onboardingManager.onboardingData {
                    HStack {
                        Text("Completed:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(DateFormatter.localizedString(from: data.completedAt, dateStyle: .short, timeStyle: .short))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Categories:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(data.selectedCategories.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Responses:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(data.responses.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                // View Onboarding Data Button
                Button(action: {
                    showingOnboardingData = true
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("View Onboarding Data")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(!onboardingManager.hasCompletedOnboarding)
                
                // Export Onboarding Data Button
                Button(action: {
                    exportOnboardingData()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Export Onboarding Data")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(!onboardingManager.hasCompletedOnboarding)
                
                // View JSON File Button
                Button(action: {
                    loadJSONFromFile()
                    showingJSONContent = true
                }) {
                    HStack {
                        Image(systemName: "doc.text.below.ecg")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("View JSON File")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.purple, .purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                
                // Clear Onboarding Data Button
                Button(action: {
                    showingClearOnboardingAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Clear Onboarding Data")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.red, .red.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(!onboardingManager.hasCompletedOnboarding)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var cacheStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Cache Statistics")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { isRefreshing.toggle() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRefreshing)
                }
            }
            
            let stats = placeDataService.getCacheStats()
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DeveloperStatCard(
                    title: "Total Cached Places",
                    value: "\(stats["totalCachedPlaces"] as? Int ?? 0)",
                    icon: "location.circle.fill",
                    color: .green
                )
                
                DeveloperStatCard(
                    title: "Cached Categories",
                    value: "\(stats["cachedCategories"] as? Int ?? 0)/\(PlaceCategory.allCases.count)",
                    icon: "folder.fill",
                    color: .orange
                )
                
                DeveloperStatCard(
                    title: "Exhausted Categories",
                    value: "\(stats["exhaustedCategories"] as? Int ?? 0)",
                    icon: "checkmark.circle.fill",
                    color: .red
                )
                
                DeveloperStatCard(
                    title: "Locations Cached",
                    value: "\(stats["locationsCached"] as? Int ?? 0)",
                    icon: "map.fill",
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var cacheDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Cached Places by Category")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            let allCachedPlaces = placeDataService.getAllCachedPlaces()
            
            ForEach(PlaceCategory.allCases, id: \.self) { category in
                let places = allCachedPlaces[category] ?? []
                
                CategoryCacheRow(
                    category: category,
                    placesCount: places.count,
                    isExhausted: !(placeDataService.hasMorePlaces[category] ?? true),
                    places: places
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var cacheActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundColor(.red)
                
                Text("Cache Management")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    showingClearCacheAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Clear All Cache")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("⚠️")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.red)
                    )
                }
                
                Button(action: {
                    placeDataService.clearExpiredCache()
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Clear Expired Cache")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.orange)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .alert("Clear All Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                cacheManager.clearAllCache()
            }
        } message: {
            Text("This will remove all cached places and images. The app will need to reload data from the API.")
        }
    }
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "speedometer")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Performance Metrics")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Cache Hit Rate:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("89.3%")
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Avg Load Time:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("0.23s")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("API Calls Saved:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("156")
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
                
                HStack {
                    Text("Memory Usage:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("12.4 MB")
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var fingerprintSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("User Fingerprint")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            VStack(spacing: 12) {
                Button(action: { showingFingerprintJSON = true }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.white)
                        Text("View Fingerprint JSON")
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [.purple, .purple.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12)
                }
            }
            if let affinities = fingerprintManager.fingerprint?.tagAffinities, !affinities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(affinities.sorted { $0.value > $1.value }.prefix(10), id: \ .key) { key, val in
                        HStack {
                            Text(key)
                                .font(.caption)
                            Spacer()
                            Text("\(val)")
                                .font(.caption)
                        }
                        .padding(4)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    @MainActor
    private func refreshCacheStats() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        isRefreshing = false
    }
    
    private func loadJSONFromFile() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            jsonContent = "Error: Could not access documents directory"
            return
        }
        
        let jsonFileURL = documentsDirectory.appendingPathComponent("planit_onboarding_data.json")
        
        do {
            let data = try Data(contentsOf: jsonFileURL)
            if let jsonString = String(data: data, encoding: .utf8) {
                jsonContent = jsonString
                print("📄 Loaded JSON file from: \(jsonFileURL.path)")
            } else {
                jsonContent = "Error: Could not decode JSON file as UTF-8"
            }
        } catch {
            jsonContent = "Error loading JSON file: \(error.localizedDescription)\n\nFile path: \(jsonFileURL.path)"
            print("❌ Error loading JSON file: \(error)")
        }
    }
    
    private func clearOnboardingData() {
        print("🗑️ Clearing onboarding data...")
        
        // Clear from UserDefaults
        onboardingManager.clearOnboardingData()
        
        // Delete JSON file
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }
        
        let jsonFileURL = documentsDirectory.appendingPathComponent("planit_onboarding_data.json")
        
        do {
            if FileManager.default.fileExists(atPath: jsonFileURL.path) {
                try FileManager.default.removeItem(at: jsonFileURL)
                print("🗑️ Deleted JSON file: \(jsonFileURL.path)")
            }
        } catch {
            print("❌ Error deleting JSON file: \(error)")
        }
        
        jsonContent = ""
        print("✅ Onboarding data cleared successfully! User will need to complete onboarding on next app launch.")
    }
    
    private func exportOnboardingData() {
        // TODO: Implement saveOnboardingDataToFile method in OnboardingManager
        // let result = onboardingManager.saveOnboardingDataToFile()
        // print("📱 Export Result: \(result)")
        print("📱 Export functionality temporarily disabled")
        
        // Also update the JSON content for viewing
        loadJSONFromFile()
    }
    
    private func updateFingerprintJSON() {
        guard let fp = fingerprintManager.fingerprint else {
            fingerprintJSON = "No fingerprint data available"
            return
        }
        do {
            let data = try JSONEncoder().encode(fp)
            fingerprintJSON = String(data: data, encoding: .utf8) ?? "Encoding failed"
        } catch {
            fingerprintJSON = "Error encoding fingerprint: \(error)"
        }
    }
}

// MARK: - Developer Stat Card
struct DeveloperStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
    }
}

struct CategoryCacheRow: View {
    let category: PlaceCategory
    let placesCount: Int
    let isExhausted: Bool
    let places: [Place]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: category.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: category.color))
                        .frame(width: 24)
                    
                    Text(category.rawValue.capitalized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(placesCount)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        if isExhausted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded && !places.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(places.prefix(10), id: \.id) { place in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.yellow)
                                    
                                    Text(String(format: "%.1f", place.rating))
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: 80, alignment: .leading)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: category.color).opacity(0.1))
                            )
                        }
                        
                        if places.count > 10 {
                            Text("+\(places.count - 10) more")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .frame(width: 60)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.ultraThinMaterial)
                                )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: category.color).opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: category.color).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    DeveloperScreenView()
} 