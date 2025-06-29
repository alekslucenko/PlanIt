import SwiftUI
import Charts

// MARK: - Revenue Chart View Component
struct RevenueChartView: View {
    let chartData: [HostAnalyticsService.DailyMetricPoint]
    let accent: Color
    @State private var selectedTimeRange: ChartTimeRange = .week
    @State private var animateChart = false
    
    enum ChartTimeRange: String, CaseIterable {
        case week = "This Week"
        case month = "Last 30 Days"
        case quarter = "Last 3 Months"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            }
        }
    }
    
    private var filteredData: [HostAnalyticsService.DailyMetricPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
        
        return chartData.filter { dataPoint in
            dataPoint.date >= startDate && dataPoint.date <= endDate
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            chartHeader
            chartContent
        }
        .padding(20)
        .background(chartBackground)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                animateChart = true
            }
        }
    }
    
    private var chartHeader: some View {
        HStack {
            titleSection
            Spacer()
            timeRangeSelector
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accent)
                
                Text("Revenue Trend")
                    .font(.geist(18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Interactive real-time analytics")
                .font(.geist(12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ChartTimeRange.allCases, id: \.self) { range in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTimeRange = range
                    }
                }) {
                    Text(range.rawValue.replacingOccurrences(of: "Last ", with: ""))
                        .font(.geist(11, weight: .medium))
                        .foregroundColor(selectedTimeRange == range ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTimeRange == range ? .white : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(selectorBackground)
    }
    
    private var selectorBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    private var chartContent: some View {
        Group {
            if filteredData.isEmpty {
                emptyStateView
            } else {
                revenueChart
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No data available")
                .font(.geist(16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Chart will update when data is available")
                .font(.geist(12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(height: 200)
    }
    
    private var revenueChart: some View {
        Chart {
            ForEach(filteredData) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date, unit: .day),
                    y: .value("Revenue", animateChart ? dataPoint.revenue : 0)
                )
                .foregroundStyle(lineGradient)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                AreaMark(
                    x: .value("Date", dataPoint.date, unit: .day),
                    y: .value("Revenue", animateChart ? dataPoint.revenue : 0)
                )
                .foregroundStyle(areaGradient)
            }
        }
        .chartXAxis {
            AxisMarks(preset: .extended, position: .bottom) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.2))
                AxisValueLabel() {
                    if let date = value.as(Date.self) {
                        Text(formatDate(date))
                            .font(.geist(10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(preset: .extended, position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(.white.opacity(0.1))
                AxisValueLabel() {
                    if let revenue = value.as(Double.self) {
                        Text("$\(formatRevenue(revenue))")
                            .font(.geist(10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .frame(height: 200)
        .animation(.easeInOut(duration: 1.0), value: animateChart)
        .animation(.easeInOut(duration: 0.5), value: selectedTimeRange)
    }
    
    private var lineGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.6)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.3), accent.opacity(0.1), Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var chartBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.04)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedTimeRange {
        case .week:
            formatter.dateFormat = "E"
        case .month:
            formatter.dateFormat = "MMM d"
        case .quarter:
            formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }
    
    private func formatRevenue(_ revenue: Double) -> String {
        if revenue >= 1000 {
            return String(format: "%.1fk", revenue / 1000)
        } else {
            return String(format: "%.0f", revenue)
        }
    }
} 