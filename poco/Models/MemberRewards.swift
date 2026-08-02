import Foundation

nonisolated enum AchievementStamp: String, CaseIterable, Identifiable, Codable, Sendable {
    case firstFeedback = "first_feedback"
    case threeFeedbacks = "three_feedbacks"
    case feedback5 = "feedback_5"
    case feedback10 = "feedback_10"
    case feedback20 = "feedback_20"
    case feedback30 = "feedback_30"
    case feedback50 = "feedback_50"
    case feedback100 = "feedback_100"
    case feedback200 = "feedback_200"
    case feedback500 = "feedback_500"
    case feedbackStreak2 = "feedback_streak_2"
    case feedbackStreak3 = "feedback_streak_3"
    case feedbackStreak5 = "feedback_streak_5"
    case feedbackStreak7 = "feedback_streak_7"
    case feedbackStreak10 = "feedback_streak_10"
    case feedbackStreak14 = "feedback_streak_14"
    case feedbackStreak21 = "feedback_streak_21"
    case feedbackStreak30 = "feedback_streak_30"
    case feedbackStreak60 = "feedback_streak_60"
    case feedbackStreak100 = "feedback_streak_100"
    case uniqueProjects2 = "unique_projects_2"
    case uniqueProjects3 = "unique_projects_3"
    case uniqueProjects5 = "unique_projects_5"
    case uniqueProjects10 = "unique_projects_10"
    case uniqueProjects20 = "unique_projects_20"
    case uniqueProjects30 = "unique_projects_30"
    case uniqueProjects50 = "unique_projects_50"
    case uniqueProjects100 = "unique_projects_100"
    case firstProject = "first_project"
    case projects3 = "projects_3"
    case projects5 = "projects_5"
    case projects10 = "projects_10"
    case projects20 = "projects_20"
    case projects30 = "projects_30"
    case firstLike = "first_like"
    case likesGiven5 = "likes_given_5"
    case likesGiven10 = "likes_given_10"
    case likesGiven25 = "likes_given_25"
    case likesGiven50 = "likes_given_50"
    case likesGiven100 = "likes_given_100"
    case likesReceived1 = "likes_received_1"
    case likesReceived5 = "likes_received_5"
    case likesReceived10 = "likes_received_10"
    case likesReceived25 = "likes_received_25"
    case likesReceived50 = "likes_received_50"
    case likesReceived100 = "likes_received_100"
    case creatorHeart = "creator_heart"
    case creatorHearts3 = "creator_hearts_3"
    case creatorHearts5 = "creator_hearts_5"
    case creatorHearts10 = "creator_hearts_10"
    case creatorHearts25 = "creator_hearts_25"
    case creatorHearts50 = "creator_hearts_50"
    case sevenDayStreak = "seven_day_streak"
    case thirtyDayLoginStreak = "thirty_day_login_streak"

    var id: Self { self }

    var title: String {
        switch self {
        case .firstFeedback: "はじめのことば"
        case .threeFeedbacks: "ことばの花束"
        case .firstProject: "はじめての感想箱"
        case .firstLike: "はじめての共感"
        case .creatorHeart: "作者に届いた！"
        case .sevenDayStreak: "Pocoな一週間"
        default: generatedTitle
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
        default: metric.detail(threshold: threshold)
        }
    }

    var symbolName: String {
        metric.symbolName
    }

    var artworkAssetName: String {
        "Badge" + rawValue
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
    }

    var color: BubbleColor {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return BubbleColor.allCases[index % BubbleColor.allCases.count]
    }

    func isUnlocked(signals: AchievementSignals, loginStreak: Int) -> Bool {
        switch metric {
        case .feedbackCount: signals.sentFeedbackCount >= threshold
        case .feedbackStreak: signals.longestFeedbackStreak >= threshold
        case .uniqueProjects: signals.uniqueProjectCount >= threshold
        case .projectsCreated: signals.projectCount >= threshold
        case .likesGiven: signals.likedFeedbackCount >= threshold
        case .likesReceived: signals.receivedLikeCount >= threshold
        case .creatorHearts: signals.creatorHeartCount >= threshold
        case .loginStreak: loginStreak >= threshold
        }
    }

    private var metric: AchievementMetric {
        switch self {
        case .firstFeedback, .threeFeedbacks, .feedback5, .feedback10, .feedback20,
             .feedback30, .feedback50, .feedback100, .feedback200, .feedback500:
            .feedbackCount
        case .feedbackStreak2, .feedbackStreak3, .feedbackStreak5, .feedbackStreak7,
             .feedbackStreak10, .feedbackStreak14, .feedbackStreak21,
             .feedbackStreak30, .feedbackStreak60, .feedbackStreak100:
            .feedbackStreak
        case .uniqueProjects2, .uniqueProjects3, .uniqueProjects5, .uniqueProjects10,
             .uniqueProjects20, .uniqueProjects30, .uniqueProjects50, .uniqueProjects100:
            .uniqueProjects
        case .firstProject, .projects3, .projects5, .projects10, .projects20, .projects30:
            .projectsCreated
        case .firstLike, .likesGiven5, .likesGiven10, .likesGiven25,
             .likesGiven50, .likesGiven100:
            .likesGiven
        case .likesReceived1, .likesReceived5, .likesReceived10, .likesReceived25,
             .likesReceived50, .likesReceived100:
            .likesReceived
        case .creatorHeart, .creatorHearts3, .creatorHearts5, .creatorHearts10,
             .creatorHearts25, .creatorHearts50:
            .creatorHearts
        case .sevenDayStreak, .thirtyDayLoginStreak:
            .loginStreak
        }
    }

    private var threshold: Int {
        switch self {
        case .firstFeedback, .firstProject, .firstLike, .likesReceived1, .creatorHeart: 1
        case .feedbackStreak2, .uniqueProjects2: 2
        case .threeFeedbacks, .feedbackStreak3, .uniqueProjects3,
             .projects3, .creatorHearts3: 3
        case .feedback5, .feedbackStreak5, .uniqueProjects5, .projects5,
             .likesGiven5, .likesReceived5, .creatorHearts5: 5
        case .sevenDayStreak, .feedbackStreak7: 7
        case .feedback10, .feedbackStreak10, .uniqueProjects10, .projects10,
             .likesGiven10, .likesReceived10, .creatorHearts10: 10
        case .feedbackStreak14: 14
        case .feedback20, .uniqueProjects20, .projects20: 20
        case .feedbackStreak21: 21
        case .likesGiven25, .likesReceived25, .creatorHearts25: 25
        case .feedback30, .feedbackStreak30, .uniqueProjects30, .projects30,
             .thirtyDayLoginStreak: 30
        case .feedback50, .uniqueProjects50, .likesGiven50,
             .likesReceived50, .creatorHearts50: 50
        case .feedbackStreak60: 60
        case .feedback100, .feedbackStreak100, .uniqueProjects100,
             .likesGiven100, .likesReceived100: 100
        case .feedback200: 200
        case .feedback500: 500
        }
    }

    private var generatedTitle: String {
        switch metric {
        case .feedbackCount:
            switch threshold {
            case 5: "ことばの芽"
            case 10: "ことばの小径"
            case 20: "ことば日和"
            case 30: "ことばの庭"
            case 50: "ことばの森"
            case 100: "百のことば"
            case 200: "ことばの星空"
            default: "ことばの銀河"
            }
        case .feedbackStreak:
            switch threshold {
            case 2: "ふつかの便り"
            case 3: "三日つづり"
            case 5: "五日つづり"
            case 7: "ことばの一週間"
            case 10: "十日つづり"
            case 14: "二週間の便り"
            case 21: "三週間の便り"
            case 30: "ことばのひと月"
            case 60: "ことばのふた月"
            default: "百日つづり"
            }
        case .uniqueProjects:
            switch threshold {
            case 2: "ふたつの出会い"
            case 3: "みっつの出会い"
            case 5: "五つの物語"
            case 10: "十の作品めぐり"
            case 20: "作品さんぽ"
            case 30: "作品めぐりの達人"
            case 50: "五十の出会い"
            default: "百の作品めぐり"
            }
        case .projectsCreated:
            switch threshold {
            case 3: "みっつの感想箱"
            case 5: "五つの感想箱"
            case 10: "十の感想箱"
            case 20: "感想箱の街"
            default: "感想箱の王国"
            }
        case .likesGiven:
            switch threshold {
            case 5: "共感の芽"
            case 10: "共感の花束"
            case 25: "やさしい共感"
            case 50: "共感の輪"
            default: "百の共感"
            }
        case .likesReceived:
            switch threshold {
            case 1: "はじめて届いた共感"
            case 5: "共感が咲いた"
            case 10: "十の共感"
            case 25: "共感の花畑"
            case 50: "共感のきらめき"
            default: "百の共感を受けて"
            }
        case .creatorHearts:
            switch threshold {
            case 3: "作者に三度届いた"
            case 5: "作者の五つのハート"
            case 10: "作者に十度届いた"
            case 25: "作者とのことばの輪"
            default: "作者に五十度届いた"
            }
        case .loginStreak:
            "Pocoな一か月"
        }
    }
}

nonisolated private enum AchievementMetric {
    case feedbackCount
    case feedbackStreak
    case uniqueProjects
    case projectsCreated
    case likesGiven
    case likesReceived
    case creatorHearts
    case loginStreak

    var symbolName: String {
        switch self {
        case .feedbackCount: "bubble.left.fill"
        case .feedbackStreak: "calendar.badge.checkmark"
        case .uniqueProjects: "books.vertical.fill"
        case .projectsCreated: "shippingbox.fill"
        case .likesGiven: "hand.thumbsup.fill"
        case .likesReceived: "heart.fill"
        case .creatorHearts: "heart.circle.fill"
        case .loginStreak: "flame.fill"
        }
    }

    func detail(threshold: Int) -> String {
        switch self {
        case .feedbackCount: "感想を\(threshold)件届ける"
        case .feedbackStreak: "\(threshold)日続けて感想を届ける"
        case .uniqueProjects: "\(threshold)作品に感想を届ける"
        case .projectsCreated: "作品の感想箱を\(threshold)個作る"
        case .likesGiven: "フキダシに\(threshold)回いいねする"
        case .likesReceived: "自分の感想に\(threshold)件いいねをもらう"
        case .creatorHearts: "作者から❤️を\(threshold)件もらう"
        case .loginStreak: "\(threshold)日続けてログインする"
        }
    }
}

nonisolated struct AchievementSignals: Sendable {
    let sentFeedbackCount: Int
    let longestFeedbackStreak: Int
    let uniqueProjectCount: Int
    let projectCount: Int
    let likedFeedbackCount: Int
    let receivedLikeCount: Int
    let creatorHeartCount: Int
}

nonisolated struct MemberRewardSnapshot: Equatable, Sendable {
    let loginStreak: Int
    let lastClaimedDay: String?
    let starCoinBalance: Int
    let walletRevision: Int64
    let unlockedStamps: Set<AchievementStamp>

    var canClaimToday: Bool {
        lastClaimedDay != PocoCalendar.todayKey()
    }

    static let empty = Self(
        loginStreak: 0,
        lastClaimedDay: nil,
        starCoinBalance: 0,
        walletRevision: 0,
        unlockedStamps: []
    )
}

nonisolated struct DailyLoginBonusClaim: Equatable, Sendable {
    let awardedCoins: Int
    let starCoinBalance: Int
    let loginStreak: Int
    let claimed: Bool
    let claimedDay: String
    let walletRevision: Int64
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
    let walletRevision: Int64
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

    static func longestConsecutiveDayStreak(_ dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
        var longest = 1
        var current = 1

        for (previous, next) in zip(days, days.dropFirst()) {
            if calendar.date(byAdding: .day, value: 1, to: previous) == next {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
}
