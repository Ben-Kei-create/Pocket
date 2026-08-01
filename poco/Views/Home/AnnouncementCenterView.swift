import SwiftUI

struct AnnouncementCenterView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("poco.announcements.lastSeenAt") private var lastSeenTimestamp = 0.0
    let showsNavigationChrome: Bool

    init(showsNavigationChrome: Bool = true) {
        self.showsNavigationChrome = showsNavigationChrome
    }

    var body: some View {
        Group {
            if showsNavigationChrome {
                NavigationStack {
                    content
                        .navigationTitle("お知らせ")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("閉じる", action: dismiss.callAsFunction)
                            }
                        }
                }
            } else {
                content
            }
        }
        .task {
            await store.loadAnnouncements()
            markAllAsSeen()
        }
        .onDisappear(perform: markAllAsSeen)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if store.announcementLoadState == .loading && store.announcements.isEmpty {
                ProgressView("お知らせを読み込んでいます")
            } else if case .error = store.announcementLoadState,
                      store.announcements.isEmpty {
                VStack(spacing: 0) {
                    PocoCharacterView(
                        size: 120,
                        expression: .worried,
                        isInteractive: false
                    )
                    ContentUnavailableView {
                        Label("読み込めませんでした", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("通信環境を確認して、もう一度お試しください。")
                    } actions: {
                        Button("もう一度試す") {
                            Task {
                                await store.loadAnnouncements()
                                markAllAsSeen()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PocoTheme.primary)
                    }
                }
            } else if store.announcements.isEmpty {
                VStack(spacing: 0) {
                    PocoCharacterView(
                        size: 124,
                        expression: .sleep,
                        isInteractive: false
                    )
                    ContentUnavailableView {
                        Label("新しいお知らせはありません", systemImage: "megaphone")
                    } description: {
                        Text("アップデートやPoco運営からのメッセージをここでお届けします。")
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(store.announcements) { announcement in
                            AnnouncementCard(announcement: announcement)
                        }
                    }
                    .padding(PocoTheme.pagePadding)
                }
                .refreshable {
                    await store.loadAnnouncements()
                    markAllAsSeen()
                }
            }
        }
        .background(PocoTheme.groupedBackground)
    }

    private func markAllAsSeen() {
        guard let latest = store.announcements.map(\.publishedAt).max() else { return }
        lastSeenTimestamp = max(lastSeenTimestamp, latest.timeIntervalSince1970)
    }
}

private struct AnnouncementCard: View {
    let announcement: AppAnnouncement

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(announcement.kind.title, systemImage: announcement.kind.symbolName)
                    .pocoFont(.caption, weight: .bold)
                    .foregroundStyle(PocoTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PocoTheme.bubble(kindColor).opacity(0.72), in: Capsule())
                Spacer()
                Text(announcement.publishedAt, style: .date)
                    .pocoFont(.caption2)
                    .foregroundStyle(PocoTheme.tertiaryText)
            }

            Text(announcement.title)
                .pocoFont(.headline, weight: .bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(announcement.message)
                .pocoFont(.subheadline)
                .foregroundStyle(PocoTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(17)
        .pocoCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(announcement.kind.title)、\(announcement.title)、\(announcement.message)"
        )
    }

    private var kindColor: BubbleColor {
        switch announcement.kind {
        case .news: .pink
        case .update: .yellow
        case .maintenance: .blue
        }
    }
}
