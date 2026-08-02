import Foundation

nonisolated struct ProfileDTO: Codable, Sendable {
    let id: UUID
    let displayName: String
    let avatarName: String?
    let avatarURL: String?
    let handle: String?
    let socialLinks: [String: String]?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarName = "avatar_name"
        case avatarURL = "avatar_url"
        case handle
        case socialLinks = "social_links"
        case createdAt = "created_at"
    }

    init(creator: Creator) {
        id = creator.id
        displayName = creator.name
        avatarName = creator.avatarName
        avatarURL = creator.avatarURL?.absoluteString
        handle = creator.handle
        socialLinks = creator.profileLinks.reduce(into: [:]) { values, link in
            values[link.service.rawValue] = link.url.absoluteString
        }
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

        try container.encode(socialLinks ?? [:], forKey: .socialLinks)

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
            handle: handle,
            profileLinks: ProfileLinkService.allCases.compactMap { service in
                guard let value = socialLinks?[service.rawValue] else { return nil }
                return ProfileSocialLink(service: service, value: value)
            }
        )
    }
}

nonisolated struct ProjectDTO: Codable, Sendable {
    let id: UUID
    let creatorID: UUID
    let title: String
    let creatorName: String
    let authorName: String
    let category: String
    let description: String
    let imageURL: String?
    let externalURL: String?
    let createdAt: Date
    let isPublished: Bool
    let relationship: String
    let purpose: String
    let verificationStatus: String
    let contentRating: String
    let publishingRulesVersion: Int
    let publishingRulesAcceptedAt: Date
    let acceptsQuestions: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case creatorID = "creator_id"
        case title
        case creatorName = "creator_name"
        case authorName = "author_name"
        case category
        case description
        case imageURL = "image_url"
        case externalURL = "external_url"
        case createdAt = "created_at"
        case isPublished = "is_published"
        case relationship
        case purpose
        case verificationStatus = "verification_status"
        case contentRating = "content_rating"
        case publishingRulesVersion = "publishing_rules_version"
        case publishingRulesAcceptedAt = "publishing_rules_accepted_at"
        case acceptsQuestions = "accepts_questions"
    }

    init(project: Project, isPublished: Bool = true) {
        id = project.id
        creatorID = project.creator.id
        title = project.title
        creatorName = project.creator.name
        authorName = project.creditedAuthorName
        category = project.category.rawValue
        description = project.description
        imageURL = project.imageURL?.absoluteString
        externalURL = project.externalURL?.absoluteString
        createdAt = project.createdAt
        self.isPublished = isPublished
        relationship = project.relationship.rawValue
        purpose = project.purpose.rawValue
        verificationStatus = project.verificationStatus.rawValue
        contentRating = project.contentRating.rawValue
        publishingRulesVersion = PocoPublishingRules.currentVersion
        publishingRulesAcceptedAt = project.createdAt
        acceptsQuestions = project.acceptsQuestions
    }
}

nonisolated struct ProjectQueryDTO: Codable, Sendable {
    let id: UUID
    let creatorID: UUID
    let title: String
    let creatorName: String
    let authorName: String?
    let category: String
    let description: String
    let imageURL: String?
    let externalURL: String?
    let createdAt: Date
    let isPublished: Bool
    let feedbackCount: Int?
    let creatorAvatarName: String?
    let creatorAvatarURL: String?
    let creatorHandle: String?
    let relationship: String?
    let purpose: String?
    let verificationStatus: String?
    let contentRating: String?
    let isContentLocked: Bool?
    let acceptsQuestions: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case creatorID = "creator_id"
        case title
        case creatorName = "creator_name"
        case authorName = "author_name"
        case category
        case description
        case imageURL = "image_url"
        case externalURL = "external_url"
        case createdAt = "created_at"
        case isPublished = "is_published"
        case feedbackCount = "feedback_count"
        case creatorAvatarName = "creator_avatar_name"
        case creatorAvatarURL = "creator_avatar_url"
        case creatorHandle = "creator_handle"
        case relationship
        case purpose
        case verificationStatus = "verification_status"
        case contentRating = "content_rating"
        case isContentLocked = "is_content_locked"
        case acceptsQuestions = "accepts_questions"
    }

    var domainModel: Project {
        let isLegacyEvent = relationship == "event"
        return Project(
            id: id,
            title: title,
            creator: Creator(
                id: creatorID,
                name: creatorName,
                avatarName: creatorAvatarName,
                avatarURL: creatorAvatarURL.flatMap(URL.init(string:)),
                handle: creatorHandle
            ),
            authorName: authorName ?? creatorName,
            category: ProjectCategory(rawValue: category) ?? .other,
            description: description,
            imageName: nil,
            imageURL: imageURL.flatMap(URL.init(string:)),
            externalURL: externalURL.flatMap { PocoExternalURL.normalized(from: $0) },
            feedbackCount: feedbackCount ?? 0,
            createdAt: createdAt,
            relationship: isLegacyEvent
                ? .fan
                : relationship.flatMap(ProjectRelationship.init(rawValue:)) ?? .creator,
            purpose: isLegacyEvent
                ? .event
                : purpose.flatMap(ProjectPurpose.init(rawValue:)) ?? .standard,
            verificationStatus: verificationStatus.flatMap(ProjectVerificationStatus.init(rawValue:)) ?? .unverified,
            contentRating: contentRating.flatMap(ProjectContentRating.init(rawValue:)) ?? .general,
            isContentLocked: isContentLocked ?? false,
            acceptsQuestions: acceptsQuestions ?? false
        )
    }
}

nonisolated struct ProjectUpdateDTO: Encodable, Sendable {
    let title: String
    let authorName: String
    let category: String
    let description: String
    let imageURL: String?
    let externalURL: String?
    let relationship: String
    let purpose: String
    let contentRating: String
    let acceptsQuestions: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case category
        case description
        case imageURL = "image_url"
        case externalURL = "external_url"
        case relationship
        case purpose
        case contentRating = "content_rating"
        case acceptsQuestions = "accepts_questions"
    }

    init(project: Project) {
        title = project.title
        authorName = project.creditedAuthorName
        category = project.category.rawValue
        description = project.description
        imageURL = project.imageURL?.absoluteString
        externalURL = project.externalURL?.absoluteString
        relationship = project.relationship.rawValue
        purpose = project.purpose.rawValue
        contentRating = project.contentRating.rawValue
        acceptsQuestions = project.acceptsQuestions
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(authorName, forKey: .authorName)
        try container.encode(category, forKey: .category)
        try container.encode(description, forKey: .description)
        if let imageURL {
            try container.encode(imageURL, forKey: .imageURL)
        } else {
            try container.encodeNil(forKey: .imageURL)
        }
        if let externalURL {
            try container.encode(externalURL, forKey: .externalURL)
        } else {
            try container.encodeNil(forKey: .externalURL)
        }
        try container.encode(relationship, forKey: .relationship)
        try container.encode(purpose, forKey: .purpose)
        try container.encode(contentRating, forKey: .contentRating)
        try container.encode(acceptsQuestions, forKey: .acceptsQuestions)
    }
}

nonisolated struct ProjectMutationResultDTO: Decodable, Sendable {
    let id: UUID
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
    let moderationStatus: String
    let createdAt: Date
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "project_id"
        case authorProfileID = "author_profile_id"
        case nickname
        case message
        case isPublic = "is_public"
        case bubbleColor = "bubble_color"
        case likesCount = "likes_count"
        case moderationStatus = "moderation_status"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
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
        moderationStatus = "visible"
        createdAt = feedback.createdAt
        expiresAt = feedback.expiresAt
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
            senderID: authorProfileID,
            publishesProfile: authorProfileID != nil,
            expiresAt: expiresAt
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

nonisolated struct SubmitRightsHolderRequestParameters: Encodable, Sendable {
    let projectID: UUID
    let requesterName: String
    let requesterEmail: String
    let relationship: String
    let details: String

    enum CodingKeys: String, CodingKey {
        case projectID = "p_project_id"
        case requesterName = "p_requester_name"
        case requesterEmail = "p_requester_email"
        case relationship = "p_relationship"
        case details = "p_details"
    }
}

nonisolated struct RightsHolderRequestResultDTO: Decodable, Sendable {
    let requestID: UUID

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
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

nonisolated struct PocoQuestionDTO: Decodable, Sendable {
    let id: UUID
    let projectID: UUID?
    let projectTitle: String?
    let senderID: UUID
    let senderName: String
    let senderAvatarName: String?
    let senderAvatarURL: String?
    let senderHandle: String?
    let creatorID: UUID
    let creatorName: String
    let creatorAvatarName: String?
    let creatorAvatarURL: String?
    let creatorHandle: String?
    let message: String
    let answer: String?
    let status: String
    let createdAt: Date
    let answeredAt: Date?
    let withdrawnAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "project_id"
        case projectTitle = "project_title"
        case senderID = "sender_id"
        case senderName = "sender_name"
        case senderAvatarName = "sender_avatar_name"
        case senderAvatarURL = "sender_avatar_url"
        case senderHandle = "sender_handle"
        case creatorID = "creator_id"
        case creatorName = "creator_name"
        case creatorAvatarName = "creator_avatar_name"
        case creatorAvatarURL = "creator_avatar_url"
        case creatorHandle = "creator_handle"
        case message
        case answer
        case status
        case createdAt = "created_at"
        case answeredAt = "answered_at"
        case withdrawnAt = "withdrawn_at"
    }

    var domainModel: PocoQuestion {
        PocoQuestion(
            id: id,
            projectID: projectID,
            projectTitle: projectTitle,
            sender: Creator(
                id: senderID,
                name: senderName,
                avatarName: senderAvatarName,
                avatarURL: senderAvatarURL.flatMap(URL.init(string:)),
                handle: senderHandle
            ),
            creator: Creator(
                id: creatorID,
                name: creatorName,
                avatarName: creatorAvatarName,
                avatarURL: creatorAvatarURL.flatMap(URL.init(string:)),
                handle: creatorHandle
            ),
            message: message,
            answer: answer,
            status: PocoQuestionStatus(rawValue: status) ?? .expired,
            createdAt: createdAt,
            answeredAt: answeredAt,
            withdrawnAt: withdrawnAt
        )
    }
}

nonisolated struct SendQuestionParameters: Encodable, Sendable {
    let creatorID: UUID
    let projectID: UUID?
    let message: String

    enum CodingKeys: String, CodingKey {
        case creatorID = "p_creator_id"
        case projectID = "p_project_id"
        case message = "p_message"
    }
}

nonisolated struct AnswerQuestionParameters: Encodable, Sendable {
    let questionID: UUID
    let answer: String

    enum CodingKeys: String, CodingKey {
        case questionID = "p_question_id"
        case answer = "p_answer"
    }
}

nonisolated struct UpdateQuestionParameters: Encodable, Sendable {
    let questionID: UUID
    let message: String

    enum CodingKeys: String, CodingKey {
        case questionID = "p_question_id"
        case message = "p_message"
    }
}

nonisolated struct QuestionIDParameters: Encodable, Sendable {
    let questionID: UUID

    enum CodingKeys: String, CodingKey {
        case questionID = "p_question_id"
    }
}

nonisolated struct ReportQuestionParameters: Encodable, Sendable {
    let questionID: UUID
    let reason: String
    let details: String?

    enum CodingKeys: String, CodingKey {
        case questionID = "p_question_id"
        case reason = "p_reason"
        case details = "p_details"
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
    let walletRevision: Int64

    enum CodingKeys: String, CodingKey {
        case loginStreak = "login_streak"
        case lastLoginBonusDay = "last_login_bonus_day"
        case starCoinBalance = "star_coin_balance"
        case walletRevision = "wallet_revision"
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
    let walletRevision: Int64

    enum CodingKeys: String, CodingKey {
        case awardedCoins = "awarded_coins"
        case starCoinBalance = "star_coin_balance"
        case loginStreak = "login_streak"
        case claimed
        case claimedDay = "claimed_day"
        case walletRevision = "wallet_revision"
    }

    var domainModel: DailyLoginBonusClaim {
        DailyLoginBonusClaim(
            awardedCoins: awardedCoins,
            starCoinBalance: starCoinBalance,
            loginStreak: loginStreak,
            claimed: claimed,
            claimedDay: claimedDay,
            walletRevision: walletRevision
        )
    }
}

nonisolated struct StarCoinAwardDTO: Decodable, Sendable {
    let starCoinBalance: Int
    let awardedCoins: Int
    let claimed: Bool
    let walletRevision: Int64

    enum CodingKeys: String, CodingKey {
        case starCoinBalance = "star_coin_balance"
        case awardedCoins = "awarded_coins"
        case claimed
        case walletRevision = "wallet_revision"
    }

    var domainModel: StarCoinAward {
        StarCoinAward(
            balance: starCoinBalance,
            awardedCoins: awardedCoins,
            claimed: claimed,
            walletRevision: walletRevision
        )
    }
}

nonisolated struct StarCoinClaimParameters: Encodable, Sendable {
    let eventKey: String

    enum CodingKeys: String, CodingKey {
        case eventKey = "p_event_key"
    }
}
