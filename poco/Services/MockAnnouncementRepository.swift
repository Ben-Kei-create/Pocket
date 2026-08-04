import Foundation

actor MockAnnouncementRepository: AnnouncementRepository {
    private let announcements: [AppAnnouncement]

    init(announcements: [AppAnnouncement]? = nil) {
        self.announcements = announcements ?? [
            AppAnnouncement(
                id: UUID(uuidString: "70000000-0000-0000-0000-000000000001")!,
                kind: .update,
                title: "フキダシがもっと、ぽよんと動くようになりました",
                message: "フキダシ同士が触れたときの傾きと、やわらかな揺れを調整しました。",
                publishedAt: .now.addingTimeInterval(-3_600)
            ),
            AppAnnouncement(
                id: UUID(uuidString: "70000000-0000-0000-0000-000000000002")!,
                kind: .news,
                title: "Pocoへようこそ",
                message: "運営からのお知らせや、新しく追加した機能をここでお伝えします。",
                publishedAt: .now.addingTimeInterval(-86_400 * 3)
            )
        ]
    }

    func fetchPublishedAnnouncements() async throws -> [AppAnnouncement] {
        announcements.sorted { $0.publishedAt > $1.publishedAt }
    }
}
