import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - RSVP Log Sheet View
struct RSVPLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rsvps: [RSVP] = []
    @State private var isLoading = true
    @State private var totalGuests: Int = 0
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.blue.opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    if isLoading {
                        loadingSection
                    } else if rsvps.isEmpty {
                        emptyStateSection
                    } else {
                        contentSection
                    }
                }
            }
        }
        .onAppear {
            loadRSVPData()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Close") {
                    dismiss()
                }
                .font(.geist(16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("RSVP History")
                        .font(.geist(20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("All guest confirmations")
                        .font(.geist(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Stats Cards Row
            HStack(spacing: 12) {
                StatMiniCard(
                    title: "Total RSVPs",
                    value: "\(rsvps.count)",
                    icon: "person.2.fill",
                    color: .blue
                )
                
                StatMiniCard(
                    title: "Total Guests",
                    value: "\(totalGuests)",
                    icon: "person.3.fill",
                    color: .purple
                )
                
                StatMiniCard(
                    title: "Avg per RSVP",
                    value: rsvps.isEmpty ? "0" : String(format: "%.1f", Double(totalGuests) / Double(rsvps.count)),
                    icon: "chart.bar.fill",
                    color: .orange
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            
            Text("Loading RSVP data...")
                .font(.geist(16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No RSVPs Yet")
                .font(.geist(24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Guest confirmations will appear here when people RSVP to your events.")
                .font(.geist(14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(rsvps.sorted { $0.rsvpDate > $1.rsvpDate }) { rsvp in
                    RSVPItemView(rsvp: rsvp)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .padding(.top, 20)
    }
    
    private func loadRSVPData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        // Get parties hosted by this user first, then filter RSVPs
        db.collection("parties")
            .whereField("hostId", isEqualTo: userId)
            .addSnapshotListener { partiesSnapshot, error in
                if let error = error {
                    print("❌ Error loading parties: \(error)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                guard let partyDocs = partiesSnapshot?.documents else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                let partyIds = partyDocs.map { $0.documentID }
                
                if partyIds.isEmpty {
                    DispatchQueue.main.async {
                        self.rsvps = []
                        self.totalGuests = 0
                        self.isLoading = false
                    }
                    return
                }
                
                // Now get RSVPs for these parties
                db.collection("rsvps")
                    .whereField("partyId", in: partyIds)
                    .addSnapshotListener { rsvpSnapshot, rsvpError in
                        DispatchQueue.main.async {
                            if let rsvpError = rsvpError {
                                print("❌ Error loading RSVP data: \(rsvpError)")
                                self.isLoading = false
                                return
                            }
                            
                            guard let rsvpDocuments = rsvpSnapshot?.documents else {
                                self.isLoading = false
                                return
                            }
                            
                            self.rsvps = rsvpDocuments.compactMap { doc in
                                try? doc.data(as: RSVP.self)
                            }
                            
                            self.totalGuests = self.rsvps.reduce(0) { $0 + $1.quantity }
                            self.isLoading = false
                        }
                    }
            }
    }
}

// MARK: - RSVP Item Component
struct RSVPItemView: View {
    let rsvp: RSVP
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Guest Avatar/Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                if rsvp.quantity > 1 {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            // RSVP Details
            VStack(alignment: .leading, spacing: 4) {
                Text(rsvp.userName)
                    .font(.geist(16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(rsvp.userEmail)
                    .font(.geist(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(formatRelativeDate(rsvp.rsvpDate))
                        .font(.geist(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    if let userData = rsvp.userData.specialRequests, !userData.isEmpty {
                        Image(systemName: "message.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            
            Spacer()
            
            // Guest Count & Status
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(rsvp.quantity)")
                        .font(.geist(18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(rsvp.status.rawValue)
                    .font(.geist(10, weight: .medium))
                    .foregroundColor(statusColor(rsvp.status))
                    .textCase(.uppercase)
            }
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
    
    private func statusColor(_ status: RSVP.RSVPStatus) -> Color {
        switch status {
        case .confirmed:
            return .green
        case .pending:
            return .yellow
        case .cancelled:
            return .red
        case .checkedIn:
            return .blue
        case .noShow:
            return .orange
        }
    }
}

// MARK: - Mini Stat Card Component
struct StatMiniCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.geist(18, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.geist(10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
} 