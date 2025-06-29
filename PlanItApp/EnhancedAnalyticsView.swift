import SwiftUI
import Firebase
import FirebaseAuth

struct EnhancedAnalyticsView: View {
    @StateObject private var clickTracker = ClickTrackingService.shared
    @StateObject private var customerService = CustomerAnalyticsService.shared
    @StateObject private var analyticsService = HostAnalyticsService.shared
    @State private var selectedTimeframe: HostAnalyticsService.Timeframe = .thisMonth
    @State private var showingCustomerSheet = false
    @State private var showingRevenueSheet = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Key metrics
                    keyMetricsSection
                    
                    // Event performance ranking
                    eventRankingSection
                    
                    // Quick actions
                    quickActionsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingCustomerSheet) {
            EnhancedCustomersSheet()
        }
        .sheet(isPresented: $showingRevenueSheet) {
            EnhancedRevenueSheet()
        }
        .onAppear {
            if let userId = Auth.auth().currentUser?.uid {
                clickTracker.startTrackingForHost(userId)
                customerService.startTrackingForHost(userId)
                analyticsService.startTracking(for: userId)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Business Analytics")
                .font(.inter(28, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Real-time insights into your events performance")
                .font(.inter(14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Timeframe selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HostAnalyticsService.Timeframe.allCases, id: \.self) { timeframe in
                        Button(timeframe.rawValue) {
                            selectedTimeframe = timeframe
                        }
                        .font(.inter(12, weight: .medium))
                        .foregroundColor(selectedTimeframe == timeframe ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTimeframe == timeframe ? .white : Color.white.opacity(0.1))
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var keyMetricsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                MetricCard(
                    title: "Total Clicks",
                    value: "\(clickTracker.totalClicksAllEvents)",
                    subtitle: "All events",
                    color: .blue,
                    icon: "hand.tap.fill"
                )
                
                MetricCard(
                    title: "Customers",
                    value: "\(customerService.totalUniqueCustomers)",
                    subtitle: "Paying customers",
                    color: .green,
                    icon: "person.2.fill"
                )
            }
            
            HStack(spacing: 16) {
                MetricCard(
                    title: "Revenue",
                    value: "$\(formatCurrency(customerService.totalCustomerRevenue))",
                    subtitle: "Total earnings",
                    color: .orange,
                    icon: "dollarsign.circle.fill"
                )
                
                MetricCard(
                    title: "Conversion",
                    value: "\(String(format: "%.1f", clickTracker.demographicInsights.conversionRate))%",
                    subtitle: "Click to purchase",
                    color: .purple,
                    icon: "chart.bar.fill"
                )
            }
        }
    }
    
    private var eventRankingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Performing Events")
                .font(.inter(18, weight: .bold))
                .foregroundColor(.white)
            
            let rankedEvents = clickTracker.getClickAnalyticsForTimeframe(selectedTimeframe)
            
            if !rankedEvents.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(Array(rankedEvents.prefix(5).enumerated()), id: \.element.id) { index, event in
                        EventRankingRow(event: event, rank: index + 1)
                    }
                }
            } else {
                VStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("No event data available for this timeframe")
                        .font(.inter(14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(height: 120)
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Text("Detailed Analytics")
                .font(.inter(18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                ActionButton(
                    title: "View Customers",
                    subtitle: "Customer details & demographics",
                    icon: "person.3.fill",
                    color: .blue
                ) {
                    showingCustomerSheet = true
                }
                
                ActionButton(
                    title: "Revenue Details",
                    subtitle: "Sales breakdown & trends",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                ) {
                    showingRevenueSheet = true
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.1fk", amount / 1000)
        }
        return String(format: "%.0f", amount)
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.inter(18, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.inter(11, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.inter(9, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EventRankingRow: View {
    let event: ClickTrackingService.EventClickAnalytics
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(.inter(16, weight: .bold))
                .foregroundColor(rankColor)
                .frame(width: 32)
            
            // Event info
            VStack(alignment: .leading, spacing: 2) {
                Text(event.partyTitle)
                    .font(.inter(14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    Text("\(event.totalClicks) clicks")
                        .font(.inter(11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("\(event.uniqueUsers) users")
                        .font(.inter(11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Metrics
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", event.conversionRate))%")
                    .font(.inter(12, weight: .bold))
                    .foregroundColor(.green)
                
                Text("conversion")
                    .font(.inter(9, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(rankColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.inter(14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.inter(11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// Add the sheet files
struct EnhancedCustomersSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    Text("Customer Analytics")
                        .font(.inter(24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Detailed customer analytics coming soon...")
                        .font(.inter(16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct EnhancedRevenueSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    Text("Revenue Analytics")
                        .font(.inter(24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Detailed revenue analytics coming soon...")
                        .font(.inter(16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
} 