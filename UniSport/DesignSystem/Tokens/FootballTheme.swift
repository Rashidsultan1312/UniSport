import SwiftUI

enum FootballColors {
    static let background = Color(hex: "#F6FBF7")
    static let accent = Color(hex: "#1E9E43")
    static let textPrimary = Color(hex: "#17321E")
    static let textSecondary = Color(hex: "#4F6A57")
    static let surfacePrimary = Color(hex: "#FFFFFF")
    static let surfaceSecondary = Color(hex: "#EEF8F0")
    static let surfaceTertiary = Color(hex: "#D7ECD9")
    static let divider = Color(hex: "#DCECDF")
    static let warning = Color(hex: "#F5B700")
    static let danger = Color(hex: "#E04F5F")
    static let info = Color(hex: "#4B8BF4")
}

enum FootballSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let hero: CGFloat = 32
}

enum FootballRadius {
    static let standard: CGFloat = 12
    static let card: CGFloat = 16
    static let modal: CGFloat = 20
    static let hero: CGFloat = 24
}

enum FootballTypography {
    static let hero = Font.system(size: 32, weight: .bold, design: .rounded)
    static let title = Font.system(size: 24, weight: .bold, design: .rounded)
    static let section = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let cardTitle = Font.system(size: 18, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let caption = Font.system(size: 13, weight: .medium)
    static let tiny = Font.system(size: 11, weight: .semibold)
}

extension Color {
    init(hex: String) {
        let hex = hex.replacingOccurrences(of: "#", with: "")
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

struct FootballCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(FootballSpacing.lg)
            .background(FootballColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: FootballRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FootballRadius.card, style: .continuous)
                    .stroke(FootballColors.divider, lineWidth: 1)
            )
    }
}

extension View {
    func footballCardStyle() -> some View {
        modifier(FootballCardModifier())
    }
}
