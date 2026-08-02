import Foundation

actor MockNotificationRepository: NotificationRepository {
    nonisolated private static let achievementNotificationsKey =
        "poco.mockReward.achievementNotifications"
    private var notifications: [PocoNotification]
    private var observers: [
        UUID: AsyncThrowingStream<PocoNotification, any Error>.Continuation
    ] = [:]

    init(notifications: [PocoNotification]? = nil) {
        let likeTarget = MockData.feedbacks.first {
            $0.senderID == MockData.previewUser.id
        }
        self.notifications = notifications ?? [
            PocoNotification(
                id: UUID(uuidString: "60000000-0000-0000-0000-000000000001")!,
                recipientID: MockData.previewUser.id,
                eventKey: "feedback:creator-heart:\(likeTarget?.id.uuidString ?? "preview")",
                type: .creatorHeart,
                projectID: likeTarget?.projectID,
                feedbackID: likeTarget?.id,
                actorProfileID: MockData.forestCreator.id,
                projectTitle: MockData.forestProject.title,
                actorDisplayName: MockData.forestCreator.name,
                messagePreview: likeTarget?.message,
                createdAt: Date.now.addingTimeInterval(-90),
                readAt: nil
            ),
            PocoNotification(
                id: UUID(uuidString: "60000000-0000-0000-0000-000000000002")!,
                recipientID: MockData.previewUser.id,
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
        materializeAchievementNotifications()
        return notifications.sorted { $0.createdAt > $1.createdAt }
    }

    func markRead(id: UUID) async throws -> Date {
        materializeAchievementNotifications()
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

    private func materializeAchievementNotifications() {
        let queued = UserDefaults.standard.stringArray(
            forKey: Self.achievementNotificationsKey
        ) ?? []
        for rawValue in queued {
            guard let stamp = AchievementStamp(rawValue: rawValue),
                  !notifications.contains(where: {
                      $0.eventKey == "achievement:\(rawValue)"
                  }),
                  let index = AchievementStamp.allCases.firstIndex(of: stamp),
                  let id = UUID(uuidString: String(
                      format: "60000000-0000-0000-0000-%012d",
                      100 + index
                  )) else { continue }
            notifications.append(
                PocoNotification(
                    id: id,
                    recipientID: MockData.previewUser.id,
                    eventKey: "achievement:\(rawValue)",
                    type: .achievement,
                    projectID: nil,
                    feedbackID: nil,
                    actorProfileID: nil,
                    projectTitle: nil,
                    actorDisplayName: nil,
                    messagePreview: stamp.detail,
                    createdAt: .now.addingTimeInterval(Double(-index)),
                    readAt: nil
                )
            )
        }
    }
}
