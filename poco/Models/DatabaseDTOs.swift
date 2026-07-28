import Foundation

nonisolated struct ProfileDTO: Codable, Sendable {
    let id: UUID
    let displayName: String
    let avatarName: String?
    let avatarURL: String?
    let handle: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarName = "avatar_name"
        case avatarURL = "avatar_url"
        case handle
        case createdAt = "created_at"
    }

    init(creator: Creator) {
        id = creator.id
        displayName = creator.name
        avatarName = creator.avatarName
        avatarURL = creator.avatarURL?.absoluteString
        handle = creator.handle
        createdAt = nil
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)

        if let avatarName {
            try container.encode(avatarName, forKey: .avatarName)
        } else {
            try container.encodeNil(forKey: .avatarName)
        }

        if let avatarURL {
            try container.encode(avatarURL, forKey: .avatarURL)
        } else {
            try container.encodeNil(forKey: .avatarURL)
        }

        if let handle {
            try container.encode(handle, forKey: .handle)
        }

        if let createdAt {
            try container.encode(createdAt, forKey: .createdAt)
        }
    }

    var domainModel: Creator {
        Creator(
            id: id,
            name: displayName,
            avatarName: avatarName,
            avatarURL: avatarURL.flatMap(URL.init(string:)),
            handle: handle
        )
    }
}

nonisolated struct ProjectDTO: Codable, Sendable {
    let id: UUID
    let creatorID: UUID
    let title: String
    let creatorName: String
    let category: String
    let description: String
    let imageURL: String?
    let createdAt: Date
    let isPublished: Bool
    let relationship: String
    let verificationStatus: String
    let publishingRulesVersion: Int
    let publishingRulesAcceptedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorID = "creator_id"
        case title
        case creatorName = "creator_name"
        case category
        case description
        case imageURL = "image_url"
        case createdAt = "created_at"
        case isPublished = "is_published"
        case relationship
        case verificationStatus = "verification_status"
        case publishingRulesVersion = "publishing_rules_version"
        case publishingRulesAcceptedAt = "publishing_rules_accepted_at"
    }

    init(project: Project, isPublished: Bool = true) {
        id = project.id
        creatorID = project.creator.id
        title = project.title
        creatorName = project.creator.name
        category = project.category.rawValue
        description = project.description
        imageURL = project.imageURL?.absoluteString
        createdAt = project.createdAt
        self.isPublished = isPublished
        relationship = project.relationship.rawValue
        verificationStatus = project.verificationStatus.rawValue
        publishingRulesVersion = PocoPublishingRules.currentVersion
        publishingRulesAcceptedAt = project.createdAt
    }
}

nonisolated struct ProjectQueryDTO: Codable, Sendable {
    let id: UUID
    let creatorID: UUID
    let title: String
    let creatorName: String
    let category: String
    let description: String
    let imageURL: String?
    let createdAt: Date
    let isPublished: Bool
    let feedbackCount: Int?
    let creatorAvatarName: String?
    let creatorAvatarURL: String?
    let creatorHandle: String?
    let relationship: String?
    let verificationStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case creatorID = "creator_id"
        case title
        case creatorName = "creator_name"
        case category
        case description
        case imageURL = "image_url"
        case createdAt = "created_at"
        case isPublished = "is_published"
        case feedbackCount = "feedback_count"
        case creatorAvatarName = "creator_avatar_name"
        case creatorAvatarURL = "creator_avatar_url"
        case creatorHandle = "creator_handle"
        case relationship
        case verificationStatus = "verification_status"
    }

    var domainModel: Project {
        Project(
            id: id,
            title: title,
            creator: Creator(
                id: creatorID,
                name: creatorName,
                avatarName: creatorAvatarName,
                avatarURL: creatorAvatarURL.flatMap(URL.init(string:)),
                handle: creatorHandle
            ),
            category: ProjectCategory(rawValue: category) ?? .other,
            description: description,
            imageName: nil,
            imageURL: imageURL.flatMap(URL.init(string:)),
            feedbackCount: feedbackCount ?? 0,
            createdAt: createdAt,
            relationship: relationship.flatMap(ProjectRelationship.init(rawValue:)) ?? .creator,
            verificationStatus: verificationStatus.flatMap(ProjectVerificationStatus.init(rawValue:)) ?? .unverified
        )
    }
}

nonisolated struct FeedbackDTO: Codable, Sendable {
    let id: UUID
    let projectID: UUID
    let authorProfileID: UUID?
    let nickname: String
    let message: String
    let isPublic: Bool
    let bubbleColor: String
    let likesCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "project_id"
        case authorProfileID = "author_profile_id"
        case nickname
        case message
        case isPublic = "is_public"
        case bubbleColor = "bubble_color"
        case likesCount = "likes_count"
        case createdAt = "created_at"
    }

    init(feedback: Feedback, authorProfileID: UUID?) {
        id = feedback.id
        projectID = feedback.projectID
        self.authorProfileID = authorProfileID
        nickname = feedback.nickname
        message = feedback.message
        isPublic = feedback.isPublic
        bubbleColor = feedback.bubbleColor.rawValue
        likesCount = feedback.likes
        createdAt = feedback.createdAt
    }

    var domainModel: Feedback {
        Feedback(
            id: id,
            projectID: projectID,
            message: message,
            nickname: nickname,
            isPublic: isPublic,
            createdAt: createdAt,
            likes: likesCount,
            bubbleColor: BubbleColor(rawValue: bubbleColor) ?? .coral,
            senderID: authorProfileID
        )
    }
}

nonisolated struct SubmitFeedbackParameters: Encodable, Sendable {
    let feedbackID: UUID
    let projectID: UUID
    let nickname: String
    let message: String
    let isPublic: Bool
    let bubbleColor: String
    let publishesProfile: Bool

    enum CodingKeys: String, CodingKey {
        case feedbackID = "p_feedback_id"
        case projectID = "p_project_id"
        case nickname = "p_nickname"
        case message = "p_message"
        case isPublic = "p_is_public"
        case bubbleColor = "p_bubble_color"
        case publishesProfile = "p_publishes_profile"
    }
}

nonisolated struct CreatorReceiptDTO: Codable, Sendable {
    let feedbackID: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case feedbackID = "feedback_id"
        case createdAt = "created_at"
    }
}

nonisolated struct CreatorReceiptInsertDTO: Encodable, Sendable {
    let feedbackID: UUID

    enum CodingKeys: String, CodingKey {
        case feedbackID = "feedback_id"
    }
}

nonisolated struct FeedbackOwnershipDTO: Decodable, Sendable {
    let feedbackID: UUID

    enum CodingKeys: String, CodingKey {
        case feedbackID = "feedback_id"
    }
}

nonisolated struct FeedbackProjectParameters: Encodable, Sendable {
    let projectID: UUID

    enum CodingKeys: String, CodingKey {
        case projectID = "p_project_id"
    }
}

nonisolated struct UserBlockDTO: Decodable, Sendable {
    let blockedProfileID: UUID

    enum CodingKeys: String, CodingKey {
        case blockedProfileID = "blocked_profile_id"
    }
}

nonisolated struct ReportFeedbackParameters: Encodable, Sendable {
    let feedbackID: UUID
    let reason: String
    let details: String?

    enum CodingKeys: String, CodingKey {
        case feedbackID = "p_feedback_id"
        case reason = "p_reason"
        case details = "p_details"
    }
}

nonisolated struct ModerateFeedbackParameters: Encodable, Sendable {
    let feedbackID: UUID
    let action: String

    enum CodingKeys: String, CodingKey {
        case feedbackID = "p_feedback_id"
        case action = "p_action"
    }
}

nonisolated struct UserBlockInsertDTO: Encodable, Sendable {
    let blockerID: UUID
    let blockedProfileID: UUID

    enum CodingKeys: String, CodingKey {
        case blockerID = "blocker_id"
        case blockedProfileID = "blocked_profile_id"
    }
}

nonisolated struct MembershipDTO: Codable, Sendable {
    let tier: String
    let status: String
    let currentPeriodEnd: Date?

    enum CodingKeys: String, CodingKey {
        case tier
        case status
        case currentPeriodEnd = "current_period_end"
    }

    var membershipTier: MembershipTier {
        guard MembershipTier(rawValue: tier) == .pocoMember,
              ["active", "trialing"].contains(status),
              currentPeriodEnd.map({ $0 > .now }) ?? true else {
            return .guest
        }
        return .pocoMember
    }
}

nonisolated struct FeedbackLikeDTO: Encodable, Sendable {
    let id: UUID
    let feedbackID: UUID
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case feedbackID = "feedback_id"
        case userID = "user_id"
    }
}

nonisolated struct FeedbackLikeQueryDTO: Decodable, Sendable {
    let feedbackID: UUID

    enum CodingKeys: String, CodingKey {
        case feedbackID = "feedback_id"
    }
}

nonisolated struct MemberRewardProgressDTO: Decodable, Sendable {
    let loginStreak: Int
    let lastLoginBonusDay: String?
    let starCoinBalance: Int

    enum CodingKeys: String, CodingKey {
        case loginStreak = "login_streak"
        case lastLoginBonusDay = "last_login_bonus_day"
        case starCoinBalance = "star_coin_balance"
    }
}

nonisolated struct AchievementStampDTO: Decodable, Sendable {
    let stampKey: String

    enum CodingKeys: String, CodingKey {
        case stampKey = "stamp_key"
    }
}

nonisolated struct DailyLoginBonusClaimDTO: Decodable, Sendable {
    let awardedCoins: Int
    let starCoinBalance: Int
    let loginStreak: Int
    let claimed: Bool
    let claimedDay: String

    enum CodingKeys: String, CodingKey {
        case awardedCoins = "awarded_coins"
        case starCoinBalance = "star_coin_balance"
        case loginStreak = "login_streak"
        case claimed
        case claimedDay = "claimed_day"
    }

    var domainModel: DailyLoginBonusClaim {
        DailyLoginBonusClaim(
            awardedCoins: awardedCoins,
            starCoinBalance: starCoinBalance,
            loginStreak: loginStreak,
            claimed: claimed,
            claimedDay: claimedDay
        )
    }
}
