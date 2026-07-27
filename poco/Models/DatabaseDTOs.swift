import Foundation

nonisolated struct ProfileDTO: Codable, Sendable {
    let id: UUID
    let displayName: String
    let avatarName: String?
    let avatarURL: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarName = "avatar_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
    }

    init(creator: Creator) {
        id = creator.id
        displayName = creator.name
        avatarName = creator.avatarName
        avatarURL = creator.avatarURL?.absoluteString
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

        if let createdAt {
            try container.encode(createdAt, forKey: .createdAt)
        }
    }

    var domainModel: Creator {
        Creator(
            id: id,
            name: displayName,
            avatarName: avatarName,
            avatarURL: avatarURL.flatMap(URL.init(string:))
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
    }

    var domainModel: Project {
        Project(
            id: id,
            title: title,
            creator: Creator(
                id: creatorID,
                name: creatorName,
                avatarName: creatorAvatarName,
                avatarURL: creatorAvatarURL.flatMap(URL.init(string:))
            ),
            category: ProjectCategory(rawValue: category) ?? .other,
            description: description,
            imageName: nil,
            imageURL: imageURL.flatMap(URL.init(string:)),
            feedbackCount: feedbackCount ?? 0,
            createdAt: createdAt
        )
    }
}

nonisolated struct FeedbackDTO: Codable, Sendable {
    let id: UUID
    let projectID: UUID
    let senderID: UUID?
    let nickname: String
    let message: String
    let isPublic: Bool
    let bubbleColor: String
    let likesCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "project_id"
        case senderID = "sender_id"
        case nickname
        case message
        case isPublic = "is_public"
        case bubbleColor = "bubble_color"
        case likesCount = "likes_count"
        case createdAt = "created_at"
    }

    init(feedback: Feedback, senderID: UUID?) {
        id = feedback.id
        projectID = feedback.projectID
        self.senderID = senderID
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
            senderID: senderID
        )
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
