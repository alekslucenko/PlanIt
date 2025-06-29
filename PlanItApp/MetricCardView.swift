import SwiftUI
import Foundation

struct MetricCardView: View {
    let metric: MetricType
    let data: MetricData
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                Spacer()
                
                // Icon at top
                VStack(spacing: 12) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(metric.iconColor)
                        .scaleEffect(isPressed ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: isPressed)
                    
                    // Value
                    if data.isLoading {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5).opacity(0.3))
                            .frame(width: 80, height: 32)
                            .modifier(LocalShimmerModifier())
                    } else {
                        Text(data.value)
                            .font(.custom("Geist-Bold", size: 32))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    
                    // Title
                    Text(metric.title)
                        .font(.custom("Geist-SemiBold", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer()
                
                // Bottom section
                VStack(spacing: 6) {
                    Text(metric.subtitle)
                        .font(.custom("Geist-Regular", size: 12))
                        .foregroundColor(Color(.systemGray3))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                    
                    Text(metric.extraInfo)
                        .font(.custom("Geist-Medium", size: 12))
                        .fontWeight(.medium)
                        .foregroundColor(Color(.systemGray2))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
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
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animationPhase = 1
            }
        }
    }
}

// Enhanced shimmer effect for loading states
// Shimmer modifier moved to avoid duplication - using the one from BusinessDashboardView.swift

private struct LocalShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                .white.opacity(0.3),
                                .clear
                            ]),
                            startPoint: .init(x: phase - 0.3, y: 0),
                            endPoint: .init(x: phase + 0.3, y: 0)
                        )
                    )
                    .animation(
                        .linear(duration: 1.8)
                        .repeatForever(autoreverses: false),
                        value: phase
                    )
            )
            .onAppear {
                phase = 2
            }
    }
}

// MARK: - StatMiniCard Component
struct StatMiniCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.inter(18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(title)
                    .font(.inter(10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            MetricCardView(
                metric: .revenue,
                data: MetricData(value: "$12,450", trend: "+15%", isLoading: false, hasError: false),
                onTap: {}
            )
            
            MetricCardView(
                metric: .customers,
                data: MetricData(value: "247", trend: "+32", isLoading: false, hasError: false),
                onTap: {}
            )
            
            MetricCardView(
                metric: .events,
                data: MetricData.placeholder,
                onTap: {}
            )
            
            MetricCardView(
                metric: .attendees,
                data: MetricData(value: "1,234", trend: "92%", isLoading: false, hasError: false),
                onTap: {}
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
} 