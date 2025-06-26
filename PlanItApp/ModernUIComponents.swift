import SwiftUI
import UIKit

// MARK: - Modern Social Media Inspired Theme
struct ModernSocialTheme {
    
    // MARK: - Color Palette
    struct Colors {
        // Primary Colors (TikTok-inspired)
        static let primaryPink = Color(hex: "#FE2C55")
        static let primaryBlue = Color(hex: "#25F4EE")
        static let primaryPurple = Color(hex: "#8B5CF6")
        
        // Instagram-inspired gradients
        static let instagramGradient = LinearGradient(
            colors: [Color(hex: "#833AB4"), Color(hex: "#FD1D1D"), Color(hex: "#FCB045")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let modernGradient = LinearGradient(
            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Dark Mode Colors
        static let darkBackground = Color(hex: "#000000")
        static let darkSecondary = Color(hex: "#161823")
        static let darkCard = Color(hex: "#1F1F23")
        static let darkBorder = Color(hex: "#2F2F2F")
        
        // Light Mode Colors
        static let lightBackground = Color(hex: "#FFFFFF")
        static let lightSecondary = Color(hex: "#F8F9FA")
        static let lightCard = Color(hex: "#FFFFFF")
        static let lightBorder = Color(hex: "#E5E5E5")
        
        // Text Colors
        static let primaryText = Color(hex: "#FFFFFF")
        static let secondaryText = Color(hex: "#A0A0A0")
        static let tertiaryText = Color(hex: "#666666")
        
        // Accent Colors
        static let successGreen = Color(hex: "#00D4AA")
        static let warningOrange = Color(hex: "#FF6B35")
        static let errorRed = Color(hex: "#FF3B30")
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)
        static let callout = Font.system(size: 16, weight: .regular, design: .rounded)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .rounded)
        static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
        static let pill: CGFloat = 50
    }
}

// MARK: - Modern Card View
struct ModernCard<Content: View>: View {
    let content: Content
    let backgroundColor: Color?
    let cornerRadius: CGFloat
    let shadowEnabled: Bool
    
    init(
        backgroundColor: Color? = nil,
        cornerRadius: CGFloat = ModernSocialTheme.CornerRadius.large,
        shadowEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowEnabled = shadowEnabled
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor ?? .adaptiveCard)
                    .shadow(
                        color: shadowEnabled ? Color.black.opacity(0.1) : Color.clear,
                        radius: shadowEnabled ? 10 : 0,
                        x: 0,
                        y: shadowEnabled ? 5 : 0
                    )
            )
    }
}

// MARK: - Modern Button Styles
struct ModernPrimaryButton: ButtonStyle {
    let isLoading: Bool
    let gradient: LinearGradient
    
    init(isLoading: Bool = false, gradient: LinearGradient = ModernSocialTheme.Colors.instagramGradient) {
        self.isLoading = isLoading
        self.gradient = gradient
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ModernSocialTheme.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ModernSocialTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                    .fill(gradient)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .overlay(
                RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

struct ModernSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ModernSocialTheme.Typography.headline)
            .foregroundColor(.adaptivePrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ModernSocialTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                    .fill(Color.adaptiveSecondary)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                    .stroke(Color.adaptiveBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Modern Navigation Bar
struct ModernNavigationBar: View {
    let title: String
    let subtitle: String?
    let leadingAction: (() -> Void)?
    let trailingAction: (() -> Void)?
    let leadingIcon: String?
    let trailingIcon: String?
    
    init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: String? = nil,
        trailingIcon: String? = nil,
        leadingAction: (() -> Void)? = nil,
        trailingAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.leadingAction = leadingAction
        self.trailingAction = trailingAction
    }
    
    var body: some View {
        HStack {
            // Leading button
            if let leadingIcon = leadingIcon, let leadingAction = leadingAction {
                Button(action: leadingAction) {
                    Image(systemName: leadingIcon)
                        .font(.title2)
                        .foregroundColor(.adaptivePrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.adaptiveSecondary))
                }
            } else {
                Spacer()
                    .frame(width: 44)
            }
            
            Spacer()
            
            // Title and subtitle
            VStack(spacing: 2) {
                Text(title)
                    .font(ModernSocialTheme.Typography.headline)
                    .foregroundColor(.adaptivePrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(ModernSocialTheme.Typography.caption)
                        .foregroundColor(.adaptiveSecondary)
                }
            }
            
            Spacer()
            
            // Trailing button
            if let trailingIcon = trailingIcon, let trailingAction = trailingAction {
                Button(action: trailingAction) {
                    Image(systemName: trailingIcon)
                        .font(.title2)
                        .foregroundColor(.adaptivePrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.adaptiveSecondary))
                }
            } else {
                Spacer()
                    .frame(width: 44)
            }
        }
        .padding(.horizontal, ModernSocialTheme.Spacing.md)
        .padding(.vertical, ModernSocialTheme.Spacing.sm)
    }
}

// MARK: - Modern Loading Animation
struct ModernLoadingView: View {
    @State private var rotation: Double = 0
    
    let size: CGFloat
    let colors: [Color]
    
    init(size: CGFloat = 40, colors: [Color] = [ModernSocialTheme.Colors.primaryPink, ModernSocialTheme.Colors.primaryBlue]) {
        self.size = size
        self.colors = colors
    }
    
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.8)
                .stroke(
                    AngularGradient(
                        colors: colors,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        }
    }
}

// MARK: - Modern Search Bar
struct ModernSearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    let placeholder: String
    let onSearchButtonClicked: (() -> Void)?
    
    init(text: Binding<String>, placeholder: String = "Search...", onSearchButtonClicked: (() -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.onSearchButtonClicked = onSearchButtonClicked
    }
    
    var body: some View {
        HStack(spacing: ModernSocialTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.adaptiveSecondary)
                .font(.system(size: 16, weight: .medium))
            
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .font(ModernSocialTheme.Typography.body)
                .foregroundColor(.adaptivePrimary)
                .onSubmit {
                    onSearchButtonClicked?()
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.adaptiveSecondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, ModernSocialTheme.Spacing.md)
        .padding(.vertical, ModernSocialTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                .fill(Color.adaptiveSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                        .stroke(isFocused ? ModernSocialTheme.Colors.primaryPink : Color.adaptiveBorder, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Modern Tag/Chip View
struct ModernTag: View {
    let text: String
    let isSelected: Bool
    let onTap: (() -> Void)?
    
    init(text: String, isSelected: Bool = false, onTap: (() -> Void)? = nil) {
        self.text = text
        self.isSelected = isSelected
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            Text(text)
                .font(ModernSocialTheme.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .adaptivePrimary)
                .padding(.horizontal, ModernSocialTheme.Spacing.md)
                .padding(.vertical, ModernSocialTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.pill)
                        .fill(isSelected ? ModernSocialTheme.Colors.primaryPink : Color.adaptiveSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.pill)
                        .stroke(isSelected ? Color.clear : Color.adaptiveBorder, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Color Extensions for Adaptive Colors
extension Color {
    @Environment(\.colorScheme) static var colorScheme
    
    static var adaptiveBackground: Color {
        return Color(.systemBackground)
    }
    
    static var adaptiveSecondary: Color {
        return Color(.secondarySystemBackground)
    }
    
    static var adaptiveCard: Color {
        return Color(.systemBackground)
    }
    
    static var adaptivePrimary: Color {
        return Color(.label)
    }
    
    static var adaptiveBorder: Color {
        return Color(.separator)
    }
}

// MARK: - Modern Grid Layout
struct ModernGridLayout<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    let content: Content
    
    init(columns: Int = 2, spacing: CGFloat = ModernSocialTheme.Spacing.md, @ViewBuilder content: () -> Content) {
        self.columns = columns
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            content
        }
    }
}

// MARK: - Modern Rating View
struct ModernRatingView: View {
    let rating: Double
    let maxRating: Int = 5
    let size: CGFloat
    let color: Color
    
    init(rating: Double, size: CGFloat = 14, color: Color = ModernSocialTheme.Colors.warningOrange) {
        self.rating = rating
        self.size = size
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maxRating, id: \.self) { index in
                Image(systemName: starType(for: index))
                    .foregroundColor(color)
                    .font(.system(size: size, weight: .bold))
            }
        }
    }
    
    private func starType(for index: Int) -> String {
        let starValue = Double(index) + 1
        if rating >= starValue {
            return "star.fill"
        } else if rating > Double(index) {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
} 