import SwiftUI

// MARK: - Design Palettes

enum PaletteType: String, CaseIterable {
    case zenLight
    case zenNight
}

struct Palette {
    let backgroundGradient: LinearGradient
    let cardBackground: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let favourite: Color
    let glass: Material
}

extension Palette {
    static let zenLight: Palette = Palette(
        backgroundGradient: LinearGradient(colors: [Color(hex: "#f7f8fc"), Color(hex: "#e3e5f1")], startPoint: .topLeading, endPoint: .bottomTrailing),
        cardBackground: Color.white,
        primaryText: Color.black,
        secondaryText: Color.black.opacity(0.6),
        accent: Color(hex: "#0066ff"),
        favourite: Color(hex: "#FF3864"),
        glass: .ultraThinMaterial
    )
    
    static let zenNight: Palette = Palette(
        backgroundGradient: LinearGradient(colors: [Color(hex: "#0f0c29"), Color(hex: "#302b63"), Color(hex: "#24243e")], startPoint: .topLeading, endPoint: .bottomTrailing),
        cardBackground: Color(hex: "#1e1e2e"),
        primaryText: Color.white,
        secondaryText: Color.white.opacity(0.7),
        accent: Color(hex: "#55c1ff"),
        favourite: Color(hex: "#FF6680"),
        glass: .thinMaterial
    )
} 