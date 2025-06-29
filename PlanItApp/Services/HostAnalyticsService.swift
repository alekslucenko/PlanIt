import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine

/// 📊 PROFESSIONAL REAL-TIME ANALYTICS SERVICE
/// Comprehensive tracking system for business dashboard with real-time updates
/// Handles RSVPs, ticket sales, event analytics, and user interactions
@MainActor
class HostAnalyticsService: ObservableObject {
    static let shared = HostAnalyticsService()
    
    // MARK: - Nested Types
    
    enum Timeframe: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case last30Days = "Last 30 Days"
        case last3Months = "Last 3 Months"
    }
    
    struct DailyMetricPoint: Identifiable, Codable, Equatable {
        let id: UUID
        let date: Date
        let revenue: Double
        let rsvps: Int
        let events: Int
        let customers: Int
        
        init(date: Date, revenue: Double = 0, rsvps: Int = 0, events: Int = 0, customers: Int = 0) {
            self.id = UUID()
            self.date = date
            self.revenue = revenue
            self.rsvps = rsvps
            self.events = events
            self.customers = customers
        }
    }
    
    // MARK: - Published Analytics Data
    @Published var totalRevenue: Double = 0
    @Published var todayRevenue: Double = 0
    @Published var weeklyRevenue: Double = 0
    @Published var monthlyRevenue: Double = 0
    
    @Published var totalRSVPs: Int = 0
    @Published var confirmedRSVPs: Int = 0
    @Published var pendingRSVPs: Int = 0
    @Published var todayRSVPs: Int = 0
    
    @Published var activeEvents: Int = 0
    @Published var upcomingEvents: Int = 0
    @Published var completedEvents: Int = 0
    @Published var soldOutEvents: Int = 0
    
    @Published var uniqueCustomers: Int = 0
    @Published var newCustomersToday: Int = 0
    @Published var returningCustomers: Int = 0
    
    @Published var conversionRate: Double = 0
    @Published var totalViews: Int = 0
    @Published var totalClicks: Int = 0
    
    /// The date when the host published their first party – used for time-based metric availability checks.
    @Published var hostStartDate: Date? = nil
    
    // MARK: - Detailed Data for Drill-down Views
    @Published var recentRSVPs: [RSVPDetail] = []
    @Published var recentTicketSales: [TicketSaleDetail] = []
    @Published var topPerformingEvents: [EventPerformance] = []
    @Published var customerInsights: [CustomerInsight] = []
    @Published var revenueBreakdown: [RevenueBreakdown] = []
    
    // MARK: - Real-time Chart Data
    @Published var revenueChartData: [DailyMetricPoint] = []
    @Published var rsvpChartData: [DailyMetricPoint] = []
    @Published var attendanceChartData: [DailyMetricPoint] = []
    
    // MARK: - Service State
    @Published var isLoading = false
    @Published var hasError = false
    @Published var lastUpdated = Date()
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var currentUserId: String?
    private var updateTimer: Timer?
    
    private init() {
        setupRealtimeTracking()
    }
    
    deinit {
        Task { @MainActor in
            removeAllListeners()
            updateTimer?.invalidate()
        }
    }
    
    // MARK: - Public Interface
    
    func startTracking(for userId: String) {
        guard currentUserId != userId else { return }
        
        print("📊 Starting real-time analytics tracking for user: \(userId)")
        
        currentUserId = userId
        // Store the moment tracking begins as a fallback for `hostStartDate` until real data is loaded.
        if hostStartDate == nil {
            hostStartDate = Date()
        }
        removeAllListeners()
        
        setupRealtimeListeners()
        startPeriodicUpdates()
        
        // Initial data fetch
        Task {
            await fetchAllAnalytics()
        }
    }
    
    func stopTracking() {
        print("📊 Stopping analytics tracking")
        
        currentUserId = nil
        removeAllListeners()
        updateTimer?.invalidate()
        
        // Reset data
        resetAnalyticsData()
    }
    
    func refreshData() async {
        await fetchAllAnalytics()
    }
    
    // MARK: - Real-time Listeners Setup
    
    private func setupRealtimeTracking() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        startTracking(for: userId)
    }
    
    private func setupRealtimeListeners() {
        guard let userId = currentUserId else { return }
        
        print("🔗 Setting up real-time analytics listeners...")
        
        // 1. Ticket Sales Listener with fallback
        setupTicketSalesListener(for: userId)
        
        // 2. RSVPs Listener with fallback
        setupRSVPListener(for: userId)
        
        // 3. Events Listener
        setupEventsListener(for: userId)
        
        // 4. Event Interactions Listener
        setupInteractionsListener(for: userId)
        
        // 5. Users/Customers Listener
        setupCustomersListener()
    }
    
    private func setupTicketSalesListener(for userId: String) {
        // Try collection group query first, with fallback for missing indexes
        let salesListener = db.collectionGroup("ticketSales")
            .whereField("hostId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error in ticket sales listener: \(error)")
                    if error.localizedDescription.contains("index") {
                        print("🔧 Using fallback ticket sales tracking")
                        self.setupTicketSalesFallback(for: userId)
                    }
                    return
                }
                
                print("💰 Ticket sales data updated")
                Task {
                    await self.processTicketSalesData(snapshot?.documents ?? [])
                }
            }
        
        listeners.append(salesListener)
    }
    
    private func setupTicketSalesFallback(for userId: String) {
        // Fallback: Listen to host's parties and track ticket sales manually
        let partiesListener = db.collection("parties")
            .whereField("hostId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error in parties listener for ticket sales: \(error)")
                    return
                }
                
                Task {
                    await self.fetchTicketSalesForParties(snapshot?.documents ?? [])
                }
            }
        
        listeners.append(partiesListener)
    }
    
    private func setupRSVPListener(for userId: String) {
        // Listen to RSVPs for host's events
        let rsvpListener = db.collectionGroup("rsvps")
            .whereField("hostId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error in RSVP listener: \(error)")
                    if error.localizedDescription.contains("index") {
                        print("🔧 Using fallback RSVP tracking")
                        self.setupRSVPFallback(for: userId)
                    }
                    return
                }
                
                print("🎫 RSVP data updated")
                Task {
                    await self.processRSVPData(snapshot?.documents ?? [])
                }
            }
        
        listeners.append(rsvpListener)
    }
    
    private func setupRSVPFallback(for userId: String) {
        // Fallback: Listen to parties and manually track RSVPs
        let partiesListener = db.collection("parties")
            .whereField("hostId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error in parties listener for RSVPs: \(error)")
                    return
                }
                
                Task {
                    await self.fetchRSVPsForParties(snapshot?.documents ?? [])
                }
            }
        
        listeners.append(partiesListener)
    }
    
    private func setupEventsListener(for userId: String) {
        let eventsListener = db.collection("parties")
            .whereField("hostId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error in events listener: \(error)")
                    return
                }
                
                print("🎉 Events data updated")
                Task {
                    await self.processEventsData(snapshot?.documents ?? [])
                }
            }
        
        listeners.append(eventsListener)
    }
    
    private func setupInteractionsListener(for userId: String) {
        let interactionsListener = db.collection("eventInteractions")
            .whereField("hostId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error in interactions listener: \(error)")
                    // Continue without interactions for now
                    return
                }
                
                print("👁️ Interactions data updated")
                Task {
                    await self.processInteractionsData(snapshot?.documents ?? [])
                }
            }
        
        listeners.append(interactionsListener)
    }
    
    private func setupCustomersListener() {
        let customersListener = db.collection("users")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error in customers listener: \(error)")
                    return
                }
                
                print("👤 Customers data updated")
                Task {
                    await self.processCustomersData(snapshot?.documents ?? [])
                }
            }
        
        listeners.append(customersListener)
    }
    
    // MARK: - Data Processing Methods
    
    private func processTicketSalesDataFromDict(_ salesData: [[String: Any]]) async {
        var revenue: Double = 0
        var todayRev: Double = 0
        var weeklyRev: Double = 0
        var monthlyRev: Double = 0
        var salesDetails: [TicketSaleDetail] = []
        var revenueBreakdown: [RevenueBreakdown] = []
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? today
        let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? today
        
        for (index, data) in salesData.enumerated() {
            guard let ticketPrice = data["ticketPrice"] as? Double,
                  let quantity = data["quantity"] as? Int,
                  let purchaseDate = data["purchaseDate"] as? Timestamp else {
                continue
            }
            
            let saleAmount = ticketPrice * Double(quantity)
            let date = purchaseDate.dateValue()
            
            revenue += saleAmount
            
            // Time-based revenue calculation
            if date >= today {
                todayRev += saleAmount
            }
            if date >= weekStart {
                weeklyRev += saleAmount
            }
            if date >= monthStart {
                monthlyRev += saleAmount
            }
            
            // Create detailed sale record
            let saleDetail = TicketSaleDetail(
                id: "sale_\(index)",
                eventName: data["eventName"] as? String ?? "Unknown Event",
                buyerName: data["buyerName"] as? String ?? "Anonymous",
                buyerEmail: data["buyerEmail"] as? String ?? "",
                ticketType: data["ticketType"] as? String ?? "General",
                quantity: quantity,
                unitPrice: ticketPrice,
                totalAmount: saleAmount,
                purchaseDate: date,
                status: data["status"] as? String ?? "completed"
            )
            
            salesDetails.append(saleDetail)
        }
        
        // Create revenue breakdown by event
        let eventGroups = Dictionary(grouping: salesDetails) { $0.eventName }
        revenueBreakdown = eventGroups.map { eventName, sales in
            RevenueBreakdown(
                eventName: eventName,
                totalRevenue: sales.reduce(0) { $0 + $1.totalAmount },
                ticketsSold: sales.reduce(0) { $0 + $1.quantity },
                averageTicketPrice: sales.isEmpty ? 0 : sales.reduce(0) { $0 + $1.unitPrice } / Double(sales.count)
            )
        }.sorted { $0.totalRevenue > $1.totalRevenue }
        
        await MainActor.run {
            self.totalRevenue = revenue
            self.todayRevenue = todayRev
            self.weeklyRevenue = weeklyRev
            self.monthlyRevenue = monthlyRev
            self.recentTicketSales = Array(salesDetails.sorted { $0.purchaseDate > $1.purchaseDate }.prefix(10))
            self.revenueBreakdown = revenueBreakdown
            self.lastUpdated = Date()
            
            print("✅ Revenue analytics updated: $\(revenue) total, $\(todayRev) today")
        }
    }
    
    private func processTicketSalesData(_ documents: [QueryDocumentSnapshot]) async {
        var revenue: Double = 0
        var todayRev: Double = 0
        var weeklyRev: Double = 0
        var monthlyRev: Double = 0
        var salesDetails: [TicketSaleDetail] = []
        var revenueBreakdown: [RevenueBreakdown] = []
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? today
        let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? today
        
        for document in documents {
            let data = document.data()
            
            guard let ticketPrice = data["ticketPrice"] as? Double,
                  let quantity = data["quantity"] as? Int,
                  let purchaseDate = data["purchaseDate"] as? Timestamp else {
                continue
            }
            
            let saleAmount = ticketPrice * Double(quantity)
            let date = purchaseDate.dateValue()
            
            revenue += saleAmount
            
            // Time-based revenue calculation
            if date >= today {
                todayRev += saleAmount
            }
            if date >= weekStart {
                weeklyRev += saleAmount
            }
            if date >= monthStart {
                monthlyRev += saleAmount
            }
            
            // Create detailed sale record
            let saleDetail = TicketSaleDetail(
                id: document.documentID,
                eventName: data["eventName"] as? String ?? "Unknown Event",
                buyerName: data["buyerName"] as? String ?? "Anonymous",
                buyerEmail: data["buyerEmail"] as? String ?? "",
                ticketType: data["ticketType"] as? String ?? "General",
                quantity: quantity,
                unitPrice: ticketPrice,
                totalAmount: saleAmount,
                purchaseDate: date,
                status: data["status"] as? String ?? "completed"
            )
            
            salesDetails.append(saleDetail)
        }
        
        // Create revenue breakdown by event
        let eventGroups = Dictionary(grouping: salesDetails) { $0.eventName }
        revenueBreakdown = eventGroups.map { eventName, sales in
            RevenueBreakdown(
                eventName: eventName,
                totalRevenue: sales.reduce(0) { $0 + $1.totalAmount },
                ticketsSold: sales.reduce(0) { $0 + $1.quantity },
                averageTicketPrice: sales.isEmpty ? 0 : sales.reduce(0) { $0 + $1.unitPrice } / Double(sales.count)
            )
        }.sorted { $0.totalRevenue > $1.totalRevenue }
        
        await MainActor.run {
            self.totalRevenue = revenue
            self.todayRevenue = todayRev
            self.weeklyRevenue = weeklyRev
            self.monthlyRevenue = monthlyRev
            self.recentTicketSales = Array(salesDetails.sorted { $0.purchaseDate > $1.purchaseDate }.prefix(10))
            self.revenueBreakdown = revenueBreakdown
            self.lastUpdated = Date()
            
            print("✅ Revenue analytics updated: $\(revenue) total, $\(todayRev) today")
        }
    }
    
    private func processRSVPDataFromDict(_ rsvpData: [[String: Any]]) async {
        var total = 0
        var confirmed = 0
        var pending = 0
        var todayCount = 0
        var rsvpDetails: [RSVPDetail] = []
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for (index, data) in rsvpData.enumerated() {
            guard let status = data["status"] as? String,
                  let rsvpDate = data["rsvpDate"] as? Timestamp else {
                continue
            }
            
            total += 1
            
            switch status {
            case "confirmed":
                confirmed += 1
            case "pending":
                pending += 1
            default:
                break
            }
            
            let date = rsvpDate.dateValue()
            if date >= today {
                todayCount += 1
            }
            
            // Create detailed RSVP record
            let rsvpDetail = RSVPDetail(
                id: "rsvp_\(index)",
                eventName: data["eventName"] as? String ?? "Unknown Event",
                guestName: data["guestName"] as? String ?? "Anonymous",
                guestEmail: data["guestEmail"] as? String ?? "",
                status: status,
                rsvpDate: date,
                partySize: data["partySize"] as? Int ?? 1,
                specialRequests: data["specialRequests"] as? String ?? ""
            )
            
            rsvpDetails.append(rsvpDetail)
        }
        
        await MainActor.run {
            self.totalRSVPs = total
            self.confirmedRSVPs = confirmed
            self.pendingRSVPs = pending
            self.todayRSVPs = todayCount
            self.recentRSVPs = Array(rsvpDetails.sorted { $0.rsvpDate > $1.rsvpDate }.prefix(10))
            
            print("✅ RSVP analytics updated: \(total) total, \(confirmed) confirmed, \(todayCount) today")
        }
    }
    
    private func processRSVPData(_ documents: [QueryDocumentSnapshot]) async {
        var total = 0
        var confirmed = 0
        var pending = 0
        var todayCount = 0
        var rsvpDetails: [RSVPDetail] = []
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for document in documents {
            let data = document.data()
            
            guard let status = data["status"] as? String,
                  let rsvpDate = data["rsvpDate"] as? Timestamp else {
                continue
            }
            
            total += 1
            
            switch status {
            case "confirmed":
                confirmed += 1
            case "pending":
                pending += 1
            default:
                break
            }
            
            let date = rsvpDate.dateValue()
            if date >= today {
                todayCount += 1
            }
            
            // Create detailed RSVP record
            let rsvpDetail = RSVPDetail(
                id: document.documentID,
                eventName: data["eventName"] as? String ?? "Unknown Event",
                guestName: data["guestName"] as? String ?? "Anonymous",
                guestEmail: data["guestEmail"] as? String ?? "",
                status: status,
                rsvpDate: date,
                partySize: data["partySize"] as? Int ?? 1,
                specialRequests: data["specialRequests"] as? String ?? ""
            )
            
            rsvpDetails.append(rsvpDetail)
        }
        
        await MainActor.run {
            self.totalRSVPs = total
            self.confirmedRSVPs = confirmed
            self.pendingRSVPs = pending
            self.todayRSVPs = todayCount
            self.recentRSVPs = Array(rsvpDetails.sorted { $0.rsvpDate > $1.rsvpDate }.prefix(10))
            
            print("✅ RSVP analytics updated: \(total) total, \(confirmed) confirmed, \(todayCount) today")
        }
    }
    
    private func processEventsData(_ documents: [QueryDocumentSnapshot]) async {
        var active = 0
        var upcoming = 0
        var completed = 0
        var soldOut = 0
        var eventPerformances: [EventPerformance] = []
        var earliestDate: Date?
        
        for document in documents {
            let data = document.data()
            
            guard let status = data["status"] as? String,
                  let startDate = data["startDate"] as? Timestamp else {
                continue
            }
            
            let currentAttendees = data["currentAttendees"] as? Int ?? 0
            let rawCapacity = data["capacity"] as? Int ?? 0
            
            // FORCE MINIMUM CAPACITY - Never allow 0 capacity events
            let capacity = max(rawCapacity, 1) // Minimum capacity of 1
            
            // If original capacity was 0, we should update it in Firestore
            if rawCapacity == 0 {
                print("⚠️ Found event with 0 capacity, setting minimum to 1: \(document.documentID)")
                document.reference.updateData(["capacity": 1]) { error in
                    if let error = error {
                        print("❌ Failed to update capacity: \(error)")
                    } else {
                        print("✅ Updated event capacity from 0 to 1")
                    }
                }
            }
            
            let isSoldOut = currentAttendees >= capacity
            
            // Track earliest event start date
            let eventStart = startDate.dateValue()
            if let current = earliestDate {
                if eventStart < current { earliestDate = eventStart }
            } else {
                earliestDate = eventStart
            }
            
            switch status {
            case "live":
                active += 1
            case "upcoming":
                upcoming += 1
            case "ended", "completed":
                completed += 1
            default:
                break
            }
            
            if isSoldOut {
                soldOut += 1
            }
            
            // Create event performance record with proper percentage calculation
            let performance = EventPerformance(
                id: document.documentID,
                eventName: data["title"] as? String ?? "Unknown Event",
                startDate: startDate.dateValue(),
                status: status,
                currentAttendees: currentAttendees,
                capacity: capacity,
                occupancyRate: capacity > 0 ? Double(currentAttendees) / Double(capacity) * 100 : 0,
                revenue: 0, // Will be calculated from ticket sales
                views: 0,   // Will be calculated from interactions
                clicks: 0   // Will be calculated from interactions
            )
            
            eventPerformances.append(performance)
        }
        
        // Save earliest event date (host first party) if we have one
        if let date = earliestDate {
            await MainActor.run {
                if self.hostStartDate == nil || date < (self.hostStartDate ?? date) {
                    self.hostStartDate = date
                }
            }
        }
        
        await MainActor.run {
            self.activeEvents = active
            self.upcomingEvents = upcoming
            self.completedEvents = completed
            self.soldOutEvents = soldOut
            self.topPerformingEvents = eventPerformances.sorted { $0.occupancyRate > $1.occupancyRate }
            
            print("✅ Events analytics updated: \(active) active, \(upcoming) upcoming, \(completed) completed")
        }
    }
    
    private func processInteractionsData(_ documents: [QueryDocumentSnapshot]) async {
        var views = 0
        var clicks = 0
        
        for document in documents {
            let data = document.data()
            
            guard let type = data["type"] as? String else { continue }
            
            switch type {
            case "view":
                views += 1
            case "click":
                clicks += 1
            default:
                break
            }
        }
        
        let conversion = views > 0 ? (Double(confirmedRSVPs) / Double(views)) * 100 : 0
        
        await MainActor.run {
            self.totalViews = views
            self.totalClicks = clicks
            self.conversionRate = conversion
            
            print("✅ Interactions analytics updated: \(views) views, \(clicks) clicks, \(conversion)% conversion")
        }
    }
    
    private func processCustomersData(_ documents: [QueryDocumentSnapshot]) async {
        let uniqueIds = Set(documents.map { $0.documentID })
        let today = Calendar.current.startOfDay(for: Date())
        
        var newToday = 0
        var customerInsights: [CustomerInsight] = []
        
        for document in documents {
            let data = document.data()
            
            if let createdAt = data["createdAt"] as? Timestamp,
               createdAt.dateValue() >= today {
                newToday += 1
            }
            
            // Create customer insight
            let insight = CustomerInsight(
                id: document.documentID,
                name: data["displayName"] as? String ?? "Anonymous",
                email: data["email"] as? String ?? "",
                totalSpent: data["totalSpent"] as? Double ?? 0,
                eventsAttended: data["eventsAttended"] as? Int ?? 0,
                joinDate: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                lastActivity: (data["lastActivity"] as? Timestamp)?.dateValue() ?? Date()
            )
            
            customerInsights.append(insight)
        }
        
        await MainActor.run {
            self.uniqueCustomers = uniqueIds.count
            self.newCustomersToday = newToday
            self.customerInsights = customerInsights.sorted { $0.totalSpent > $1.totalSpent }
            
            print("✅ Customers analytics updated: \(uniqueIds.count) unique, \(newToday) new today")
        }
    }
    
    // MARK: - Fallback Data Fetching
    
    private func fetchTicketSalesForParties(_ partyDocs: [QueryDocumentSnapshot]) async {
        var allSales: [[String: Any]] = []
        
        await withTaskGroup(of: [[String: Any]].self) { group in
            for partyDoc in partyDocs {
                group.addTask {
                    do {
                        let salesSnapshot = try await partyDoc.reference.collection("ticketSales").getDocuments()
                        return salesSnapshot.documents.map { $0.data() }
                    } catch {
                        print("❌ Error fetching ticket sales for party \(partyDoc.documentID): \(error)")
                        return []
                    }
                }
            }
            
            for await sales in group {
                allSales.append(contentsOf: sales)
            }
        }
        
        // Process the sales data directly
        await processTicketSalesDataFromDict(allSales)
    }
    
    private func fetchRSVPsForParties(_ partyDocs: [QueryDocumentSnapshot]) async {
        var allRSVPs: [[String: Any]] = []
        
        await withTaskGroup(of: [[String: Any]].self) { group in
            for partyDoc in partyDocs {
                group.addTask {
                    do {
                        let rsvpsSnapshot = try await partyDoc.reference.collection("rsvps").getDocuments()
                        return rsvpsSnapshot.documents.map { $0.data() }
                    } catch {
                        print("❌ Error fetching RSVPs for party \(partyDoc.documentID): \(error)")
                        return []
                    }
                }
            }
            
            for await rsvps in group {
                allRSVPs.append(contentsOf: rsvps)
            }
        }
        
        // Process the RSVP data directly
        await processRSVPDataFromDict(allRSVPs)
    }
    
    // MARK: - Helper Methods
    
    private func fetchAllAnalytics() async {
        guard let userId = currentUserId else { return }
        
        isLoading = true
        
        do {
            // Fetch all data in parallel
            async let partiesTask = db.collection("parties").whereField("hostId", isEqualTo: userId).getDocuments()
            
            let partiesSnapshot = try await partiesTask
            await processEventsData(partiesSnapshot.documents)
            
            // Fetch ticket sales and RSVPs for those parties
            await fetchTicketSalesForParties(partiesSnapshot.documents)
            await fetchRSVPsForParties(partiesSnapshot.documents)
            
        } catch {
            print("❌ Error fetching analytics: \(error)")
            hasError = true
        }
        
        isLoading = false
    }
    
    private func startPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in // 5 minutes
            Task {
                await self.refreshData()
            }
        }
    }
    
    private func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        print("🔌 Removed all analytics listeners")
    }
    
    private func resetAnalyticsData() {
        totalRevenue = 0
        todayRevenue = 0
        weeklyRevenue = 0
        monthlyRevenue = 0
        totalRSVPs = 0
        confirmedRSVPs = 0
        pendingRSVPs = 0
        todayRSVPs = 0
        activeEvents = 0
        upcomingEvents = 0
        completedEvents = 0
        soldOutEvents = 0
        uniqueCustomers = 0
        newCustomersToday = 0
        returningCustomers = 0
        conversionRate = 0
        totalViews = 0
        totalClicks = 0
        
        recentRSVPs.removeAll()
        recentTicketSales.removeAll()
        topPerformingEvents.removeAll()
        customerInsights.removeAll()
        revenueBreakdown.removeAll()
        revenueChartData.removeAll()
        rsvpChartData.removeAll()
        attendanceChartData.removeAll()
    }
}

// MARK: - Data Models

struct RSVPDetail: Identifiable, Codable {
    let id: String
    let eventName: String
    let guestName: String
    let guestEmail: String
    let status: String
    let rsvpDate: Date
    let partySize: Int
    let specialRequests: String
}

struct TicketSaleDetail: Identifiable, Codable {
    let id: String
    let eventName: String
    let buyerName: String
    let buyerEmail: String
    let ticketType: String
    let quantity: Int
    let unitPrice: Double
    let totalAmount: Double
    let purchaseDate: Date
    let status: String
}

struct EventPerformance: Identifiable, Codable {
    let id: String
    let eventName: String
    let startDate: Date
    let status: String
    let currentAttendees: Int
    let capacity: Int
    let occupancyRate: Double
    var revenue: Double
    var views: Int
    var clicks: Int
}

struct CustomerInsight: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let totalSpent: Double
    let eventsAttended: Int
    let joinDate: Date
    let lastActivity: Date
}

struct RevenueBreakdown: Identifiable, Codable {
    let id: UUID
    let eventName: String
    let totalRevenue: Double
    let ticketsSold: Int
    let averageTicketPrice: Double
    
    init(eventName: String, totalRevenue: Double, ticketsSold: Int, averageTicketPrice: Double) {
        self.id = UUID()
        self.eventName = eventName
        self.totalRevenue = totalRevenue
        self.ticketsSold = ticketsSold
        self.averageTicketPrice = averageTicketPrice
    }
}

// MARK: - Mock Document for Fallback Processing

// Mock query document snapshot for fallback processing
struct MockQueryDocumentSnapshot {
    let documentID: String
    private let mockData: [String: Any]
    
    init(id: String, data: [String: Any]) {
        self.documentID = id
        self.mockData = data
    }
    
    func data() -> [String: Any] {
        return mockData
    }
} 