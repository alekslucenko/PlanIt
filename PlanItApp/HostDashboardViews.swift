import SwiftUI
import Charts
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - UNIFIED CHART DATA MODEL (FIXING AMBIGUITY)

/// Unified ChartDataPoint structure that handles all chart data requirements
struct ChartDataPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let month: String
    let revenue: Double
    let rsvps: Int
    let attendance: Int
    let growthRate: Double
    
    // Initializer for monthly data (legacy support)
    init(month: String, rsvps: Int, revenue: Double) {
        self.month = month
        self.rsvps = rsvps
        self.revenue = revenue
        self.timestamp = Date()
        self.attendance = rsvps // Map rsvps to attendance
        self.growthRate = 0.0 // Default growth rate
    }
    
    // Initializer for detailed time-series data
    init(timestamp: Date, revenue: Double, attendance: Int, growthRate: Double) {
        self.timestamp = timestamp
        self.revenue = revenue
        self.attendance = attendance
        self.growthRate = growthRate
        
        // Generate month string from timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        self.month = formatter.string(from: timestamp)
        self.rsvps = attendance // Map attendance to rsvps
    }
    
    // Full initializer
    init(id: UUID = UUID(), timestamp: Date, month: String, revenue: Double, rsvps: Int, attendance: Int, growthRate: Double) {
        self.timestamp = timestamp
        self.month = month
        self.revenue = revenue
        self.rsvps = rsvps
        self.attendance = attendance
        self.growthRate = growthRate
    }
}

// MARK: - REAL-TIME ANALYTICS DATA STRUCTURE

struct RealTimeAnalyticsData: Codable {
    var totalRevenue: Double = 0.0
    var newCustomers: Int = 0
    var activeEvents: Int = 0
    var totalAttendees: Int = 0
    var averageEventSize: Double = 0.0
    var overallGrowth: Double = 0.0
    var revenueGrowth: Double = 0.0
    var customerGrowth: Double = 0.0
    var eventGrowth: Double = 0.0
    var attendeeGrowth: Double = 0.0
    var eventSizeGrowth: Double = 0.0
    var lastUpdated: Date = Date()
    var chartData: [ChartDataPoint] = []
    var soldOutEvents: Int = 0
    
    // Initialize with mock data for testing
    init() {
        loadMockData()
    }
    
    mutating func loadMockData() {
        totalRevenue = Double.random(in: 8000...15000)
        newCustomers = Int.random(in: 150...300)
        activeEvents = Int.random(in: 8...20)
        totalAttendees = Int.random(in: 300...600)
        averageEventSize = Double.random(in: 25...50)
        overallGrowth = Double.random(in: -5...15)
        revenueGrowth = Double.random(in: -10...20)
        customerGrowth = Double.random(in: -15...25)
        eventGrowth = Double.random(in: -5...12)
        attendeeGrowth = Double.random(in: -8...18)
        eventSizeGrowth = Double.random(in: -3...8)
        lastUpdated = Date()
        
        // Generate sample chart data
        chartData = generateSampleChartData()
    }
    
    private func generateSampleChartData() -> [ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        var data: [ChartDataPoint] = []
        
        for i in 0..<12 {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let monthName = formatter.string(from: monthDate)
            
            let revenue = Double.random(in: 1000...3000)
            let attendance = Int.random(in: 50...150)
            let growth = Double.random(in: -10...15)
            
            data.append(ChartDataPoint(
                timestamp: monthDate,
                month: monthName,
                revenue: revenue,
                rsvps: attendance,
                attendance: attendance,
                growthRate: growth
            ))
        }
        
        return data.reversed() // Most recent first
    }
}

// MARK: - ANALYTICS DATA STRUCTURE

struct AnalyticsData: Codable {
    let totalRevenue: Double
    let newCustomers: Int
    let activeEvents: Int
    let totalAttendees: Int
    let averageEventSize: Double
    let growthRate: Double
    
    static let mock = AnalyticsData(
        totalRevenue: 12500.0,
        newCustomers: 234,
        activeEvents: 12,
        totalAttendees: 456,
        averageEventSize: 38.0,
        growthRate: 4.5
    )
}

// MARK: - ESSENTIAL HOST DASHBOARD COMPONENTS (FIXING BUILD ERRORS)

// ProfileModeSwitcher - Critical Component
struct ProfileModeSwitcher: View {
    @StateObject private var partyManager = PartyManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isBusinessMode = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isBusinessMode.toggle()
                partyManager.toggleHostMode()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: isBusinessMode ? "building.2" : "person.circle")
                    .font(.system(size: 16, weight: .semibold))
                
                Text(isBusinessMode ? "Business" : "Personal")
                    .font(.geist(12, weight: .semibold))
            }
            .foregroundColor(isBusinessMode ? themeManager.businessAccent : themeManager.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isBusinessMode ? themeManager.businessPrimary : themeManager.cardBackground)
                    .overlay(
                        Capsule()
                            .stroke(isBusinessMode ? themeManager.businessPrimary : themeManager.secondaryText.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .animation(.easeInOut(duration: 0.3), value: isBusinessMode)
        .onAppear {
            isBusinessMode = partyManager.isHostMode
        }
        .onChange(of: partyManager.isHostMode) { _, newValue in
            isBusinessMode = newValue
        }
    }
}

// MARK: - Modern Analytics Dashboard (FIXED LAYOUT)
struct HostAnalyticsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var partyManager = PartyManager.shared
    @StateObject private var analyticsService = HostAnalyticsService.shared
    @State private var selectedTimeframe: HostAnalyticsService.Timeframe = .thisWeek
    @State private var isLoading = false
    @State private var realTimeData = RealTimeAnalyticsData()
    @State private var lastUpdateTime = Date()
    
    // Sheet presentation states
    @State private var showRevenueSheet = false
    @State private var showCustomersSheet = false
    @State private var showEventsSheet = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background matching image
                Color.black
                    .ignoresSafeArea(.all)
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        // Header Section
                        headerSection
                            .padding(.top, geometry.safeAreaInsets.top + 20)
                        
                        // Live Status Indicator
                        liveStatusSection
                        
                        // Analytics Cards
                        analyticsCardsSection
                        
                        // Chart Section (for scrolling)
                        chartSection
                        
                        // Bottom padding for tab bar
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                }
                .refreshable {
                    await refreshAnalytics()
                }
            }
        }
        .sheet(isPresented: $showRevenueSheet) {
            RevenueLogSheet()
        }
        .sheet(isPresented: $showCustomersSheet) {
            NewCustomersSheet()
        }
        .sheet(isPresented: $showEventsSheet) {
            ActiveEventsSheet()
        }
        .onAppear {
            startRealTimeUpdates()
        }
        .onDisappear {
            stopRealTimeUpdates()
        }
    }
    
    // MARK: - Header Section (Exact Match)
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Party Analytics")
                        .font(.inter(28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Real-time insights powered by Firebase")
                        .font(.inter(16, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Time Frame Selector
                timeFrameSelector
            }
        }
    }
    
    private var timeFrameSelector: some View {
        Menu {
            ForEach(HostAnalyticsService.Timeframe.allCases, id: \.self) { timeframe in
                Button(timeframe.rawValue) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTimeframe = timeframe
                        analyticsService.timeframe = timeframe
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.white)
                
                Text(selectedTimeframe.rawValue)
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.down")
                    .font(.inter(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Live Status Section (Exact Match)
    private var liveStatusSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            
            Text("Live Data")
                .font(.inter(12, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            Text("•")
                .font(.inter(12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            
            Text("Updated \(formatTime(lastUpdateTime))")
                .font(.inter(12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Analytics Cards Section (Exact Layout Match)
    private var analyticsCardsSection: some View {
        VStack(spacing: 16) {
            // Top row - Revenue card (full width)
            AnalyticsCardView(
                title: "Total Revenue",
                value: "$\(formatRevenue(realTimeData.totalRevenue))",
                subtitle: "from ticket sales",
                trend: "+15%",
                trendUp: true,
                color: .green,
                icon: "$"
            ) {
                showRevenueSheet = true
            }
            
            // Bottom row - Two cards side by side
            HStack(spacing: 16) {
                AnalyticsCardView(
                    title: "New Customers",
                    value: "\(realTimeData.newCustomers)",
                    subtitle: "unique buyers",
                    trend: "+\(realTimeData.customerGrowth)",
                    trendUp: realTimeData.customerGrowth > 0,
                    color: .blue,
                    icon: "👥"
                ) {
                    showCustomersSheet = true
                }
                
                AnalyticsCardView(
                    title: "Active Events",
                    value: "\(realTimeData.activeEvents)",
                    subtitle: "happening this month",
                    trend: "\(realTimeData.soldOutEvents) sold out",
                    trendUp: true,
                    color: .purple,
                    icon: "📅"
                ) {
                    showEventsSheet = true
                }
            }
        }
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Revenue Trend")
                    .font(.inter(18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Revenue Chart
            RevenueChartView(
                chartData: analyticsService.chartPoints,
                accent: Color.green
            )
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Helper Functions
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func formatRevenue(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.0f", amount / 1000) + "K"
        } else {
            return String(format: "%.0f", amount)
        }
    }
    
    private func startRealTimeUpdates() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await refreshAnalytics()
            }
        }
        
        Task {
            await refreshAnalytics()
        }
    }
    
    private func stopRealTimeUpdates() {
        // Stop any running timers
    }
    
    private func refreshAnalytics() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("parties")
                .whereField("hostId", isEqualTo: currentUserID)
                .getDocuments()
            
            let parties = snapshot.documents.compactMap { doc -> Party? in
                try? doc.data(as: Party.self)
            }
            
            await MainActor.run {
                // Calculate real-time metrics
                realTimeData.totalRevenue = calculateTotalRevenue(from: parties)
                realTimeData.newCustomers = calculateNewCustomers(from: parties)
                realTimeData.activeEvents = calculateActiveEvents(from: parties)
                realTimeData.soldOutEvents = calculateSoldOutEvents(from: parties)
                realTimeData.customerGrowth = Double.random(in: 15...35) // Sample growth
                lastUpdateTime = Date()
            }
        } catch {
            print("Error fetching analytics: \(error)")
        }
    }
    
    private func calculateTotalRevenue(from parties: [Party]) -> Double {
        return parties.reduce(0.0) { result, party in
            let partyRevenue = party.ticketTiers.reduce(0.0) { tierResult, tier in
                return tierResult + (tier.price * Double(tier.soldCount))
            }
            return result + partyRevenue
        }
    }
    
    private func calculateNewCustomers(from parties: [Party]) -> Int {
        return parties.reduce(0) { result, party in
            return result + party.currentAttendees
        }
    }
    
    private func calculateActiveEvents(from parties: [Party]) -> Int {
        return parties.filter { $0.status == .live || $0.status == .upcoming }.count
    }
    
    private func calculateSoldOutEvents(from parties: [Party]) -> Int {
        return parties.filter { party in
            party.ticketTiers.allSatisfy { $0.soldCount >= $0.maxQuantity }
        }.count
    }
}

// MARK: - Analytics Card View (Exact Image Match)
struct AnalyticsCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let trend: String
    let trendUp: Bool
    let color: Color
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon and trend
                HStack {
                    Text(icon)
                        .font(.inter(16, weight: .semibold))
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    Text(trend)
                        .font(.inter(12, weight: .medium))
                        .foregroundColor(trendUp ? .green : .red)
                }
                
                // Main value
                Text(value)
                    .font(.inter(24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.inter(14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(subtitle)
                        .font(.inter(12, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {}) { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
    }
}



// MARK: - Analytics Card Component (FIXED SIZE)
struct AnalyticsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    let percentage: String
    
    @StateObject private var themeManager = ThemeManager.shared
    
    enum TrendDirection {
        case up, down, neutral
        
        var iconName: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
                
                HStack(spacing: 3) {
                    Image(systemName: trend.iconName)
                        .font(.system(size: 10, weight: .semibold))
                    Text(percentage)
                        .font(.geist(10, weight: .semibold))
                }
                .foregroundColor(trend.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(trend.color.opacity(0.1))
                )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.geist(20, weight: .bold))
                    .foregroundColor(themeManager.businessText)
                    .lineLimit(1)
                
                Text(title)
                    .font(.geist(12, weight: .medium))
                    .foregroundColor(themeManager.businessSecondaryText)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.geist(9, weight: .medium))
                    .foregroundColor(themeManager.businessSecondaryText.opacity(0.8))
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 110)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeManager.businessCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeManager.businessBorder, lineWidth: 1)
                )
        )
        .shadow(
            color: themeManager.businessShadow.opacity(0.1),
            radius: 6,
            x: 0,
            y: 3
        )
    }
}

// MARK: - Clickable Analytics Card Component

struct ClickableAnalyticsCard: View {
    let type: EnhancedHostAnalyticsView.AnalyticType
    let title: String
    let value: String
    let subtitle: String
    let trend: TrendDirection
    let color: Color
    let action: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isPressed = false
    
    enum TrendDirection {
        case up, down, neutral
        
        var iconName: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: type.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: trend.iconName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(trend.color)
                        
                        Text(subtitle.components(separatedBy: " ").last ?? "")
                            .font(.geist(10, weight: .semibold))
                            .foregroundColor(trend.color)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.geist(20, weight: .bold))
                        .foregroundColor(themeManager.businessText)
                        .lineLimit(1)
                    
                    Text(title)
                        .font(.geist(12, weight: .medium))
                        .foregroundColor(themeManager.businessSecondaryText)
                        .lineLimit(1)
                }
                
                Text(subtitle)
                    .font(.geist(10, weight: .medium))
                    .foregroundColor(themeManager.businessSecondaryText.opacity(0.8))
                    .lineLimit(2)
            }
            .padding(16)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.businessCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isPressed ? color : themeManager.businessBorder, lineWidth: isPressed ? 2 : 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(
                color: isPressed ? color.opacity(0.3) : themeManager.businessShadow.opacity(0.1),
                radius: isPressed ? 8 : 6,
                x: 0,
                y: isPressed ? 6 : 3
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - KPI Card Component

struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.geist(14, weight: .bold))
                .foregroundColor(themeManager.businessText)
                .lineLimit(1)
            
            Text(title)
                .font(.geist(10, weight: .medium))
                .foregroundColor(themeManager.businessSecondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeManager.businessCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeManager.businessBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Analytic Detail View (Full-Screen Sheet)

struct AnalyticDetailView: View {
    let analyticType: EnhancedHostAnalyticsView.AnalyticType
    let data: RealTimeAnalyticsData
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedTimeframe: String = "7 Days"
    @State private var detailChartData: [ChartDataPoint] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.businessBackground
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with main metric
                        headerSection
                        
                        // Detailed chart
                        detailedChartSection
                        
                        // Insights and recommendations
                        insightsSection
                        
                        // Historical data table
                        historicalDataSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle(analyticType.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.businessPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    timeframeMenu
                }
            }
        }
        .onAppear {
            generateDetailChartData()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: analyticType.icon)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(themeManager.businessPrimary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(getMainValue())
                        .font(.geist(36, weight: .bold))
                        .foregroundColor(themeManager.businessText)
                    
                    Text(analyticType.rawValue)
                        .font(.geist(16, weight: .medium))
                        .foregroundColor(themeManager.businessSecondaryText)
                }
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Growth")
                        .font(.geist(12, weight: .medium))
                        .foregroundColor(themeManager.businessSecondaryText)
                    
                    Text("\(getGrowthValue() >= 0 ? "+" : "")\(String(format: "%.1f", getGrowthValue()))%")
                        .font(.geist(16, weight: .bold))
                        .foregroundColor(getGrowthValue() >= 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Period")
                        .font(.geist(12, weight: .medium))
                        .foregroundColor(themeManager.businessSecondaryText)
                    
                    Text(selectedTimeframe)
                        .font(.geist(16, weight: .bold))
                        .foregroundColor(themeManager.businessText)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.businessCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.businessBorder, lineWidth: 1)
                    )
            )
        }
    }
    
    private var detailedChartSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("📈 Detailed Performance")
                    .font(.geist(18, weight: .bold))
                    .foregroundColor(themeManager.businessPrimary)
                
                Spacer()
            }
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(detailChartData) { dataPoint in
                        LineMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value(analyticType.rawValue, getDetailChartValue(for: dataPoint))
                        )
                        .foregroundStyle(themeManager.businessPrimary)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        
                        AreaMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value(analyticType.rawValue, getDetailChartValue(for: dataPoint))
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeManager.businessPrimary.opacity(0.3), themeManager.businessPrimary.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel(format: .dateTime.day())
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            } else {
                Text("Charts require iOS 16+")
                    .font(.geist(16, weight: .medium))
                    .foregroundColor(themeManager.businessSecondaryText)
                    .frame(height: 200)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.businessCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.businessBorder, lineWidth: 1)
                )
        )
    }
    
    private var insightsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("💡 AI Insights")
                    .font(.geist(18, weight: .bold))
                    .foregroundColor(themeManager.businessPrimary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                InsightCard(
                    title: "Performance Trend",
                    description: getPerformanceInsight(),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
                
                InsightCard(
                    title: "Recommendation",
                    description: getRecommendation(),
                    icon: "lightbulb.fill",
                    color: .orange
                )
                
                InsightCard(
                    title: "Next Action",
                    description: getNextAction(),
                    icon: "arrow.right.circle.fill",
                    color: .green
                )
            }
        }
    }
    
    private var historicalDataSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("📊 Historical Data")
                    .font(.geist(18, weight: .bold))
                    .foregroundColor(themeManager.businessPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(getHistoricalData(), id: \.period) { dataEntry in
                    HStack {
                        Text(dataEntry.period)
                            .font(.geist(14, weight: .medium))
                            .foregroundColor(themeManager.businessSecondaryText)
                        
                        Spacer()
                        
                        Text(dataEntry.value)
                            .font(.geist(14, weight: .bold))
                            .foregroundColor(themeManager.businessText)
                        
                        Text(dataEntry.change)
                            .font(.geist(12, weight: .semibold))
                            .foregroundColor(dataEntry.change.hasPrefix("+") ? .green : .red)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.businessCardBackground.opacity(0.5))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.businessCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.businessBorder, lineWidth: 1)
                )
        )
    }
    
    private var timeframeMenu: some View {
        Menu {
            ForEach(["24 Hours", "7 Days", "30 Days", "3 Months", "1 Year"], id: \.self) { timeframe in
                Button(timeframe) {
                    selectedTimeframe = timeframe
                    generateDetailChartData()
                }
            }
        } label: {
            Text(selectedTimeframe)
                .font(.geist(14, weight: .medium))
                .foregroundColor(themeManager.businessPrimary)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getMainValue() -> String {
        switch analyticType {
        case .revenue:
            return "$\(Int(data.totalRevenue))"
        case .customers:
            return "\(data.newCustomers)"
        case .events:
            return "\(data.activeEvents)"
        case .growth:
            return "\(String(format: "%.1f", data.overallGrowth))%"
        case .attendees:
            return "\(data.totalAttendees)"
        case .eventSize:
            return "\(Int(data.averageEventSize))"
        }
    }
    
    private func getGrowthValue() -> Double {
        switch analyticType {
        case .revenue:
            return data.revenueGrowth
        case .customers:
            return data.customerGrowth
        case .events:
            return data.eventGrowth
        case .growth:
            return data.overallGrowth
        case .attendees:
            return data.attendeeGrowth
        case .eventSize:
            return data.eventSizeGrowth
        }
    }
    
    private func getDetailChartValue(for dataPoint: ChartDataPoint) -> Double {
        switch analyticType {
        case .revenue:
            return dataPoint.revenue
        case .customers, .attendees:
            return Double(dataPoint.attendance)
        case .events:
            return Double(dataPoint.attendance / 10) // Scaled for visualization
        case .growth:
            return dataPoint.growthRate
        case .eventSize:
            return Double(dataPoint.attendance / 5) // Average event size approximation
        }
    }
    
    private func generateDetailChartData() {
        let calendar = Calendar.current
        let now = Date()
        var newDetailData: [ChartDataPoint] = []
        
        let days = selectedTimeframe == "24 Hours" ? 1 : (selectedTimeframe == "7 Days" ? 7 : 30)
        
        for i in 0..<days {
            guard let dayTime = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            
            // Generate realistic sample data based on analytics type
            let baseValue = getBaseValue()
            let variance = getVariance()
            let value = baseValue + Double.random(in: -variance...variance)
            
            newDetailData.append(ChartDataPoint(
                timestamp: dayTime,
                revenue: analyticType == .revenue ? value : Double.random(in: 1000...5000),
                attendance: analyticType == .attendees ? Int(value) : Int.random(in: 50...200),
                growthRate: analyticType == .growth ? value : Double.random(in: -10...20)
            ))
        }
        
        detailChartData = newDetailData.reversed()
    }
    
    private func getBaseValue() -> Double {
        switch analyticType {
        case .revenue:
            return 2500.0
        case .customers, .attendees:
            return 150.0
        case .events:
            return 10.0
        case .growth:
            return 12.0
        case .eventSize:
            return 25.0
        }
    }
    
    private func getVariance() -> Double {
        switch analyticType {
        case .revenue:
            return 800.0
        case .customers, .attendees:
            return 50.0
        case .events:
            return 3.0
        case .growth:
            return 8.0
        case .eventSize:
            return 10.0
        }
    }
    
    private func getPerformanceInsight() -> String {
        switch analyticType {
        case .revenue:
            return "Revenue shows strong upward trend with peak performance on weekends. Consider increasing premium event offerings."
        case .customers:
            return "Customer acquisition is steady but could benefit from targeted marketing campaigns during weekdays."
        case .events:
            return "Event frequency is optimal for current capacity. Consider expanding to new venues for growth."
        case .growth:
            return "Overall growth rate is above industry average. Focus on maintaining quality while scaling."
        case .attendees:
            return "Attendance patterns show strong community engagement. Leverage word-of-mouth marketing."
        case .eventSize:
            return "Event sizes are well-balanced. Consider creating both intimate and large-scale experiences."
        }
    }
    
    private func getRecommendation() -> String {
        switch analyticType {
        case .revenue:
            return "Implement dynamic pricing strategy based on demand patterns and seasonality."
        case .customers:
            return "Launch referral program to leverage existing customer satisfaction for growth."
        case .events:
            return "Diversify event types to capture different market segments and increase frequency."
        case .growth:
            return "Invest in customer retention programs to sustain long-term growth momentum."
        case .attendees:
            return "Optimize event capacity utilization and consider wait-list strategies for popular events."
        case .eventSize:
            return "Create tiered event experiences to cater to different group sizes and preferences."
        }
    }
    
    private func getNextAction() -> String {
        switch analyticType {
        case .revenue:
            return "Schedule strategy meeting to discuss pricing optimization for next quarter."
        case .customers:
            return "Design and launch customer acquisition campaign within 2 weeks."
        case .events:
            return "Research new venue partnerships and plan expansion strategy."
        case .growth:
            return "Conduct customer satisfaction survey to identify retention opportunities."
        case .attendees:
            return "Analyze attendance patterns to optimize event scheduling and promotion."
        case .eventSize:
            return "Survey customers about preferred event sizes and experiences."
        }
    }
    
    private func getHistoricalData() -> [HistoricalDataEntry] {
        // Generate sample historical data
        return [
            HistoricalDataEntry(period: "This Week", value: getMainValue(), change: "+12.5%"),
            HistoricalDataEntry(period: "Last Week", value: getPreviousValue(-7), change: "+8.2%"),
            HistoricalDataEntry(period: "This Month", value: getMonthValue(), change: "+15.3%"),
            HistoricalDataEntry(period: "Last Month", value: getPreviousValue(-30), change: "+5.7%"),
            HistoricalDataEntry(period: "3 Months Ago", value: getPreviousValue(-90), change: "-2.1%")
        ]
    }
    
    private func getPreviousValue(_ daysAgo: Int) -> String {
        let factor = 1.0 + (Double(abs(daysAgo)) * 0.01) // Simulate growth over time
        let currentValue = getCurrentNumericValue()
        let previousValue = currentValue / factor
        
        switch analyticType {
        case .revenue:
            return "$\(Int(previousValue))"
        case .growth:
            return "\(String(format: "%.1f", previousValue))%"
        default:
            return "\(Int(previousValue))"
        }
    }
    
    private func getMonthValue() -> String {
        let currentValue = getCurrentNumericValue()
        let monthValue = currentValue * 4.2 // Approximate monthly value
        
        switch analyticType {
        case .revenue:
            return "$\(Int(monthValue))"
        case .growth:
            return "\(String(format: "%.1f", monthValue))%"
        default:
            return "\(Int(monthValue))"
        }
    }
    
    private func getCurrentNumericValue() -> Double {
        switch analyticType {
        case .revenue:
            return data.totalRevenue
        case .customers:
            return Double(data.newCustomers)
        case .events:
            return Double(data.activeEvents)
        case .growth:
            return data.overallGrowth
        case .attendees:
            return Double(data.totalAttendees)
        case .eventSize:
            return data.averageEventSize
        }
    }
}

struct HistoricalDataEntry {
    let period: String
    let value: String
    let change: String
}

// MARK: - Insight Card Component

struct InsightCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.geist(14, weight: .semibold))
                    .foregroundColor(themeManager.businessText)
                
                Text(description)
                    .font(.geist(12, weight: .medium))
                    .foregroundColor(themeManager.businessSecondaryText)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(12)
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

// MARK: - Firestore Integration Extension
extension HostAnalyticsView {
    private func loadAnalyticsDataFromFirestore() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoading = true
            }
        }
        
        do {
            // Calculate analytics from user's hosted parties with real-time Firebase integration
            let snapshot = try await db.collection("parties")
                .whereField("hostId", isEqualTo: currentUserID)
                .getDocuments()
            
            let parties = snapshot.documents.compactMap { doc -> Party? in
                try? doc.data(as: Party.self)
            }
            
            // Calculate metrics from Party model properties
            let totalRevenue = parties.reduce(into: 0.0) { result, party in
                // Calculate revenue from ticket tiers
                let partyRevenue = party.ticketTiers.reduce(into: 0.0) { tierResult, tier in
                    tierResult += tier.price * Double(tier.soldCount)
                }
                result += partyRevenue
            }
            
            let activeEvents = parties.filter { $0.status == .live || $0.status == .upcoming }.count
            let totalAttendees = parties.reduce(into: 0) { result, party in
                result += party.currentAttendees
            }
            let averageEventSize = parties.isEmpty ? 0.0 : Double(totalAttendees) / Double(parties.count)
            
            // Calculate new customers (approximation using recent parties)
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let recentParties = parties.filter { $0.createdAt >= thirtyDaysAgo }
            let newCustomers = recentParties.reduce(into: 0) { result, party in
                result += party.currentAttendees
            }
            
            // Calculate growth rate (simplified based on recent vs older parties)
            let olderParties = parties.filter { $0.createdAt < thirtyDaysAgo }
            let recentRevenue = recentParties.reduce(into: 0.0) { result, party in
                let partyRevenue = party.ticketTiers.reduce(into: 0.0) { tierResult, tier in
                    tierResult += tier.price * Double(tier.soldCount)
                }
                result += partyRevenue
            }
            let olderRevenue = olderParties.reduce(into: 0.0) { result, party in
                let partyRevenue = party.ticketTiers.reduce(into: 0.0) { tierResult, tier in
                    tierResult += tier.price * Double(tier.soldCount)
                }
                result += partyRevenue
            }
            let growthRate = olderRevenue > 0 ? ((recentRevenue - olderRevenue) / olderRevenue) * 100 : 0
            
            // Update real-time data with Firebase results - IMMEDIATE UI UPDATE
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    realTimeData.totalRevenue = totalRevenue
                    realTimeData.newCustomers = newCustomers
                    realTimeData.activeEvents = activeEvents
                    realTimeData.lastUpdated = Date()
                    
                    isLoading = false
                }
            }
            
            print("✅ Firebase analytics data loaded: \(parties.count) parties, $\(Int(totalRevenue)) revenue")
            
        } catch {
            print("⚠️ Error loading analytics data: \(error)")
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Celebrity Booking View (Placeholder)
struct CelebrityBookingView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 20) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Celebrity Booking")
                        .font(.inter(28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Connect with celebrities for your events")
                        .font(.inter(16, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top + 40)
            }
        }
    }
}

// MARK: - Security Booking View (Placeholder)
struct SecurityBookingView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 20) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Security Services")
                        .font(.inter(28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Professional security for your events")
                        .font(.inter(16, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top + 40)
            }
        }
    }
}

// MARK: - Enhanced Analytics View with Clickable Elements
struct EnhancedHostAnalyticsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var partyManager = PartyManager.shared
    @State private var selectedTimeframe: HostAnalyticsService.Timeframe = .thisWeek
    @State private var chartViewMode: ChartViewMode = .revenue
    @State private var selectedAnalytic: AnalyticType? = nil
    @State private var showingDetailSheet = false
    @State private var animateCards = false
    @State private var isLoading = true
    @State private var realTimeData = RealTimeAnalyticsData()
    @State private var refreshTimer: Timer?
    
    private let db = Firestore.firestore()
    
    enum ChartViewMode: String, CaseIterable {
        case revenue = "Revenue"
        case attendance = "Attendance"
        case growth = "Growth"
        
        var title: String { rawValue }
        var yAxisLabel: String {
            switch self {
            case .revenue: return "Revenue ($)"
            case .attendance: return "Attendees"
            case .growth: return "Growth Rate (%)"
            }
        }
        var color: Color {
            switch self {
            case .revenue: return .green
            case .attendance: return .blue
            case .growth: return .purple
            }
        }
    }
    
    enum AnalyticType: String, CaseIterable {
        case revenue = "Revenue"
        case customers = "Customers"
        case events = "Events"
        case growth = "Growth"
        case attendees = "Attendees"
        case eventSize = "Event Size"
        
        var icon: String {
            switch self {
            case .revenue: return "dollarsign.circle.fill"
            case .customers: return "person.2.circle.fill"
            case .events: return "calendar.circle.fill"
            case .growth: return "chart.line.uptrend.xyaxis.circle.fill"
            case .attendees: return "person.3.circle.fill"
            case .eventSize: return "person.crop.circle.fill"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                themeManager.businessBackground
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 20) {
                    Text("🚀")
                        .font(.system(size: 60))
                    
                    Text("Enhanced Analytics")
                        .font(.geist(24, weight: .bold))
                        .foregroundColor(themeManager.businessText)
                    
                    Text("Advanced analytics dashboard coming soon")
                        .font(.geist(14, weight: .medium))
                        .foregroundColor(themeManager.businessSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top + 40)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}

// NOTE: HostDashboardView, HostPartiesView, HostTabBar, FilterChip, HostPartyCard, StatusBadge
// and other components are defined in ModernMainTabView.swift to avoid duplication 