import Foundation

nonisolated enum AchievementStamp: String, CaseIterable, Identifiable, Codable, Sendable {
    case firstFeedback = "first_feedback"
    case threeFeedbacks = "three_feedbacks"
    case firstProject = "first_project"
    case firstLike = "first_like"
    case creatorHeart = "creator_heart"
    case sevenDayStreak = "seven_day_streak"

    var id: Self { self }

    var title: String {
        switch self {
        case .firstFeedback: "はじめのことば"
        case .threeFeedbacks: "ことばの花束"
        case .firstProject: "はじめての感想箱"
        case .firstLike: "はじめての共感"
        case .creatorHeart: "作者に届いた！"
        case .sevenDayStreak: "Pocoな一週間"
        }
    }

    var detail: String {
        switch self {
        case .firstFeedback: "感想を1件届ける"
        case .threeFeedbacks: "感想を3件届ける"
        case .firstProject: "作品の感想箱を1つ作る"
        case .firstLike: "フキダシにいいねする"
        case .creatorHeart: "作者から❤️をもらう"
        case .sevenDayStreak: "7日続けてログインする"
        }
    }

    var symbolName: String {
        switch self {
        case .firstFeedback: "bubble.left.fill"
        case .threeFeedbacks: "text.bubble.fill"
        case .firstProject: "shippingbox.fill"
        case .firstLike: "heart.fill"
        case .creatorHeart: "heart.circle.fill"
        case .sevenDayStreak: "calendar.badge.checkmark"
        }
    }

    var color: BubbleColor {
        switch self {
        case .firstFeedback: .pink
        case .threeFeedbacks: .lavender
        case .firstProject: .blue
        case .firstLike: .coral
        case .creatorHeart: .yellow
        case .sevenDayStreak: .mint
        }
    }
}

nonisolated struct AchievementSignals: Sendable {
    let sentFeedbackCount: Int
    let projectCount: Int
    let likedFeedbackCount: Int
    let hasCreatorHeart: Bool
}

nonisolated struct MemberRewardSnapshot: Equatable, Sendable {
    let loginStreak: Int
    let lastClaimedDay: String?
    let starCoinBalance: Int
    let unlockedStamps: Set<AchievementStamp>

    var canClaimToday: Bool {
        lastClaimedDay != PocoCalendar.todayKey()
    }

    static let empty = Self(
        loginStreak: 0,
        lastClaimedDay: nil,
        starCoinBalance: 0,
        unlockedStamps: []
    )
}

nonisolated struct DailyLoginBonusClaim: Equatable, Sendable {
    let awardedCoins: Int
    let starCoinBalance: Int
    let loginStreak: Int
    let claimed: Bool
    let claimedDay: String
}

nonisolated enum StarCoinEvent: Equatable, Sendable {
    case feedbackDelivered(UUID)
    case companionTapped(UUID)
    case rareCompanionBorn(UUID, UUID)
    case rareCompanionTapped(UUID, UUID)

    init?(eventKey: String) {
        if let id = Self.singleID(eventKey, prefix: "feedback-delivered:") {
            self = .feedbackDelivered(id)
        } else if let id = Self.singleID(eventKey, prefix: "companion-tap:") {
            self = .companionTapped(id)
        } else if let ids = Self.pairIDs(eventKey, prefix: "rare-birth:") {
            self = .rareCompanionBorn(ids.0, ids.1)
        } else if let ids = Self.pairIDs(eventKey, prefix: "rare-tap:") {
            self = .rareCompanionTapped(ids.0, ids.1)
        } else {
            return nil
        }
    }

    var eventKey: String {
        switch self {
        case .feedbackDelivered(let id):
            "feedback-delivered:\(id.uuidString)"
        case .companionTapped(let id):
            "companion-tap:\(id.uuidString)"
        case .rareCompanionBorn(let first, let second):
            "rare-birth:\(Self.canonicalPair(first, second))"
        case .rareCompanionTapped(let first, let second):
            "rare-tap:\(Self.canonicalPair(first, second))"
        }
    }

    var mockAward: Int {
        switch self {
        case .feedbackDelivered: 3
        case .companionTapped, .rareCompanionTapped: 1
        case .rareCompanionBorn: 5
        }
    }

    private static func singleID(_ value: String, prefix: String) -> UUID? {
        guard value.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(value.dropFirst(prefix.count)))
    }

    private static func pairIDs(_ value: String, prefix: String) -> (UUID, UUID)? {
        guard value.hasPrefix(prefix) else { return nil }
        let parts = value.dropFirst(prefix.count).split(separator: ":")
        guard parts.count == 2,
              let first = UUID(uuidString: String(parts[0])),
              let second = UUID(uuidString: String(parts[1])),
              first != second,
              value == prefix + canonicalPair(first, second) else { return nil }
        return (first, second)
    }

    private static func canonicalPair(_ first: UUID, _ second: UUID) -> String {
        [first.uuidString, second.uuidString].sorted().joined(separator: ":")
    }
}

nonisolated struct StarCoinAward: Equatable, Sendable {
    let balance: Int
    let awardedCoins: Int
    let claimed: Bool
}

nonisolated enum PocoCalendar {
    static func todayKey(now: Date = .now) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func yesterdayKey(now: Date = .now) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        return todayKey(now: yesterday)
    }
}
