import Foundation

nonisolated enum PocoGuestIdentity {
    static let displayName = "名無し"
}

nonisolated struct Creator: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var avatarName: String?
    var avatarURL: URL? = nil
    var handle: String? = nil
    var profileLinks: [ProfileSocialLink] = []
}

nonisolated enum PocoExternalURL {
    static let maximumLength = 2_048

    static func normalized(from value: String) -> URL? {
        var candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate.count <= maximumLength else { return nil }
        guard !candidate.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains)
        else { return nil }

        if !candidate.contains("://") {
            candidate = "https://" + candidate
        }

        guard var components = URLComponents(string: candidate),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty,
              components.port == nil,
              components.user == nil,
              components.password == nil else { return nil }
        components.scheme = "https"
        components.host = host
        return components.url
    }
}

nonisolated enum ProfileLinkService: String, CaseIterable, Identifiable, Codable, Sendable {
    case x
    case instagram
    case youtube
    case tiktok
    case website

    var id: Self { self }

    var title: String {
        switch self {
        case .x: "X"
        case .instagram: "Instagram"
        case .youtube: "YouTube"
        case .tiktok: "TikTok"
        case .website: "Webサイト"
        }
    }

    var symbolName: String {
        switch self {
        case .x: "xmark"
        case .instagram: "camera.fill"
        case .youtube: "play.rectangle.fill"
        case .tiktok: "music.note"
        case .website: "globe"
        }
    }

    var placeholder: String {
        switch self {
        case .x: "x.com/ユーザー名"
        case .instagram: "instagram.com/ユーザー名"
        case .youtube: "youtube.com/@チャンネル"
        case .tiktok: "tiktok.com/@ユーザー名"
        case .website: "あなたのWebサイト"
        }
    }

    func allows(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let allowedHosts: [String]
        switch self {
        case .x: allowedHosts = ["x.com", "twitter.com"]
        case .instagram: allowedHosts = ["instagram.com"]
        case .youtube: allowedHosts = ["youtube.com", "youtu.be"]
        case .tiktok: allowedHosts = ["tiktok.com"]
        case .website: return true
        }
        return allowedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

nonisolated struct ProfileSocialLink: Identifiable, Hashable, Codable, Sendable {
    let service: ProfileLinkService
    let url: URL

    var id: String { "\(service.rawValue):\(url.absoluteString)" }

    init?(service: ProfileLinkService, value: String) {
        guard let url = PocoExternalURL.normalized(from: value), service.allows(url) else {
            return nil
        }
        self.service = service
        self.url = url
    }

    init?(service: ProfileLinkService, url: URL) {
        guard let normalizedURL = PocoExternalURL.normalized(from: url.absoluteString),
              service.allows(normalizedURL) else { return nil }
        self.service = service
        self.url = normalizedURL
    }
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
    case greenBear = "PocoAvatarGreenBear"
    case greenSpirit = "PocoAvatarGreenSpirit"
    case starSpirit = "PocoAvatarStarSpirit"
    case blueSpirit = "PocoAvatarBlueSpirit"
    case pinkCat = "PocoAvatarPinkCat"

    static let characterAssetName = "PocoCharacterDefault"
    static let selectableCases: [Self] = Self.allCases

    var id: Self { self }

    var title: String {
        switch self {
        case .cat: "ミントねこ"
        case .pig: "ラベンダーねこ"
        case .bear: "はちみつベア"
        case .dog: "ももいろバニー"
        case .lion: "コーラルねこ"
        case .greenBear: "みどりベア"
        case .greenSpirit: "みどりのぷよ"
        case .starSpirit: "ほしのぷよ"
        case .blueSpirit: "そらのぷよ"
        case .pinkCat: "さくらねこ"
        }
    }

    var companionAssetName: String {
        rawValue
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

    var assetName: String {
        "PocoCharacterRare"
    }

    static func born(from avatar: BuiltInAvatar, eventKey: String) -> Self {
        let secretKinds: [Self] = [.mouse, .rabbit, .goat]
        let seed = pocoStableSeed(eventKey)
        if seed % 5 == 0 {
            return secretKinds[seed % secretKinds.count]
        }
        return switch avatar {
        case .cat, .greenBear: Self.cat
        case .pig, .greenSpirit: Self.pig
        case .bear, .starSpirit: Self.bear
        case .dog, .blueSpirit: Self.dog
        case .lion, .pinkCat: Self.lion
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
    /// The name credited on the work. `creator` is always the Poco account
    /// that owns this feedback box, which may be a different person.
    var authorName: String? = nil
    var category: ProjectCategory
    var description: String
    var imageName: String?
    var imageURL: URL? = nil
    /// Ordered project artwork. `imageURL` remains the primary-image field so
    /// older clients and rows continue to work while Pro galleries use up to
    /// three images.
    var imageURLs: [URL]? = nil
    var externalURL: URL? = nil
    var feedbackCount: Int
    let createdAt: Date
    var relationship: ProjectRelationship = .creator
    var purpose: ProjectPurpose = .standard
    var verificationStatus: ProjectVerificationStatus = .unverified
    var contentRating: ProjectContentRating = .general
    var isContentLocked: Bool = false
    var acceptsQuestions: Bool = false

    var creditedAuthorName: String {
        let trimmed = authorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? creator.name : trimmed
    }

    var artworkURLs: [URL] {
        let candidates = (imageURLs?.isEmpty == false)
            ? imageURLs ?? []
            : [imageURL].compactMap { $0 }
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.absoluteString).inserted }
    }

    mutating func setArtworkURLs(_ urls: [URL]) {
        let limited = Array(urls.prefix(3))
        imageURL = limited.first
        imageURLs = limited
    }
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

    var id: Self { self }

    var title: String {
        switch self {
        case .creator: "制作者本人"
        case .authorized: "許可を得ている"
        case .fan: "ファンの感想箱"
        }
    }

    var explanation: String {
        switch self {
        case .creator: "私または所属チームが制作した作品です"
        case .authorized: "権利者・制作関係者から登録の許可を得ています"
        case .fan: "作品を応援するための非公式な感想箱です"
        }
    }

    var symbolName: String {
        switch self {
        case .creator: "person.crop.circle.badge.checkmark"
        case .authorized: "checkmark.seal"
        case .fan: "heart.circle"
        }
    }

    func badgeTitle(verificationStatus: ProjectVerificationStatus) -> String {
        if verificationStatus == .verified {
            return switch self {
            case .creator, .authorized: "公式クリエイター"
            case .fan: "ファンの感想箱・非公式"
            }
        }
        return switch self {
        case .creator: "制作者として登録・未確認"
        case .authorized: "許諾済みとして登録・未確認"
        case .fan: "ファンの感想箱・非公式"
        }
    }
}

nonisolated enum ProjectPurpose: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard
    case event

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: "通常の作品ページ"
        case .event: "イベントで使う"
        }
    }

    var explanation: String {
        switch self {
        case .standard: "Home・検索から継続的に見つけてもらう"
        case .event: "会場や頒布物のQRから、その場で感想を集める"
        }
    }

    var discoveryLabel: String {
        switch self {
        case .standard: "Home・検索向け"
        case .event: "QR・頒布物向け"
        }
    }

    var symbolName: String {
        switch self {
        case .standard: "globe"
        case .event: "ticket"
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
    case anime
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .book: "本"
        case .game: "ゲーム"
        case .manga: "マンガ"
        case .anime: "アニメ"
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
        case .anime: "play.rectangle.fill"
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
    var publishesProfile: Bool = true
    var creatorReceivedAt: Date? = nil
    var expiresAt: Date? = nil

    func isVisible(at date: Date = .now) -> Bool {
        expiresAt.map { $0 > date } ?? true
    }
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
        guard publishesProfile, let senderID else { return nil }
        return Creator(
            id: senderID,
            name: nickname,
            avatarName: senderAvatarName,
            avatarURL: senderAvatarURL,
            handle: senderHandle
        )
    }
}

nonisolated struct FeedbackDraft: Identifiable, Hashable, Codable, Sendable {
    var id: UUID { projectID }
    let projectID: UUID
    var message: String
    var nickname: String
    var isPublic: Bool
    var publishesProfile: Bool
    var updatedAt: Date
    let ownerKey: String
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
                canSeeOwnReactionCounts: true,
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

nonisolated enum AccountDeletionState: Equatable, Sendable {
    case idle
    case deleting
    case deleted
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
