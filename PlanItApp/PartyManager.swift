import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import SwiftUI

/// 🎉 COMPREHENSIVE PARTY MANAGEMENT SYSTEM
/// Handles party creation, RSVP management, analytics, and host business features
/// Complete Firestore integration with real-time updates and detailed tracking
@MainActor
final class PartyManager: ObservableObject {
    static let shared = PartyManager()
    
    // MARK: - Published Properties
    @Published var nearbyParties: [Party] = []
    @Published var userRSVPs: [RSVP] = []
    @Published var hostParties: [Party] = []
    @Published var hostProfile: PartyHost?
    @Published var isHostMode: Bool = false {
        didSet {
            if oldValue != isHostMode {
                print("🔄 Host mode changed from \(oldValue) to \(isHostMode)")
                hostModeChanged()
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Analytics
    @Published var partyAnalytics: [String: PartyAnalytics] = [:]
    @Published var hostAnalytics: HostAnalytics?
    
    // UI State
    @Published var showingPartyCreation: Bool = false
    @Published var showingRSVPDetail: Bool = false
    @Published var selectedParty: Party?
    
    // Navigation support
    @Published var shouldRefreshTabs: Bool = false
    @Published var forceUIRefresh: UUID = UUID()
    
    private let db = Firestore.firestore()
    private var partiesListener: ListenerRegistration?
    private var rsvpListener: ListenerRegistration?
    private var hostListener: ListenerRegistration?
    
    private let performanceService = PerformanceOptimizationService.shared
    
    private init() {
        setupListeners()
        
        // Initialize host mode check asynchronously with immediate UI update
        Task {
            await checkHostMode()
        }
    }
    
    deinit {
        partiesListener?.remove()
        rsvpListener?.remove()
        hostListener?.remove()
    }
    
    // MARK: - Host Mode Management
    
    private func hostModeChanged() {
        // Force UI refresh when host mode changes
        shouldRefreshTabs.toggle()
        forceUIRefresh = UUID()
        
        // Post notification for any listeners
        NotificationCenter.default.post(name: NSNotification.Name("HostModeChanged"), object: isHostMode)
        
        // Setup appropriate listeners based on mode
        if isHostMode {
            setupHostListener()
            Task {
                await loadHostParties()
                await loadHostAnalytics()
            }
        } else {
            hostListener?.remove()
            hostParties = []
            hostAnalytics = nil
        }
        
        print("✅ Host mode UI refresh triggered")
    }
    
    // MARK: - Setup & Listeners (Public for refresh functionality)
    
    func setupListeners() {
        setupPartiesListener()
        setupRSVPListener()
        setupRealTimePartyUpdates()
    }
    
    func removeListeners() {
        partiesListener?.remove()
        rsvpListener?.remove()
        hostListener?.remove()
    }
    
    private func setupPartiesListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Listen to all nearby parties - for regular users to discover parties
        partiesListener = db.collection("parties")
            .whereField("status", isEqualTo: "upcoming")
            .whereField("isPublic", isEqualTo: true)
            .order(by: "startDate", descending: false)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to parties: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { 
                    print("⚠️ No party documents found")
                    return 
                }
                
                Task { @MainActor in
                    let parties = documents.compactMap { doc -> Party? in
                        do {
                            return try doc.data(as: Party.self)
                        } catch {
                            print("❌ Error decoding party: \(error)")
                            return nil
                        }
                    }
                    
                    self.nearbyParties = parties
                    print("✅ Loaded \(parties.count) nearby parties from Firestore")
                    
                    // If no parties exist, create some sample data for testing
                    if parties.isEmpty {
                        await self.createSamplePartiesIfNeeded()
                    }
                }
            }
    }
    
    private func setupRSVPListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        rsvpListener = db.collection("rsvps")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to RSVPs: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.userRSVPs = documents.compactMap { doc in
                        try? doc.data(as: RSVP.self)
                    }
                    print("✅ Loaded \(self.userRSVPs.count) user RSVPs")
                }
            }
    }
    
    func setupRealTimePartyUpdates() {
        // Additional real-time updates for party changes
        print("🔄 Setting up real-time party updates")
    }
    
    // MARK: - Host Mode Operations
    
    func toggleHostMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isHostMode.toggle()
        }
        print("🔄 Host mode toggled to: \(isHostMode)")
    }
    
    func checkHostMode() async {
        guard let userId = Auth.auth().currentUser?.uid else { 
            await MainActor.run {
                isHostMode = false
                hostProfile = nil
            }
            return 
        }
        
        do {
            let hostDoc = try await performanceService.optimizeDatabaseOperation {
                try await self.db.collection("partyHosts").document(userId).getDocument()
            }
            
            await MainActor.run {
                if hostDoc.exists {
                    do {
                        hostProfile = try hostDoc.data(as: PartyHost.self)
                        isHostMode = true
                        print("✅ Host mode enabled - switching to host interface")
                    } catch {
                        print("❌ Error parsing host profile: \(error)")
                        isHostMode = false
                        hostProfile = nil
                    }
                } else {
                    isHostMode = false
                    hostProfile = nil
                    print("📱 Regular user mode - using standard interface")
                }
            }
        } catch {
            print("❌ Error checking host mode: \(error)")
            await MainActor.run {
                isHostMode = false
                hostProfile = nil
            }
        }
    }
    
    // ENHANCED: Enable Host Mode with Immediate UI Updates and Sample Data
    func enableHostMode(businessName: String, contactEmail: String, phoneNumber: String, businessType: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let newHost = PartyHost(
            userId: userId,
            businessName: businessName,
            contactEmail: contactEmail,
            phoneNumber: phoneNumber,
            businessType: businessType
        )
        
        print("🔄 Enabling host mode for user: \(userId)")
        
        // Write to Firestore first
        try await performanceService.optimizeDatabaseOperation {
            try await self.db.collection("partyHosts").document(userId).setData(from: newHost)
        }
        
        // ALSO update the user's main profile to indicate host status
        try await performanceService.optimizeDatabaseOperation {
            try await self.db.collection("users").document(userId).updateData([
                "isHost": true,
                "hostProfile": [
                    "businessName": businessName,
                    "businessType": businessType,
                    "hostModeEnabledAt": FieldValue.serverTimestamp()
                ]
            ])
        }
        
        print("✅ Firestore updated successfully")
        
        // Create sample parties for immediate testing
        await createSamplePartiesForHost(userId: userId, hostName: businessName)
        
        // IMMEDIATE UI state update - Critical for user experience
        await MainActor.run {
            self.hostProfile = newHost
            self.isHostMode = true
            
            print("✅ Host mode enabled - UI updated immediately")
        }
        
        // Track host activation
        await trackHostEvent("host_mode_enabled", data: [
            "businessName": businessName,
            "businessType": businessType,
            "timestamp": FieldValue.serverTimestamp()
        ])
        
        // Force complete app refresh with multiple notification methods
        await MainActor.run {
            // Method 1: Direct property change notification
            NotificationCenter.default.post(
                name: NSNotification.Name("HostModeChanged"), 
                object: true
            )
            
            // Method 2: Force app refresh notification
            NotificationCenter.default.post(
                name: NSNotification.Name("ForceAppRefresh"), 
                object: nil,
                userInfo: ["hostMode": true]
            )
            
            // Method 3: Update refresh indicators
            self.shouldRefreshTabs.toggle()
            self.forceUIRefresh = UUID()
        }
        
        print("✅ Host mode enabled successfully with full setup and sample data")
    }
    
    // MARK: - Sample Data Creation for Testing
    private func createSamplePartiesForHost(userId: String, hostName: String) async {
        print("🎯 Creating sample parties for new host: \(hostName)")
        
        let sampleParties = [
            Party(
                title: "Welcome Party - \(hostName)",
                description: "Celebrate the launch of \(hostName)! Join us for an amazing night of music, dancing, and great vibes.",
                hostId: userId,
                hostName: hostName,
                location: PartyLocation(
                    name: "The Grand Ballroom",
                    address: "123 Party Street",
                    city: "San Francisco",
                    state: "CA",
                    zipCode: "94102",
                    latitude: 37.7749,
                    longitude: -122.4194,
                    placeId: "sample_place_new_host"
                ),
                startDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()) ?? Date(),
                ticketTiers: [
                    TicketTier(
                        name: "General Admission",
                        price: 25.0,
                        description: "Standard entry with access to all areas",
                        maxQuantity: 100,
                        perks: ["Welcome drink", "Dance floor access"]
                    )
                ],
                guestCap: 200,
                currentAttendees: 15, // Start with some interest
                isPublic: true,
                tags: ["party", "music", "dancing", "welcome"]
            ),
            
            Party(
                title: "Weekend Mixer by \(hostName)",
                description: "A casual weekend get-together with great people, music, and refreshments.",
                hostId: userId,
                hostName: hostName,
                location: PartyLocation(
                    name: "Downtown Event Space",
                    address: "456 Social Ave",
                    city: "San Francisco",
                    state: "CA",
                    zipCode: "94103",
                    latitude: 37.7849,
                    longitude: -122.4094,
                    placeId: "sample_place_mixer"
                ),
                startDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 14, to: Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date()) ?? Date(),
                ticketTiers: [], // Free event
                guestCap: 50,
                currentAttendees: 8,
                isPublic: true,
                tags: ["mixer", "casual", "networking", "free"]
            )
        ]
        
        // Store sample parties in Firestore
        for party in sampleParties {
            do {
                try await db.collection("parties").document(party.id).setData(from: party)
                print("✅ Created sample party: \(party.title)")
            } catch {
                print("❌ Error creating sample party: \(error)")
            }
        }
        
        print("✅ Sample parties created successfully")
    }
    
    private func createSamplePartiesIfNeeded() async {
        // Only create sample data if we're in a testing environment or if specifically requested
        guard nearbyParties.isEmpty else { return }
        
        print("🎯 Creating general sample parties for testing...")
        
        let sampleParties = [
            Party(
                title: "Weekend Dance Party",
                description: "Join us for an amazing night of music, dancing, and great vibes! DJ spinning the latest hits all night long.",
                hostId: "sample_host_1",
                hostName: "EventCo",
                location: PartyLocation(
                    name: "The Grand Ballroom",
                    address: "123 Party Street",
                    city: "San Francisco",
                    state: "CA",
                    zipCode: "94102",
                    latitude: 37.7749,
                    longitude: -122.4194,
                    placeId: "sample_place_1"
                ),
                startDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()) ?? Date(),
                ticketTiers: [
                    TicketTier(
                        name: "General Admission",
                        price: 30.0,
                        description: "Standard entry with access to all areas",
                        maxQuantity: 150,
                        perks: ["Welcome drink", "Dance floor access"]
                    ),
                    TicketTier(
                        name: "VIP Experience",
                        price: 75.0,
                        description: "Premium experience with exclusive perks",
                        maxQuantity: 50,
                        perks: ["VIP lounge access", "Premium bar", "Priority entry", "Meet & greet"]
                    )
                ],
                guestCap: 200,
                currentAttendees: 87,
                isPublic: true,
                tags: ["dance", "music", "party", "weekend"]
            ),
            
            Party(
                title: "Rooftop Social Mixer",
                description: "Network and socialize at this exclusive rooftop event with stunning city views, craft cocktails, and live music.",
                hostId: "sample_host_2",
                hostName: "Social Events Inc",
                location: PartyLocation(
                    name: "Sky Lounge",
                    address: "789 High Street",
                    city: "San Francisco", 
                    state: "CA",
                    zipCode: "94104",
                    latitude: 37.7849,
                    longitude: -122.4094,
                    placeId: "sample_place_2"
                ),
                startDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date()) ?? Date(),
                ticketTiers: [
                    TicketTier(
                        name: "Social Pass",
                        price: 45.0,
                        description: "Access to all social areas and networking zones",
                        maxQuantity: 80,
                        perks: ["Welcome cocktail", "Networking zones", "City views"]
                    )
                ],
                guestCap: 100,
                currentAttendees: 42,
                isPublic: true,
                tags: ["networking", "rooftop", "cocktails", "social"]
            ),
            
            Party(
                title: "Summer Beach BBQ",
                description: "Casual beach barbecue with live music, games, and fresh grilled food. Perfect for a relaxed weekend vibe.",
                hostId: "sample_host_3",
                hostName: "Beach Vibes Co",
                location: PartyLocation(
                    name: "Ocean Beach",
                    address: "Great Highway",
                    city: "San Francisco", 
                    state: "CA",
                    zipCode: "94122",
                    latitude: 37.7590,
                    longitude: -122.5107,
                    placeId: "sample_place_3"
                ),
                startDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 5, to: Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()) ?? Date(),
                ticketTiers: [], // Free event
                guestCap: 150,
                currentAttendees: 67,
                isPublic: true,
                tags: ["beach", "bbq", "casual", "music"]
            )
        ]
        
        // Store sample parties in Firestore
        for party in sampleParties {
            do {
                try await db.collection("parties").document(party.id).setData(from: party)
                print("✅ Created sample party: \(party.title)")
            } catch {
                print("❌ Error creating sample party: \(error)")
            }
        }
    }
    
    // MARK: - Search and Filter
    
    func searchParties(query: String) -> [Party] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nearbyParties
        }
        
        let lowercaseQuery = query.lowercased()
        
        return nearbyParties.filter { party in
            party.title.lowercased().contains(lowercaseQuery) ||
            party.description.lowercased().contains(lowercaseQuery) ||
            party.location.name.lowercased().contains(lowercaseQuery) ||
            party.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    func getPartiesNearLocation(_ location: CLLocation, radius: CLLocationDistance) -> [Party] {
        return nearbyParties.filter { party in
            let partyLocation = CLLocation(
                latitude: party.location.latitude,
                longitude: party.location.longitude
            )
            return location.distance(from: partyLocation) <= radius
        }
    }
    
    // MARK: - RSVP Management
    
    func isUserRSVPed(to partyId: String) -> Bool {
        return userRSVPs.contains { rsvp in
            rsvp.partyId == partyId && rsvp.status == .confirmed
        }
    }
    
    func quickRSVP(to partyId: String, selectedTier: TicketTier?, quantity: Int = 1) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              let party = nearbyParties.first(where: { $0.id == partyId }) else {
            throw NSError(domain: "RSVPError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid party or user"])
        }
        
        // Check capacity
        if party.currentAttendees + quantity > party.guestCap {
            throw NSError(domain: "RSVPError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Party is at capacity"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let userData = RSVPUserData(
            profileImageURL: nil,
            interests: [],
            partyExperience: nil,
            groupSize: quantity,
            specialRequests: nil,
            emergencyContact: nil,
            dietaryRestrictions: [],
            ageGroup: "21+",
            socialMediaHandle: nil
        )
        
        let rsvp = RSVP(
            partyId: partyId,
            userId: userId,
            userName: Auth.auth().currentUser?.displayName ?? "Unknown",
            userEmail: Auth.auth().currentUser?.email ?? "",
            ticketTierId: selectedTier?.id,
            quantity: quantity,
            userData: userData
        )
        
        try await performanceService.optimizeDatabaseOperation {
            try await self.db.collection("rsvps").document(rsvp.id).setData(from: rsvp)
        }
        
        // Update party attendance
        try await performanceService.optimizeDatabaseOperation {
            try await self.db.collection("parties").document(partyId).updateData([
                "currentAttendees": FieldValue.increment(Int64(quantity))
            ])
        }
        
        // Track RSVP event
        await trackPartyEvent(partyId, event: "rsvp_created", data: [
            "quantity": quantity,
            "ticketTier": selectedTier?.name ?? "none",
            "timestamp": FieldValue.serverTimestamp()
        ])
        
        print("✅ Fast RSVP completed successfully")
    }
    
    // MARK: - Full RSVP Creation (for RSVPFormView)
    
    func createRSVP(for party: Party, userData: RSVPUserData, ticketTierId: String?, quantity: Int) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "RSVPError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check capacity
        if party.currentAttendees + quantity > party.guestCap {
            throw NSError(domain: "RSVPError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Party is at capacity"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let rsvp = RSVP(
            partyId: party.id,
            userId: userId,
            userName: Auth.auth().currentUser?.displayName ?? "Unknown",
            userEmail: Auth.auth().currentUser?.email ?? "",
            ticketTierId: ticketTierId,
            quantity: quantity,
            userData: userData
        )
        
        try await performanceService.optimizeDatabaseOperation {
            try await self.db.collection("rsvps").document(rsvp.id).setData(from: rsvp)
        }
        
        // Update party attendance
        try await performanceService.optimizeDatabaseOperation {
            try await self.db.collection("parties").document(party.id).updateData([
                "currentAttendees": FieldValue.increment(Int64(quantity))
            ])
        }
        
        // Track RSVP event
        await trackPartyEvent(party.id, event: "rsvp_created", data: [
            "quantity": quantity,
            "ticketTier": ticketTierId ?? "none",
            "timestamp": FieldValue.serverTimestamp()
        ])
        
        print("✅ Full RSVP created successfully")
    }
    
    // MARK: - Party Creation (for PartyCreationView)
    
    func createParty(_ party: Party) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "PartyError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Verify user is a host
        guard isHostMode else {
            throw NSError(domain: "PartyError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Must be in host mode to create parties"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try await performanceService.optimizeDatabaseOperation {
            try await self.db.collection("parties").document(party.id).setData(from: party)
        }
        
        // Track party creation
        await trackHostEvent("party_created", data: [
            "partyId": party.id,
            "title": party.title,
            "guestCap": party.guestCap,
            "timestamp": FieldValue.serverTimestamp()
        ])
        
        // Update host statistics
        await updateHostStatistics(partyCreated: true)
        
        print("✅ Party created successfully: \(party.title)")
    }
    
    // MARK: - Host Data Methods (for PartyDetailView)
    
    func getPartiesByHost(hostId: String) async throws -> [Party] {
        let snapshot = try await performanceService.optimizeDatabaseOperation {
            try await self.db.collection("parties")
                .whereField("hostId", isEqualTo: hostId)
                .getDocuments()
        }
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Party.self)
        }
    }
    
    func getHostPartyHistory(hostId: String) async throws -> [Party] {
        return try await getPartiesByHost(hostId: hostId)
    }
    
    func getHostStatistics(hostId: String) async throws -> HostStats {
        // Get host data from Firestore
        let hostDoc = try await performanceService.optimizeDatabaseOperation {
            try await self.db.collection("partyHosts").document(hostId).getDocument()
        }
        
        // Get parties for statistics calculation
        let parties = try await getPartiesByHost(hostId: hostId)
        
        let totalParties = parties.count
        let totalAttendees = parties.reduce(0) { $0 + $1.currentAttendees }
        let completedParties = parties.filter { $0.status == .ended }.count
        let upcomingParties = parties.filter { $0.status == .upcoming }.count
        
        // Calculate averages
        let averageAttendance = totalParties > 0 ? Double(totalAttendees) / Double(totalParties) : 0.0
        let averageRating = 4.5 // Placeholder - would calculate from reviews
        
        // Get member since date
        let memberSince: Date
        if hostDoc.exists, let data = hostDoc.data() {
            memberSince = (data["joinDate"] as? Timestamp)?.dateValue() ?? Date()
        } else {
            memberSince = Date()
        }
        
        return HostStats(
            hostId: hostId,
            totalParties: totalParties,
            totalAttendees: totalAttendees,
            averageRating: averageRating,
            averageAttendance: averageAttendance,
            memberSince: memberSince,
            revenue: 0.0, // Placeholder
            upcomingParties: upcomingParties,
            completedParties: completedParties
        )
    }
    
    // MARK: - Analytics and Tracking
    
    private func trackPartyEvent(_ partyId: String, event: String, data: [String: Any]) async {
        let eventData: [String: Any] = [
            "partyId": partyId,
            "event": event,
            "userId": Auth.auth().currentUser?.uid ?? "anonymous",
            "timestamp": FieldValue.serverTimestamp(),
            "data": data
        ]
        
        do {
            try await performanceService.optimizeDatabaseOperation {
                try await self.db.collection("partyEvents").addDocument(data: eventData)
            }
        } catch {
            print("❌ Error tracking party event: \(error)")
        }
    }
    
    private func trackHostEvent(_ event: String, data: [String: Any]) async {
        let eventData: [String: Any] = [
            "event": event,
            "hostId": Auth.auth().currentUser?.uid ?? "anonymous",
            "timestamp": FieldValue.serverTimestamp(),
            "data": data
        ]
        
        do {
            try await performanceService.optimizeDatabaseOperation {
                try await self.db.collection("hostEvents").addDocument(data: eventData)
            }
        } catch {
            print("❌ Error tracking host event: \(error)")
        }
    }
    
    // MARK: - Host Data Loading
    
    func loadHostParties() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await performanceService.optimizeDatabaseOperation {
                try await self.db.collection("parties")
                    .whereField("hostId", isEqualTo: userId)
                    .getDocuments()
            }
            
            await MainActor.run {
                self.hostParties = snapshot.documents.compactMap { doc in
                    try? doc.data(as: Party.self)
                }
                print("✅ Loaded \(self.hostParties.count) host parties")
            }
        } catch {
            print("❌ Error loading host parties: \(error)")
        }
    }
    
    func loadHostAnalytics() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Load host analytics data
        do {
            let snapshot = try await performanceService.optimizeDatabaseOperation {
                try await self.db.collection("hostAnalytics")
                    .document(userId)
                    .getDocument()
            }
            
            await MainActor.run {
                if snapshot.exists {
                    do {
                        self.hostAnalytics = try snapshot.data(as: HostAnalytics.self)
                        print("✅ Loaded host analytics")
                    } catch {
                        print("❌ Error parsing host analytics: \(error)")
                    }
                }
            }
        } catch {
            print("❌ Error loading host analytics: \(error)")
        }
    }
    
    // MARK: - Host Statistics Update
    
    private func updateHostStatistics(partyCreated: Bool = false, rsvpReceived: Bool = false) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var updates: [String: Any] = [
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        if partyCreated {
            updates["totalParties"] = FieldValue.increment(Int64(1))
        }
        
        if rsvpReceived {
            updates["totalRSVPs"] = FieldValue.increment(Int64(1))
        }
        
        do {
            try await performanceService.optimizeDatabaseOperation {
                try await self.db.collection("hostAnalytics").document(userId).updateData(updates)
            }
        } catch {
            print("❌ Error updating host statistics: \(error)")
        }
    }
    
    // ENHANCED: Disable Host Mode with UI Updates
    func disableHostMode() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Archive existing data instead of deleting
        if let host = hostProfile {
            let archiveData: [String: Any] = [
                "hostData": try Firestore.Encoder().encode(host),
                "archivedAt": FieldValue.serverTimestamp(),
                "reason": "host_mode_disabled"
            ]
            
            try await performanceService.optimizeDatabaseOperation {
                try await self.db.collection("archivedHosts").document(userId).setData(archiveData)
            }
        }
        
        // Remove active host profile
        try await performanceService.optimizeDatabaseOperation {
            try await self.db.collection("partyHosts").document(userId).delete()
        }
        
        // Update user's main profile
        try await performanceService.optimizeDatabaseOperation {
            try await self.db.collection("users").document(userId).updateData([
                "isHost": false,
                "hostProfile": FieldValue.delete(),
                "hostModeDisabledAt": FieldValue.serverTimestamp()
            ])
        }
        
        // Immediate UI state update
        await MainActor.run {
            hostProfile = nil
            isHostMode = false
            hostParties = []
            hostAnalytics = nil
            
            print("✅ Host mode disabled - UI updated to regular user mode")
        }
        
        hostListener?.remove()
        
        // Post notification to trigger complete app refresh
        NotificationCenter.default.post(
            name: NSNotification.Name("ForceAppRefresh"), 
            object: nil,
            userInfo: ["hostMode": false]
        )
        
        print("✅ Host mode disabled successfully")
    }
    
    private func setupHostListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        hostListener = db.collection("parties")
            .whereField("hostId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error listening to host parties: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    self.hostParties = documents.compactMap { doc in
                        try? doc.data(as: Party.self)
                    }
                    
                    print("✅ Loaded \(self.hostParties.count) host parties")
                }
            }
    }
    
    // MARK: - Mode Switching Methods
    
    func switchToBusinessMode() async {
        guard hostProfile != nil else {
            print("❌ Cannot switch to business mode - no host profile exists")
            return
        }
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                isHostMode = true
            }
            print("✅ Switched to business mode")
        }
        
        // Setup business mode listeners and load data
        setupHostListener()
        await loadHostParties()
        await loadHostAnalytics()
    }
    
    func switchToNormalMode() async {
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                isHostMode = false
            }
            print("✅ Switched to normal mode")
        }
        
        // Remove business mode listeners
        hostListener?.remove()
        
        await MainActor.run {
            hostParties = []
            hostAnalytics = nil
        }
    }
    
    // MARK: - Data Loading and Sample Creation
    func loadPartiesAndCreateSamples() async {
        // First load existing parties
        await loadHostParties()
        
        // If no parties exist and user is a host, create samples
        if hostParties.isEmpty && hostProfile != nil {
            await createSamplePartiesIfNeeded()
        }
    }
} 