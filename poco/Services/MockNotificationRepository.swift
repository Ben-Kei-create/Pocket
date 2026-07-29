import Foundation

actor MockNotificationRepository: NotificationRepository {
    private var notifications: [PocoNotification]
    private var observers: [
        UUID: AsyncThrowingStream<PocoNotification, any Error>.Continuation
    ] = [:]

    init(notifications: [PocoNotification]? = nil) {
        let feedback = MockData.feedbacks.first {
            $0.projectID == MockData.forestProject.id
                && $0.senderID != MockData.forestCreator.id
        }
        let likeTarget = MockData.feedbacks.first {
            $0.senderID == MockData.forestCreator.id
        }
        self.notifications = notifications ?? [
            PocoNotification(
                id: UUID(uuidString: "60000000-0000-0000-0000-000000000001")!,
                recipientID: MockData.forestCreator.id,
                eventKey: "feedback:new:\(feedback?.id.uuidString ?? "preview")",
                type: .newFeedback,
                projectID: MockData.forestProject.id,
                feedbackID: feedback?.id,
                actorProfileID: feedback?.senderID,
                projectTitle: MockData.forestProject.title,
                actorDisplayName: feedback?.nickname,
                messagePreview: feedback?.message,
                createdAt: Date.now.addingTimeInterval(-90),
                readAt: nil
            ),
            PocoNotification(
                id: UUID(uuidString: "60000000-0000-0000-0000-000000000002")!,
                recipientID: MockData.forestCreator.id,
                eventKey: "feedback:like:\(likeTarget?.id.uuidString ?? "preview")",
                type: .feedbackLike,
                projectID: likeTarget?.projectID,
                feedbackID: likeTarget?.id,
                actorProfileID: nil,
                projectTitle: MockData.forestProject.title,
                actorDisplayName: nil,
                messagePreview: likeTarget?.message,
                createdAt: Date.now.addingTimeInterval(-7_200),
                readAt: Date.now.addingTimeInterval(-7_000)
            )
        ]
    }

    func fetchNotifications() async throws -> [PocoNotification] {
        notifications.sorted { $0.createdAt > $1.createdAt }
    }

    func markRead(id: UUID) async throws -> Date {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound
        }
        let readAt = notifications[index].readAt ?? .now
        notifications[index].readAt = readAt
        return readAt
    }

    func observeNotifications() async -> AsyncThrowingStream<PocoNotification, any Error> {
        let observerID = UUID()
        return AsyncThrowingStream { continuation in
            observers[observerID] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(id: observerID) }
            }
        }
    }

    private func removeObserver(id: UUID) {
        observers[id] = nil
    }
}
