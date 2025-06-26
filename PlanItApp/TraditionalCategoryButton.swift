import SwiftUI
import CoreLocation

/// Traditional category button for navigation to category detail view
struct TraditionalCategoryButton: View {
    let category: PlaceCategory
    let locationManager: LocationManager
    let selectedRadius: Double
    
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink(destination: EnhancedCategoryDetailView(
            category: category,
            locationManager: locationManager,
            selectedRadius: selectedRadius
        )) {
            HStack(spacing: 16) {
                // Category icon
                Image(systemName: category.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color(hex: category.color))
                    )
                
                // Category info
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Explore \(category.rawValue.lowercased())")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: category.color).opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
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