import Foundation

nonisolated enum AppAnnouncementKind: String, Codable, CaseIterable, Sendable {
    case news
    case update
    case maintenance

    var title: String {
        switch self {
        case .news: "お知らせ"
        case .update: "アップデート"
        case .maintenance: "メンテナンス"
        }
    }

    var symbolName: String {
        switch self {
        case .news: "megaphone.fill"
        case .update: "sparkles"
        case .maintenance: "wrench.and.screwdriver.fill"
        }
    }
}

nonisolated struct AppAnnouncement: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: AppAnnouncementKind
    let title: String
    let message: String
    let publishedAt: Date
}

nonisolated struct AppAnnouncementDTO: Decodable, Sendable {
    let id: UUID
    let kind: String
    let title: String
    let message: String
    let publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case message
        case publishedAt = "published_at"
    }

    var domainModel: AppAnnouncement {
        AppAnnouncement(
            id: id,
            kind: AppAnnouncementKind(rawValue: kind) ?? .news,
            title: title,
            message: message,
            publishedAt: publishedAt
        )
    }
}
