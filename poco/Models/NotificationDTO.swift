import Foundation

nonisolated struct NotificationDTO: Codable, Sendable {
    let id: UUID
    let recipientID: UUID
    let eventKey: String
    let type: String
    let projectID: UUID?
    let feedbackID: UUID?
    let actorProfileID: UUID?
    let projectTitle: String?
    let actorDisplayName: String?
    let messagePreview: String?
    let createdAt: Date
    let readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case recipientID = "recipient_id"
        case eventKey = "event_key"
        case type
        case projectID = "project_id"
        case feedbackID = "feedback_id"
        case actorProfileID = "actor_profile_id"
        case projectTitle = "project_title"
        case actorDisplayName = "actor_display_name"
        case messagePreview = "message_preview"
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    var domainModel: PocoNotification {
        PocoNotification(
            id: id,
            recipientID: recipientID,
            eventKey: eventKey,
            type: PocoNotificationType(rawValue: type) ?? .system,
            projectID: projectID,
            feedbackID: feedbackID,
            actorProfileID: actorProfileID,
            projectTitle: projectTitle,
            actorDisplayName: actorDisplayName,
            messagePreview: messagePreview,
            createdAt: createdAt,
            readAt: readAt
        )
    }
}

nonisolated struct MarkNotificationReadParameters: Encodable, Sendable {
    let notificationID: UUID

    enum CodingKeys: String, CodingKey {
        case notificationID = "p_notification_id"
    }
}
