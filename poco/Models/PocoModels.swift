import Foundation

nonisolated struct Creator: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var avatarName: String?
    var avatarURL: URL? = nil
}

nonisolated enum BuiltInAvatar: String, CaseIterable, Identifiable, Codable, Sendable {
    case cat = "PocoAvatarCat"
    case pig = "PocoAvatarPig"
    case bear = "PocoAvatarBear"
    case dog = "PocoAvatarDog"
    case lion = "PocoAvatarLion"

    var id: Self { self }

    var title: String {
        switch self {
        case .cat: "くろねこ"
        case .pig: "こぶた"
        case .bear: "くま"
        case .dog: "こいぬ"
        case .lion: "ライオン"
        }
    }

    var companionAssetName: String {
        switch self {
        case .cat: "PocoCompanionCat"
        case .pig: "PocoCompanionPig"
        case .bear: "PocoCompanionBear"
        case .dog: "PocoCompanionDog"
        case .lion: "PocoCompanionLion"
        }
    }
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
    var senderAvatarName: String? = nil
    var senderAvatarURL: URL? = nil
    var creatorReceivedAt: Date? = nil
}

nonisolated struct CreatorReceipt: Equatable, Sendable {
    let feedbackID: UUID
    let createdAt: Date
}

nonisolated enum FeedbackReportReason: String, CaseIterable, Identifiable, Codable, Sendable {
    case harassment
    case spam
    case personalInformation = "personal_information"
    case sexualOrViolent = "sexual_or_violent"
    case copyright
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .harassment: "嫌がらせ・攻撃的な内容"
        case .spam: "スパム・宣伝"
        case .personalInformation: "個人情報が含まれている"
        case .sexualOrViolent: "性的・暴力的な内容"
        case .copyright: "著作権・権利侵害"
        case .other: "その他"
        }
    }
}

nonisolated extension Feedback {
    var senderCreator: Creator? {
        guard let senderID else { return nil }
        return Creator(
            id: senderID,
            name: nickname,
            avatarName: senderAvatarName,
            avatarURL: senderAvatarURL
        )
    }
}

nonisolated enum MembershipTier: String, Codable, Sendable {
    case guest
    case pocoMember = "poco_member"

    var isMember: Bool { self == .pocoMember }
}

nonisolated enum PocoRole: String, Codable, Sendable {
    case guest
    case user
    case pro

    var title: String {
        switch self {
        case .guest: "Pocoゲスト"
        case .user: "Pocoユーザー"
        case .pro: "Poco Pro"
        }
    }
}

nonisolated struct AppCapabilities: Equatable, Sendable {
    let canCreateProject: Bool
    let maximumProjectCount: Int
    let canSeePopularFeedbacks: Bool
    let canSeeOwnReactionCounts: Bool
    let canUseProReactions: Bool
    let canUseCodeProtectedProjects: Bool
    let canCustomizeProjectTheme: Bool
    let shouldShowAds: Bool

    static func forRole(_ role: PocoRole) -> Self {
        switch role {
        case .guest:
            Self(
                canCreateProject: false,
                maximumProjectCount: 0,
                canSeePopularFeedbacks: false,
                canSeeOwnReactionCounts: false,
                canUseProReactions: false,
                canUseCodeProtectedProjects: false,
                canCustomizeProjectTheme: false,
                shouldShowAds: true
            )
        case .user:
            Self(
                canCreateProject: true,
                maximumProjectCount: 3,
                canSeePopularFeedbacks: false,
                canSeeOwnReactionCounts: false,
                canUseProReactions: false,
                canUseCodeProtectedProjects: false,
                canCustomizeProjectTheme: false,
                shouldShowAds: true
            )
        case .pro:
            Self(
                canCreateProject: true,
                maximumProjectCount: 30,
                canSeePopularFeedbacks: true,
                canSeeOwnReactionCounts: true,
                canUseProReactions: true,
                canUseCodeProtectedProjects: true,
                canCustomizeProjectTheme: true,
                shouldShowAds: false
            )
        }
    }
}

nonisolated enum AccountStatus: String, Codable, Sendable {
    case guest
    case registered

    var canCreateProjects: Bool { self == .registered }
}

nonisolated struct AuthenticatedAccount: Equatable, Sendable {
    let id: UUID
    let displayName: String?
}

nonisolated struct AppleIdentityCredential: Sendable {
    let identityToken: String
    let rawNonce: String
    let displayName: String?
}

nonisolated enum AuthenticationState: Equatable, Sendable {
    case idle
    case authenticating
    case authenticated
    case error(String)
}

nonisolated struct MemberLikeSummary: Equatable, Sendable {
    let projectLikes: Int
    let feedbackLikes: Int
}

nonisolated struct MembershipOffer: Equatable, Sendable {
    let productID: String
    let displayPrice: String
}

nonisolated enum MembershipPurchaseResult: Sendable {
    case purchased(MembershipEntitlement)
    case pending
    case cancelled
}

nonisolated struct MembershipEntitlement: Equatable, Sendable {
    let productID: String
    let originalTransactionID: String
    let signedTransactionInfo: String
}

nonisolated enum MembershipSyncState: Equatable, Sendable {
    case idle
    case syncing
    case synced
    case deferred
}

nonisolated enum MembershipPurchaseState: Equatable, Sendable {
    case idle
    case loading
    case purchasing
    case purchased
    case error(String)
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
