import SwiftUI
import Charts
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct BusinessDashboardView: View {
    @StateObject private var analyticsService = HostAnalyticsService.shared
    @StateObject private var firestoreService = FirestoreService()
    @StateObject private var clickService = ClickTrackingService.shared
    @State private var selectedTimeframe = "Today"
    @State private var selectedMetric: MetricType? = nil
    @State private var showingMetricDetail = false
    @State private var currentTime = Date()
    
    let timeframes = ["Today", "This Week", "Last 30 Days", "Last 3 Months"]
    
    var body: some View {
        ZStack {
            // Pure black background like MagicPath
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section with more spacing from top
                    headerSection
                        .padding(.top, 60) // Push down to avoid safe area issues
                    
                    // Metrics Grid Section - Made smaller  
                    metricsGridSection
                        .padding(.top, 20)
                    
                    // Professional Detail Cards Section
                    detailCardsSection
                        .padding(.top, 30)
                    
                    // Chart Section (Interactive and scrollable)
                    chartSection
                        .padding(.top, 30)
                        .padding(.bottom, 120) // Space for bottom navigation
                }
            }
            .refreshable {
                await analyticsService.refreshData()
                firestoreService.fetchData(for: selectedTimeframe)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startTimeUpdater()
            firestoreService.fetchData(for: selectedTimeframe)
            
            // Start analytics tracking
            if let userId = Auth.auth().currentUser?.uid {
                analyticsService.startTracking(for: userId)
                // Start click analytics real-time listener for this host
                clickService.startTrackingForHost(userId)
            }
        }
        .onChange(of: selectedTimeframe) { newValue in
            firestoreService.fetchData(for: newValue)
        }
        .sheet(isPresented: $showingMetricDetail) {
            if let metric = selectedMetric {
                ProfessionalMetricDetailView(
                    metric: metric,
                    analyticsService: analyticsService,
                    firestoreService: firestoreService
                )
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Top Header with Inter Bold font
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Party Analytics")
                        .font(.inter(28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Real-time insights powered by Firebase")
                        .font(.inter(14, weight: .medium))
                        .foregroundColor(Color(.systemGray2))
                }
                
                Spacer()
                
                TimeframeDropdownView(selectedTimeframe: $selectedTimeframe, timeframes: timeframes)
            }
            
            // Status Indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(analyticsService.hasError ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                
                Text(analyticsService.hasError ? "Connection Error" : "Live Data")
                    .font(.inter(14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("•")
                    .font(.inter(14, weight: .regular))
                    .foregroundColor(Color(.systemGray3))
                
                Text("Updated \(formatTime(analyticsService.lastUpdated))")
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
                
                Spacer()
                
                if analyticsService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5).opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(Color.black)
    }
    
    private var metricsGridSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(MetricType.allCases, id: \.self) { metric in
                ProfessionalMetricCardView(
                    metric: metric,
                    data: getMetricData(for: metric),
                    onTap: {
                        selectedMetric = metric
                        showingMetricDetail = true
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .background(Color.black)
    }
    
    private var detailCardsSection: some View {
        VStack(spacing: 16) {
            // Recent Activity Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Activity")
                        .font(.inter(20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("View All") {
                        // Show full activity log
                    }
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.blue)
                }
                
                LazyVStack(spacing: 8) {
                    ForEach(analyticsService.recentRSVPs.prefix(3), id: \.id) { rsvp in
                        RecentActivityRow(
                            title: "New RSVP",
                            subtitle: "\(rsvp.guestName) confirmed for \(rsvp.eventName)",
                            time: rsvp.rsvpDate,
                            icon: "person.badge.plus",
                            iconColor: .green
                        )
                    }
                    
                    ForEach(analyticsService.recentTicketSales.prefix(3), id: \.id) { sale in
                        RecentActivityRow(
                            title: "Ticket Sale",
                            subtitle: "\(sale.buyerName) purchased \(sale.quantity) ticket(s) for \(sale.eventName)",
                            time: sale.purchaseDate,
                            icon: "creditcard",
                            iconColor: .orange
                        )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
                    )
            )
            
            // Top Performing Events Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Most Clicked Events")
                        .font(.inter(20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("View All") {
                        selectedMetric = .clicks
                        showingMetricDetail = true
                    }
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.blue)
                }
                
                LazyVStack(spacing: 8) {
                    ForEach(clickService.eventClickAnalytics.prefix(3)) { analytics in
                        MostClickedEventRow(analytics: analytics)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 16)
    }
    
    private var chartSection: some View {
        VStack(spacing: 0) {
            ChartSectionView(firestoreService: firestoreService)
                .padding(.horizontal, 16)
        }
        .background(Color.black)
    }
    
    // MARK: - Helper Methods
    
    private func getMetricData(for metric: MetricType) -> MetricData {
        let isLoading = analyticsService.isLoading || firestoreService.isLoading
        let hasError = analyticsService.hasError || firestoreService.hasError
        
        switch metric {
        case .revenue:
            return MetricData(
                value: formatCurrency(analyticsService.totalRevenue),
                trend: "+\(formatCurrency(analyticsService.todayRevenue)) today",
                isLoading: isLoading,
                hasError: hasError
            )
        case .customers:
            return MetricData(
                value: "\(analyticsService.uniqueCustomers)",
                trend: "+\(analyticsService.newCustomersToday) today",
                isLoading: isLoading,
                hasError: hasError
            )
        case .events:
            return MetricData(
                value: "\(analyticsService.activeEvents)",
                trend: "\(analyticsService.soldOutEvents) sold out",
                isLoading: isLoading,
                hasError: hasError
            )
        case .attendees:
            return MetricData(
                value: "\(analyticsService.confirmedRSVPs)",
                trend: "+\(analyticsService.todayRSVPs) today",
                isLoading: isLoading,
                hasError: hasError
            )
        case .conversion:
            return MetricData(
                value: "\(Int(analyticsService.conversionRate))%",
                trend: "\(analyticsService.totalViews) views",
                isLoading: isLoading,
                hasError: hasError
            )
        case .clicks:
            return MetricData(
                value: "\(analyticsService.totalClicks)",
                trend: "\(analyticsService.totalViews) impressions",
                isLoading: isLoading,
                hasError: hasError
            )
        }
    }
    
    private func startTimeUpdater() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        
        if amount >= 1000 {
            return formatter.string(from: NSNumber(value: amount / 1000)) ?? "$0" + "k"
        }
        
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Professional Metric Card View
struct ProfessionalMetricCardView: View {
    let metric: MetricType
    let data: MetricData
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon and value section
                VStack(spacing: 8) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(metric.iconColor)
                    
                    // Value with Inter Bold
                    if data.isLoading {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5).opacity(0.3))
                            .frame(width: 60, height: 24)
                            .shimmer()
                    } else {
                        Text(data.value)
                            .font(.inter(24, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                
                // Title and trend
                VStack(spacing: 4) {
                    Text(metric.title)
                        .font(.inter(14, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Text(data.trend)
                        .font(.inter(11, weight: .medium))
                        .foregroundColor(data.hasError ? .red : Color(.systemGray3))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 55/255, green: 65/255, blue: 81/255).opacity(0.6),
                                Color(red: 31/255, green: 41/255, blue: 55/255).opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(.systemGray5).opacity(0.3),
                                        Color(.systemGray6).opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(0.25),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Supporting Views

struct RecentActivityRow: View {
    let title: String
    let subtitle: String
    let time: Date
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.inter(14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.inter(12, weight: .regular))
                    .foregroundColor(Color(.systemGray2))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(timeAgoString(from: time))
                .font(.inter(11, weight: .medium))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.vertical, 8)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }
}

struct TopEventRow: View {
    let event: EventPerformance
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.eventName)
                    .font(.inter(14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(event.currentAttendees)/\(event.capacity) attendees")
                    .font(.inter(12, weight: .regular))
                    .foregroundColor(Color(.systemGray2))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(event.occupancyRate))%")
                    .font(.inter(14, weight: .bold))
                    .foregroundColor(event.occupancyRate >= 90 ? .green : .orange)
                
                Text("capacity")
                    .font(.inter(11, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
        }
        .padding(.vertical, 8)
    }
}

struct MostClickedEventRow: View {
    let analytics: EventClickAnalytics
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(analytics.partyTitle)
                    .font(.inter(14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(analytics.totalClicks) clicks")
                    .font(.inter(12, weight: .regular))
                    .foregroundColor(Color(.systemGray2))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(analytics.conversionRate))%")
                    .font(.inter(14, weight: .bold))
                    .foregroundColor(analytics.conversionRate >= 90 ? .green : .orange)
                
                Text("conversion")
                    .font(.inter(11, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    BusinessDashboardView()
        .preferredColorScheme(.dark)
} 