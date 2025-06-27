import SwiftUI

// MARK: - Enhanced Font Configuration with Geist Support
extension Font {
    // Geist font family with SF Pro fallbacks (Updated with correct font names)
    static func geist(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        switch weight {
        case .black:
            return .custom("Geist-Black", size: size).fallback(.system(size: size, weight: .black, design: .default))
        case .heavy:
            return .custom("Geist-ExtraBold", size: size).fallback(.system(size: size, weight: .heavy, design: .default))
        case .bold:
            return .custom("Geist-Bold", size: size).fallback(.system(size: size, weight: .bold, design: .default))
        case .semibold:
            return .custom("Geist-SemiBold", size: size).fallback(.system(size: size, weight: .semibold, design: .default))
        case .medium:
            return .custom("Geist-Medium", size: size).fallback(.system(size: size, weight: .medium, design: .default))
        case .regular:
            return .custom("Geist-Regular", size: size).fallback(.system(size: size, weight: .regular, design: .default))
        case .light:
            return .custom("Geist-Light", size: size).fallback(.system(size: size, weight: .light, design: .default))
        case .thin:
            return .custom("Geist-Thin", size: size).fallback(.system(size: size, weight: .thin, design: .default))
        default:
            return .custom("Geist-Medium", size: size).fallback(.system(size: size, weight: .medium, design: .default))
        }
    }
    
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
    
    // Modern Geist-based typography scale
    static let geistDisplay = Font.geist(32, weight: .bold)
    static let geistTitle = Font.geist(28, weight: .bold)
    static let geistHeadline = Font.geist(24, weight: .semibold)
    static let geistSubheadline = Font.geist(20, weight: .medium)
    static let geistBody = Font.geist(16, weight: .regular)
    static let geistBodyMedium = Font.geist(16, weight: .medium)
    static let geistCallout = Font.geist(15, weight: .medium)
    static let geistCaption = Font.geist(13, weight: .medium)
    static let geistSmall = Font.geist(11, weight: .medium)
    
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

// MARK: - Font Extension for Fallbacks
extension Font {
    func fallback(_ font: Font) -> Font {
        // In real implementation, this would check if the custom font is available
        // For now, return self and fallback to system fonts automatically
        return self
    }
}

// MARK: - Text Modifiers (No negative letter spacing)
extension Text {
    func interStyle(_ font: Font) -> some View {
        self
            .font(font)
            .kerning(0) // No negative spacing
    }
    
    func geistStyle(_ font: Font) -> some View {
        self
            .font(font)
            .kerning(0)
    }
    
    func titleStyle() -> some View {
        self.geistStyle(.geistTitle)
            .foregroundColor(.primary)
    }
    
    func headlineStyle() -> some View {
        self.geistStyle(.geistHeadline)
            .foregroundColor(.primary)
    }
    
    func subheadlineStyle() -> some View {
        self.geistStyle(.geistSubheadline)
            .foregroundColor(.secondary)
    }
    
    func bodyStyle() -> some View {
        self.geistStyle(.geistBody)
            .foregroundColor(.primary)
    }
    
    func captionStyle() -> some View {
        self.geistStyle(.geistCaption)
            .foregroundColor(.secondary)
    }
}

// MARK: - View Extension for Geist Fonts
extension View {
    func geistFont(_ size: CGFloat, weight: Font.Weight = .medium, letterSpacing: CGFloat = 0) -> some View {
        self.font(.geist(size, weight: weight))
            .kerning(letterSpacing)
    }
    
    func interFont(_ size: CGFloat, weight: Font.Weight = .medium, letterSpacing: CGFloat = 0) -> some View {
        self.font(.inter(size, weight: weight))
            .kerning(letterSpacing)
    }
}

// MARK: - Custom Font Styles with Bolder Weights
struct GeistFontStyle {
    static let largeTitle = Font.geist(34, weight: .bold)
    static let title1 = Font.geist(28, weight: .bold)
    static let title2 = Font.geist(22, weight: .bold)
    static let title3 = Font.geist(20, weight: .semibold)
    static let headline = Font.geist(17, weight: .semibold)
    static let body = Font.geist(17, weight: .regular)
    static let callout = Font.geist(16, weight: .medium)
    static let subheadline = Font.geist(15, weight: .medium)
    static let footnote = Font.geist(13, weight: .medium)
    static let caption1 = Font.geist(12, weight: .medium)
    static let caption2 = Font.geist(11, weight: .medium)
}

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