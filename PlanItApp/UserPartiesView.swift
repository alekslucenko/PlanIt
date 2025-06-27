import SwiftUI
import FirebaseAuth
import CoreLocation

/// 🎉 USER-FOCUSED PARTIES VIEW
/// Modern, user-friendly interface for discovering and RSVPing to live parties
/// Shows real Firestore data with beautiful cards, search, filtering, and RSVP management
struct UserPartiesView: View {
    @EnvironmentObject var partyManager: PartyManager
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    
    @State private var searchText = ""
    @State private var selectedFilter: PartyFilter = .all
    @State private var showingPartyDetail = false
    @State private var selectedParty: Party?
    @State private var showingRSVPSheet = false
    @State private var isRefreshing = false
    @State private var hasAppeared = false
    @State private var showingMyRSVPs = false
    
    enum PartyFilter: String, CaseIterable {
        case all = "All Parties"
        case today = "Today"
        case thisWeek = "This Week"
        case free = "Free Events"
        case nearby = "Nearby"
        case myRSVPs = "My RSVPs"
        
        var icon: String {
            switch self {
            case .all: return "party.popper"
            case .today: return "calendar.circle"
            case .thisWeek: return "calendar.badge.clock"
            case .free: return "gift.circle"
            case .nearby: return "location.circle"
            case .myRSVPs: return "checkmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .purple
            case .today: return .orange
            case .thisWeek: return .blue
            case .free: return .green
            case .nearby: return .teal
            case .myRSVPs: return .pink
            }
        }
    }
    
    var filteredParties: [Party] {
        var parties = partyManager.nearbyParties
        
        // Apply text search first
        if !searchText.isEmpty {
            parties = parties.filter { party in
                party.title.localizedCaseInsensitiveContains(searchText) ||
                party.description.localizedCaseInsensitiveContains(searchText) ||
                party.location.name.localizedCaseInsensitiveContains(searchText) ||
                party.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            parties = parties.filter { party in
                party.startDate >= today && party.startDate < tomorrow
            }
        case .thisWeek:
            let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek)!
            parties = parties.filter { party in
                party.startDate >= startOfWeek && party.startDate < endOfWeek
            }
        case .free:
            parties = parties.filter { party in
                party.ticketTiers.isEmpty || party.ticketTiers.contains { $0.price == 0 }
            }
        case .nearby:
            // Filter by distance if location is available
            if let userLocation = locationManager.selectedLocation ?? locationManager.currentLocation {
                parties = parties.filter { party in
                    let partyLocation = CLLocation(latitude: party.location.latitude, longitude: party.location.longitude)
                    let distance = userLocation.distance(from: partyLocation)
                    return distance <= 10000 // 10km radius
                }
            }
        case .myRSVPs:
            let userRSVPPartyIds = Set(partyManager.userRSVPs.map { $0.partyId })
            parties = parties.filter { userRSVPPartyIds.contains($0.id) }
        }
        
        return parties.sorted { $0.startDate < $1.startDate }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background with party theme
                PartyThemeBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with search and stats
                    headerSection
                    
                    // Filter chips
                    filterSection
                    
                    // Content
                    if isRefreshing {
                        loadingView
                    } else if filteredParties.isEmpty {
                        emptyStateView
                    } else {
                        partyGridView
                    }
                }
            }
            .navigationTitle("🎉 Live Parties")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { Task { await refreshParties() } }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: { showingMyRSVPs.toggle() }) {
                            Label("My RSVPs", systemImage: "list.bullet.clipboard")
                        }
                        
                        Button(action: { selectedFilter = .nearby }) {
                            Label("Find Nearby", systemImage: "location.magnifyingglass")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(themeManager.travelBlue)
                    }
                }
            }
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
        .sheet(isPresented: $showingMyRSVPs) {
            MyRSVPsView()
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                performanceService.optimizeForKeyboardInput()
                
                Task {
                    await initialLoadParties()
                }
                
                print("🎉 UserPartiesView appeared - initial load")
            }
        }
        .onDisappear {
            performanceService.restoreNormalInputMode()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Search bar with party stats
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeManager.secondaryText)
                    
                    TextField("Search parties, venues, hosts...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .themedText(.primary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.cardBackground.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.travelPurple.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Party count badge
                VStack(spacing: 2) {
                    Text("\(filteredParties.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.travelPink)
                    
                    Text("live")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(themeManager.secondaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.travelPink.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.travelPink.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(themeManager.primaryBackground.opacity(0.95))
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PartyFilter.allCases, id: \.self) { filter in
                    PartyFilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        count: getFilterCount(filter),
                        action: { selectedFilter = filter }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var partyGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredParties) { party in
                    ModernPartyCard(
                        party: party,
                        isRSVPed: partyManager.isUserRSVPed(to: party.id),
                        onTap: {
                            selectedParty = party
                            showingPartyDetail = true
                        },
                        onQuickRSVP: {
                            selectedParty = party
                            Task {
                                do {
                                    try await partyManager.quickRSVP(to: party.id, selectedTier: party.ticketTiers.first)
                                    print("✅ Quick RSVP successful")
                                } catch {
                                    print("❌ Quick RSVP failed: \(error)")
                                    // Show RSVP form instead
                                    showingRSVPSheet = true
                                }
                            }
                        },
                        onFullRSVP: {
                            selectedParty = party
                            showingRSVPSheet = true
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(themeManager.travelPink)
            
            Text("Loading live parties...")
                .font(.headline)
                .themedText(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "party.popper")
                .font(.system(size: 80))
                .foregroundColor(themeManager.travelPink.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Parties Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .themedText(.primary)
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .themedText(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 16) {
                Button("Refresh") {
                    Task { await refreshParties() }
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.travelBlue)
                
                Button("Clear Filters") {
                    searchText = ""
                    selectedFilter = .all
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return searchText.isEmpty ? "No parties are currently live. Check back later for exciting events!" : "No parties match your search. Try different keywords."
        case .today:
            return "No parties happening today. Try checking 'This Week' or 'All Parties'."
        case .thisWeek:
            return "No parties this week. Check 'All Parties' for upcoming events."
        case .free:
            return "No free events available right now. Check 'All Parties' for paid events."
        case .nearby:
            return "No parties found nearby. Try expanding your search or enable location services."
        case .myRSVPs:
            return "You haven't RSVP'd to any parties yet. Browse 'All Parties' to find events!"
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFilterCount(_ filter: PartyFilter) -> Int {
        switch filter {
        case .all:
            return partyManager.nearbyParties.count
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            return partyManager.nearbyParties.filter { $0.startDate >= today && $0.startDate < tomorrow }.count
        case .thisWeek:
            let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek)!
            return partyManager.nearbyParties.filter { $0.startDate >= startOfWeek && $0.startDate < endOfWeek }.count
        case .free:
            return partyManager.nearbyParties.filter { party in
                party.ticketTiers.isEmpty || party.ticketTiers.contains { $0.price == 0 }
            }.count
        case .nearby:
            if let userLocation = locationManager.selectedLocation ?? locationManager.currentLocation {
                return partyManager.nearbyParties.filter { party in
                    let partyLocation = CLLocation(latitude: party.location.latitude, longitude: party.location.longitude)
                    let distance = userLocation.distance(from: partyLocation)
                    return distance <= 10000 // 10km radius
                }.count
            }
            return 0
        case .myRSVPs:
            return partyManager.userRSVPs.count
        }
    }
    
    private func initialLoadParties() async {
        do {
            try await performanceService.performBackgroundTask {
                await partyManager.checkHostMode()
                partyManager.setupListeners()
            }
        } catch {
            print("⚠️ Error during initial party load: \(error)")
        }
        
        print("✅ Initial parties load completed")
    }
    
    private func refreshParties() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        
        print("🎉 Refreshing parties...")
        
        do {
            try await performanceService.performBackgroundTask {
                await MainActor.run {
                    partyManager.removeListeners()
                    partyManager.setupListeners()
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        } catch {
            print("⚠️ Error refreshing parties: \(error)")
        }
        
        await MainActor.run {
            isRefreshing = false
            print("✅ Parties refreshed - Found \(partyManager.nearbyParties.count) parties")
        }
    }
}

// MARK: - Supporting Views

struct PartyThemeBackground: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    themeManager.travelPurple.opacity(0.1),
                    themeManager.travelPink.opacity(0.05),
                    themeManager.primaryBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated particles effect
            GeometryReader { geometry in
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(themeManager.travelPink.opacity(0.1))
                        .frame(width: 4, height: 4)
                        .offset(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 3...6))
                            .repeatForever(autoreverses: true),
                            value: UUID()
                        )
                }
            }
        }
    }
}

struct PartyFilterChip: View {
    let filter: UserPartiesView.PartyFilter
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: filter.icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(filter.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 20, minHeight: 16)
                        .background(Circle().fill(filter.color))
                }
            }
            .foregroundColor(isSelected ? .white : filter.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? filter.color : filter.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(filter.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    UserPartiesView()
        .environmentObject(PartyManager.shared)
} 