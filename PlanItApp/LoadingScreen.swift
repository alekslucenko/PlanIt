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
    
    let loadingSteps = [
        "Getting your location...",
        "Finding amazing places nearby...",
        "Personalizing recommendations...",
        "Almost ready!"
    ]
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color(hex: "#1a1a2e"),
                    Color(hex: "#16213e"),
                    Color(hex: "#0f3460")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2.0), value: animationProgress)
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo/Icon with pulse animation
                ZStack {
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
                    
                    Image(systemName: "location.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(animationProgress * 360))
                }
                .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 10)
                
                // App title
                VStack(spacing: 8) {
                    Text("PlanIt")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Discovering amazing places...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Loading progress section
                VStack(spacing: 24) {
                    // Progress bar
                    if showProgress {
                        VStack(spacing: 12) {
                            ProgressView(value: animationProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .scaleEffect(y: 2)
                                .animation(.easeInOut(duration: 0.5), value: animationProgress)
                            
                            Text("\(Int(animationProgress * 100))%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    // Current step indicator
                    if currentStep < loadingSteps.count {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                            
                            Text(loadingSteps[currentStep])
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .animation(.easeInOut(duration: 0.3), value: currentStep)
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
            startLoadingAnimation()
        }
    }
    
    private func startLoadingAnimation() {
        // Start the continuous rotation animation
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            animationProgress = 1.0
        }
        
        // Show progress after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showProgress = true
            }
        }
        
        // Cycle through loading steps
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.5)) {
                if currentStep < loadingSteps.count - 1 {
                    currentStep += 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}

// Custom Linear Progress View Style
struct LinearProgressViewStyle: ProgressViewStyle {
    let tint: Color
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0),
                        height: 4
                    )
                    .cornerRadius(2)
                    .animation(.easeInOut(duration: 0.5), value: configuration.fractionCompleted)
            }
        }
    }
}

#Preview {
    LoadingScreen()
} 