import Foundation

nonisolated enum PocoNotificationType: String, Codable, Sendable {
    case newFeedback = "new_feedback"
    case feedbackLike = "feedback_like"
    case creatorHeart = "creator_heart"
    case achievement
    case moderation
    case system

    var sectionTitle: String {
        switch self {
        case .newFeedback: "届いたことば"
        case .creatorHeart: "作者から❤️"
        case .feedbackLike: "共感"
        case .achievement: "達成スタンプ"
        case .moderation, .system: "Pocoからのお知らせ"
        }
    }

    var symbolName: String {
        switch self {
        case .newFeedback: "bubble.left.fill"
        case .feedbackLike: "heart.fill"
        case .creatorHeart: "heart.circle.fill"
        case .achievement: "rosette"
        case .moderation: "checkmark.shield.fill"
        case .system: "bell.fill"
        }
    }
}

nonisolated struct PocoNotification: Identifiable, Hashable, Sendable {
    let id: UUID
    let recipientID: UUID
    let eventKey: String
    let type: PocoNotificationType
    let projectID: UUID?
    let feedbackID: UUID?
    let actorProfileID: UUID?
    let projectTitle: String?
    let actorDisplayName: String?
    let messagePreview: String?
    let createdAt: Date
    var readAt: Date?

    var isRead: Bool { readAt != nil }

    var achievementStamp: AchievementStamp? {
        guard type == .achievement,
              eventKey.hasPrefix("achievement:") else { return nil }
        return AchievementStamp(
            rawValue: String(eventKey.dropFirst("achievement:".count))
        )
    }

    var title: String {
        switch type {
        case .newFeedback:
            if let actorDisplayName, !actorDisplayName.isEmpty {
                return "\(actorDisplayName)さんから感想が届きました"
            }
            return "新しい感想が届きました"
        case .feedbackLike:
            return "あなたのことばに共感が届きました"
        case .creatorHeart:
            return "作者があなたのことばにいいねしました"
        case .achievement:
            if let achievementStamp {
                return "「\(achievementStamp.title)」を達成しました"
            }
            return "新しい達成スタンプを獲得しました"
        case .moderation:
            return "確認結果が届きました"
        case .system:
            return "Pocoからのお知らせ"
        }
    }

    var destinationDescription: String? {
        guard feedbackID != nil else { return nil }
        return "該当するフキダシの詳細を開きます"
    }
}
