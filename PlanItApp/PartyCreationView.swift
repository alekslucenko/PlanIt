import SwiftUI
import MapKit
import FirebaseAuth

/// 🎉 COMPREHENSIVE PARTY CREATION VIEW
/// Allows hosts to create detailed party events with tickets, location, and customization
struct PartyCreationView: View {
    @StateObject private var partyManager = PartyManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Basic party info
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var guestCap = 50
    @State private var isPublic = true
    
    // Location
    @State private var selectedLocation: PartyLocation?
    @State private var showingLocationPicker = false
    @State private var locationSearchText = ""
    
    // Tickets
    @State private var ticketTiers: [TicketTier] = []
    @State private var showingTicketEditor = false
    @State private var editingTicket: TicketTier?
    
    // Additional details
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var perks: [String] = []
    @State private var newPerk = ""
    @State private var flyerImageURL = ""
    @State private var landingPageURL = ""
    
    // UI state
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var currentStep = 0
    
    private let steps = ["Basic Info", "Location", "Tickets", "Details"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Step content
                TabView(selection: $currentStep) {
                    basicInfoStep.tag(0)
                    locationStep.tag(1)
                    ticketsStep.tag(2)
                    detailsStep.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Navigation buttons
                navigationButtons
            }
            .themedBackground()
            .navigationTitle("Create Party")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(selectedLocation: $selectedLocation)
        }
        .sheet(isPresented: $showingTicketEditor) {
            TicketTierEditorView(
                ticketTier: $editingTicket,
                onSave: { tier in
                    if let index = ticketTiers.firstIndex(where: { $0.id == tier.id }) {
                        ticketTiers[index] = tier
                    } else {
                        ticketTiers.append(tier)
                    }
                }
            )
        }
    }
    
    private var progressIndicator: some View {
        HStack {
            ForEach(0..<steps.count, id: \.self) { index in
                VStack(spacing: 8) {
                    Circle()
                        .fill(index <= currentStep ? themeManager.travelPink : Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        )
                    
                    Text(steps[index])
                        .font(.caption)
                        .fontWeight(.medium)
                        .themedText(index <= currentStep ? .primary : .secondary)
                }
                
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ? themeManager.travelPink : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(themeManager.cardBackground)
    }
    
    private var basicInfoStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Text("📝 Basic Information")
                        .font(.title2)
                        .fontWeight(.bold)
                        .themedText(.primary)
                    
                    Text("Tell us about your party")
                        .font(.subheadline)
                        .themedText(.secondary)
                }
                
                VStack(spacing: 16) {
                    TextField("Party Title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3, reservesSpace: true)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Date & Time")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .themedText(.primary)
                        
                        DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("End Date & Time")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .themedText(.primary)
                        
                        DatePicker("End", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Guest Capacity")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .themedText(.primary)
                        
                        HStack {
                            Button(action: {
                                if guestCap > 10 {
                                    guestCap -= 10
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(themeManager.travelBlue)
                            }
                            
                            Text("\(guestCap)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(minWidth: 80)
                                .themedText(.primary)
                            
                            Button(action: {
                                guestCap += 10
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(themeManager.travelBlue)
                            }
                        }
                    }
                    
                    Toggle("Public Event", isOn: $isPublic)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .themedCard()
                .padding()
            }
            .padding()
        }
    }
    
    private var locationStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Text("📍 Location")
                        .font(.title2)
                        .fontWeight(.bold)
                        .themedText(.primary)
                    
                    Text("Where will your party be?")
                        .font(.subheadline)
                        .themedText(.secondary)
                }
                
                VStack(spacing: 16) {
                    if let location = selectedLocation {
                        LocationDisplayCard(location: location) {
                            showingLocationPicker = true
                        }
                    } else {
                        Button(action: {
                            showingLocationPicker = true
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "location.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(themeManager.travelBlue)
                                
                                Text("Select Location")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .themedText(.primary)
                                
                                Text("Choose your party venue")
                                    .font(.subheadline)
                                    .themedText(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeManager.travelBlue, style: StrokeStyle(lineWidth: 2, dash: [8]))
                                    .background(themeManager.travelBlue.opacity(0.05))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .themedCard()
                .padding()
            }
            .padding()
        }
    }
    
    private var ticketsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Text("🎟️ Tickets")
                        .font(.title2)
                        .fontWeight(.bold)
                        .themedText(.primary)
                    
                    Text("Set up ticket tiers (optional)")
                        .font(.subheadline)
                        .themedText(.secondary)
                }
                
                VStack(spacing: 16) {
                    ForEach(ticketTiers) { tier in
                        EditableTicketTierCard(tier: tier) {
                            editingTicket = tier
                            showingTicketEditor = true
                        }
                    }
                    
                    Button(action: {
                        editingTicket = TicketTier(
                            id: UUID().uuidString,
                            name: "",
                            price: 0,
                            description: "",
                            maxQuantity: 10
                        )
                        showingTicketEditor = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            
                            Text("Add Ticket Tier")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(themeManager.travelBlue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.travelBlue, style: StrokeStyle(lineWidth: 2, dash: [8]))
                                .background(themeManager.travelBlue.opacity(0.05))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .themedCard()
                .padding()
            }
            .padding()
        }
    }
    
    private var detailsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Text("✨ Final Details")
                        .font(.title2)
                        .fontWeight(.bold)
                        .themedText(.primary)
                    
                    Text("Add finishing touches")
                        .font(.subheadline)
                        .themedText(.secondary)
                }
                
                VStack(spacing: 20) {
                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .themedText(.primary)
                        
                        HStack {
                            TextField("Add tag", text: $newTag)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Add") {
                                if !newTag.isEmpty && !tags.contains(newTag) {
                                    tags.append(newTag)
                                    newTag = ""
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(newTag.isEmpty)
                        }
                        
                        if !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(tags, id: \.self) { tag in
                                        TagChip(tag: tag) {
                                            tags.removeAll { $0 == tag }
                                        }
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                        }
                    }
                    
                    // Perks
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Perks & Amenities")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .themedText(.primary)
                        
                        HStack {
                            TextField("Add perk", text: $newPerk)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Add") {
                                if !newPerk.isEmpty && !perks.contains(newPerk) {
                                    perks.append(newPerk)
                                    newPerk = ""
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(newPerk.isEmpty)
                        }
                        
                        if !perks.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(perks, id: \.self) { perk in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(themeManager.travelGreen)
                                        
                                        Text(perk)
                                            .font(.subheadline)
                                            .themedText(.primary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            perks.removeAll { $0 == perk }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Optional URLs
                    VStack(spacing: 12) {
                        TextField("Flyer Image URL (optional)", text: $flyerImageURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Landing Page URL (optional)", text: $landingPageURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .themedCard()
                .padding()
            }
            .padding()
        }
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button("Previous") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .buttonStyle(GlassButtonStyle(tint: themeManager.travelBlue))
            }
            
            Spacer()
            
            if currentStep < steps.count - 1 {
                Button("Next") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(GlassButtonStyle(tint: themeManager.travelBlue))
            } else {
                Button(action: createParty) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "party.popper")
                            Text("Create Party")
                        }
                    }
                }
                .buttonStyle(GlassButtonStyle(tint: themeManager.travelPink))
                .disabled(!canProceed || isCreating)
            }
        }
        .padding()
        .background(themeManager.cardBackground)
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return !title.isEmpty && !description.isEmpty && startDate < endDate
        case 1:
            return selectedLocation != nil
        case 2:
            return true // Tickets are optional
        case 3:
            return true
        default:
            return false
        }
    }
    
    private var canCreate: Bool {
        return !title.isEmpty && 
               !description.isEmpty && 
               selectedLocation != nil && 
               startDate < endDate &&
               guestCap > 0
    }
    
    private func createParty() {
        guard let userId = Auth.auth().currentUser?.uid,
              let hostProfile = partyManager.hostProfile,
              let location = selectedLocation else {
            errorMessage = "Unable to create party. Please check your host status and try again."
            showingError = true
            return
        }
        
        isCreating = true
        
        let party = Party(
            title: title,
            description: description,
            hostId: userId,
            hostName: hostProfile.businessName,
            location: location,
            startDate: startDate,
            endDate: endDate,
            ticketTiers: ticketTiers,
            guestCap: guestCap,
            isPublic: isPublic,
            tags: tags,
            flyerImageURL: flyerImageURL.isEmpty ? nil : flyerImageURL,
            landingPageURL: landingPageURL.isEmpty ? nil : landingPageURL,
            perks: perks
        )
        
        Task {
            do {
                try await partyManager.createParty(party)
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct EditableTicketTierCard: View {
    let tier: TicketTier
    let onEdit: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.name.isEmpty ? "Untitled Ticket" : tier.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .themedText(.primary)
                    
                    Text(tier.description.isEmpty ? "No description" : tier.description)
                        .font(.subheadline)
                        .themedText(.secondary)
                        .lineLimit(2)
                    
                    if !tier.perks.isEmpty {
                        Text("Includes: \(tier.perks.joined(separator: ", "))")
                            .font(.caption)
                            .themedText(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(tier.price == 0 ? "Free" : "$\(String(format: "%.0f", tier.price))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(tier.price == 0 ? themeManager.travelGreen : themeManager.primaryText)
                    
                    Text("Max: \(tier.maxQuantity)")
                        .font(.caption)
                        .themedText(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .themedText(.secondary)
                }
            }
            .padding()
            .background(themeManager.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.travelBlue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LocationDisplayCard: View {
    let location: PartyLocation
    let onEdit: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(location.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .themedText(.primary)
                
                Spacer()
                
                Button("Change", action: onEdit)
                    .font(.subheadline)
                    .foregroundColor(themeManager.travelBlue)
            }
            
            Text(location.fullAddress)
                .font(.subheadline)
                .themedText(.secondary)
        }
        .padding()
        .background(themeManager.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.travelBlue, lineWidth: 1)
        )
    }
}

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(themeManager.travelPink)
        .cornerRadius(12)
    }
}

// MARK: - Location Picker View (Placeholder)
struct LocationPickerView: View {
    @Binding var selectedLocation: PartyLocation?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Search for a location", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                // For now, provide some sample locations
                List {
                    ForEach(sampleLocations, id: \.name) { location in
                        Button(action: {
                            selectedLocation = location
                            dismiss()
                        }) {
                            VStack(alignment: .leading) {
                                Text(location.name)
                                    .font(.headline)
                                Text(location.fullAddress)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var sampleLocations: [PartyLocation] {
        [
            PartyLocation(
                name: "Downtown Event Hall",
                address: "123 Main St",
                city: "San Francisco",
                state: "CA",
                zipCode: "94102",
                latitude: 37.7749,
                longitude: -122.4194,
                placeId: nil
            ),
            PartyLocation(
                name: "Rooftop Lounge",
                address: "456 Market St",
                city: "San Francisco",
                state: "CA",
                zipCode: "94103",
                latitude: 37.7849,
                longitude: -122.4094,
                placeId: nil
            ),
            PartyLocation(
                name: "Garden Venue",
                address: "789 Park Ave",
                city: "San Francisco",
                state: "CA",
                zipCode: "94104",
                latitude: 37.7949,
                longitude: -122.3994,
                placeId: nil
            )
        ]
    }
}

// MARK: - Ticket Tier Editor View (Placeholder)
struct TicketTierEditorView: View {
    @Binding var ticketTier: TicketTier?
    let onSave: (TicketTier) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var price: Double = 0
    @State private var description = ""
    @State private var maxQuantity = 10
    @State private var perks: [String] = []
    @State private var newPerk = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Ticket Details") {
                    TextField("Ticket Name", text: $name)
                    TextField("Price", value: $price, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    TextField("Description", text: $description)
                    Stepper("Max Quantity: \(maxQuantity)", value: $maxQuantity, in: 1...1000)
                }
                
                Section("Perks") {
                    HStack {
                        TextField("Add perk", text: $newPerk)
                        Button("Add") {
                            if !newPerk.isEmpty {
                                perks.append(newPerk)
                                newPerk = ""
                            }
                        }
                        .disabled(newPerk.isEmpty)
                    }
                    
                    ForEach(perks, id: \.self) { perk in
                        Text(perk)
                    }
                    .onDelete { indexSet in
                        perks.remove(atOffsets: indexSet)
                    }
                }
            }
            .navigationTitle("Edit Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let tier = TicketTier(
                            id: ticketTier?.id ?? UUID().uuidString,
                            name: name,
                            price: price,
                            description: description,
                            maxQuantity: maxQuantity,
                            perks: perks
                        )
                        onSave(tier)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            if let tier = ticketTier {
                name = tier.name
                price = tier.price
                description = tier.description
                maxQuantity = tier.maxQuantity
                perks = tier.perks
            }
        }
    }
}

#Preview {
    PartyCreationView()
} 