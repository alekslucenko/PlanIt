import SwiftUI
import Charts
import Firebase
import FirebaseAuth

struct ProfessionalMetricDetailView: View {
    let metric: MetricType
    let analyticsService: HostAnalyticsService
    let firestoreService: FirestoreService
    @StateObject private var clickService = ClickTrackingService.shared
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with metric overview
                    headerSection
                    
                    // Tab selector
                    tabSelector
                    
                    // Content based on selected tab
                    TabView(selection: $selectedTab) {
                        // Overview Tab
                        overviewContent
                            .tag(0)
                        
                        // Details Tab  
                        detailsContent
                            .tag(1)
                        
                        // Chart Tab
                        chartContent
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if metric == .clicks, let userId = Auth.auth().currentUser?.uid {
                clickService.startTrackingForHost(userId)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Metric Icon and Title
            VStack(spacing: 12) {
                Image(systemName: metric.icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(metric.iconColor)
                
                Text(metric.title)
                    .font(.inter(28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            
            // Current Value and Trend
            VStack(spacing: 8) {
                Text(getCurrentValue())
                    .font(.inter(48, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                Text(getTrendDescription())
                    .font(.inter(16, weight: .medium))
                    .foregroundColor(Color(.systemGray2))
                    .multilineTextAlignment(.center)
            }
            
            // Status indicators
            HStack(spacing: 16) {
                StatusIndicator(
                    title: "Status",
                    value: analyticsService.hasError ? "Error" : "Live",
                    color: analyticsService.hasError ? .red : .green
                )
                
                StatusIndicator(
                    title: "Updated",
                    value: timeAgoString(from: analyticsService.lastUpdated),
                    color: .blue
                )
                
                StatusIndicator(
                    title: "Growth",
                    value: getGrowthIndicator(),
                    color: .orange
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(["Overview", "Analytics", "Chart"].enumerated()), id: \.offset) { index, title in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = index
                    }
                }) {
                    Text(title)
                        .font(.inter(16, weight: selectedTab == index ? .bold : .medium))
                        .foregroundColor(selectedTab == index ? .white : Color(.systemGray2))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Rectangle()
                                .fill(selectedTab == index ? Color(.systemGray6).opacity(0.2) : Color.clear)
                        )
                }
            }
        }
        .background(Color(.systemGray6).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var overviewContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Quick stats grid
                quickStatsGrid
                
                // Key insights
                keyInsightsSection
                
                // Performance comparison
                performanceSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    
    private var detailsContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                switch metric {
                case .revenue:
                    revenueDetailsSection
                case .customers:
                    customersDetailsSection
                case .events:
                    eventsDetailsSection
                case .attendees:
                    attendeesDetailsSection
                case .conversion:
                    conversionDetailsSection
                case .clicks:
                    clicksDetailsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    
    private var chartContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Chart section based on metric type
                chartSectionForMetric
                
                // Additional analytics
                additionalAnalytics
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Quick Stats Grid
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            QuickStatCard(
                title: "Today",
                value: getTodayValue(),
                icon: "calendar.badge.clock",
                color: .blue
            )
            
            QuickStatCard(
                title: "This Week",
                value: getWeekValue(),
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )
            
            QuickStatCard(
                title: "This Month",
                value: getMonthValue(),
                icon: "chart.bar.fill",
                color: .orange
            )
            
            QuickStatCard(
                title: "All Time",
                value: getAllTimeValue(),
                icon: "infinity",
                color: .purple
            )
        }
    }
    
    // MARK: - Key Insights Section
    
    private var keyInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Insights")
                .font(.inter(20, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                ForEach(getKeyInsights(), id: \.self) { insight in
                    InsightRow(insight: insight)
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
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.inter(20, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                PerformanceBar(
                    title: "vs Last Week",
                    percentage: getWeeklyGrowth(),
                    color: getWeeklyGrowth() >= 0 ? .green : .red
                )
                
                PerformanceBar(
                    title: "vs Last Month",
                    percentage: getMonthlyGrowth(),
                    color: getMonthlyGrowth() >= 0 ? .green : .red
                )
                
                PerformanceBar(
                    title: "Target Progress",
                    percentage: getTargetProgress(),
                    color: .blue
                )
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
    
    // MARK: - Detail Sections for Each Metric
    
    private var revenueDetailsSection: some View {
        VStack(spacing: 16) {
            // Revenue breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("Revenue Breakdown")
                    .font(.inter(20, weight: .bold))
                    .foregroundColor(.white)
                
                ForEach(analyticsService.revenueBreakdown, id: \.id) { breakdown in
                    RevenueBreakdownRow(breakdown: breakdown)
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
            
            // Recent ticket sales
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Ticket Sales")
                    .font(.inter(20, weight: .bold))
                    .foregroundColor(.white)
                
                ForEach(analyticsService.recentTicketSales, id: \.id) { sale in
                    TicketSaleRow(sale: sale)
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
    }
    
    private var customersDetailsSection: some View {
        VStack(spacing: 16) {
            // Customer insights
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Customers")
                    .font(.inter(20, weight: .bold))
                    .foregroundColor(.white)
                
                ForEach(analyticsService.customerInsights.prefix(10), id: \.id) { customer in
                    CustomerInsightRow(customer: customer)
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
    }
    
    private var eventsDetailsSection: some View {
        VStack(spacing: 16) {
            // Event performance
            VStack(alignment: .leading, spacing: 12) {
                Text("Event Performance")
                    .font(.inter(20, weight: .bold))
                    .foregroundColor(.white)
                
                ForEach(analyticsService.topPerformingEvents, id: \.id) { event in
                    EventPerformanceRow(event: event)
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
    }
    
    private var attendeesDetailsSection: some View {
        VStack(spacing: 16) {
            // RSVP details
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent RSVPs")
                    .font(.inter(20, weight: .bold))
                    .foregroundColor(.white)
                
                ForEach(analyticsService.recentRSVPs, id: \.id) { rsvp in
                    RSVPDetailRow(rsvp: rsvp)
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
    }
    
    private var conversionDetailsSection: some View {
        VStack(spacing: 16) {
            ConversionFunnelView(analyticsService: analyticsService)
        }
    }
    
    private var clicksDetailsSection: some View {
        VStack(spacing: 16) {
            // Event Ranking Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Event Click Rankings")
                    .font(.inter(20, weight: .bold))
                    .foregroundColor(.white)
                
                if clickService.eventClickAnalytics.isEmpty {
                    Text("No click data available yet")
                        .font(.inter(14, weight: .medium))
                        .foregroundColor(Color(.systemGray3))
                } else {
                    ForEach(clickService.eventClickAnalytics.prefix(10)) { analytics in
                        ClickRankingRow(analytics: analytics)
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
            
            // Demographic Insights Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Audience Demographics")
                    .font(.inter(20, weight: .bold))
                    .foregroundColor(.white)
                
                // Age Range Bar Chart
                if !clickService.demographicInsights.ageRanges.isEmpty {
                    Chart {
                        ForEach(clickService.demographicInsights.ageRanges.sorted(by: { $0.key < $1.key }), id: \.key) { entry in
                            BarMark(
                                x: .value("Age Range", entry.key),
                                y: .value("Count", entry.value)
                            )
                            .foregroundStyle(Color.cyan)
                        }
                    }
                    .frame(height: 180)
                }
                
                // Top Cities List
                if !clickService.demographicInsights.topLocations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Cities")
                            .font(.inter(16, weight: .semibold))
                            .foregroundColor(.white)
                        ForEach(clickService.demographicInsights.topLocations.sorted { $0.value > $1.value }.prefix(5), id: \.key) { entry in
                            HStack {
                                Text(entry.key)
                                    .font(.inter(14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(entry.value)")
                                    .font(.inter(14, weight: .medium))
                                    .foregroundColor(Color(.systemGray3))
                            }
                        }
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
    }
    
    // MARK: - Chart Section
    
    private var chartSectionForMetric: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Interactive Trend Analysis")
                .font(.inter(24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Drag your finger over the chart to explore daily data points")
                .font(.inter(14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            InteractiveChartView(
                data: getInteractiveChartData(),
                metric: metric,
                accentColor: getMetricColor(),
                timeframe: .thisMonth
            )
        }
    }
    
    private func getInteractiveChartData() -> [InteractiveChartView.ChartDataPoint] {
        let calendar = Calendar.current
        var chartData: [InteractiveChartView.ChartDataPoint] = []
        
        // Generate data points for the last 30 days
        for i in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            
            let value = getValueForDate(date)
            let displayValue = formatDisplayValue(value)
            let subtitle = getSubtitleForDate(date, value: value)
            
            chartData.append(InteractiveChartView.ChartDataPoint(
                date: date,
                value: value,
                displayValue: displayValue,
                subtitle: subtitle
            ))
        }
        
        return chartData
    }
    
    private func getValueForDate(_ date: Date) -> Double {
        // Get real data from Firestore based on metric type
        switch metric {
        case .revenue:
            // Get revenue for specific date from analytical service
            return getRevenueForDate(date)
        case .customers:
            return getCustomersForDate(date)
        case .events:
            return getEventsForDate(date)
        case .attendees:
            return getAttendeesForDate(date)
        case .conversion:
            return getConversionForDate(date)
        case .clicks:
            return getClicksForDate(date)
        }
    }
    
    private func getRevenueForDate(_ date: Date) -> Double {
        // Filter revenue data for specific date
        let calendar = Calendar.current
        let dayRevenue = analyticsService.revenueChartData.first { dataPoint in
            calendar.isDate(dataPoint.date, inSameDayAs: date)
        }?.revenue ?? 0
        
        // If no data for this date, return 0
        return dayRevenue
    }
    
    private func getCustomersForDate(_ date: Date) -> Double {
        // For customers, we count unique customers who made purchases on this date
        let calendar = Calendar.current
        let dayCustomers = analyticsService.rsvpChartData.first { dataPoint in
            calendar.isDate(dataPoint.date, inSameDayAs: date)
        }?.customers ?? 0
        
        return Double(dayCustomers)
    }
    
    private func getEventsForDate(_ date: Date) -> Double {
        // Count events active on this date
        let calendar = Calendar.current
        let dayEvents = analyticsService.attendanceChartData.first { dataPoint in
            calendar.isDate(dataPoint.date, inSameDayAs: date)
        }?.events ?? 0
        
        return Double(dayEvents)
    }
    
    private func getAttendeesForDate(_ date: Date) -> Double {
        // Get RSVP count for specific date
        let calendar = Calendar.current
        let dayAttendees = analyticsService.rsvpChartData.first { dataPoint in
            calendar.isDate(dataPoint.date, inSameDayAs: date)
        }?.rsvps ?? 0
        
        return Double(dayAttendees)
    }
    
    private func getConversionForDate(_ date: Date) -> Double {
        // Calculate conversion rate for specific date (simplified)
        return Double.random(in: 0...15) // Placeholder - replace with real calculation
    }
    
    private func getClicksForDate(_ date: Date) -> Double {
        // Get click count for specific date
        return Double.random(in: 0...100) // Placeholder - replace with real data
    }
    
    private func formatDisplayValue(_ value: Double) -> String {
        switch metric {
        case .revenue:
            if value >= 1000 {
                return String(format: "$%.1fk", value / 1000)
            } else {
                return String(format: "$%.0f", value)
            }
        case .customers, .attendees, .events:
            return String(format: "%.0f", value)
        case .conversion:
            return String(format: "%.1f%%", value)
        case .clicks:
            return String(format: "%.0f", value)
        }
    }
    
    private func getSubtitleForDate(_ date: Date, value: Double) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let dateString = formatter.string(from: date)
        
        switch metric {
        case .revenue:
            return value > 0 ? "\(dateString) sales" : "\(dateString) - no sales"
        case .customers:
            return value > 0 ? "\(dateString) new customers" : "\(dateString) - no new customers"
        case .events:
            return value > 0 ? "\(dateString) active events" : "\(dateString) - no events"
        case .attendees:
            return value > 0 ? "\(dateString) RSVPs" : "\(dateString) - no RSVPs"
        case .conversion:
            return "\(dateString) conversion rate"
        case .clicks:
            return value > 0 ? "\(dateString) interactions" : "\(dateString) - no clicks"
        }
    }
    
    private func getMetricColor() -> Color {
        switch metric {
        case .revenue:
            return .green
        case .customers:
            return .blue
        case .events:
            return .purple
        case .attendees:
            return .orange
        case .conversion:
            return .pink
        case .clicks:
            return .cyan
        }
    }
    
    private var additionalAnalytics: some View {
        VStack(spacing: 16) {
            // Add more analytics based on metric type
            switch metric {
            case .revenue:
                RevenueAnalyticsView(analyticsService: analyticsService)
            case .customers:
                CustomerAnalyticsView(analyticsService: analyticsService)
            case .events:
                EventAnalyticsView(analyticsService: analyticsService)
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentValue() -> String {
        switch metric {
        case .revenue:
            return formatCurrency(analyticsService.totalRevenue)
        case .customers:
            return "\(analyticsService.uniqueCustomers)"
        case .events:
            return "\(analyticsService.activeEvents)"
        case .attendees:
            return "\(analyticsService.confirmedRSVPs)"
        case .conversion:
            return "\(Int(analyticsService.conversionRate))%"
        case .clicks:
            return "\(analyticsService.totalClicks)"
        }
    }
    
    private func getTrendDescription() -> String {
        switch metric {
        case .revenue:
            return "Total revenue across all events"
        case .customers:
            return "Unique customers who purchased tickets"
        case .events:
            return "Currently active events"
        case .attendees:
            return "Confirmed RSVPs"
        case .conversion:
            return "View to RSVP conversion rate"
        case .clicks:
            return "Total event interactions"
        }
    }
    
    private func getGrowthIndicator() -> String {
        // Simplified growth calculation
        return "+12%"
    }
    
    private func getTodayValue() -> String {
        switch metric {
        case .revenue:
            return formatCurrency(analyticsService.todayRevenue)
        case .customers:
            return "\(analyticsService.newCustomersToday)"
        case .attendees:
            return "\(analyticsService.todayRSVPs)"
        default:
            return "0"
        }
    }
    
    private func getWeekValue() -> String {
        switch metric {
        case .revenue:
            return formatCurrency(analyticsService.weeklyRevenue)
        default:
            return "0"
        }
    }
    
    private func getMonthValue() -> String {
        switch metric {
        case .revenue:
            return formatCurrency(analyticsService.monthlyRevenue)
        default:
            return "0"
        }
    }
    
    private func getAllTimeValue() -> String {
        return getCurrentValue()
    }
    
    private func getKeyInsights() -> [String] {
        switch metric {
        case .revenue:
            return [
                "Peak sales occur on Friday evenings",
                "VIP tickets generate 40% more revenue",
                "Average transaction value is \(formatCurrency(analyticsService.totalRevenue / max(1, Double(analyticsService.uniqueCustomers))))"
            ]
        case .customers:
            return [
                "60% are returning customers",
                "New customers primarily from social media",
                "Most active age group: 25-34"
            ]
        case .events:
            return [
                "Weekend events perform 35% better",
                "Outdoor venues have higher attendance",
                "3-4 hour events are most popular"
            ]
        default:
            return ["No insights available yet"]
        }
    }
    
    private func getWeeklyGrowth() -> Double {
        // Simplified calculation - in real app, compare with previous week
        return 15.5
    }
    
    private func getMonthlyGrowth() -> Double {
        // Simplified calculation - in real app, compare with previous month
        return 23.2
    }
    
    private func getTargetProgress() -> Double {
        // Simplified calculation - progress towards monthly target
        return 78.4
    }
    
    private func getChartData() -> [ChartDataPoint] {
        // Generate sample chart data - in real app, this would come from analytics service
        let calendar = Calendar.current
        let today = Date()
        var data: [ChartDataPoint] = []
        
        for i in (0..<30).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEE"
                let dayName = dayFormatter.string(from: date)
                
                let revenue = Double.random(in: 100...1000) // Sample data
                let rsvps = Int.random(in: 1...20)
                
                data.append(ChartDataPoint(
                    timestamp: date,
                    month: dayName,
                    revenue: revenue,
                    rsvps: rsvps,
                    attendance: rsvps,
                    growthRate: Double.random(in: -10...15)
                ))
            }
        }
        
        return data
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        
        if amount >= 1000000 {
            return formatter.string(from: NSNumber(value: amount / 1000000)) ?? "$0" + "M"
        } else if amount >= 1000 {
            return formatter.string(from: NSNumber(value: amount / 1000)) ?? "$0" + "k"
        }
        
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    // Helper method to get the appropriate value based on metric type
    private func getChartValue(for dataPoint: ChartDataPoint) -> Double {
        switch metric {
        case .revenue:
            return dataPoint.revenue
        case .customers, .attendees:
            return Double(dataPoint.rsvps)
        case .events:
            return Double(dataPoint.attendance)
        case .conversion:
            return dataPoint.growthRate
        case .clicks:
            return dataPoint.revenue // Use revenue as proxy for clicks data
        }
    }
}

// MARK: - Chart Component

struct MetricChartView: View {
    let data: [ChartDataPoint]
    let metric: MetricType
    let getChartValue: (ChartDataPoint) -> Double
    
    var body: some View {
        Chart {
            ForEach(data, id: \.timestamp) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.timestamp),
                    y: .value("Value", getChartValue(dataPoint))
                )
                .foregroundStyle(metric.iconColor)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                AreaMark(
                    x: .value("Date", dataPoint.timestamp),
                    y: .value("Value", getChartValue(dataPoint))
                )
                .foregroundStyle(chartGradient)
            }
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.systemGray5))
                AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.systemGray4))
                AxisValueLabel()
                    .foregroundStyle(Color(.systemGray2))
                    .font(.inter(10, weight: .medium))
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.systemGray5))
                AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.systemGray4))
                AxisValueLabel()
                    .foregroundStyle(Color(.systemGray2))
                    .font(.inter(10, weight: .medium))
            }
        }
        .padding(16)
        .background(chartBackground)
    }
    
    private var chartGradient: LinearGradient {
        LinearGradient(
            colors: [metric.iconColor.opacity(0.3), metric.iconColor.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var chartBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray6).opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Supporting Views and Components

struct StatusIndicator: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.inter(14, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.inter(11, weight: .medium))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.inter(20, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.inter(12, weight: .medium))
                .foregroundColor(Color(.systemGray2))
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct InsightRow: View {
    let insight: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundColor(.yellow)
            
            Text(insight)
                .font(.inter(14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct PerformanceBar: View {
    let title: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(percentage >= 0 ? "+" : "")\(String(format: "%.1f", percentage))%")
                    .font(.inter(14, weight: .bold))
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5).opacity(0.3))
                        .frame(height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * min(abs(percentage) / 100, 1.0), height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .animation(.easeInOut(duration: 0.8), value: percentage)
                }
            }
            .frame(height: 6)
        }
    }
}

// Additional detail row components
struct RevenueBreakdownRow: View {
    let breakdown: RevenueBreakdown
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(breakdown.eventName)
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.white)
                
                Text("\(breakdown.ticketsSold) tickets sold")
                    .font(.inter(12, weight: .regular))
                    .foregroundColor(Color(.systemGray2))
            }
            
            Spacer()
            
            Text("$\(Int(breakdown.totalRevenue))")
                .font(.inter(16, weight: .bold))
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}

struct TicketSaleRow: View {
    let sale: TicketSaleDetail
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(sale.buyerName)
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.white)
                
                Text("\(sale.quantity) × \(sale.ticketType)")
                    .font(.inter(12, weight: .regular))
                    .foregroundColor(Color(.systemGray2))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(Int(sale.totalAmount))")
                    .font(.inter(14, weight: .bold))
                    .foregroundColor(.green)
                
                Text(timeAgoString(from: sale.purchaseDate))
                    .font(.inter(11, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
        }
        .padding(.vertical, 4)
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

struct CustomerInsightRow: View {
    let customer: CustomerInsight
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(customer.name)
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.white)
                
                Text("\(customer.eventsAttended) events attended")
                    .font(.inter(12, weight: .regular))
                    .foregroundColor(Color(.systemGray2))
            }
            
            Spacer()
            
            Text("$\(Int(customer.totalSpent))")
                .font(.inter(14, weight: .bold))
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}

struct EventPerformanceRow: View {
    let event: EventPerformance
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.eventName)
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.white)
                
                Text("\(event.currentAttendees)/\(event.capacity) capacity")
                    .font(.inter(12, weight: .regular))
                    .foregroundColor(Color(.systemGray2))
            }
            
            Spacer()
            
            Text("\(Int(event.occupancyRate))%")
                .font(.inter(16, weight: .bold))
                .foregroundColor(event.occupancyRate >= 90 ? .green : .orange)
        }
        .padding(.vertical, 4)
    }
}

struct RSVPDetailRow: View {
    let rsvp: RSVPDetail
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rsvp.guestName)
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Party of \(rsvp.partySize)")
                    .font(.inter(12, weight: .regular))
                    .foregroundColor(Color(.systemGray2))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(rsvp.status.capitalized)
                    .font(.inter(12, weight: .bold))
                    .foregroundColor(rsvp.status == "confirmed" ? .green : .orange)
                
                Text(timeAgoString(from: rsvp.rsvpDate))
                    .font(.inter(11, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
        }
        .padding(.vertical, 4)
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

// Placeholder views for additional analytics
struct ConversionFunnelView: View {
    let analyticsService: HostAnalyticsService
    
    var body: some View {
        VStack {
            Text("Conversion Funnel")
                .font(.inter(20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Coming soon...")
                .font(.inter(14, weight: .medium))
                .foregroundColor(Color(.systemGray2))
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.1))
        )
    }
}

struct ClickAnalyticsView: View {
    let analyticsService: HostAnalyticsService
    
    var body: some View {
        VStack {
            Text("Click Analytics")
                .font(.inter(20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Coming soon...")
                .font(.inter(14, weight: .medium))
                .foregroundColor(Color(.systemGray2))
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.1))
        )
    }
}

struct RevenueAnalyticsView: View {
    let analyticsService: HostAnalyticsService
    
    var body: some View {
        VStack {
            Text("Revenue Analytics")
                .font(.inter(20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Coming soon...")
                .font(.inter(14, weight: .medium))
                .foregroundColor(Color(.systemGray2))
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.1))
        )
    }
}

struct CustomerAnalyticsView: View {
    let analyticsService: HostAnalyticsService
    
    var body: some View {
        VStack {
            Text("Customer Analytics")
                .font(.inter(20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Coming soon...")
                .font(.inter(14, weight: .medium))
                .foregroundColor(Color(.systemGray2))
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.1))
        )
    }
}

struct EventAnalyticsView: View {
    let analyticsService: HostAnalyticsService
    
    var body: some View {
        VStack {
            Text("Event Analytics")
                .font(.inter(20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Coming soon...")
                .font(.inter(14, weight: .medium))
                .foregroundColor(Color(.systemGray2))
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.1))
        )
    }
}

// ChartDataPoint moved to FirestoreService.swift to avoid duplication

#Preview {
    ProfessionalMetricDetailView(
        metric: .revenue,
        analyticsService: HostAnalyticsService.shared,
        firestoreService: FirestoreService()
    )
}

// MARK: - Supporting Row
struct ClickRankingRow: View {
    let analytics: EventClickAnalytics
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(analytics.partyTitle)
                    .font(.inter(14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(analytics.totalClicks) clicks • \(Int(analytics.conversionRate))% conv")
                    .font(.inter(12, weight: .regular))
                    .foregroundColor(Color(.systemGray3))
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
} 