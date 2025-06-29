import SwiftUI
import Charts
import FirebaseFirestore

/// 🚀 PROFESSIONAL INTERACTIVE CHART COMPONENT
/// Real-time draggable charts with finger interaction and Firestore integration
struct InteractiveChartView: View {
    let data: [ChartDataPoint]
    let metric: MetricType
    let accentColor: Color
    let timeframe: HostAnalyticsService.Timeframe
    
    @State private var selectedDataPoint: ChartDataPoint?
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var animateChart = false
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let displayValue: String
        let subtitle: String
    }
    
    var body: some View {
        VStack(spacing: 16) {
            chartHeader
            chartContainer
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                animateChart = true
            }
        }
    }
    
    private var chartHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                    
                    Text(metric.title)
                        .font(.inter(18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                if let selectedDataPoint = selectedDataPoint {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedDataPoint.displayValue)
                            .font(.inter(24, weight: .black))
                            .foregroundColor(accentColor)
                        
                        Text(selectedDataPoint.subtitle)
                            .font(.inter(12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    Text("Drag to explore data")
                        .font(.inter(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Current total display
            VStack(alignment: .trailing, spacing: 2) {
                Text(getTotalValue())
                    .font(.inter(20, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Total")
                    .font(.inter(10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    private var chartContainer: some View {
        ZStack {
            // Background with glassmorphic effect
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            VStack(spacing: 0) {
                // Interactive chart
                interactiveChart
                    .frame(height: 200)
                    .padding(16)
                
                // Date range indicator
                if !data.isEmpty {
                    HStack {
                        Text(formatDate(data.first?.date ?? Date()))
                            .font(.inter(10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Spacer()
                        
                        Text(formatDate(data.last?.date ?? Date()))
                            .font(.inter(10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            
            // Selection indicator overlay
            if isDragging, let selectedDataPoint = selectedDataPoint {
                selectionIndicator(for: selectedDataPoint)
            }
        }
    }
    
    private var interactiveChart: some View {
        Chart {
            ForEach(data) { dataPoint in
                // Area mark for filled area under line
                AreaMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Value", animateChart ? dataPoint.value : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor.opacity(0.3), accentColor.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Line mark for the main trend line
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Value", animateChart ? dataPoint.value : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                // Point marks for data points
                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Value", animateChart ? dataPoint.value : 0)
                )
                .foregroundStyle(accentColor)
                .symbolSize(selectedDataPoint?.id == dataPoint.id ? 80 : 40)
                .opacity(selectedDataPoint?.id == dataPoint.id ? 1.0 : 0.6)
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, position: .bottom) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.1))
                AxisValueLabel()
                    .foregroundStyle(.clear) // Hide default labels
            }
        }
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(.white.opacity(0.1))
                AxisValueLabel() {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatAxisValue(doubleValue))
                            .font(.inter(10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleDragChanged(value: value, proxy: proxy, geometry: geometry)
                            }
                            .onEnded { _ in
                                handleDragEnded()
                            }
                    )
                
                // Vertical selection line
                if isDragging {
                    Rectangle()
                        .fill(accentColor.opacity(0.8))
                        .frame(width: 2)
                        .position(x: dragLocation.x, y: geometry.size.height / 2)
                        .animation(.easeInOut(duration: 0.1), value: dragLocation)
                }
            }
        }
        .animation(.easeInOut(duration: 0.8), value: animateChart)
        .animation(.easeInOut(duration: 0.1), value: selectedDataPoint?.id)
    }
    
    private func selectionIndicator(for dataPoint: ChartDataPoint) -> some View {
        VStack(spacing: 8) {
            // Floating info card
            VStack(alignment: .leading, spacing: 4) {
                Text(dataPoint.displayValue)
                    .font(.inter(16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(formatDate(dataPoint.date))
                    .font(.inter(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(dataPoint.subtitle)
                    .font(.inter(10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .offset(y: -20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
    
    // MARK: - Gesture Handling
    
    private func handleDragChanged(value: DragGesture.Value, proxy: ChartProxy, geometry: GeometryProxy) {
        let location = value.location
        dragLocation = location
        
        // Convert touch location to chart coordinates
        let frame = geometry[proxy.plotAreaFrame]
        let chartX = location.x - frame.origin.x
        
        guard chartX >= 0, chartX <= frame.width else {
            return
        }
        
        // Find the closest data point
        if let closestDataPoint = findClosestDataPoint(chartX: chartX, proxy: proxy) {
            withAnimation(.easeInOut(duration: 0.1)) {
                selectedDataPoint = closestDataPoint
                isDragging = true
            }
        }
    }
    
    private func handleDragEnded() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isDragging = false
            selectedDataPoint = nil
        }
    }
    
    private func findClosestDataPoint(chartX: CGFloat, proxy: ChartProxy) -> ChartDataPoint? {
        guard !data.isEmpty else { return nil }
        
        var closestPoint: ChartDataPoint?
        var minDistance: CGFloat = .infinity
        
        for dataPoint in data {
            if let pointX = proxy.position(forX: dataPoint.date) {
                let distance = abs(chartX - pointX)
                if distance < minDistance {
                    minDistance = distance
                    closestPoint = dataPoint
                }
            }
        }
        
        return closestPoint
    }
    
    // MARK: - Helper Methods
    
    private func getTotalValue() -> String {
        let total = data.reduce(0) { $0 + $1.value }
        return formatValue(total)
    }
    
    private func formatValue(_ value: Double) -> String {
        switch metric {
        case .revenue:
            return formatCurrency(value)
        case .customers, .attendees, .events:
            return formatNumber(Int(value))
        case .conversion:
            return "\(Int(value))%"
        case .clicks:
            return formatNumber(Int(value))
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "$%.1fk", amount / 1000)
        } else {
            return String(format: "$%.0f", amount)
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000)
        } else {
            return "\(number)"
        }
    }
    
    private func formatAxisValue(_ value: Double) -> String {
        switch metric {
        case .revenue:
            if value >= 1000 {
                return String(format: "$%.0fk", value / 1000)
            } else {
                return String(format: "$%.0f", value)
            }
        default:
            if value >= 1000 {
                return String(format: "%.0fk", value / 1000)
            } else {
                return String(format: "%.0f", value)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch timeframe {
        case .today:
            formatter.dateFormat = "h:mm a"
        case .thisWeek:
            formatter.dateFormat = "EEE"
        case .thisMonth, .last30Days:
            formatter.dateFormat = "MMM d"
        case .last3Months:
            formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    InteractiveChartView(
        data: [
            InteractiveChartView.ChartDataPoint(
                date: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
                value: 1200,
                displayValue: "$1.2k",
                subtitle: "Monday revenue"
            ),
            InteractiveChartView.ChartDataPoint(
                date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                value: 1800,
                displayValue: "$1.8k",
                subtitle: "Tuesday revenue"
            ),
            InteractiveChartView.ChartDataPoint(
                date: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
                value: 900,
                displayValue: "$900",
                subtitle: "Wednesday revenue"
            ),
            InteractiveChartView.ChartDataPoint(
                date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                value: 2100,
                displayValue: "$2.1k",
                subtitle: "Thursday revenue"
            ),
            InteractiveChartView.ChartDataPoint(
                date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                value: 1500,
                displayValue: "$1.5k",
                subtitle: "Friday revenue"
            ),
            InteractiveChartView.ChartDataPoint(
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                value: 1700,
                displayValue: "$1.7k",
                subtitle: "Saturday revenue"
            ),
            InteractiveChartView.ChartDataPoint(
                date: Date(),
                value: 1300,
                displayValue: "$1.3k",
                subtitle: "Today revenue"
            )
        ],
        metric: .revenue,
        accentColor: .green,
        timeframe: .thisWeek
    )
    .preferredColorScheme(.dark)
    .padding()
    .background(Color.black)
} 