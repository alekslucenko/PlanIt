import SwiftUI
import CoreLocation
import FirebaseAuth

/// 🎉 ENHANCED COMPREHENSIVE PARTIES VIEW
/// Modern UI for discovering and RSVPing to nearby parties
/// Includes search, filtering, detailed party information, and real-time updates
struct PartiesView: View, Equatable {
    @StateObject private var partyManager = PartyManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    @State private var searchText = ""
    @State private var selectedFilter: PartyFilter = .all
    @State private var showingPartyDetail = false
    @State private var selectedParty: Party?
    @State private var showingRSVPSheet = false
    @State private var isRefreshing = false
    @State private var viewId = UUID()
    
    enum PartyFilter: String, CaseIterable {
        case all = "All Parties"
        case today = "Today"
        case thisWeek = "This Week"
        case free = "Free Events"
        case nearby = "Nearby"
    }
    
    // Equatable implementation for performance
    static func == (lhs: PartiesView, rhs: PartiesView) -> Bool {
        return lhs.searchText == rhs.searchText &&
               lhs.selectedFilter == rhs.selectedFilter &&
               lhs.isRefreshing == rhs.isRefreshing &&
               lhs.partyManager.nearbyParties.count == rhs.partyManager.nearbyParties.count
    }
    
    var filteredParties: [Party] {
        var parties = partyManager.nearbyParties
        
        // Apply search filter
        if !searchText.isEmpty {
            parties = partyManager.searchParties(query: searchText)
        }
        
        // Apply category filter
        switch selectedFilter {
        case .all:
            break
        case .today:
            parties = parties.filter { Calendar.current.isDateInToday($0.startDate) }
        case .thisWeek:
            let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            parties = parties.filter { $0.startDate <= weekFromNow }
        case .free:
            parties = parties.filter { $0.ticketTiers.isEmpty || $0.ticketTiers.contains { $0.price == 0 } }
        case .nearby:
            if let location = locationManager.currentLocation {
                parties = partyManager.getPartiesNearLocation(location, radius: 10000) // 10km
            }
        }
        
        return parties.sorted { $0.startDate < $1.startDate }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Themed background
                themeManager.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Enhanced header with search and filters
                    headerSection
                    
                    // Party content
                    if isRefreshing {
                        loadingView
                    } else if filteredParties.isEmpty {
                        emptyStateView
                    } else {
                        partyListView
                    }
                }
            }
            .navigationTitle("🎉 Parties")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button(action: {
                    Task { await refreshParties() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(themeManager.travelBlue)
                }
            )
            .refreshable {
                await refreshParties()
            }
        }
        .sheet(isPresented: $showingPartyDetail) {
            if let party = selectedParty {
                PartyDetailView(party: party)
            }
        }
        .sheet(isPresented: $showingRSVPSheet) {
            if let party = selectedParty {
                RSVPFormView(party: party)
            }
        }
        .onAppear {
            performanceService.optimizeForKeyboardInput()
            
            Task {
                await refreshParties()
            }
            
            // Force view refresh when appearing
            viewId = UUID()
            print("🎉 PartiesView appeared and refreshed")
        }
        .onDisappear {
            performanceService.restoreNormalInputMode()
        }
        .id(viewId)
        .performanceOptimized(identifier: "PartiesView")
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Enhanced search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.secondaryText)
                
                TextField("Search parties...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .themedText(.primary)
                    .onTapGesture {
                        performanceService.optimizeForKeyboardInput()
                    }
                
                if !searchText.isEmpty {
                    Button(action: { 
                        searchText = ""
                        performanceService.restoreNormalInputMode()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(themeManager.secondaryText)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            
            // Enhanced filter tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PartyFilter.allCases, id: \.self) { filter in
                        EnhancedFilterChip(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(themeManager.primaryBackground.opacity(0.95))
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(themeManager.travelBlue)
            
            Text("Loading parties...")
                .themedText(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var partyListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredParties) { party in
                    EnhancedPartyCard(
                        party: party,
                        isRSVPed: partyManager.isUserRSVPed(to: party.id),
                        onTap: {
                            selectedParty = party
                            showingPartyDetail = true
                        },
                        onRSVP: {
                            selectedParty = party
                            showingRSVPSheet = true
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "party.popper")
                .font(.system(size: 64))
                .foregroundColor(themeManager.travelPink)
            
            VStack(spacing: 8) {
                Text("No Parties Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .themedText(.primary)
                
                Text("Check back later for exciting events in your area!")
                    .font(.subheadline)
                    .themedText(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Refresh") {
                Task { await refreshParties() }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.travelBlue)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func refreshParties() async {
        isRefreshing = true
        
        print("🎉 Starting parties refresh...")
        
        // Use performance-optimized operations
        do {
            try await performanceService.performBackgroundTask {
                await partyManager.checkHostMode()
                
                // Load parties and create samples if needed
                await partyManager.loadPartiesAndCreateSamples()
                
                // Force PartyManager to refresh its listeners and data
                await MainActor.run {
                    partyManager.removeListeners()
                    partyManager.setupListeners()
                }
            }
        } catch {
            print("⚠️ Error refreshing parties: \(error)")
        }
        
        // Add a small delay for smooth animation and data loading
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds for data to load
        
        await MainActor.run {
            isRefreshing = false
            viewId = UUID() // Force view refresh
            print("✅ Parties refreshed successfully - Found \(partyManager.nearbyParties.count) parties")
        }
    }
}

// MARK: - Performance-Optimized Filter Chip Component
struct EnhancedFilterChip: View, Equatable {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    
    static func == (lhs: EnhancedFilterChip, rhs: EnhancedFilterChip) -> Bool {
        return lhs.title == rhs.title && lhs.isSelected == rhs.isSelected
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isSelected ? 
                            themeManager.travelPink : 
                            themeManager.cardBackground
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isSelected ? 
                                    themeManager.travelPink : 
                                    themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), 
                                    lineWidth: 1
                                )
                        )
                )
                .foregroundColor(isSelected ? .white : themeManager.primaryText)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(performanceService.getOptimizedSpringAnimation(), value: isSelected)
    }
}

// MARK: - Performance-Optimized Party Card Component
struct EnhancedPartyCard: View, Equatable {
    let party: Party
    let isRSVPed: Bool
    let onTap: () -> Void
    let onRSVP: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    
    static func == (lhs: EnhancedPartyCard, rhs: EnhancedPartyCard) -> Bool {
        return lhs.party.id == rhs.party.id && 
               lhs.isRSVPed == rhs.isRSVPed &&
               lhs.party.currentAttendees == rhs.party.currentAttendees
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Party image or placeholder
            partyImageSection
            
            // Party details
            VStack(alignment: .leading, spacing: 12) {
                // Header with title and status
                headerSection
                
                // Host and timing info
                detailsSection
                
                // Location info
                locationSection
                
                // Action buttons
                actionSection
            }
            .padding(16)
        }
        .themedCard()
        .onTapGesture {
            onTap()
        }
        .performanceOptimized(identifier: "PartyCard_\(party.id)")
    }
    
    private var partyImageSection: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [themeManager.travelPink, themeManager.travelPurple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 120)
            .overlay(
                VStack {
                    Image(systemName: "party.popper")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    
                    Text(party.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding()
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(party.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .themedText(.primary)
                    .lineLimit(2)
                
                if !party.description.isEmpty {
                    Text(party.description)
                        .font(.subheadline)
                        .themedText(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Party status
            Text(party.status.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
                .cornerRadius(8)
        }
    }
    
    private var detailsSection: some View {
        VStack(spacing: 8) {
            // Host info
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(themeManager.travelBlue)
                
                Text("Hosted by \(party.hostName)")
                    .font(.subheadline)
                    .themedText(.secondary)
                
                Spacer()
            }
            
            // Date and time
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(themeManager.travelGreen)
                
                Text(formatDate(party.startDate))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .themedText(.primary)
                
                Spacer()
                
                Text("\(formatTime(party.startDate)) - \(formatTime(party.endDate))")
                    .font(.subheadline)
                    .themedText(.secondary)
            }
        }
    }
    
    private var locationSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .foregroundColor(themeManager.travelOrange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(party.location.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .themedText(.primary)
                
                Text(party.location.fullAddress)
                    .font(.caption)
                    .themedText(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
    }
    
    private var actionSection: some View {
        HStack {
            // Attendance info
            VStack(alignment: .leading, spacing: 2) {
                Text("\(party.currentAttendees) / \(party.guestCap)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .themedText(.primary)
                
                Text("Attending")
                    .font(.caption)
                    .themedText(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Details") {
                    onTap()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(themeManager.travelBlue)
                
                if !isRSVPed && party.currentAttendees < party.guestCap && party.status == .upcoming {
                    Button("RSVP") {
                        onRSVP()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(themeManager.travelPink)
                } else if isRSVPed {
                    Text("✓ RSVP'd")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.travelGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.travelGreen.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch party.status {
        case .upcoming:
            return themeManager.travelBlue
        case .live:
            return themeManager.travelGreen
        case .ended:
            return themeManager.tertiaryText
        case .cancelled:
            return themeManager.travelRed
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    PartiesView()
} 