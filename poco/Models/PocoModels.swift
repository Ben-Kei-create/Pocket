import Foundation

nonisolated struct Creator: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var avatarName: String?
    var avatarURL: URL? = nil
}

nonisolated struct Project: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var creator: Creator
    var category: ProjectCategory
    var description: String
    var imageName: String?
    var imageURL: URL? = nil
    var feedbackCount: Int
    let createdAt: Date
}

nonisolated enum ProjectCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case book
    case game
    case manga
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .book: "本"
        case .game: "ゲーム"
        case .manga: "マンガ"
        case .other: "その他"
        }
    }

    var creatorPrefix: String {
        self == .game ? "開発" : "作"
    }

    var symbolName: String {
        switch self {
        case .book: "book.closed.fill"
        case .game: "gamecontroller.fill"
        case .manga: "text.bubble.fill"
        case .other: "sparkles"
        }
    }

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .other
    }
}

nonisolated struct Feedback: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let projectID: UUID
    var message: String
    var nickname: String
    var isPublic: Bool
    let createdAt: Date
    var likes: Int
    let bubbleColor: BubbleColor
    var senderID: UUID? = nil
}

nonisolated enum MembershipTier: String, Codable, Sendable {
    case guest
    case pocoMember = "poco_member"

    var isMember: Bool { self == .pocoMember }
}

nonisolated struct MemberLikeSummary: Equatable, Sendable {
    let projectLikes: Int
    let feedbackLikes: Int
}

nonisolated enum BubbleColor: String, CaseIterable, Codable, Sendable {
    case coral
    case yellow
    case mint
    case blue
    case lavender
    case pink

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .coral
    }
}
