import Foundation

nonisolated struct Creator: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var avatarName: String?
    var avatarURL: URL? = nil
    var handle: String? = nil
}

nonisolated enum CreatorHandle {
    static let minimumLength = 3
    static let maximumLength = 24

    static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("@")
            .lowercased()
    }

    static func isValid(_ value: String) -> Bool {
        let normalized = normalize(value)
        guard normalized.count >= minimumLength,
              normalized.count <= maximumLength else { return false }
        return normalized.unicodeScalars.allSatisfy { scalar in
            (97...122).contains(scalar.value)
                || (48...57).contains(scalar.value)
                || scalar.value == 95
        }
    }

    static func generated(for id: UUID) -> String {
        "poco_" + id.uuidString
            .replacingOccurrences(of: "-", with: "")
            .prefix(12)
            .lowercased()
    }
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

nonisolated enum RareCompanionKind: String, CaseIterable, Sendable {
    case cat = "PocoRareCat"
    case pig = "PocoRarePig"
    case bear = "PocoRareBear"
    case dog = "PocoRareDog"
    case lion = "PocoRareLion"
    case mouse = "PocoRareMouse"
    case rabbit = "PocoRareRabbit"
    case goat = "PocoRareGoat"

    static func born(from avatar: BuiltInAvatar, eventKey: String) -> Self {
        let secretKinds: [Self] = [.mouse, .rabbit, .goat]
        let seed = pocoStableSeed(eventKey)
        if seed % 5 == 0 {
            return secretKinds[seed % secretKinds.count]
        }
        return switch avatar {
        case .cat: Self.cat
        case .pig: Self.pig
        case .bear: Self.bear
        case .dog: Self.dog
        case .lion: Self.lion
        }
    }
}

nonisolated func pocoStableSeed(_ value: String) -> Int {
    value.unicodeScalars.reduce(0) { partial, scalar in
        (partial &* 31 &+ Int(scalar.value)) & 0x7fff_ffff
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
    var relationship: ProjectRelationship = .creator
    var verificationStatus: ProjectVerificationStatus = .unverified
    var contentRating: ProjectContentRating = .general
    var isContentLocked: Bool = false
}

nonisolated enum ProjectContentRating: String, CaseIterable, Identifiable, Codable, Sendable {
    case general
    case mature

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "一般向け"
        case .mature: "成人向けの可能性あり"
        }
    }

    var explanation: String {
        switch self {
        case .general: "幅広い人が安心して閲覧できる内容です"
        case .mature: "刺激の強い表現を含む可能性があります。露骨な性的表現は登録できません"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "checkmark.shield"
        case .mature: "eye.slash"
        }
    }
}

nonisolated enum ProjectRelationship: String, CaseIterable, Identifiable, Codable, Sendable {
    case creator
    case authorized
    case fan
    case event

    var id: Self { self }

    var title: String {
        switch self {
        case .creator: "制作者本人"
        case .authorized: "許可を得ている"
        case .fan: "ファンの感想箱"
        case .event: "イベント・頒布用"
        }
    }

    var explanation: String {
        switch self {
        case .creator: "私または所属チームが制作した作品です"
        case .authorized: "権利者・制作関係者から登録の許可を得ています"
        case .fan: "作品を応援するための非公式な感想箱です"
        case .event: "イベントや頒布の場で感想を集めるページです"
        }
    }

    var symbolName: String {
        switch self {
        case .creator: "person.crop.circle.badge.checkmark"
        case .authorized: "checkmark.seal"
        case .fan: "heart.circle"
        case .event: "ticket"
        }
    }

    func badgeTitle(verificationStatus: ProjectVerificationStatus) -> String {
        if verificationStatus == .verified {
            return switch self {
            case .creator, .authorized: "公式クリエイター"
            case .fan: "ファンの感想箱・非公式"
            case .event: "イベント感想箱・確認済み"
            }
        }
        return switch self {
        case .creator: "制作者として登録・未確認"
        case .authorized: "許諾済みとして登録・未確認"
        case .fan: "ファンの感想箱・非公式"
        case .event: "イベント感想箱・未確認"
        }
    }
}

nonisolated enum ProjectVerificationStatus: String, Codable, Sendable {
    case unverified
    case pending
    case verified
}

nonisolated enum PocoPublishingRules {
    static let currentVersion = 1
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
    var senderHandle: String? = nil
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

nonisolated enum RightsHolderRelationship: String, CaseIterable, Identifiable, Codable, Sendable {
    case rightsHolder = "rights_holder"
    case authorizedRepresentative = "authorized_representative"
    case creator
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .rightsHolder: "権利者本人"
        case .authorizedRepresentative: "権利者の代理人"
        case .creator: "作品の制作者・関係者"
        case .other: "その他"
        }
    }
}

nonisolated struct RightsHolderRequest: Sendable {
    let projectID: UUID
    let requesterName: String
    let requesterEmail: String
    let relationship: RightsHolderRelationship
    let details: String
}

nonisolated extension Feedback {
    var senderCreator: Creator? {
        guard let senderID else { return nil }
        return Creator(
            id: senderID,
            name: nickname,
            avatarName: senderAvatarName,
            avatarURL: senderAvatarURL,
            handle: senderHandle
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
    let canUseCompanionEvolution: Bool
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
                canUseCompanionEvolution: false,
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
                canUseCompanionEvolution: false,
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
                canUseCompanionEvolution: true,
                canUseCodeProtectedProjects: true,
                canCustomizeProjectTheme: true,
                shouldShowAds: false
            )
        }
    }
}

nonisolated enum PocoLimits {
    static let feedbacksPerProject = 3
}

nonisolated enum AccountStatus: String, Codable, Sendable {
    case guest
    case registered

    var canCreateProjects: Bool { self == .registered }
}

nonisolated enum PocoOnboardingGuide: String, Identifiable, Sendable {
    case member
    case pro

    var id: Self { self }
}

nonisolated struct AuthenticatedAccount: Equatable, Sendable {
    let id: UUID
    let displayName: String?
    let email: String?

    init(id: UUID, displayName: String?, email: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.email = email
    }
}

nonisolated struct AppleIdentityCredential: Sendable {
    let identityToken: String
    let rawNonce: String
    let displayName: String?
    let appleFullName: String?
    let email: String?

    init(
        identityToken: String,
        rawNonce: String,
        displayName: String?,
        appleFullName: String? = nil,
        email: String? = nil
    ) {
        self.identityToken = identityToken
        self.rawNonce = rawNonce
        self.displayName = displayName
        self.appleFullName = appleFullName
        self.email = email
    }
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
