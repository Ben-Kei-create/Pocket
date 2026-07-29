import SwiftUI

struct PocoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pocoFont(.headline, weight: .medium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(
                configuration.isPressed ? PocoTheme.primaryPressed : PocoTheme.primary,
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PocoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pocoFont(.headline, weight: .medium)
            .foregroundStyle(PocoTheme.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(PocoTheme.primary.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule())
    }
}
