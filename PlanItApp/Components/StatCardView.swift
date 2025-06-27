import SwiftUI
import FirebaseFirestore

// MARK: - Reusable Stat Card View Component
struct StatCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let systemIcon: String
    let trend: TrendDirection
    let accent: Color
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    enum TrendDirection {
        case up, down, neutral
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .neutral: return "minus"
            }
        }
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                onTap()
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon and trend
                HStack {
                    Image(systemName: systemIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accent)
                    
                    Spacer()
                    
                    if trend != .neutral {
                        HStack(spacing: 4) {
                            Image(systemName: trend.icon)
                                .font(.system(size: 12, weight: .medium))
                            Text("12.5%")
                                .font(.geist(11, weight: .medium))
                        }
                        .foregroundColor(trend.color)
                    }
                }
                
                // Main stat value
                Text(value)
                    .font(.geist(24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.geist(14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(subtitle)
                        .font(.geist(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {
            // Long press completed action (if needed)
        }, onPressingChanged: { isPressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = isPressing
            }
        })
    }
}

// MARK: - Styled Header Component
struct StyledHeaderView: View {
    let title: String
    let subtitle: String
    @Binding var selectedTimeframe: String
    let timeframes: [String]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.geist(32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.geist(16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer(minLength: 10)
                
                TimeFilterSegmentView(
                    selectedTimeframe: $selectedTimeframe,
                    timeframes: timeframes
                )
            }
        }
    }
}

// MARK: - Time Filter Segment Control
struct TimeFilterSegmentView: View {
    @Binding var selectedTimeframe: String
    let timeframes: [String]
    
    var body: some View {
        Menu {
            ForEach(timeframes, id: \.self) { timeframe in
                Button(timeframe) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTimeframe = timeframe
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedTimeframe)
                    .font(.geist(14, weight: .medium))
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Live Status Indicator
struct LiveStatusIndicator: View {
    let lastUpdated: Date
    @State private var pulse = false
    
    private func formatLastUpdate() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdated)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
            
            Text("Live Data")
                .font(.geist(12, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
            Text("•")
                .foregroundColor(.white.opacity(0.5))
            
            Text("Updated \(formatLastUpdate())")
                .font(.geist(11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            pulse = true
        }
    }
} 