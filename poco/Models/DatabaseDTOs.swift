import Foundation

nonisolated struct ProfileDTO: Codable, Sendable {
    let id: UUID
    let displayName: String
    let avatarURL: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
    }

    init(creator: Creator) {
        id = creator.id
        displayName = creator.name
        avatarURL = creator.avatarURL?.absoluteString
        createdAt = nil
    }

    var domainModel: Creator {
        Creator(
            id: id,
            name: displayName,
            avatarName: nil,
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
    }

    var domainModel: Project {
        Project(
            id: id,
            title: title,
            creator: Creator(id: creatorID, name: creatorName, avatarName: nil),
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
            bubbleColor: BubbleColor(rawValue: bubbleColor) ?? .coral
        )
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
