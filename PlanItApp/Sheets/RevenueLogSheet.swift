import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Revenue Log Sheet
struct RevenueLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analyticsService = HostAnalyticsService.shared
    @State private var selectedTimeframe: HostAnalyticsService.Timeframe = .thisMonth
    
    private var filteredSales: [TicketSaleDetail] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch selectedTimeframe {
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
        
        return analyticsService.recentTicketSales.filter { $0.purchaseDate >= startDate }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.green.opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.top, 40) // Push header down for visibility
                    
                    if analyticsService.recentTicketSales.isEmpty {
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
                Button("Done") {
                    dismiss()
                }
                .font(.inter(16, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Total Revenue")
                        .font(.inter(20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("from ticket sales")
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
            
            // Current Value Display
            VStack(spacing: 8) {
                Text("$\(String(format: "%.2f", analyticsService.totalRevenue))")
                    .font(.inter(36, weight: .bold))
                    .foregroundColor(.green)
                
                Text("Total revenue from all sales")
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.green.opacity(0.8))
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
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Revenue Data")
                .font(.inter(24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Ticket sales will appear here when customers purchase tickets for your events.")
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
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
                
                Text("Recent Transactions")
                    .font(.inter(16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(filteredSales.count) transactions")
                    .font(.inter(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredSales.sorted { $0.purchaseDate > $1.purchaseDate }) { sale in
                        EnhancedRevenueTransactionRow(sale: sale)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .padding(.top, 10)
        .onAppear {
            if let userId = Auth.auth().currentUser?.uid {
                analyticsService.startTracking(for: userId)
            }
        }
    }
}

// MARK: - Enhanced Revenue Transaction Row
struct EnhancedRevenueTransactionRow: View {
    let sale: TicketSaleDetail
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Sale icon
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                )
            
            // Sale details
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(sale.buyerName)
                        .font(.inter(14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", sale.totalAmount))")
                        .font(.inter(16, weight: .bold))
                        .foregroundColor(.green)
                }
                
                Text(sale.eventName)
                    .font(.inter(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                
                HStack {
                    Text("\(sale.quantity)x \(sale.ticketType)")
                        .font(.inter(11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(formatRelativeDate(sale.purchaseDate))
                        .font(.inter(11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text(sale.status)
                        .font(.inter(10, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    RevenueLogSheet()
} 