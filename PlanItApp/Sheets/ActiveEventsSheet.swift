import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Active Events Sheet View
struct ActiveEventsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var activeEvents: [Party] = []
    @State private var isLoading = true
    @State private var totalAttendees: Int = 0
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.orange.opacity(0.3)
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
                    } else if activeEvents.isEmpty {
                        emptyStateSection
                    } else {
                        contentSection
                    }
                }
            }
        }
        .onAppear {
            loadActiveEventsData()
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
                    Text("Active Events")
                        .font(.geist(20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Live and upcoming events")
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
            
            // Stats Row
            HStack(spacing: 12) {
                StatMiniCard(
                    title: "Active Events",
                    value: "\(activeEvents.count)",
                    icon: "calendar.circle.fill",
                    color: .orange
                )
                
                StatMiniCard(
                    title: "Total Attendees",
                    value: "\(totalAttendees)",
                    icon: "person.3.fill",
                    color: .blue
                )
                
                StatMiniCard(
                    title: "Avg per Event",
                    value: activeEvents.isEmpty ? "0" : String(format: "%.1f", Double(totalAttendees) / Double(activeEvents.count)),
                    icon: "chart.bar.fill",
                    color: .green
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
            
            Text("Loading events...")
                .font(.geist(16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Active Events")
                .font(.geist(24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Create your first event to see it listed here with real-time analytics.")
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
                ForEach(activeEvents.sorted { 
                    $0.startDate < $1.startDate 
                }) { event in
                    EventItemView(event: event)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .padding(.top, 20)
    }
    
    private func loadActiveEventsData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        db.collection("parties")
            .whereField("hostId", isEqualTo: userId)
            .whereField("status", in: ["live", "upcoming"])
            .addSnapshotListener { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error loading active events: \(error)")
                        self.isLoading = false
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.isLoading = false
                        return
                    }
                    
                    self.activeEvents = documents.compactMap { doc in
                        try? doc.data(as: Party.self)
                    }
                    
                    self.totalAttendees = self.activeEvents.reduce(0) { $0 + $1.currentAttendees }
                    self.isLoading = false
                }
            }
    }
}

// MARK: - Event Item View
struct EventItemView: View {
    let event: Party
    
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
    
    private func statusColor(_ status: Party.PartyStatus) -> Color {
        switch status {
        case .live:
            return .green
        case .upcoming:
            return .orange
        case .ended:
            return .gray
        case .cancelled:
            return .red
        }
    }
    
    private func statusIcon(_ status: Party.PartyStatus) -> String {
        switch status {
        case .live:
            return "dot.radiowaves.left.and.right"
        case .upcoming:
            return "clock.fill"
        case .ended:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            eventHeader
            eventDetails
            if (event.capacity ?? 0) > 0 {
                progressSection
            }
        }
        .padding(16)
        .background(cardBackground)
    }
    
    private var eventHeader: some View {
        HStack {
            eventTitleSection
            Spacer()
            statusBadge
        }
    }
    
    private var eventTitleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.geist(18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(event.location.name)
                .font(.geist(14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon(event.status))
                .font(.system(size: 10, weight: .medium))
            
            Text(event.status.rawValue.uppercased())
                .font(.geist(10, weight: .bold))
                .textCase(.uppercase)
        }
        .foregroundColor(statusColor(event.status))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusBadgeBackground)
    }
    
    private var statusBadgeBackground: some View {
        Capsule()
            .fill(statusColor(event.status).opacity(0.2))
    }
    
    private var eventDetails: some View {
        HStack(spacing: 20) {
            dateTimeSection
            attendeesSection
            revenueSection
            Spacer()
        }
    }
    
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Event Time")
                .font(.geist(10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
            
            Text(formatDate(event.startDate))
                .font(.geist(12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Attendees")
                .font(.geist(10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
            
            Text("\(event.currentAttendees)/\(event.capacity ?? 0)")
                .font(.geist(12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Revenue")
                .font(.geist(10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
            
            Text("$\(String(format: "%.0f", calculatedRevenue))")
                .font(.geist(12, weight: .medium))
                .foregroundColor(.green)
        }
    }
    
    private var calculatedRevenue: Double {
        event.ticketTiers.reduce(0.0) { $0 + ($1.price * Double($1.soldCount)) }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            progressHeader
            progressBar
        }
    }
    
    private var progressHeader: some View {
        HStack {
            Text("Capacity")
                .font(.geist(10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
            
            Text("\(Int((Double(event.currentAttendees) / Double(event.capacity ?? 1)) * 100))%")
                .font(.geist(10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                progressBarBackground
                progressBarFill(geometry: geometry)
            }
        }
        .frame(height: 4)
    }
    
    private var progressBarBackground: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(height: 4)
            .cornerRadius(2)
    }
    
    private func progressBarFill(geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(progressGradient)
            .frame(
                width: geometry.size.width * min(1.0, Double(event.currentAttendees) / Double(event.capacity ?? 1)),
                height: 4
            )
            .cornerRadius(2)
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [.orange, .red],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
} 