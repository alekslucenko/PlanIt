import SwiftUI
import Charts

// MARK: - Glassmorphic Metric Card
struct GlassMetricCard: View {
    enum Trend { case up, down, neutral }
    
    let title: String
    let value: String
    let subtitle: String
    let systemIcon: String
    let trend: Trend
    let accent: Color
    
    init(title: String, value: String, subtitle: String, systemIcon: String, trend: Trend = .neutral, accent: Color = .teal) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.systemIcon = systemIcon
        self.trend = trend
        self.accent = accent
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemIcon)
                    .foregroundColor(accent)
                Text(title)
                    .font(.geist(12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                trendIcon
            }
            Text(value)
                .font(.geist(22, weight: .bold))
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.geist(11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    private var trendIcon: some View {
        switch trend {
        case .up:
            return Image(systemName: "arrow.up.right").foregroundColor(.green)
        case .down:
            return Image(systemName: "arrow.down.right").foregroundColor(.red)
        case .neutral:
            return Image(systemName: "minus").foregroundColor(.gray)
        }
    }
}

// MARK: - Glass Button Style
struct GlassButtonStyle: ButtonStyle {
    let cornerRadius: CGFloat
    let tint: Color
    init(cornerRadius: CGFloat = 20, tint: Color = .blue) {
        self.cornerRadius = cornerRadius
        self.tint = tint
    }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(tint.opacity(0.4), lineWidth: 1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tint.opacity(configuration.isPressed ? 0.15 : 0.05))
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Daily Line Chart View
struct DailyLineChartView: View {
    let points: [HostAnalyticsService.DailyMetricPoint]
    let accent: Color
    @State private var selected: HostAnalyticsService.DailyMetricPoint?
    
    init(points: [HostAnalyticsService.DailyMetricPoint], accent: Color = .green) {
        self.points = points
        self.accent = accent
    }
    var body: some View {
        Chart(points) { pt in
            LineMark(x: .value("Day", pt.date), y: .value("Value", pt.value))
                .foregroundStyle(accent)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            AreaMark(x: .value("Day", pt.date), y: .value("Value", pt.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(accent.opacity(0.2).gradient)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let loc = value.location
                            if let date: Date = proxy.value(atX: loc.x) {
                                // find nearest pt
                                if let nearest = points.min(by: { abs($0.date.timeIntervalSince1970 - date.timeIntervalSince1970) < abs($1.date.timeIntervalSince1970 - date.timeIntervalSince1970) }) {
                                    selected = nearest
                                }
                            }
                        }
                        .onEnded { _ in selected = nil })
            }
        }
        .frame(height: 220)
        .padding(.top, 8)
        .animation(.easeInOut, value: points)
        .overlay(alignment: .topLeading) {
            if let sel = selected {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sel.date, style: .date)
                        .font(.geist(11))
                        .foregroundColor(.secondary)
                    Text("$"+String(format: "%.0f", sel.value))
                        .font(.geist(13, weight: .semibold))
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
                .offset(x: 12, y: -4)
            }
        }
    }
}

// MARK: - Shimmer Modifier (simple)
extension View {
    func shimmer(active: Bool = true, duration: Double = 1.0) -> some View {
        if !active { return AnyView(self) }
        return AnyView(
            self.overlay(
                LinearGradient(gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.4), Color.clear]), startPoint: .leading, endPoint: .trailing)
                    .rotationEffect(.degrees(30))
                    .offset(x: -200)
                    .mask(self)
                    .animation(Animation.linear(duration: duration).repeatForever(autoreverses: false), value: UUID())
            )
        )
    }
} 