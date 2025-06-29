import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Active Events Sheet View
struct ActiveEventsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var activeEvents: [Party] = []
    @State private var isLoading = true
    @State private var totalAttendees: Int = 0
    @State private var showingEventDetail: Party? = nil
    @State private var showingEditEvent: Party? = nil
    
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
                        .padding(.top, 40) // Push header down for visibility
                    
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
        .sheet(item: $showingEventDetail) { event in
            EventDetailView(party: event)
        }
        .sheet(item: $showingEditEvent) { event in
            EditEventSheet(event: event) {
                // Refresh data after edit
                loadActiveEventsData()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Done") {
                    dismiss()
                }
                .font(.inter(16, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Active Events")
                        .font(.inter(20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Live and upcoming events")
                        .font(.inter(12, weight: .medium))
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
                    color: Color.orange
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
        .padding(.bottom, 20)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            
            Text("Loading events...")
                .font(.inter(16, weight: .medium))
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
                .font(.inter(24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Create your first event to see it listed here with real-time analytics.")
                .font(.inter(14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(activeEvents.sorted { 
                    $0.startDate < $1.startDate 
                }) { event in
                    HorizontalEventCard(
                        event: event,
                        onTap: {
                            showingEventDetail = event
                        },
                        onEdit: {
                            showingEditEvent = event
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .padding(.top, 10)
    }
    
    private func loadActiveEventsData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        // Real-time listener for active events from Firestore
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
                    
                    print("✅ Loaded \(self.activeEvents.count) active events from Firestore")
                }
            }
    }
}

// MARK: - Horizontal Event Card
struct HorizontalEventCard: View {
    let event: Party
    let onTap: () -> Void
    let onEdit: () -> Void
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Event Image Box (Left)
                eventImageBox
                
                // Event Details (Center)
                eventDetailsSection
                
                Spacer()
                
                // Edit Button (Right)
                editButton
            }
            .padding(16)
            .background(cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var eventImageBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color.orange.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 60, height: 60)
            
            // Event image or placeholder
            if let imageUrl = event.images.first, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(8)
                } placeholder: {
                    eventPlaceholderIcon
                }
            } else {
                eventPlaceholderIcon
            }
        }
    }
    
    private var eventPlaceholderIcon: some View {
        Image(systemName: "party.popper.fill")
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
    }
    
    private var eventDetailsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title and Status
            HStack {
                Text(event.title)
                    .font(.inter(16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                statusBadge
            }
            
            // Location
            Text(event.location.name)
                .font(.inter(12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
            
            // Date and time
            Text(formatDate(event.startDate))
                .font(.inter(11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
            
            // Attendees and Revenue
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    
                    Text("\(event.currentAttendees)/\(event.capacity ?? 0)")
                        .font(.inter(10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    
                    Text("$\(String(format: "%.0f", calculatedRevenue))")
                        .font(.inter(10, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: statusIcon(event.status))
                .font(.system(size: 8, weight: .medium))
            
            Text(event.status.rawValue.uppercased())
                .font(.inter(8, weight: .bold))
                .textCase(.uppercase)
        }
        .foregroundColor(statusColor(event.status))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(statusColor(event.status).opacity(0.2))
        )
    }
    
    private var editButton: some View {
        Button(action: onEdit) {
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                
                Text("Edit")
                    .font(.inter(12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var calculatedRevenue: Double {
        event.ticketTiers.reduce(0.0) { $0 + ($1.price * Double($1.soldCount)) }
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

// MARK: - Edit Event Sheet
struct EditEventSheet: View {
    let event: Party
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var capacity: String
    @State private var isUpdating = false
    
    private let db = Firestore.firestore()
    
    init(event: Party, onSave: @escaping () -> Void) {
        self.event = event
        self.onSave = onSave
        self._title = State(initialValue: event.title)
        self._description = State(initialValue: event.description)
        self._capacity = State(initialValue: String(event.capacity ?? 0))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Edit Event")
                            .font(.inter(24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Update your event details")
                            .font(.inter(14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // Form
                    VStack(spacing: 16) {
                        editField(title: "Event Title", text: $title)
                        editField(title: "Description", text: $description)
                        editField(title: "Capacity", text: $capacity, keyboardType: .numberPad)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Buttons
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.inter(16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(12)
                        
                        Button(action: saveChanges) {
                            if isUpdating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
                                    .font(.inter(16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .disabled(isUpdating)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private func editField(title: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.inter(14, weight: .bold))
                .foregroundColor(.white)
            
            TextField("", text: text)
                .font(.inter(16, weight: .medium))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .keyboardType(keyboardType)
        }
    }
    
    private func saveChanges() {
        isUpdating = true
        
        var updateData: [String: Any] = [:]
        
        if title != event.title {
            updateData["title"] = title
        }
        
        if description != event.description {
            updateData["description"] = description
        }
        
        if let newCapacity = Int(capacity), newCapacity != (event.capacity ?? 0) {
            updateData["capacity"] = newCapacity
        }
        
        updateData["updatedAt"] = Timestamp()
        
        db.collection("parties").document(event.id).updateData(updateData) { error in
            DispatchQueue.main.async {
                self.isUpdating = false
                
                if let error = error {
                    print("❌ Error updating event: \(error)")
                } else {
                    print("✅ Event updated successfully")
                    self.onSave()
                    self.dismiss()
                }
            }
        }
    }
} 