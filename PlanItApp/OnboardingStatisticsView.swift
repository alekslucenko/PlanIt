import SwiftUI

// MARK: - Statistics View
struct StatisticsView: View {
    let statistic: AppStatistic
    let onContinue: () -> Void
    @State private var isAnimating = false
    @State private var showNextButton = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Main statistic display
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [hexToColor(statistic.color).opacity(0.3), hexToColor(statistic.color).opacity(0.1)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Image(systemName: statistic.iconName)
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(hexToColor(statistic.color))
                        .scaleEffect(isAnimating ? 1 : 0.3)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: isAnimating)
                }
                
                // Title and value
                VStack(spacing: 16) {
                    Text(statistic.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: isAnimating)
                    
                    Text(statistic.value)
                        .font(.system(size: 56, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [hexToColor(statistic.color), hexToColor(statistic.color).opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1 : 0.5)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.4), value: isAnimating)
                    
                    Text(statistic.subtitle)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.6), value: isAnimating)
                }
            }
            
            Spacer()
            
            // Continue button
            if showNextButton {
                Button(action: onContinue) {
                    HStack(spacing: 12) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [hexToColor(statistic.color), hexToColor(statistic.color).opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: hexToColor(statistic.color).opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 40)
                .scaleEffect(showNextButton ? 1 : 0.8)
                .opacity(showNextButton ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: showNextButton)
            }
            
            Spacer().frame(height: 50)
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    showNextButton = true
                }
            }
        }
    }
    
    // Helper function to convert hex string to Color
    private func hexToColor(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Statistics Completion View
struct StatisticsCompletionView: View {
    let selectedCategories: [OnboardingCategory]
    let onComplete: () -> Void
    @State private var isAnimating = false
    @State private var showCelebration = false
    @State private var particleOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Simple celebration background (no particle effect to avoid conflicts)
            if showCelebration {
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.1), .purple.opacity(0.05), .clear],
                            center: .center,
                            startRadius: 100,
                            endRadius: 500
                        )
                    )
                    .ignoresSafeArea()
                    .opacity(particleOpacity)
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Success animation
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.green.opacity(0.3), .blue.opacity(0.1)],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 150, height: 150)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(isAnimating ? 1 : 0.3)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: isAnimating)
                    }
                }
                
                VStack(spacing: 20) {
                    Text("🎉 You're All Set! 🎉")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4), value: isAnimating)
                    
                    Text("Your personal discovery experience is now tailored to your preferences")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.6), value: isAnimating)
                }
                
                // Selected categories summary
                VStack(spacing: 16) {
                    Text("You're interested in:")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.8), value: isAnimating)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(selectedCategories.enumerated()), id: \.element) { index, category in
                            HStack(spacing: 8) {
                                Image(systemName: category.iconName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(hexToColor(category.color))
                                
                                Text(category.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(hexToColor(category.color).opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(hexToColor(category.color).opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .scaleEffect(isAnimating ? 1 : 0.3)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.0 + Double(index) * 0.1), value: isAnimating)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Start exploring button
                Button(action: {
                    onComplete()
                }) {
                    HStack(spacing: 12) {
                        Text("Start Exploring")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 40)
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.5), value: isAnimating)
                
                Spacer().frame(height: 50)
            }
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showCelebration = true
                withAnimation(.easeInOut(duration: 1.0)) {
                    particleOpacity = 1.0
                }
            }
        }
    }
    
    // Helper function to convert hex string to Color
    private func hexToColor(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Uses shared TikTok components from OnboardingFlowView.swift

#Preview("Statistics View") {
    StatisticsView(
        statistic: AppStatistic.sampleStats[0],
        onContinue: {}
    )
}

#Preview("Completion View") {
                    StatisticsCompletionView(
        selectedCategories: [.restaurants, .nature, .shopping],
        onComplete: {}
    )
} 