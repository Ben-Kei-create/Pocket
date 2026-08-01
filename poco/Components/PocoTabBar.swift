import SwiftUI

struct PocoTabBar: View {
    let selection: AppTab
    let notificationCount: Int
    let onSelect: (AppTab) -> Void

    private let tabs: [AppTab] = [.home, .create, .notifications, .myPage]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.self) { tab in
                PocoTabButton(
                    tab: tab,
                    isSelected: selection == tab,
                    badgeCount: tab == .notifications ? notificationCount : 0,
                    action: { onSelect(tab) }
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.45)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("メインタブ")
    }
}

private struct PocoTabButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tab: AppTab
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? tab.selectedSymbolName : tab.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 34, height: 28)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(PocoTheme.bubble(.pink).opacity(0.7))
                                .frame(width: 42, height: 30)
                        }
                    }
                    .foregroundStyle(isSelected ? PocoTheme.primary : PocoTheme.secondaryText)
                    .scaleEffect(isSelected ? 1.08 : 1)
                    .offset(y: isSelected ? -1 : 0)
                    .symbolEffect(.bounce, value: isSelected)
                    .overlay(alignment: .topTrailing) {
                        if badgeCount > 0 {
                            Text(badgeCount > 99 ? "99+" : badgeCount.formatted())
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .frame(minWidth: 17, minHeight: 17)
                                .background(PocoTheme.primary, in: Capsule())
                                .offset(x: 7, y: -5)
                                .accessibilityHidden(true)
                        }
                    }

                Text(tab.title)
                    .pocoFont(.caption2, weight: isSelected ? .bold : .medium)
                    .foregroundStyle(isSelected ? PocoTheme.primary : PocoTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 49)
            .contentShape(Rectangle())
            .animation(
                reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.68),
                value: isSelected
            )
        }
        .buttonStyle(PocoTabPressStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(
            badgeCount > 0 ? "\(tab.title)、未読\(badgeCount)件" : tab.title
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PocoTabPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.91 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.58),
                value: configuration.isPressed
            )
    }
}

private extension AppTab {
    var title: String {
        switch self {
        case .home: "ホーム"
        case .create: "作る"
        case .myPage: "マイページ"
        case .notifications: "通知"
        }
    }

    var symbolName: String {
        switch self {
        case .home: "house"
        case .create: "plus.circle"
        case .myPage: "person"
        case .notifications: "bell"
        }
    }

    var selectedSymbolName: String {
        switch self {
        case .home: "house.fill"
        case .create: "plus.circle.fill"
        case .myPage: "person.fill"
        case .notifications: "bell.fill"
        }
    }
}
