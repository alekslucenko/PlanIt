import Foundation
import FirebaseFirestore

// MARK: - Ticket Sale Model
struct TicketSale: Identifiable, Codable {
    @DocumentID var id: String?
    let customerName: String
    let customerId: String
    let partyName: String // Use partyName instead of eventName for consistency
    let partyId: String   // Use partyId instead of eventId for consistency
    let hostId: String
    let amount: Double
    let ticketCount: Int
    let ticketTierName: String
    let paymentMethod: String
    let timestamp: Date
    let status: SaleStatus
    
    enum SaleStatus: String, Codable {
        case completed = "completed"
        case pending = "pending"
        case refunded = "refunded"
        case failed = "failed"
    }
    
    init(
        customerName: String,
        customerId: String,
        partyName: String,
        partyId: String,
        hostId: String,
        amount: Double,
        ticketCount: Int,
        ticketTierName: String,
        paymentMethod: String,
        timestamp: Date,
        status: SaleStatus
    ) {
        self.customerName = customerName
        self.customerId = customerId
        self.partyName = partyName
        self.partyId = partyId
        self.hostId = hostId
        self.amount = amount
        self.ticketCount = ticketCount
        self.ticketTierName = ticketTierName
        self.paymentMethod = paymentMethod
        self.timestamp = timestamp
        self.status = status
    }
    
    // Mock data for development
    static let mockSales: [TicketSale] = [
        TicketSale(
            customerName: "Alex Johnson",
            customerId: "user123",
            partyName: "Summer Pool Party",
            partyId: "party123",
            hostId: "host123",
            amount: 89.99,
            ticketCount: 2,
            ticketTierName: "VIP Access",
            paymentMethod: "credit_card",
            timestamp: Date().addingTimeInterval(-86400), // 1 day ago
            status: .completed
        ),
        TicketSale(
            customerName: "Sarah Wilson",
            customerId: "user456",
            partyName: "Rooftop Dinner Party",
            partyId: "party456",
            hostId: "host123",
            amount: 45.00,
            ticketCount: 1,
            ticketTierName: "General Admission",
            paymentMethod: "apple_pay",
            timestamp: Date().addingTimeInterval(-172800), // 2 days ago
            status: .completed
        ),
        TicketSale(
            customerName: "Mike Chen",
            customerId: "user789",
            partyName: "Game Night",
            partyId: "party789",
            hostId: "host123",
            amount: 25.00,
            ticketCount: 1,
            ticketTierName: "Standard",
            paymentMethod: "paypal",
            timestamp: Date().addingTimeInterval(-259200), // 3 days ago
            status: .completed
        )
    ]
} 