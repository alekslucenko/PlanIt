import SwiftUI
import MapKit
import FirebaseAuth

/// 🎉 COMPREHENSIVE PARTY DETAIL VIEW
/// Shows detailed party information, host history, location map, and RSVP functionality
/// Professional UI with complete feature set for party exploration
struct PartyDetailView: View {
    let party: Party
    
    @StateObject private var partyManager = PartyManager.shared
    @State private var showingRSVPForm = false
    @State private var showingHostHistory = false
    @State private var showingDirections = false
    @State private var hostPreviousParties: [Party] = []
    @State private var loadingHostParties = false
    @State private var region: MKCoordinateRegion
    @Environment(\.dismiss) private var dismiss
    
    init(party: Party) {
        self.party = party
        self._region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: party.location.latitude,
                longitude: party.location.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var isRSVPed: Bool {
        partyManager.isUserRSVPed(to: party.id)
    }
    
    var canRSVP: Bool {
        !isRSVPed && party.currentAttendees < party.guestCap && party.status == .upcoming
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero section
                    heroSection
                    
                    // Quick info cards
                    quickInfoSection
                    
                    // Description
                    descriptionSection
                    
                    // Location and map
                    locationSection
                    
                    // Ticket tiers
                    if !party.ticketTiers.isEmpty {
                        ticketTiersSection
                    }
                    
                    // Host information
                    hostSection
                    
                    // Perks
                    if !party.perks.isEmpty {
                        perksSection
                    }
                    
                    // RSVP section
                    rsvpSection
                    
                    // Host's Previous Parties Section
                    hostPreviousPartiesSection
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareParty) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingRSVPForm) {
            RSVPFormView(party: party)
        }
        .sheet(isPresented: $showingHostHistory) {
            SimpleHostHistoryView(hostId: party.hostId, hostName: party.hostName)
        }
        .onAppear {
            loadHostPreviousParties()
        }
    }
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Party image placeholder with gradient
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.purple.opacity(0.8), .blue.opacity(0.8), .cyan.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 200)
                    .cornerRadius(16)
                    .overlay(
                        VStack {
                            Image(systemName: "party.popper")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text(party.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    )
                
                // Status badge
                HStack(spacing: 8) {
                    Image(systemName: statusIcon)
                    Text(party.status.rawValue.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(16)
            }
            
            // Title and basic info
            VStack(alignment: .leading, spacing: 8) {
                Text(party.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                HStack(spacing: 16) {
                    Label(formatDateTime(party.startDate), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Label("\(party.currentAttendees)/\(party.guestCap)", systemImage: "person.2.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var quickInfoSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            InfoCard(
                icon: "clock.fill",
                title: "Duration",
                value: formatDuration(start: party.startDate, end: party.endDate),
                color: .blue
            )
            
            InfoCard(
                icon: "location.fill",
                title: "Location",
                value: party.location.name,
                color: .green
            )
            
            if let cheapestTier = party.ticketTiers.min(by: { $0.price < $1.price }) {
                InfoCard(
                    icon: "dollarsign.circle.fill",
                    title: "From",
                    value: cheapestTier.price == 0 ? "Free" : "$\(String(format: "%.0f", cheapestTier.price))",
                    color: .orange
                )
            }
            
            InfoCard(
                icon: "checkmark.circle.fill",
                title: "RSVP Status",
                value: isRSVPed ? "Confirmed" : "Not RSVP'd",
                color: isRSVPed ? .green : .gray
            )
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About This Event")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(party.description)
                .font(.body)
                .lineSpacing(4)
            
            // Tags
            if !party.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(party.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(party.location.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(party.location.fullAddress)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Map view
            Map(coordinateRegion: .constant(region), annotationItems: [MapAnnotation(party: party)]) { annotation in
                MapPin(coordinate: annotation.coordinate, tint: .red)
            }
            .frame(height: 200)
            .cornerRadius(12)
            .onTapGesture {
                showingDirections = true
            }
            
            Button(action: { showingDirections = true }) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Get Directions")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var ticketTiersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ticket Options")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                ForEach(party.ticketTiers) { tier in
                    TicketTierCard(tier: tier)
                }
            }
        }
    }
    
    private var hostSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Host")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(String(party.hostName.prefix(1)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: { showingHostHistory = true }) {
                        Text(party.hostName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("Event Host")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("View Host History") {
                        showingHostHistory = true
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "message.fill")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private var perksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's Included")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(party.perks, id: \.self) { perk in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text(perk)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var rsvpSection: some View {
        VStack(spacing: 16) {
            if isRSVPed {
                // Already RSVP'd
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("You're Going!")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text("Your RSVP has been confirmed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    
                    Button("Manage RSVP") {
                        showingRSVPForm = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            } else if canRSVP {
                // Can RSVP
                VStack(spacing: 12) {
                    Text("Ready to join the party?")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Button("RSVP Now") {
                        showingRSVPForm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(12)
            } else {
                // Cannot RSVP
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    Text(party.currentAttendees >= party.guestCap ? "Event Full" : "RSVP Unavailable")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(party.currentAttendees >= party.guestCap ? "This event has reached capacity" : "RSVP is no longer available for this event")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private var statusIcon: String {
        switch party.status {
        case .upcoming:
            return "clock.fill"
        case .live:
            return "dot.radiowaves.left.and.right"
        case .ended:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(start: Date, end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func shareParty() {
        // Implementation for sharing party
        let shareText = "Check out this party: \(party.title) on \(formatDateTime(party.startDate))"
        let activityController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
    
    private var hostPreviousPartiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Host's Previous Parties")
                .font(.title2)
                .fontWeight(.bold)
            
            if loadingHostParties {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading previous parties...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if hostPreviousParties.isEmpty {
                Text("No previous parties")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(hostPreviousParties.prefix(10)) { previousParty in
                            CompactPartyCard(party: previousParty)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }
    
    private func loadHostPreviousParties() {
        loadingHostParties = true
        
        Task {
            do {
                // Get parties hosted by this host that are not the current party
                let allHostParties = try await partyManager.getPartiesByHost(hostId: party.hostId)
                
                await MainActor.run {
                    hostPreviousParties = allHostParties.filter { $0.id != party.id }
                        .sorted { $0.startDate > $1.startDate } // Most recent first
                    loadingHostParties = false
                }
            } catch {
                print("❌ Error loading host's previous parties: \(error)")
                await MainActor.run {
                    hostPreviousParties = []
                    loadingHostParties = false
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TicketTierCard: View {
    let tier: TicketTier
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(tier.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if !tier.perks.isEmpty {
                    Text("Includes: \(tier.perks.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(tier.price == 0 ? "Free" : "$\(String(format: "%.0f", tier.price))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(tier.price == 0 ? .green : .primary)
                
                Text("\(tier.currentSold)/\(tier.maxQuantity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !tier.isAvailable {
                    Text("Sold Out")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(tier.isAvailable ? 1.0 : 0.6)
    }
}

struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    
    init(party: Party) {
        self.coordinate = CLLocationCoordinate2D(
            latitude: party.location.latitude,
            longitude: party.location.longitude
        )
        self.title = party.title
    }
}

// MARK: - ENHANCED Host History View
struct SimpleHostHistoryView: View {
    let hostId: String
    let hostName: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var partyManager = PartyManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var hostParties: [Party] = []
    @State private var isLoading = true
    @State private var hostStats: HostStats?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Enhanced Host Avatar
                    hostAvatarSection
                    
                    // Host Stats Section
                    hostStatsSection
                    
                    // Party History Section
                    partyHistorySection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .themedBackground()
            .navigationTitle("Host Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.travelBlue)
                }
            }
        }
        .onAppear {
            loadHostData()
        }
    }
    
    private var hostAvatarSection: some View {
        VStack(spacing: 16) {
            // Enhanced Host Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [themeManager.travelPurple, themeManager.travelBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(
                        color: themeManager.travelPurple.opacity(0.4),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                
                Text(String(hostName.prefix(1)).uppercased())
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text(hostName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .themedText(.primary)
                
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text("Event Host")
                        .font(.subheadline)
                        .themedText(.secondary)
                }
            }
        }
    }
    
    private var hostStatsSection: some View {
        VStack(spacing: 16) {
            Text("Host Statistics")
                .font(.headline)
                .fontWeight(.semibold)
                .themedText(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let stats = hostStats {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    HostStatCard(
                        icon: "calendar",
                        title: "Events Hosted",
                        value: "\(stats.totalParties)",
                        color: themeManager.travelBlue
                    )
                    
                    HostStatCard(
                        icon: "person.2",
                        title: "Total Attendees",
                        value: "\(stats.totalAttendees)",
                        color: themeManager.travelGreen
                    )
                    
                    HostStatCard(
                        icon: "star",
                        title: "Average Rating",
                        value: String(format: "%.1f", stats.averageRating),
                        color: themeManager.travelYellow
                    )
                    
                    HostStatCard(
                        icon: "clock",
                        title: "Hosting Since",
                        value: formatHostingSince(stats.memberSince),
                        color: themeManager.travelPurple
                    )
                }
            } else if isLoading {
                ProgressView("Loading host statistics...")
                    .themedText(.secondary)
                    .padding()
            } else {
                Text("Host statistics unavailable")
                    .themedText(.secondary)
                    .padding()
            }
        }
        .themedCard()
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
    
    private var partyHistorySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Party History")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .themedText(.primary)
                
                Spacer()
                
                if !hostParties.isEmpty {
                    Text("\(hostParties.count) events")
                        .font(.caption)
                        .themedText(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.travelBlue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading party history...")
                        .themedText(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if hostParties.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "party.popper")
                        .font(.system(size: 48))
                        .themedText(.secondary)
                    
                    Text("No Previous Parties")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .themedText(.primary)
                    
                    Text("This host hasn't hosted any previous parties.")
                        .themedText(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Horizontal scrollable party cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(hostParties.prefix(10)) { party in
                            HostPartyHistoryCard(party: party)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        }
        .themedCard()
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
    
    private func loadHostData() {
        Task {
            await loadHostParties()
            await loadHostStats()
            isLoading = false
        }
    }
    
    @MainActor
    private func loadHostParties() async {
        do {
            let parties = try await partyManager.getHostPartyHistory(hostId: hostId)
            hostParties = parties.sorted { $0.startDate > $1.startDate }
        } catch {
            print("❌ Error loading host parties: \(error)")
            hostParties = []
        }
    }
    
    @MainActor
    private func loadHostStats() async {
        do {
            let stats = try await partyManager.getHostStatistics(hostId: hostId)
            hostStats = stats
        } catch {
            print("❌ Error loading host stats: \(error)")
            hostStats = nil
        }
    }
    
    private func formatHostingSince(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Host Stat Card Component
struct HostStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .themedText(.primary)
                
                Text(title)
                    .font(.caption)
                    .themedText(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(themeManager.isDarkMode ? 0.1 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Host Party History Card
struct HostPartyHistoryCard: View {
    let party: Party
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Party Status Badge
                HStack {
                    Spacer()
                    
                    Text(party.status.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.8))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(party.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .themedText(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(party.location.name)
                        .font(.subheadline)
                        .themedText(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .themedText(.secondary)
                        
                        Text(formatDate(party.startDate))
                            .font(.caption)
                            .themedText(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(party.currentAttendees)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .themedText(.primary)
                            
                            Text("Attendees")
                                .font(.caption2)
                                .themedText(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(party.guestCap)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .themedText(.primary)
                            
                            Text("Capacity")
                                .font(.caption2)
                                .themedText(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .frame(width: 180, height: 200)
            .padding(16)
            .themedCard()
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            PartyDetailView(party: party)
        }
    }
    
    private var statusColor: Color {
        switch party.status {
        case .upcoming: return themeManager.travelBlue
        case .live: return themeManager.travelGreen
        case .ended: return themeManager.tertiaryText
        case .cancelled: return themeManager.travelRed
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Host Statistics Model (moved to AppModels.swift)

#Preview {
    PartyDetailView(party: Party(
        title: "Sample Party",
        description: "This is a sample party description for preview purposes.",
        hostId: "sample",
        hostName: "Sample Host",
        location: PartyLocation(
            name: "Sample Venue",
            address: "123 Party St",
            city: "San Francisco",
            state: "CA",
            zipCode: "94102",
            latitude: 37.7749,
            longitude: -122.4194,
            placeId: nil
        ),
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        guestCap: 100
    ))
}

// MARK: - Compact Party Card for Host Previous Parties
struct CompactPartyCard: View {
    let party: Party
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Party image placeholder
            Rectangle()
                .fill(LinearGradient(
                    colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 140, height: 80)
                .cornerRadius(8)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "party.popper")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        
                        Text(party.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(4)
                )
            
            // Party info
            VStack(alignment: .leading, spacing: 2) {
                Text(party.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(formatCompactDate(party.startDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("\(party.currentAttendees) attended")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 140)
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            PartyDetailView(party: party)
        }
    }
    
    private func formatCompactDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - EventDetailView Component
struct EventDetailView: View {
    let party: Party
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with image
                        eventHeaderSection
                        
                        // Event details
                        eventDetailsSection
                        
                        // Analytics section
                        eventAnalyticsSection
                        
                        // Attendees section
                        eventAttendeesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Event Details")
                        .font(.inter(18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var eventHeaderSection: some View {
        VStack(spacing: 16) {
            // Event image
            if let imageUrl = party.images.first, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.orange.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "party.popper.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.white.opacity(0.6))
                        )
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "party.popper.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
            
            // Title and status
            VStack(spacing: 8) {
                Text(party.title)
                    .font(.inter(24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                MainStatusBadge(status: party.status)
            }
        }
    }
    
    private var eventDetailsSection: some View {
        VStack(spacing: 16) {
            DetailCard(
                title: "Description",
                content: party.description,
                icon: "text.alignleft"
            )
            
            DetailCard(
                title: "Location",
                content: party.location.name + "\n" + party.location.fullAddress,
                icon: "location.fill"
            )
            
            DetailCard(
                title: "Date & Time",
                content: formatEventDateTime(),
                icon: "calendar"
            )
            
            DetailCard(
                title: "Capacity",
                content: "\(party.currentAttendees) / \(party.capacityValue) attendees",
                icon: "person.3.fill"
            )
        }
    }
    
    private var eventAnalyticsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Event Analytics")
                    .font(.inter(18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                StatMiniCard(
                    title: "Views",
                    value: "\(party.viewCount ?? 0)",
                    icon: "eye.fill",
                    color: .blue
                )
                
                StatMiniCard(
                    title: "Revenue",
                    value: "$\(String(format: "%.0f", calculateRevenue()))",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                StatMiniCard(
                    title: "Clicks",
                    value: "\(party.clickCount ?? 0)",
                    icon: "hand.tap.fill",
                    color: .purple
                )
            }
        }
    }
    
    private var eventAttendeesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Attendees")
                    .font(.inter(18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(party.attendees.count) total")
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            if party.attendees.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("No attendees yet")
                        .font(.inter(14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(height: 80)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(party.attendees.prefix(5)) { attendee in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(String(attendee.userName.prefix(1).uppercased()))
                                        .font(.inter(12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(attendee.userName)
                                    .font(.inter(14, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Joined \(formatJoinDate(attendee.joinedAt))")
                                    .font(.inter(11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    
                    if party.attendees.count > 5 {
                        Text("+ \(party.attendees.count - 5) more attendees")
                            .font(.inter(12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    private func formatEventDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        
        let startString = formatter.string(from: party.startDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let endString = timeFormatter.string(from: party.endDate)
        
        return "\(startString)\nUntil \(endString)"
    }
    
    private func calculateRevenue() -> Double {
        return party.ticketTiers.reduce(0.0) { $0 + ($1.price * Double($1.soldCount)) }
    }
    
    private func formatJoinDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views
struct DetailCard: View {
    let title: String
    let content: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.inter(16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text(content)
                .font(.inter(14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

