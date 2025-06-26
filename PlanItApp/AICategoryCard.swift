import SwiftUI

/// AI-powered category card with dynamic content
struct AICategoryCard: View {
    let category: PlaceCategory
    
    @State private var isPressed = false
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 16) {
            // AI Icon with category icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [
                            Color(hex: category.color),
                            Color(hex: category.color).opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                
                Image(systemName: category.iconName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Category name
            Text(category.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            // AI subtitle
            Text("AI Curated")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: category.color))
        }
        .frame(width: 120, height: 140)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: category.color).opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .offset(x: animationOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animationOffset)
        .onAppear {
            // Subtle floating animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animationOffset = 2
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isPressed = false
                }
            }
        }
    }
} 