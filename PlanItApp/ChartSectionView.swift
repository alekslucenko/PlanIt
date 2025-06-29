import SwiftUI
import Charts

enum ChartType: String, CaseIterable {
    case revenue = "revenue"
    case tickets = "tickets"
    case rsvps = "rsvps"
    case clicks = "clicks"
    
    var title: String {
        switch self {
        case .revenue: return "Revenue Trend"
        case .tickets: return "Ticket Sales"
        case .rsvps: return "RSVPs"
        case .clicks: return "Clicks & Conversion"
        }
    }
    
    var icon: String {
        switch self {
        case .revenue: return "chart.line.uptrend.xyaxis"
        case .tickets: return "ticket.fill"
        case .rsvps: return "person.3.fill"
        case .clicks: return "cursorarrow.click"
        }
    }
    
    var color: Color {
        switch self {
        case .revenue: return Color(red: 34/255, green: 197/255, blue: 94/255) // Emerald-400
        case .tickets: return Color(red: 59/255, green: 130/255, blue: 246/255) // Blue-400
        case .rsvps: return Color(red: 139/255, green: 92/255, blue: 246/255) // Purple-400
        case .clicks: return Color(red: 251/255, green: 146/255, blue: 60/255) // Orange-400
        }
    }
    
    var emoji: String {
        switch self {
        case .revenue: return "💰"
        case .tickets: return "🎫"
        case .rsvps: return "✅"
        case .clicks: return "👆"
        }
    }
    
    var formatter: (Double) -> String {
        switch self {
        case .revenue: return { "$\(Int($0))" }
        case .tickets, .rsvps, .clicks: return { "\(Int($0))" }
        }
    }
}

// ChartDataPoint is now defined in HostDashboardViews.swift

struct ChartSectionView: View {
    @ObservedObject var firestoreService: FirestoreService
    @State private var selectedChartType: ChartType = .revenue
    @State private var selectedDataPoint: ChartDataPoint?
    
    private let sampleData: [ChartDataPoint] = [
        ChartDataPoint(timestamp: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(), month: "Mon", revenue: 120, rsvps: 12, attendance: 12, growthRate: 17.8),
        ChartDataPoint(timestamp: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(), month: "Tue", revenue: 200, rsvps: 18, attendance: 18, growthRate: 17.9),
        ChartDataPoint(timestamp: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(), month: "Wed", revenue: 150, rsvps: 15, attendance: 15, growthRate: 19.2),
        ChartDataPoint(timestamp: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(), month: "Thu", revenue: 300, rsvps: 25, attendance: 25, growthRate: 20.2),
        ChartDataPoint(timestamp: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(), month: "Fri", revenue: 250, rsvps: 22, attendance: 22, growthRate: 19.2),
        ChartDataPoint(timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(), month: "Sat", revenue: 400, rsvps: 35, attendance: 35, growthRate: 19.2),
        ChartDataPoint(timestamp: Date(), month: "Sun", revenue: 350, rsvps: 28, attendance: 28, growthRate: 21.4)
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Chart Card
            VStack(spacing: 24) {
                // Header with Title and Toggles
                chartHeader
                
                // Chart Area
                chartArea
                
                // Legend
                chartLegend
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 55/255, green: 65/255, blue: 81/255).opacity(0.6), // Gray-700
                                Color(red: 31/255, green: 41/255, blue: 55/255).opacity(0.4)  // Gray-800
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
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
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
        }
    }
    
    private var chartHeader: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Title with Icon
                    HStack(spacing: 12) {
                        Image(systemName: selectedChartType.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(selectedChartType.color)
                        
                        Text("\(selectedChartType.emoji) \(selectedChartType.title)")
                            .font(.custom("Geist-SemiBold", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(selectedChartType.color)
                    }
                    
                    Spacer()
                }
                
                Text("Drag your finger over the chart to explore daily data points • Real-time data from Firestore")
                    .font(.inter(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.leading)
            }
            
            // Toggle Buttons
            HStack(spacing: 8) {
                ForEach(ChartType.allCases, id: \.self) { chartType in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedChartType = chartType
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: chartType.icon)
                                .font(.system(size: 12, weight: .medium))
                            
                            Text(chartType.emoji)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedChartType == chartType ? 
                                      chartType.color : 
                                      Color(.systemGray6).opacity(0.1))
                        )
                        .foregroundColor(selectedChartType == chartType ? .white : Color(.systemGray3))
                        .scaleEffect(selectedChartType == chartType ? 1.0 : 0.95)
                        .animation(.easeInOut(duration: 0.2), value: selectedChartType == chartType)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var chartArea: some View {
        VStack(spacing: 12) {
            // Big number display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(getTotalValue())
                        .font(.inter(32, weight: .black))
                        .foregroundColor(selectedChartType.color)
                    
                    Text("Total \(selectedChartType.title.lowercased())")
                        .font(.inter(14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(getTrendIndicator())
                        .font(.inter(16, weight: .bold))
                        .foregroundColor(getTrendColor())
                    
                    Text("Last 7 days")
                        .font(.inter(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.bottom, 8)
            
            // Interactive Chart
            InteractiveChartView(
                data: getInteractiveChartData(),
                metric: getMetricForChartType(),
                accentColor: selectedChartType.color,
                timeframe: .thisWeek
            )
        }
    }
    
    private func getInteractiveChartData() -> [InteractiveChartView.ChartDataPoint] {
        let currentData = getCurrentData()
        
        return currentData.map { dataPoint in
            let value = getValue(for: dataPoint)
            let displayValue = selectedChartType.formatter(value)
            let subtitle = getSubtitleForDataPoint(dataPoint, value: value)
            
            return InteractiveChartView.ChartDataPoint(
                date: dataPoint.timestamp,
                value: value,
                displayValue: displayValue,
                subtitle: subtitle
            )
        }
    }
    
    private func getMetricForChartType() -> MetricType {
        switch selectedChartType {
        case .revenue: return .revenue
        case .tickets: return .attendees
        case .rsvps: return .attendees
        case .clicks: return .clicks
        }
    }
    
    private func getTotalValue() -> String {
        let currentData = getCurrentData()
        let total = currentData.reduce(0) { $0 + getValue(for: $1) }
        return selectedChartType.formatter(total)
    }
    
    private func getTrendIndicator() -> String {
        let currentData = getCurrentData()
        guard currentData.count >= 2 else { return "No trend" }
        
        let lastValue = getValue(for: currentData.last!)
        let previousValue = getValue(for: currentData[currentData.count - 2])
        
        if previousValue == 0 {
            return lastValue > 0 ? "+∞%" : "0%"
        }
        
        let percentChange = ((lastValue - previousValue) / previousValue) * 100
        let sign = percentChange >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", percentChange))%"
    }
    
    private func getTrendColor() -> Color {
        let currentData = getCurrentData()
        guard currentData.count >= 2 else { return .gray }
        
        let lastValue = getValue(for: currentData.last!)
        let previousValue = getValue(for: currentData[currentData.count - 2])
        
        return lastValue >= previousValue ? .green : .red
    }
    
    private func getSubtitleForDataPoint(_ dataPoint: ChartDataPoint, value: Double) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: dataPoint.timestamp)
        
        switch selectedChartType {
        case .revenue:
            return value > 0 ? "\(dayName) sales" : "\(dayName) - no sales"
        case .tickets:
            return value > 0 ? "\(dayName) tickets sold" : "\(dayName) - no tickets sold"
        case .rsvps:
            return value > 0 ? "\(dayName) confirmations" : "\(dayName) - no RSVPs"
        case .clicks:
            return value > 0 ? "\(dayName) interactions" : "\(dayName) - no clicks"
        }
    }
    
    private var chartLegend: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(selectedChartType.color)
                    .frame(width: 12, height: 12)
                
                Text(selectedChartType.title)
                    .font(.custom("Geist-Medium", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(Color(.systemGray2))
            }
            
            Spacer()
            
            Text("Last 7 days")
                .font(.custom("Geist-Regular", size: 12))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.top, 8)
    }
    
    private func getCurrentData() -> [ChartDataPoint] {
        return firestoreService.chartData.isEmpty ? sampleData : firestoreService.chartData
    }
    
    private func getValue(for dataPoint: ChartDataPoint) -> Double {
        switch selectedChartType {
        case .revenue: return dataPoint.revenue
        case .tickets: return Double(dataPoint.rsvps) // Map tickets to rsvps
        case .rsvps: return Double(dataPoint.attendance)
        case .clicks: return dataPoint.growthRate * 10 // Map clicks to growthRate scaled up
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ChartSectionView(firestoreService: FirestoreService())
            .padding()
    }
    .preferredColorScheme(.dark)
} 