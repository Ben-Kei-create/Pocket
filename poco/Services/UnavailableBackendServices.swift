import Foundation

nonisolated struct UnavailableBackendServices: ProjectRepository,
    FeedbackRepository,
    ProfileRepository,
    MembershipRepository,
    MemberRewardRepository,
    StarStoreRepository,
    ModerationRepository,
    NotificationRepository,
    AnnouncementRepository,
    RightsHolderRequestRepository,
    QAndARepository,
    AuthRepository,
    CurrentUserProvider,
    ServerAuthorityService {

    private var error: AppError { .configuration }

    func fetchProjects() async throws -> [Project] { throw error }
    func fetchProjects(creatorID: UUID) async throws -> [Project] { throw error }
    func fetchProject(id: UUID) async throws -> Project { throw error }
    func createProject(_ project: Project) async throws { throw error }
    func updateProject(_ project: Project) async throws { throw error }
    func deleteProject(id: UUID) async throws { throw error }

    func fetchFeedbacks(projectID: UUID) async throws -> [Feedback] { throw error }
    func fetchFeedback(id: UUID) async throws -> Feedback { throw error }
    func fetchLikedFeedbacks() async throws -> [Feedback] { throw error }
    func submitFeedback(_ feedback: Feedback) async throws { throw error }
    func likeFeedback(id: UUID) async throws { throw error }
    func fetchLikedFeedbackIDs(feedbackIDs: [UUID]) async throws -> Set<UUID> { throw error }
    func fetchCreatorReceipts(feedbackIDs: [UUID]) async throws -> [UUID: Date] { throw error }
    func markReceivedByCreator(feedbackID: UUID) async throws -> Date { throw error }
    func observeCreatorReceipts(
        projectID: UUID
    ) async -> AsyncThrowingStream<CreatorReceipt, any Error> {
        unavailableStream()
    }
    func observeFeedbacks(
        projectID: UUID
    ) async -> AsyncThrowingStream<Feedback, any Error> {
        unavailableStream()
    }

    func fetchProfile(id: UUID) async throws -> Creator { throw error }
    func saveProfile(_ creator: Creator) async throws { throw error }
    func fetchMembership(userID: UUID) async throws -> MembershipTier { throw error }
    func fetchRewards(signals: AchievementSignals) async throws -> MemberRewardSnapshot {
        throw error
    }
    func claimDailyLoginBonus() async throws -> DailyLoginBonusClaim { throw error }
    func fetchCatalog() async throws -> [StarStoreItem] { throw error }
    func fetchOwnedItemQuantities() async throws -> [String: Int] { throw error }
    func fetchProjectDecoration(projectID: UUID) async throws -> ProjectDecoration { throw error }
    func purchaseItem(id: String, requestID: UUID) async throws -> StarStorePurchaseResult {
        throw error
    }
    func equipProjectBackground(projectID: UUID, itemID: String?) async throws { throw error }
    func equipProjectBadge(projectID: UUID, slot: Int, itemID: String?) async throws {
        throw error
    }
    func giftBadge(
        itemID: String,
        recipientID: UUID,
        requestID: UUID
    ) async throws -> BadgeGiftResult { throw error }
    func fetchProjectSlotStatus() async throws -> ProjectSlotStatus { throw error }
    func redeemProjectSlot(requestID: UUID) async throws -> ProjectSlotRedemptionResult {
        throw error
    }

    func fetchOwnedFeedbackIDs() async throws -> Set<UUID> { throw error }
    func fetchOwnedFeedbacks() async throws -> [Feedback] { throw error }
    func fetchOwnFeedbackCount(projectID: UUID) async throws -> Int { throw error }
    func fetchBlockedProfileIDs() async throws -> Set<UUID> { throw error }
    func reportFeedback(
        id: UUID,
        reason: FeedbackReportReason,
        details: String?
    ) async throws { throw error }
    func deleteOwnFeedback(id: UUID) async throws { throw error }
    func hideFeedbackAsCreator(id: UUID) async throws { throw error }
    func blockProfile(id: UUID) async throws { throw error }

    func fetchNotifications() async throws -> [PocoNotification] { throw error }
    func markRead(id: UUID) async throws -> Date { throw error }
    func observeNotifications() async -> AsyncThrowingStream<PocoNotification, any Error> {
        unavailableStream()
    }

    func fetchPublishedAnnouncements() async throws -> [AppAnnouncement] { throw error }

    func submit(_ request: RightsHolderRequest) async throws -> UUID { throw error }
    func fetchQuestions() async throws -> [PocoQuestion] { throw error }
    func sendQuestion(
        creatorID: UUID,
        projectID: UUID?,
        message: String
    ) async throws -> PocoQuestion { throw error }
    func updateQuestion(id: UUID, message: String) async throws -> PocoQuestion { throw error }
    func answerQuestion(id: UUID, answer: String) async throws -> PocoQuestion { throw error }
    func withdrawQuestion(id: UUID) async throws -> PocoQuestion { throw error }
    func reportQuestion(
        id: UUID,
        reason: FeedbackReportReason,
        details: String?
    ) async throws { throw error }
    func signInWithApple(
        credential: AppleIdentityCredential
    ) async throws -> AuthenticatedAccount { throw error }
    func signOut() async throws { throw error }
    func deleteAccount() async throws { throw error }
    func currentUserID() async -> UUID? { nil }
    func accountStatus() async -> AccountStatus { .guest }

    func syncMembershipEntitlement(
        _ entitlement: MembershipEntitlement
    ) async throws { throw error }
    func claimStarCoinReward(_ event: StarCoinEvent) async throws -> StarCoinAward {
        throw error
    }

    private func unavailableStream<Element>() -> AsyncThrowingStream<Element, any Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
}
