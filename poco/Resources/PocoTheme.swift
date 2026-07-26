import SwiftUI

enum PocoTheme {
    static let background = Color(uiColor: .systemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemBackground)
    static let primary = Color(red: 1.00, green: 0.47, blue: 0.40)
    static let primaryPressed = Color(red: 0.91, green: 0.35, blue: 0.31)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator)
    static let glassStroke = Color(uiColor: .systemGray4).opacity(0.72)

    static let cornerSmall: CGFloat = 14
    static let cornerMedium: CGFloat = 20
    static let cornerLarge: CGFloat = 30
    static let pagePadding: CGFloat = 20

    static func bubble(_ color: BubbleColor) -> Color {
        switch color {
        case .coral: Color(red: 1.00, green: 0.72, blue: 0.68)
        case .yellow: Color(red: 1.00, green: 0.91, blue: 0.63)
        case .mint: Color(red: 0.72, green: 0.93, blue: 0.83)
        case .blue: Color(red: 0.72, green: 0.90, blue: 0.97)
        case .lavender: Color(red: 0.85, green: 0.79, blue: 0.95)
        case .pink: Color(red: 1.00, green: 0.82, blue: 0.87)
        }
    }
}

extension View {
    func pocoCard(cornerRadius: CGFloat = PocoTheme.cornerMedium) -> some View {
        background(PocoTheme.cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.045), radius: 14, y: 5)
    }
}
