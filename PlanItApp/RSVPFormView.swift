import SwiftUI
import FirebaseAuth

/// 🎟️ COMPREHENSIVE RSVP FORM VIEW
/// Handles party RSVP creation with user data collection and validation
struct RSVPFormView: View {
    let party: Party
    @StateObject private var partyManager = PartyManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var selectedTicketTier: TicketTier?
    @State private var quantity = 1
    @State private var specialRequests = ""
    @State private var emergencyContact = ""
    @State private var dietaryRestrictions: Set<String> = []
    @State private var selectedAgeGroup = "25-34"
    @State private var selectedInterests: Set<String> = []
    @State private var groupSize = 1
    @State private var socialMediaHandle = ""
    
    // UI state
    @State private var isSubmitting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    
    private let ageGroups = ["18-24", "25-34", "35-44", "45-54", "55+"]
    private let dietaryOptions = ["Vegetarian", "Vegan", "Gluten-Free", "Nut Allergy", "Other"]
    private let interestOptions = ["Music", "Art", "Food", "Dancing", "Networking", "Entertainment"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Ticket selection (if applicable)
                    if !party.ticketTiers.isEmpty {
                        ticketSelectionSection
                    }
                    
                    // Quantity selection
                    quantitySection
                    
                    // User information
                    userInfoSection
                    
                    // Submit button
                    submitSection
                }
                .padding()
            }
            .themedBackground()
            .navigationTitle("RSVP to Party")
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
        .alert("RSVP Confirmed!", isPresented: $showingSuccess) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("Your RSVP has been confirmed. See you at the party!")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text(party.title)
                .font(.title2)
                .fontWeight(.bold)
                .themedText(.primary)
                .multilineTextAlignment(.center)
            
            Text("Complete your RSVP below")
                .font(.subheadline)
                .themedText(.secondary)
        }
        .padding()
        .themedCard()
    }
    
    @ViewBuilder
    private var ticketSelectionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select Ticket Type")
                    .font(.headline)
                    .themedText(.primary)
                Spacer()
            }
            
            ForEach(party.ticketTiers.filter { $0.isAvailable }) { tier in
                TicketTierSelectionCard(
                    tier: tier,
                    isSelected: selectedTicketTier?.id == tier.id,
                    onSelect: { selectedTicketTier = tier }
                )
            }
        }
        .padding()
        .themedCard()
    }
    
    private var quantitySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Number of Attendees")
                    .font(.headline)
                    .themedText(.primary)
                Spacer()
            }
            
            HStack {
                Button(action: {
                    if quantity > 1 {
                        quantity -= 1
                        groupSize = max(groupSize, quantity)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(quantity > 1 ? themeManager.travelBlue : .gray)
                }
                .disabled(quantity <= 1)
                
                Text("\(quantity)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(minWidth: 60)
                    .themedText(.primary)
                
                Button(action: {
                    let maxAllowed = selectedTicketTier?.maxQuantity ?? party.guestCap
                    if quantity < min(maxAllowed, party.guestCap - party.currentAttendees) {
                        quantity += 1
                        groupSize = max(groupSize, quantity)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.travelBlue)
                }
            }
            
            Text("Available: \(party.guestCap - party.currentAttendees)")
                .font(.caption)
                .themedText(.secondary)
        }
        .padding()
        .themedCard()
    }
    
    private var userInfoSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Additional Information")
                    .font(.headline)
                    .themedText(.primary)
                Spacer()
            }
            
            // Age Group
            VStack(alignment: .leading, spacing: 8) {
                Text("Age Group")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .themedText(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(ageGroups, id: \.self) { ageGroup in
                        Button(action: {
                            selectedAgeGroup = ageGroup
                        }) {
                            Text(ageGroup)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedAgeGroup == ageGroup ? .white : themeManager.primaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedAgeGroup == ageGroup ? themeManager.travelBlue : themeManager.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(themeManager.travelBlue, lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Interests
            VStack(alignment: .leading, spacing: 8) {
                Text("Interests (select all that apply)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .themedText(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(interestOptions, id: \.self) { interest in
                        Button(action: {
                            if selectedInterests.contains(interest) {
                                selectedInterests.remove(interest)
                            } else {
                                selectedInterests.insert(interest)
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedInterests.contains(interest) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedInterests.contains(interest) ? themeManager.travelGreen : .gray)
                                
                                Text(interest)
                                    .font(.subheadline)
                                    .themedText(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedInterests.contains(interest) ? themeManager.travelGreen.opacity(0.1) : themeManager.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedInterests.contains(interest) ? themeManager.travelGreen : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Optional fields
            VStack(spacing: 12) {
                TextField("Special requests or notes", text: $specialRequests, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3, reservesSpace: true)
                
                TextField("Emergency contact", text: $emergencyContact)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Social media handle (optional)", text: $socialMediaHandle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
        .padding()
        .themedCard()
    }
    
    private var submitSection: some View {
        VStack(spacing: 16) {
            Button(action: submitRSVP) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        
                        Text("Confirm RSVP")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [themeManager.travelPink, themeManager.travelPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: themeManager.travelPink.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(isSubmitting || !canSubmit)
            .opacity(canSubmit ? 1.0 : 0.6)
            
            if let ticketTier = selectedTicketTier {
                HStack {
                    Text("Total:")
                        .font(.subheadline)
                        .themedText(.secondary)
                    
                    Spacer()
                    
                    Text(ticketTier.price == 0 ? "Free" : "$\(String(format: "%.2f", ticketTier.price * Double(quantity)))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .themedText(.primary)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var canSubmit: Bool {
        if !party.ticketTiers.isEmpty {
            return selectedTicketTier != nil && quantity > 0 && !selectedAgeGroup.isEmpty
        }
        return quantity > 0 && !selectedAgeGroup.isEmpty
    }
    
    private func submitRSVP() {
        guard Auth.auth().currentUser?.uid != nil,
              Auth.auth().currentUser?.email != nil else {
            errorMessage = "Please sign in to RSVP"
            showingError = true
            return
        }
        
        isSubmitting = true
        
        let userData = RSVPUserData(
            profileImageURL: nil,
            interests: Array(selectedInterests),
            partyExperience: nil,
            groupSize: groupSize,
            specialRequests: specialRequests.isEmpty ? nil : specialRequests,
            emergencyContact: emergencyContact.isEmpty ? nil : emergencyContact,
            dietaryRestrictions: Array(dietaryRestrictions),
            ageGroup: selectedAgeGroup,
            socialMediaHandle: socialMediaHandle.isEmpty ? nil : socialMediaHandle
        )
        
        Task {
            do {
                try await partyManager.createRSVP(
                    for: party,
                    userData: userData,
                    ticketTierId: selectedTicketTier?.id,
                    quantity: quantity
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Ticket Tier Selection Card
struct TicketTierSelectionCard: View {
    let tier: TicketTier
    let isSelected: Bool
    let onSelect: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .themedText(.primary)
                    
                    Text(tier.description)
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
                    
                    Text("\(tier.maxQuantity - tier.currentSold) left")
                        .font(.caption)
                        .themedText(.secondary)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(themeManager.travelGreen)
                            .font(.title3)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? themeManager.travelGreen : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!tier.isAvailable)
        .opacity(tier.isAvailable ? 1.0 : 0.6)
    }
}

#Preview {
    RSVPFormView(party: Party(
        title: "Sample Party",
        description: "Sample description",
        hostId: "sample",
        hostName: "Sample Host",
        location: PartyLocation(
            name: "Sample Venue",
            address: "123 Main St",
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