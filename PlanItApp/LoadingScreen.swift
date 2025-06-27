//
//  LoadingScreen.swift
//  PlanIt
//
//  Created by Aleks Lucenko on 6/10/25.
//

import SwiftUI

struct LoadingScreen: View {
    @State private var animationProgress: Double = 0.0
    @State private var currentStep = 0
    @State private var showProgress = false
    @State private var detailedProgress: [String: Bool] = [:]
    
    let loadingSteps = [
        "🔐 Authenticating user...",
        "📍 Getting your location...", 
        "🧬 Loading your preferences...",
        "🏪 Finding amazing places nearby...",
        "🤖 Personalizing AI recommendations...",
        "✨ Almost ready!"
    ]
    
    let detailedSteps = [
        "auth": "User authentication",
        "location": "Location services", 
        "fingerprint": "User fingerprint",
        "places": "Google Places API",
        "ai": "AI recommendations",
        "complete": "Setup complete"
    ]
    
    var body: some View {
        ZStack {
            // Enhanced animated gradient background
            LinearGradient(
                colors: [
                    Color(hex: "#1a1a2e"),
                    Color(hex: "#16213e"), 
                    Color(hex: "#0f3460"),
                    Color(hex: "#16213e").opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3.0), value: animationProgress)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Enhanced app logo with multiple animation layers
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 150, height: 150)
                        .scaleEffect(1.0 + sin(animationProgress * .pi * 4) * 0.15)
                        .opacity(0.7)
                    
                    // Main logo circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(1.0 + sin(animationProgress * .pi * 2) * 0.1)
                    
                    // App icon
                    Image(systemName: "map.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(animationProgress * 180))
                        .scaleEffect(1.0 + sin(animationProgress * .pi * 3) * 0.05)
                }
                .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 10)
                
                // App title with loading text
                VStack(spacing: 12) {
                    Text("PlanIt")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Setting up your personalized experience...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Enhanced loading progress section
                VStack(spacing: 32) {
                    // Overall progress bar
                    if showProgress {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Overall Progress")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text("\(Int(Double(currentStep) / Double(loadingSteps.count) * 100))%")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            ProgressView(value: Double(currentStep), total: Double(loadingSteps.count))
                                .progressViewStyle(EnhancedLinearProgressViewStyle(tint: .blue))
                                .animation(.easeInOut(duration: 0.5), value: currentStep)
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    // Current step with enhanced styling
                    if currentStep < loadingSteps.count {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                // Animated loading indicator
                                ZStack {
                                    Circle()
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                                        .frame(width: 32, height: 32)
                                    
                                    Circle()
                                        .trim(from: 0, to: 0.7)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                        )
                                        .frame(width: 32, height: 32)
                                        .rotationEffect(.degrees(animationProgress * 360))
                                }
                                
                                Text(loadingSteps[currentStep])
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                                
                                Spacer()
                            }
                            
                            // Detailed progress indicators
                            VStack(spacing: 8) {
                                ForEach(Array(detailedSteps.keys.sorted()), id: \.self) { key in
                                    HStack(spacing: 12) {
                                        Image(systemName: detailedProgress[key] == true ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(detailedProgress[key] == true ? .green : .white.opacity(0.5))
                                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: detailedProgress[key])
                                        
                                        Text(detailedSteps[key] ?? "")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(detailedProgress[key] == true ? .white : .white.opacity(0.7))
                                        
                                        Spacer()
                                        
                                        if detailedProgress[key] != true && isCurrentDetailedStep(key) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                                .scaleEffect(0.7)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            startEnhancedLoadingAnimation()
        }
    }
    
    private func isCurrentDetailedStep(_ step: String) -> Bool {
        switch currentStep {
        case 0: return step == "auth"
        case 1: return step == "location"
        case 2: return step == "fingerprint"
        case 3: return step == "places"
        case 4: return step == "ai"
        case 5: return step == "complete"
        default: return false
        }
    }
    
    private func startEnhancedLoadingAnimation() {
        // Start the continuous rotation animation
        withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
            animationProgress = 1.0
        }
        
        // Show progress after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showProgress = true
            }
        }
        
        // Cycle through loading steps with realistic timing
        let stepTimings: [Double] = [1.0, 1.5, 2.0, 3.0, 2.5, 1.0] // Different timing for each step
        var cumulativeTime: Double = 0
        
        for (index, timing) in stepTimings.enumerated() {
            cumulativeTime += timing
            
            DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeTime) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    if index < loadingSteps.count {
                        currentStep = index
                        
                        // Mark previous detailed step as complete
                        if index > 0 {
                            let stepKeys = Array(detailedSteps.keys.sorted())
                            if index - 1 < stepKeys.count {
                                detailedProgress[stepKeys[index - 1]] = true
                            }
                        }
                    }
                }
            }
        }
        
        // Mark final step as complete
        DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeTime + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                detailedProgress["complete"] = true
            }
        }
    }
}

// Enhanced Linear Progress View Style
struct EnhancedLinearProgressViewStyle: ProgressViewStyle {
    let tint: Color
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 6)
                    .cornerRadius(3)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.7), Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0),
                        height: 6
                    )
                    .cornerRadius(3)
                    .animation(.easeInOut(duration: 0.5), value: configuration.fractionCompleted)
                    .overlay(
                        // Shimmer effect
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(3)
                            .scaleEffect(x: 0.3, y: 1)
                            .offset(x: -geometry.size.width)
                            .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: configuration.fractionCompleted)
                    )
            }
        }
    }
}

#Preview {
    LoadingScreen()
} 