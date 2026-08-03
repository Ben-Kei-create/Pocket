import SwiftUI

struct PocoPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pocoActionLabelTypography()
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.82))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(
                backgroundColor(isPressed: configuration.isPressed),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.16), value: isEnabled)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else { return PocoTheme.secondaryText.opacity(0.36) }
        return isPressed ? PocoTheme.primaryPressed : PocoTheme.primary
    }
}

struct PocoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pocoActionLabelTypography()
            .foregroundStyle(PocoTheme.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(PocoTheme.primary.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule())
    }
}

extension View {
    /// Keeps action labels readable inside compact iPhone layouts and at larger Dynamic Type sizes.
    func pocoActionLabelTypography() -> some View {
        pocoFont(.callout, weight: .medium)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .allowsTightening(true)
    }
}
