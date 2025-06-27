import SwiftUI
import FirebaseAuth

/// 📋 MY RSVPs VIEW
/// Comprehensive view for managing user's party RSVPs
/// Shows RSVP details, party information, and cancellation functionality
struct MyRSVPsView: View {
    @EnvironmentObject var partyManager: PartyManager
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRSVP: RSVP?
    @State private var showingCancelConfirmation = false
    @State private var showingPartyDetail = false
    @State private var isLoading = false
    
    var upcomingRSVPs: [RSVP] {
        partyManager.userRSVPs.filter { rsvp in
            rsvp.status == .confirmed || rsvp.status == .pending
        }.sorted { $0.rsvpDate > $1.rsvpDate }
    }
    
    var pastRSVPs: [RSVP] {
        partyManager.userRSVPs.filter { rsvp in
            rsvp.status == .checkedIn || rsvp.status == .cancelled || rsvp.status == .noShow
        }.sorted { $0.rsvpDate > $1.rsvpDate }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header stats
                    headerStatsSection
                    
                    // Upcoming RSVPs
                    if !upcomingRSVPs.isEmpty {
                        rsvpSection(title: "Upcoming Events", rsvps: upcomingRSVPs, isUpcoming: true)
                    }
                    
                    // Past RSVPs
                    if !pastRSVPs.isEmpty {
                        rsvpSection(title: "Past Events", rsvps: pastRSVPs, isUpcoming: false)
                    }
                    
                    // Empty state
                    if upcomingRSVPs.isEmpty && pastRSVPs.isEmpty {
                        emptyStateView
                    }
                }
                .padding()
            }
            .themedBackground()
            .navigationTitle("My RSVPs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.travelBlue)
                }
            }
        }
        .sheet(isPresented: $showingPartyDetail) {
            if let rsvp = selectedRSVP,
               let party = partyManager.nearbyParties.first(where: { $0.id == rsvp.partyId }) {
                PartyDetailView(party: party)
            }
        }
        .alert("Cancel RSVP", isPresented: $showingCancelConfirmation) {
            Button("Cancel RSVP", role: .destructive) {
                if let rsvp = selectedRSVP {
                    Task {
                        await cancelRSVP(rsvp)
                    }
                }
            }
            Button("Keep RSVP", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel your RSVP? This action cannot be undone.")
        }
    }
    
    // MARK: - View Components
    
    private var headerStatsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                RSVPStatCard(
                    title: "Total RSVPs",
                    value: "\(partyManager.userRSVPs.count)",
                    icon: "calendar",
                    color: themeManager.travelBlue
                )
                
                RSVPStatCard(
                    title: "Upcoming",
                    value: "\(upcomingRSVPs.count)",
                    icon: "clock",
                    color: themeManager.travelGreen
                )
                
                RSVPStatCard(
                    title: "Attended",
                    value: "\(pastRSVPs.filter { $0.status == .checkedIn }.count)",
                    icon: "checkmark.circle",
                    color: themeManager.travelPink
                )
            }
        }
        .padding()
        .themedCard()
    }
    
    private func rsvpSection(title: String, rsvps: [RSVP], isUpcoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .themedText(.primary)
                
                Spacer()
                
                Text("\(rsvps.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(minWidth: 24, minHeight: 16)
                    .background(Circle().fill(isUpcoming ? themeManager.travelGreen : themeManager.secondaryText))
            }
            
            ForEach(rsvps) { rsvp in
                RSVPCard(
                    rsvp: rsvp,
                    party: partyManager.nearbyParties.first { $0.id == rsvp.partyId },
                    isUpcoming: isUpcoming,
                    onViewDetails: {
                        selectedRSVP = rsvp
                        showingPartyDetail = true
                    },
                    onCancel: {
                        selectedRSVP = rsvp
                        showingCancelConfirmation = true
                    }
                )
            }
        }
        .padding()
        .themedCard()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(themeManager.secondaryText)
            
            VStack(spacing: 8) {
                Text("No RSVPs Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .themedText(.primary)
                
                Text("When you RSVP to parties, they'll appear here.")
                    .font(.subheadline)
                    .themedText(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Browse Parties") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.travelBlue)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func cancelRSVP(_ rsvp: RSVP) async {
        isLoading = true
        
        do {
            try await partyManager.cancelRSVP(rsvpId: rsvp.id)
            print("✅ RSVP cancelled successfully")
        } catch {
            print("❌ Failed to cancel RSVP: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Views

struct RSVPStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .themedText(.primary)
            
            Text(title)
                .font(.caption)
                .themedText(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct RSVPCard: View {
    let rsvp: RSVP
    let party: Party?
    let isUpcoming: Bool
    let onViewDetails: () -> Void
    let onCancel: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var statusColor: Color {
        switch rsvp.status {
        case .confirmed: return themeManager.travelGreen
        case .pending: return .orange
        case .checkedIn: return themeManager.travelBlue
        case .cancelled: return .red
        case .noShow: return .gray
        }
    }
    
    var statusText: String {
        switch rsvp.status {
        case .confirmed: return "Confirmed"
        case .pending: return "Pending"
        case .checkedIn: return "Attended"
        case .cancelled: return "Cancelled"
        case .noShow: return "No Show"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with party name and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party?.title ?? "Unknown Party")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .themedText(.primary)
                        .lineLimit(1)
                    
                    if let party = party {
                        Text("by \(party.hostName)")
                            .font(.caption)
                            .themedText(.secondary)
                    }
                }
                
                Spacer()
                
                // Status badge
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(statusColor))
            }
            
            // Party details
            if let party = party {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(themeManager.travelBlue)
                        
                        Text(formatDate(party.startDate))
                            .font(.caption)
                            .themedText(.secondary)
                        
                        Spacer()
                        
                        if rsvp.quantity > 1 {
                            Text("\(rsvp.quantity) guests")
                                .font(.caption)
                                .themedText(.secondary)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(themeManager.travelBlue)
                        
                        Text(party.location.name)
                            .font(.caption)
                            .themedText(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
            }
            
            // RSVP details
            VStack(alignment: .leading, spacing: 4) {
                Text("RSVP'd on \(formatDate(rsvp.rsvpDate))")
                    .font(.caption2)
                    .themedText(.tertiary)
                
                if let ticketTierId = rsvp.ticketTierId,
                   let tier = party?.ticketTiers.first(where: { $0.id == ticketTierId }) {
                    Text("Ticket: \(tier.name) - \(tier.price == 0 ? "Free" : "$\(String(format: "%.0f", tier.price))")")
                        .font(.caption2)
                        .themedText(.tertiary)
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                Button("View Details") {
                    onViewDetails()
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.travelBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(themeManager.travelBlue.opacity(0.3), lineWidth: 1)
                )
                
                if isUpcoming && rsvp.status == .confirmed {
                    Button("Cancel RSVP") {
                        onCancel()
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(statusColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    MyRSVPsView()
        .environmentObject(PartyManager.shared)
} 