import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine
import SwiftUI

/// 👥 CUSTOMER ANALYTICS SERVICE
/// Tracks real paying customers who have purchased tickets or confirmed RSVPs
@MainActor
class CustomerAnalyticsService: ObservableObject {
    static let shared = CustomerAnalyticsService()
    
    // MARK: - Data Models
    
    struct PayingCustomer: Identifiable, Codable {
        let id: String
        let userId: String
        let name: String
        let email: String
        let totalSpent: Double
        let totalTicketsPurchased: Int
        let eventsAttended: Int
        let firstPurchaseDate: Date
        let lastPurchaseDate: Date
        let averageTicketPrice: Double
        let preferredEventTypes: [String]
        let rsvpStatus: String // "confirmed", "pending", "attended"
        let age: Int?
        let gender: String?
        let location: String?
        let purchases: [PurchaseDetail]
        let rsvps: [RSVPDetail]
        
        var customerValue: CustomerValue {
            switch totalSpent {
            case 0..<50: return .low
            case 50..<200: return .medium
            case 200..<500: return .high
            default: return .premium
            }
        }
        
        var isNewCustomer: Bool {
            let daysSinceFirstPurchase = Calendar.current.dateComponents([.day], from: firstPurchaseDate, to: Date()).day ?? 0
            return daysSinceFirstPurchase <= 30
        }
    }
    
    enum CustomerValue: String, CaseIterable {
        case low = "Low Value"
        case medium = "Medium Value"
        case high = "High Value"
        case premium = "Premium"
        
        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .blue
            case .high: return .orange
            case .premium: return .purple
            }
        }
        
        var minSpent: Double {
            switch self {
            case .low: return 0
            case .medium: return 50
            case .high: return 200
            case .premium: return 500
            }
        }
    }
    
    struct PurchaseDetail: Identifiable, Codable {
        let id: String
        let eventName: String
        let eventId: String
        let ticketType: String
        let quantity: Int
        let unitPrice: Double
        let totalAmount: Double
        let purchaseDate: Date
        let status: String
    }
    
    struct CustomerSegment {
        let name: String
        let customers: [PayingCustomer]
        let totalRevenue: Double
        let averageSpent: Double
        let count: Int
        
        var percentage: Double {
            return count > 0 ? (totalRevenue / customers.reduce(0) { $0 + $1.totalSpent }) * 100 : 0
        }
    }
    
    // MARK: - Published Properties
    @Published var payingCustomers: [PayingCustomer] = []
    @Published var newCustomersThisWeek: [PayingCustomer] = []
    @Published var newCustomersThisMonth: [PayingCustomer] = []
    @Published var topCustomers: [PayingCustomer] = []
    @Published var customerSegments: [CustomerSegment] = []
    
    @Published var totalUniqueCustomers: Int = 0
    @Published var totalCustomerRevenue: Double = 0
    @Published var averageCustomerValue: Double = 0
    @Published var customerRetentionRate: Double = 0
    @Published var newCustomerGrowthRate: Double = 0
    
    @Published var isLoading = false
    @Published var lastUpdated = Date()
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    private init() {}
    
    // MARK: - Customer Tracking Setup
    
    func startTrackingForHost(_ hostId: String) {
        removeAllListeners()
        setupCustomerListeners(for: hostId)
    }
    
    func stopTracking() {
        removeAllListeners()
    }
    
    private func setupCustomerListeners(for hostId: String) {
        isLoading = true
        
        // Listen to ticket sales to identify paying customers
        let salesListener = db.collectionGroup("ticketSales")
            .whereField("hostId", isEqualTo: hostId)
            .order(by: "purchaseDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error in customer sales listener: \(error)")
                    return
                }
                
                Task {
                    await self.processCustomerSalesData(snapshot?.documents ?? [])
                }
            }
        
        // Listen to RSVPs to get confirmed attendees
        let rsvpListener = db.collectionGroup("rsvps")
            .whereField("hostId", isEqualTo: hostId)
            .whereField("status", isEqualTo: "confirmed")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error in customer RSVP listener: \(error)")
                    return
                }
                
                Task {
                    await self.processCustomerRSVPData(snapshot?.documents ?? [])
                }
            }
        
        listeners.append(salesListener)
        listeners.append(rsvpListener)
    }
    
    private func processCustomerSalesData(_ documents: [QueryDocumentSnapshot]) async {
        var customerMap: [String: PayingCustomer] = [:]
        
        for document in documents {
            let data = document.data()
            
            guard let buyerId = data["buyerId"] as? String,
                  let buyerName = data["buyerName"] as? String,
                  let buyerEmail = data["buyerEmail"] as? String,
                  let eventName = data["eventName"] as? String,
                  let eventId = data["eventId"] as? String,
                  let ticketPrice = data["ticketPrice"] as? Double,
                  let quantity = data["quantity"] as? Int,
                  let purchaseDate = data["purchaseDate"] as? Timestamp else {
                continue
            }
            
            let totalAmount = ticketPrice * Double(quantity)
            let date = purchaseDate.dateValue()
            
            // Get user demographics
            let userDemo = await getUserDemographics(userId: buyerId)
            
            let purchase = PurchaseDetail(
                id: document.documentID,
                eventName: eventName,
                eventId: eventId,
                ticketType: data["ticketType"] as? String ?? "General",
                quantity: quantity,
                unitPrice: ticketPrice,
                totalAmount: totalAmount,
                purchaseDate: date,
                status: data["status"] as? String ?? "completed"
            )
            
            if var customer = customerMap[buyerId] {
                // Update existing customer
                customer = PayingCustomer(
                    id: customer.id,
                    userId: customer.userId,
                    name: customer.name,
                    email: customer.email,
                    totalSpent: customer.totalSpent + totalAmount,
                    totalTicketsPurchased: customer.totalTicketsPurchased + quantity,
                    eventsAttended: customer.eventsAttended + 1,
                    firstPurchaseDate: min(customer.firstPurchaseDate, date),
                    lastPurchaseDate: max(customer.lastPurchaseDate, date),
                    averageTicketPrice: (customer.totalSpent + totalAmount) / Double(customer.totalTicketsPurchased + quantity),
                    preferredEventTypes: customer.preferredEventTypes,
                    rsvpStatus: customer.rsvpStatus,
                    age: customer.age,
                    gender: customer.gender,
                    location: customer.location,
                    purchases: customer.purchases + [purchase],
                    rsvps: customer.rsvps
                )
                customerMap[buyerId] = customer
            } else {
                // Create new customer
                let customer = PayingCustomer(
                    id: buyerId,
                    userId: buyerId,
                    name: buyerName,
                    email: buyerEmail,
                    totalSpent: totalAmount,
                    totalTicketsPurchased: quantity,
                    eventsAttended: 1,
                    firstPurchaseDate: date,
                    lastPurchaseDate: date,
                    averageTicketPrice: ticketPrice,
                    preferredEventTypes: [],
                    rsvpStatus: "confirmed",
                    age: userDemo.age,
                    gender: userDemo.gender,
                    location: userDemo.location,
                    purchases: [purchase],
                    rsvps: []
                )
                customerMap[buyerId] = customer
            }
        }
        
        await updateCustomerAnalytics(Array(customerMap.values))
    }
    
    private func processCustomerRSVPData(_ documents: [QueryDocumentSnapshot]) async {
        var rsvpCustomers: [String: PayingCustomer] = [:]
        
        for document in documents {
            let data = document.data()
            
            guard let userId = data["userId"] as? String,
                  let guestName = data["guestName"] as? String,
                  let guestEmail = data["guestEmail"] as? String,
                  let eventName = data["eventName"] as? String,
                  let rsvpDate = data["rsvpDate"] as? Timestamp else {
                continue
            }
            
            // Only include RSVPs from users who haven't purchased tickets (non-paying but confirmed attendees)
            if !payingCustomers.contains(where: { $0.userId == userId }) {
                let userDemo = await getUserDemographics(userId: userId)
                
                let rsvp = RSVPDetail(
                    id: document.documentID,
                    eventName: eventName,
                    guestName: guestName,
                    guestEmail: guestEmail,
                    status: "confirmed",
                    rsvpDate: rsvpDate.dateValue(),
                    partySize: data["partySize"] as? Int ?? 1,
                    specialRequests: data["specialRequests"] as? String ?? ""
                )
                
                let customer = PayingCustomer(
                    id: userId,
                    userId: userId,
                    name: guestName,
                    email: guestEmail,
                    totalSpent: 0, // No purchases yet
                    totalTicketsPurchased: 0,
                    eventsAttended: 1,
                    firstPurchaseDate: rsvpDate.dateValue(),
                    lastPurchaseDate: rsvpDate.dateValue(),
                    averageTicketPrice: 0,
                    preferredEventTypes: [],
                    rsvpStatus: "confirmed",
                    age: userDemo.age,
                    gender: userDemo.gender,
                    location: userDemo.location,
                    purchases: [],
                    rsvps: [rsvp]
                )
                
                rsvpCustomers[userId] = customer
            }
        }
        
        // Merge RSVP customers with paying customers
        let allCustomers = payingCustomers + Array(rsvpCustomers.values)
        await updateCustomerAnalytics(allCustomers)
    }
    
    private func updateCustomerAnalytics(_ customers: [PayingCustomer]) async {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        
        let newThisWeek = customers.filter { $0.firstPurchaseDate >= weekAgo }
        let newThisMonth = customers.filter { $0.firstPurchaseDate >= monthAgo }
        let topSpenders = customers.sorted { $0.totalSpent > $1.totalSpent }.prefix(10)
        
        // Calculate customer segments
        let segments = CustomerValue.allCases.map { value in
            let segmentCustomers = customers.filter { $0.customerValue == value }
            return CustomerSegment(
                name: value.rawValue,
                customers: segmentCustomers,
                totalRevenue: segmentCustomers.reduce(0) { $0 + $1.totalSpent },
                averageSpent: segmentCustomers.isEmpty ? 0 : segmentCustomers.reduce(0) { $0 + $1.totalSpent } / Double(segmentCustomers.count),
                count: segmentCustomers.count
            )
        }
        
        let totalRevenue = customers.reduce(0) { $0 + $1.totalSpent }
        let averageValue = customers.isEmpty ? 0 : totalRevenue / Double(customers.count)
        
        await MainActor.run {
            self.payingCustomers = customers
            self.newCustomersThisWeek = newThisWeek
            self.newCustomersThisMonth = newThisMonth
            self.topCustomers = Array(topSpenders)
            self.customerSegments = segments
            
            self.totalUniqueCustomers = customers.count
            self.totalCustomerRevenue = totalRevenue
            self.averageCustomerValue = averageValue
            self.customerRetentionRate = calculateRetentionRate(customers)
            self.newCustomerGrowthRate = calculateGrowthRate(newThisMonth, customers)
            
            self.isLoading = false
            self.lastUpdated = Date()
            
            print("✅ Customer analytics updated: \(customers.count) customers, $\(totalRevenue) revenue")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getUserDemographics(userId: String) async -> (age: Int?, gender: String?, location: String?) {
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let data = userDoc.data() ?? [:]
            
            return (
                age: data["age"] as? Int,
                gender: data["gender"] as? String,
                location: data["location"] as? String
            )
        } catch {
            print("❌ Error getting user demographics: \(error)")
            return (nil, nil, nil)
        }
    }
    
    private func calculateRetentionRate(_ customers: [PayingCustomer]) -> Double {
        let repeatCustomers = customers.filter { $0.eventsAttended > 1 }.count
        return customers.isEmpty ? 0 : (Double(repeatCustomers) / Double(customers.count)) * 100
    }
    
    private func calculateGrowthRate(_ newCustomers: [PayingCustomer], _ allCustomers: [PayingCustomer]) -> Double {
        let totalNew = newCustomers.count
        let total = allCustomers.count
        return total > 0 ? (Double(totalNew) / Double(total)) * 100 : 0
    }
    
    private func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Public Methods
    
    func getCustomersForTimeframe(_ timeframe: HostAnalyticsService.Timeframe) -> [PayingCustomer] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch timeframe {
        case .today:
            startDate = calendar.startOfDay(for: now)
        case .thisWeek:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .thisMonth:
            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .last3Months:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        }
        
        return payingCustomers.filter { $0.firstPurchaseDate >= startDate }
    }
    
    func getRevenueForTimeframe(_ timeframe: HostAnalyticsService.Timeframe) -> Double {
        return getCustomersForTimeframe(timeframe).reduce(0) { $0 + $1.totalSpent }
    }
} 