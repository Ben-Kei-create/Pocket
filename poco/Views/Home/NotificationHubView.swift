import SwiftUI

struct NotificationHubView: View {
    @Environment(PocoStore.self) private var store
    @State private var selectedSection = NotificationHubSection.words
    @AppStorage("poco.announcements.lastSeenAt") private var lastSeenAnnouncementTimestamp = 0.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("通知の種類", selection: $selectedSection) {
                    ForEach(NotificationHubSection.allCases) { section in
                        Text(section.titleWithCount(
                            words: store.unreadNotificationCount,
                            announcements: unreadAnnouncementCount
                        ))
                        .tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, PocoTheme.pagePadding)
                .padding(.vertical, 12)
                .accessibilityHint("届いたことばと運営からのお知らせを切り替えます")

                Group {
                    switch selectedSection {
                    case .words:
                        NotificationCenterView(showsNavigationChrome: false)
                            .transition(.opacity)
                    case .announcements:
                        AnnouncementCenterView(showsNavigationChrome: false)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(PocoTheme.background)
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.18), value: selectedSection)
        }
    }

    private var unreadAnnouncementCount: Int {
        store.announcements.lazy.filter {
            $0.publishedAt.timeIntervalSince1970 > lastSeenAnnouncementTimestamp
        }.count
    }
}

private enum NotificationHubSection: String, CaseIterable, Identifiable {
    case words
    case announcements

    var id: String { rawValue }

    func titleWithCount(words: Int, announcements: Int) -> String {
        let title: String
        let count: Int
        switch self {
        case .words:
            title = "届いたことば"
            count = words
        case .announcements:
            title = "お知らせ"
            count = announcements
        }
        return count > 0 ? "\(title) \(count)" : title
    }
}
