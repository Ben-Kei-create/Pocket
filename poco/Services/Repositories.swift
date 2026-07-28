import Foundation

protocol ProjectRepository: Sendable {
    nonisolated func fetchProjects() async throws -> [Project]
    nonisolated func fetchProjects(creatorID: UUID) async throws -> [Project]
    nonisolated func createProject(_ project: Project) async throws
}

protocol FeedbackRepository: Sendable {
    nonisolated func fetchFeedbacks(projectID: UUID) async throws -> [Feedback]
    nonisolated func submitFeedback(_ feedback: Feedback) async throws
    nonisolated func likeFeedback(id: UUID) async throws
    nonisolated func fetchLikedFeedbackIDs(feedbackIDs: [UUID]) async throws -> Set<UUID>
    nonisolated func fetchCreatorReceipts(feedbackIDs: [UUID]) async throws -> [UUID: Date]
    nonisolated func markReceivedByCreator(feedbackID: UUID) async throws -> Date
    nonisolated func observeCreatorReceipts() async -> AsyncThrowingStream<CreatorReceipt, any Error>
    nonisolated func observeFeedbacks(
        projectID: UUID
    ) async -> AsyncThrowingStream<Feedback, any Error>
}

protocol ProfileRepository: Sendable {
    nonisolated func fetchProfile(id: UUID) async throws -> Creator
    nonisolated func saveProfile(_ creator: Creator) async throws
}

protocol ProjectImageStorage: Sendable {
    nonisolated func uploadProjectImage(
        _ data: Data,
        projectID: UUID,
        creatorID: UUID
    ) async throws -> URL
}

protocol ProfileAvatarStorage: Sendable {
    nonisolated func uploadProfileAvatar(
        _ data: Data,
        userID: UUID
    ) async throws -> URL

    nonisolated func deleteProfileAvatar(at url: URL) async throws
}

protocol CurrentUserProvider: Sendable {
    func currentUserID() async -> UUID?
    func accountStatus() async -> AccountStatus
}

protocol AuthRepository: Sendable {
    nonisolated func signInWithApple(
        credential: AppleIdentityCredential
    ) async throws -> AuthenticatedAccount
    nonisolated func signOut() async throws
}

protocol MembershipRepository: Sendable {
    func fetchMembership(userID: UUID) async throws -> MembershipTier
}

protocol ModerationRepository: Sendable {
    nonisolated func fetchOwnedFeedbackIDs() async throws -> Set<UUID>
    nonisolated func fetchBlockedProfileIDs() async throws -> Set<UUID>
    nonisolated func reportFeedback(
        id: UUID,
        reason: FeedbackReportReason,
        details: String?
    ) async throws
    nonisolated func deleteOwnFeedback(id: UUID) async throws
    nonisolated func hideFeedbackAsCreator(id: UUID) async throws
    nonisolated func blockProfile(id: UUID) async throws
}

actor MockProjectRepository: ProjectRepository {
    private var projects: [Project]

    init(projects: [Project]? = nil) {
        self.projects = projects ?? MockData.projects
    }

    func fetchProjects() async throws -> [Project] {
        projects.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchProjects(creatorID: UUID) async throws -> [Project] {
        projects
            .filter { $0.creator.id == creatorID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createProject(_ project: Project) async throws {
        projects.insert(project, at: 0)
    }
}

actor MockFeedbackRepository: FeedbackRepository {
    private var feedbacks: [Feedback]
    private var observers: [UUID: [UUID: AsyncThrowingStream<Feedback, any Error>.Continuation]] = [:]
    private var receiptObservers: [UUID: AsyncThrowingStream<CreatorReceipt, any Error>.Continuation] = [:]

    init(feedbacks: [Feedback]? = nil) {
        self.feedbacks = feedbacks ?? MockData.feedbacks
    }

    func fetchFeedbacks(projectID: UUID) async throws -> [Feedback] {
        feedbacks
            .filter { $0.projectID == projectID && $0.isPublic }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func submitFeedback(_ feedback: Feedback) async throws {
        if !feedbacks.contains(where: { $0.id == feedback.id }) {
            feedbacks.append(feedback)
        }
        if let continuations = observers[feedback.projectID] {
            for continuation in continuations.values {
                continuation.yield(feedback)
            }
        }
    }

    func likeFeedback(id: UUID) async throws {
        var likedIDs = persistedLikedFeedbackIDs()
        guard likedIDs.insert(id).inserted else {
            throw AppError.alreadyLiked
        }
        guard let index = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        feedbacks[index].likes += 1
        UserDefaults.standard.set(
            likedIDs.map(\.uuidString),
            forKey: "poco.mockLikedFeedbackIDs"
        )
    }

    func fetchLikedFeedbackIDs(feedbackIDs: [UUID]) async throws -> Set<UUID> {
        persistedLikedFeedbackIDs().intersection(feedbackIDs)
    }

    func fetchCreatorReceipts(feedbackIDs: [UUID]) async throws -> [UUID: Date] {
        Dictionary(
            uniqueKeysWithValues: feedbacks.compactMap { feedback in
                guard feedbackIDs.contains(feedback.id),
                      let receivedAt = feedback.creatorReceivedAt else { return nil }
                return (feedback.id, receivedAt)
            }
        )
    }

    func markReceivedByCreator(feedbackID: UUID) async throws -> Date {
        guard let index = feedbacks.firstIndex(where: { $0.id == feedbackID }) else {
            throw AppError.notFound
        }
        let receivedAt = feedbacks[index].creatorReceivedAt ?? .now
        feedbacks[index].creatorReceivedAt = receivedAt
        let receipt = CreatorReceipt(feedbackID: feedbackID, createdAt: receivedAt)
        for continuation in receiptObservers.values {
            continuation.yield(receipt)
        }
        return receivedAt
    }

    func observeCreatorReceipts() async -> AsyncThrowingStream<CreatorReceipt, any Error> {
        let observerID = UUID()
        return AsyncThrowingStream { continuation in
            receiptObservers[observerID] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeReceiptObserver(id: observerID) }
            }
        }
    }

    func observeFeedbacks(projectID: UUID) async -> AsyncThrowingStream<Feedback, any Error> {
        let observerID = UUID()
        return AsyncThrowingStream { continuation in
            observers[projectID, default: [:]][observerID] = continuation
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeObserver(id: observerID, projectID: projectID)
                }
            }
        }
    }

    private func removeObserver(id: UUID, projectID: UUID) {
        observers[projectID]?[id] = nil
        if observers[projectID]?.isEmpty == true {
            observers[projectID] = nil
        }
    }

    private func removeReceiptObserver(id: UUID) {
        receiptObservers[id] = nil
    }

    private func persistedLikedFeedbackIDs() -> Set<UUID> {
        let values = UserDefaults.standard.stringArray(forKey: "poco.mockLikedFeedbackIDs") ?? []
        return Set(values.compactMap(UUID.init(uuidString:)))
    }
}

actor MockProfileRepository: ProfileRepository {
    private var creators: [UUID: Creator]

    init(creators: [Creator]? = nil) {
        let values = creators ?? [
            MockData.forestCreator,
            MockData.tetraCreator,
            MockData.hoshikoCreator
        ]
        self.creators = Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0) })
    }

    func fetchProfile(id: UUID) async throws -> Creator {
        guard let creator = creators[id] else {
            throw AppError.notFound
        }
        return creator
    }

    func saveProfile(_ creator: Creator) async throws {
        creators[creator.id] = creator
    }
}

struct MockCurrentUserProvider: CurrentUserProvider {
    let userID: UUID?

    init(userID: UUID? = MockData.forestCreator.id) {
        self.userID = userID
    }

    nonisolated func currentUserID() async -> UUID? {
        userID
    }

    nonisolated func accountStatus() async -> AccountStatus {
        UserDefaults.standard.bool(forKey: "poco.previewRegisteredAccount")
            ? .registered
            : .guest
    }
}

struct MockAuthRepository: AuthRepository {
    let userID: UUID

    init(userID: UUID = MockData.forestCreator.id) {
        self.userID = userID
    }

    nonisolated func signInWithApple(
        credential: AppleIdentityCredential
    ) async throws -> AuthenticatedAccount {
        UserDefaults.standard.set(true, forKey: "poco.previewRegisteredAccount")
        return AuthenticatedAccount(id: userID, displayName: credential.displayName)
    }

    nonisolated func signOut() async throws {
        UserDefaults.standard.set(false, forKey: "poco.previewMembership")
        UserDefaults.standard.set(false, forKey: "poco.previewRegisteredAccount")
    }
}

actor MockMembershipRepository: MembershipRepository {
    func fetchMembership(userID: UUID) async throws -> MembershipTier {
        UserDefaults.standard.bool(forKey: "poco.previewMembership") ? .pocoMember : .guest
    }
}

actor MockModerationRepository: ModerationRepository {
    private var ownedFeedbackIDs: Set<UUID>
    private var blockedProfileIDs: Set<UUID> = []

    init(ownedFeedbackIDs: Set<UUID>? = nil) {
        self.ownedFeedbackIDs = ownedFeedbackIDs ?? Set(
            MockData.feedbacks
                .filter { $0.senderID == MockData.forestCreator.id }
                .map(\.id)
        )
    }

    func fetchOwnedFeedbackIDs() async throws -> Set<UUID> { ownedFeedbackIDs }
    func fetchBlockedProfileIDs() async throws -> Set<UUID> { blockedProfileIDs }

    func reportFeedback(
        id: UUID,
        reason: FeedbackReportReason,
        details: String?
    ) async throws {}

    func deleteOwnFeedback(id: UUID) async throws {
        guard ownedFeedbackIDs.contains(id) else { throw AppError.unauthorized }
        ownedFeedbackIDs.remove(id)
    }

    func hideFeedbackAsCreator(id: UUID) async throws {}

    func blockProfile(id: UUID) async throws {
        blockedProfileIDs.insert(id)
    }
}

struct DisabledProjectImageStorage: ProjectImageStorage {
    nonisolated func uploadProjectImage(
        _ data: Data,
        projectID: UUID,
        creatorID: UUID
    ) async throws -> URL {
        throw AppError.storage
    }
}

struct DisabledProfileAvatarStorage: ProfileAvatarStorage {
    nonisolated func uploadProfileAvatar(
        _ data: Data,
        userID: UUID
    ) async throws -> URL {
        throw AppError.storage
    }

    nonisolated func deleteProfileAvatar(at url: URL) async throws {
        throw AppError.storage
    }
}
