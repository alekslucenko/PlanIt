import SwiftUI

// MARK: - Futuristic Tab Bar for Travel App
struct FuturisticTabBar: View {
    @Binding var selectedTab: TabItem
    @Binding var showTabBar: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var hapticManager = HapticManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(TabItem.allCases.enumerated()), id: \.element) { index, tab in
                ProfessionalTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                        hapticManager.lightImpact()
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            // IMPROVED Main background with better contrast
            RoundedRectangle(cornerRadius: 28)
                .fill(themeManager.professionalTabBarGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            themeManager.isDarkMode ? 
                            Color.white.opacity(0.15) : 
                            Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: themeManager.isDarkMode ? Color.black.opacity(0.4) : Color.black.opacity(0.15),
            radius: themeManager.isDarkMode ? 16 : 8,
            x: 0,
            y: themeManager.isDarkMode ? 8 : 4
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - ENHANCED Professional Tab Button with Neon Glow
struct ProfessionalTabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // NEON GLOW BACKGROUND - New implementation
                    if isSelected {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        themeManager.colorForCategory(tab.rawValue).opacity(0.8),
                                        themeManager.colorForCategory(tab.rawValue).opacity(0.4),
                                        themeManager.colorForCategory(tab.rawValue).opacity(0.1)
                                    ],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                            .blur(radius: 2)
                            .animation(.easeInOut(duration: 0.3), value: isSelected)
                    }
                    
                    // Enhanced icon with better contrast
                    Image(systemName: isSelected ? tab.iconName : tab.iconNameUnselected)
                        .font(.system(size: 22, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(
                            isSelected ? 
                            .white : 
                            themeManager.tabBarInactiveText
                        )
                        .scaleEffect(isPressed ? 0.9 : (isSelected ? 1.1 : 1.0))
                        .animation(.easeInOut(duration: 0.15), value: isPressed)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
                        .shadow(
                            color: isSelected ? themeManager.colorForCategory(tab.rawValue).opacity(0.8) : .clear,
                            radius: isSelected ? 8 : 0,
                            x: 0,
                            y: 0
                        )
                }
                
                // Enhanced tab label with better typography
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(
                        isSelected ? 
                        themeManager.colorForCategory(tab.rawValue) : 
                        themeManager.tabBarInactiveText
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                    .shadow(
                        color: isSelected ? themeManager.colorForCategory(tab.rawValue).opacity(0.6) : .clear,
                        radius: isSelected ? 4 : 0,
                        x: 0,
                        y: 0
                    )
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Enhanced Tab Bar Implementation
// HapticManager is now imported from AppModels.swift to avoid duplication

// MARK: - Legacy Compatibility
// Removed typealias to fix redeclaration error 