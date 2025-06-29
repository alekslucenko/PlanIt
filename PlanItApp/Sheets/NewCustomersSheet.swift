import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - New Customers Sheet
struct NewCustomersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customerService = CustomerAnalyticsService.shared
    @State private var selectedTimeframe: HostAnalyticsService.Timeframe = .thisMonth
    
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
                        .padding(.top, 40) // Push header down for visibility
                    
                    if customerService.newCustomersThisMonth.isEmpty {
                        emptyStateSection
                    } else {
                        contentSection
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                // Futuristic close button
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("New Customers")
                        .font(.inter(20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("paying customers & RSVPs")
                        .font(.inter(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Spacer to balance the layout (replaces export button)
                Color.clear.frame(width: 32, height: 32)
            }
            
            // Current Value Display
            VStack(spacing: 8) {
                Text("\(customerService.getCustomersForTimeframe(selectedTimeframe).count)")
                    .font(.inter(36, weight: .bold))
                    .foregroundColor(.blue)
                
                Text("+\(customerService.getCustomersForTimeframe(selectedTimeframe).count) this \(selectedTimeframe.rawValue.lowercased())")
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.blue.opacity(0.8))
            }
            
            // Timeframe selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HostAnalyticsService.Timeframe.allCases, id: \.self) { timeframe in
                        Button(timeframe.rawValue) {
                            selectedTimeframe = timeframe
                        }
                        .font(.inter(11, weight: .medium))
                        .foregroundColor(selectedTimeframe == timeframe ? .black : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTimeframe == timeframe ? .white : Color.white.opacity(0.1))
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No New Customers")
                .font(.inter(24, weight: .bold))
                .foregroundColor(.white)
            
            Text("New customer data will appear here when users RSVP or purchase tickets to your events.")
                .font(.inter(14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("New Customers")
                    .font(.inter(16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(customerService.getCustomersForTimeframe(selectedTimeframe).count) customers")
                    .font(.inter(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(customerService.getCustomersForTimeframe(selectedTimeframe)) { customer in
                        EnhancedCustomerRow(customer: customer)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .padding(.top, 10)
        .onAppear {
            if let userId = Auth.auth().currentUser?.uid {
                customerService.startTrackingForHost(userId)
            }
        }
    }
}

// MARK: - Enhanced Customer Row
struct EnhancedCustomerRow: View {
    let customer: CustomerAnalyticsService.PayingCustomer
    
    var body: some View {
        HStack(spacing: 12) {
            // Customer Avatar
            Circle()
                .fill(customer.customerValue.color.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(customer.name.prefix(1).uppercased()))
                        .font(.inter(16, weight: .bold))
                        .foregroundColor(customer.customerValue.color)
                )
            
            // Customer Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(customer.name)
                        .font(.inter(14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if customer.isNewCustomer {
                        Text("NEW")
                            .font(.inter(8, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.2))
                            )
                    }
                }
                
                Text(customer.email)
                    .font(.inter(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                HStack {
                    Text("\(customer.totalTicketsPurchased) tickets")
                        .font(.inter(10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("\(customer.eventsAttended) events")
                        .font(.inter(10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Amount Spent & Customer Value
            VStack(alignment: .trailing, spacing: 2) {
                if customer.totalSpent > 0 {
                    Text("$\(String(format: "%.0f", customer.totalSpent))")
                        .font(.inter(14, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("total spent")
                        .font(.inter(9, weight: .medium))
                        .foregroundColor(.green.opacity(0.7))
                } else {
                    Text("RSVP Only")
                        .font(.inter(12, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text("no purchase")
                        .font(.inter(9, weight: .medium))
                        .foregroundColor(.blue.opacity(0.7))
                }
                
                Text(customer.customerValue.rawValue)
                    .font(.inter(8, weight: .semibold))
                    .foregroundColor(customer.customerValue.color)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(customer.customerValue.color.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(customer.customerValue.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    NewCustomersSheet()
} 