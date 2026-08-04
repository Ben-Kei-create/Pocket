import SwiftUI
import UIKit

enum PocoFontWeight: Sendable {
    case regular
    case medium
    case bold

    fileprivate var postScriptName: String {
        switch self {
        case .regular:
            "ZenMaruGothic-Regular"
        case .medium:
            "ZenMaruGothic-Medium"
        case .bold:
            "ZenMaruGothic-Bold"
        }
    }

    fileprivate var systemWeight: UIFont.Weight {
        switch self {
        case .regular:
            .regular
        case .medium:
            .medium
        case .bold:
            .bold
        }
    }
}

enum PocoTypography {
    static let familyName = "Zen Maru Gothic"
    static let licenseName = "SIL Open Font License 1.1"

    static func font(
        _ style: Font.TextStyle,
        weight: PocoFontWeight = .regular
    ) -> Font {
        .custom(
            weight.postScriptName,
            size: baseSize(for: style),
            relativeTo: style
        )
    }

    static func fixed(
        size: CGFloat,
        weight: PocoFontWeight = .regular
    ) -> Font {
        .custom(weight.postScriptName, fixedSize: size)
    }

    static func uiFont(
        size: CGFloat,
        weight: PocoFontWeight = .regular
    ) -> UIFont {
        UIFont(name: weight.postScriptName, size: size)
            ?? .systemFont(ofSize: size, weight: weight.systemWeight)
    }

    private static func baseSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle:
            34
        case .title:
            28
        case .title2:
            22
        case .title3:
            20
        case .headline, .body:
            17
        case .callout:
            16
        case .subheadline:
            15
        case .footnote:
            13
        case .caption:
            12
        case .caption2:
            11
        @unknown default:
            17
        }
    }
}

extension View {
    func pocoFont(
        _ style: Font.TextStyle,
        weight: PocoFontWeight = .regular
    ) -> some View {
        font(PocoTypography.font(style, weight: weight))
    }

    func pocoFixedFont(
        size: CGFloat,
        weight: PocoFontWeight = .regular
    ) -> some View {
        font(PocoTypography.fixed(size: size, weight: weight))
    }
}
