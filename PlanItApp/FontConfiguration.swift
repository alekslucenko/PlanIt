import SwiftUI

// MARK: - Font Configuration
extension Font {
    static func inter(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        switch weight {
        case .black:
            return .custom("Inter-Black", size: size)
        case .heavy:
            return .custom("Inter-ExtraBold", size: size)
        case .bold:
            return .custom("Inter-Bold", size: size)
        case .semibold:
            return .custom("Inter-SemiBold", size: size)
        case .medium:
            return .custom("Inter-Medium", size: size)
        case .regular:
            return .custom("Inter-Regular", size: size)
        case .light:
            return .custom("Inter-Light", size: size)
        case .thin:
            return .custom("Inter-Thin", size: size)
        default:
            return .custom("Inter-Medium", size: size)
        }
    }
    
    // Production-ready typography scale with proper weights
    static let interTitleBold = Font.inter(28, weight: .bold)
    static let interHeadlineBold = Font.inter(24, weight: .bold)
    static let interSubheadlineSemiBold = Font.inter(20, weight: .semibold)
    static let interBodyMedium = Font.inter(16, weight: .medium)
    static let interBodyRegular = Font.inter(16, weight: .regular)
    static let interCaptionMedium = Font.inter(14, weight: .medium)
    static let interCaptionRegular = Font.inter(14, weight: .regular)
    static let interSmallMedium = Font.inter(12, weight: .medium)
    static let interSmallRegular = Font.inter(12, weight: .regular)
}

// MARK: - Text Modifiers (No negative letter spacing)
extension Text {
    func interStyle(_ font: Font) -> some View {
        self
            .font(font)
            .kerning(0) // No negative spacing
    }
    
    func titleStyle() -> some View {
        self.interStyle(.interTitleBold)
            .foregroundColor(.primary)
    }
    
    func headlineStyle() -> some View {
        self.interStyle(.interHeadlineBold)
            .foregroundColor(.primary)
    }
    
    func subheadlineStyle() -> some View {
        self.interStyle(.interSubheadlineSemiBold)
            .foregroundColor(.secondary)
    }
    
    func bodyStyle() -> some View {
        self.interStyle(.interBodyMedium)
            .foregroundColor(.primary)
    }
    
    func captionStyle() -> some View {
        self.interStyle(.interCaptionMedium)
            .foregroundColor(.secondary)
    }
}

// MARK: - View Extension for Inter Fonts (No negative letter spacing)
extension View {
    func interFont(_ size: CGFloat, weight: Font.Weight = .medium, letterSpacing: CGFloat = 0) -> some View {
        self.font(.inter(size, weight: weight))
            .kerning(letterSpacing)
    }
}

// MARK: - Custom Font Styles with Bolder Weights
struct InterFontStyle {
    static let largeTitle = Font.inter(34, weight: .black)
    static let title1 = Font.inter(28, weight: .bold)
    static let title2 = Font.inter(22, weight: .bold)
    static let title3 = Font.inter(20, weight: .bold)
    static let headline = Font.inter(17, weight: .bold)
    static let body = Font.inter(17, weight: .medium)
    static let callout = Font.inter(16, weight: .medium)
    static let subheadline = Font.inter(15, weight: .medium)
    static let footnote = Font.inter(13, weight: .medium)
    static let caption1 = Font.inter(12, weight: .medium)
    static let caption2 = Font.inter(11, weight: .medium)
} 