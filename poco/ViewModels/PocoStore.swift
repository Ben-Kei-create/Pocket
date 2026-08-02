import Foundation
import Observation

@MainActor
@Observable
final class PocoStore {
    var projects: [Project]
    var feedbacks: [Feedback]
    private(set) var notifications: [PocoNotification] = []
    private(set) var announcements: [AppAnnouncement] = []
    private(set) var questions: [PocoQuestion] = []
    private(set) var feedbackDrafts: [FeedbackDraft] = []
    var selectedTab = AppTab.home
    var homePath: [UUID] = []
    private(set) var isResolvingDeepLink = false
    var errorMessage: String?
    private(set) var membershipTier: MembershipTier = .guest
    private(set) var accountStatus: AccountStatus = .guest
    private(set) var currentUserID: UUID?
    private(set) var currentProfile: Creator?
    private(set) var currentAvatarImageData: Data?
    private(set) var likedFeedbackIDs: Set<UUID> = []
    private(set) var ownedFeedbackIDs: Set<UUID> = []
    private(set) var ownFeedbackCountsByProject: [UUID: Int] = [:]
    private(set) var blockedProfileIDs: Set<UUID> = []
    private(set) var membershipOffer: MembershipOffer?
    private(set) var membershipPurchaseState: MembershipPurchaseState = .idle
    private(set) var membershipSyncState: MembershipSyncState = .idle
    private(set) var authenticationState: AuthenticationState = .idle
    private(set) var accountDeletionState: AccountDeletionState = .idle
    private(set) var projectLoadState: LoadState = .idle
    private(set) var feedbackLoadStates: [UUID: LoadState] = [:]
    private(set) var activityLoadState: LoadState = .idle
    private(set) var memberRewardLoadState: LoadState = .idle
    private(set) var notificationLoadState: LoadState = .idle
    private(set) var announcementLoadState: LoadState = .idle
    private(set) var starStoreLoadState: LoadState = .idle
    private(set) var qAndALoadState: LoadState = .idle
    private(set) var memberRewardSnapshot = MemberRewardSnapshot.empty
    private(set) var lastDailyLoginClaim: DailyLoginBonusClaim?
    private(set) var starCoinBalance = 0
    private(set) var starStoreItems: [StarStoreItem] = []
    private(set) var ownedStarItemQuantities: [String: Int] = [:]
    var ownedStarItemIDs: Set<String> {
        Set(ownedStarItemQuantities.lazy.filter { $0.value > 0 }.map(\.key))
    }
    private(set) var projectDecorations: [UUID: ProjectDecoration] = [:]
    private(set) var projectSlotStatus = ProjectSlotStatus.base
    var onboardingGuideRequest: PocoOnboardingGuide?
    let backendMode: BackendMode

    private let projectRepository: any ProjectRepository
    private let feedbackRepository: any FeedbackRepository
    private let profileRepository: any ProfileRepository
    private let membershipRepository: any MembershipRepository
    private let memberRewardRepository: any MemberRewardRepository
    private let starStoreRepository: any StarStoreRepository
    private let moderationRepository: any ModerationRepository
    private let notificationRepository: any NotificationRepository
    private let announcementRepository: any AnnouncementRepository
    private let rightsHolderRequestRepository: any RightsHolderRequestRepository
    private let qAndARepository: any QAndARepository
    private let membershipPurchaseService: any MembershipPurchaseService
    private let serverAuthorityService: any ServerAuthorityService
    private let authRepository: any AuthRepository
    private let currentUserProvider: any CurrentUserProvider
    private let projectImageStorage: (any ProjectImageStorage)?
    private let profileAvatarStorage: (any ProfileAvatarStorage)?
    private var realtimeTasks: [UUID: Task<Void, Never>] = [:]
    private var realtimeReceiptTasks: [UUID: Task<Void, Never>] = [:]
    private var notificationRealtimeTask: Task<Void, Never>?
    private var deepLinkResolutionTask: Task<Void, Never>?
    private var profileCache: [UUID: Creator] = [:]
    private var optimisticFeedbackIDs: Set<UUID> = []
    private var pendingDeepLinkProjectID: UUID?
    private var rewardedCoinEventKeys: Set<String> = []
    private var starCoinWalletRevision: Int64 = 0

    private static let starCoinBalanceKey = "poco.starCoinBalance"
    private static let starCoinWalletRevisionKey = "poco.starCoinWalletRevision"
    private static let rewardedCoinEventsKey = "poco.rewardedCoinEvents"
    private static let feedbackDraftsKey = "poco.feedbackDrafts"
    private static let mockAvatarImageDataKey = "poco.mockAvatarImageData"

    init(
        projectRepository: (any ProjectRepository)? = nil,
        feedbackRepository: (any FeedbackRepository)? = nil,
        profileRepository: (any ProfileRepository)? = nil,
        membershipRepository: (any MembershipRepository)? = nil,
        memberRewardRepository: (any MemberRewardRepository)? = nil,
        starStoreRepository: (any StarStoreRepository)? = nil,
        moderationRepository: (any ModerationRepository)? = nil,
        notificationRepository: (any NotificationRepository)? = nil,
        announcementRepository: (any AnnouncementRepository)? = nil,
        rightsHolderRequestRepository: (any RightsHolderRequestRepository)? = nil,
        qAndARepository: (any QAndARepository)? = nil,
        membershipPurchaseService: (any MembershipPurchaseService)? = nil,
        serverAuthorityService: (any ServerAuthorityService)? = nil,
        authRepository: (any AuthRepository)? = nil,
        currentUserProvider: (any CurrentUserProvider)? = nil,
        projectImageStorage: (any ProjectImageStorage)? = nil,
        profileAvatarStorage: (any ProfileAvatarStorage)? = nil,
        backendMode: BackendMode = .mock,
        initialProjects: [Project]? = nil,
        initialFeedbacks: [Feedback]? = nil
    ) {
        self.projectRepository = projectRepository ?? MockProjectRepository()
        self.feedbackRepository = feedbackRepository ?? MockFeedbackRepository()
        self.profileRepository = profileRepository ?? MockProfileRepository()
        self.membershipRepository = membershipRepository ?? MockMembershipRepository()
        self.memberRewardRepository = memberRewardRepository ?? MockMemberRewardRepository()
        self.starStoreRepository = starStoreRepository ?? MockStarStoreRepository()
        self.moderationRepository = moderationRepository ?? MockModerationRepository()
        self.notificationRepository = notificationRepository ?? MockNotificationRepository()
        self.announcementRepository = announcementRepository ?? MockAnnouncementRepository()
        self.rightsHolderRequestRepository = rightsHolderRequestRepository
            ?? MockRightsHolderRequestRepository()
        self.qAndARepository = qAndARepository ?? MockQAndARepository()
        self.membershipPurchaseService = membershipPurchaseService ?? DisabledMembershipPurchaseService()
        self.serverAuthorityService = serverAuthorityService ?? MockServerAuthorityService()
        self.authRepository = authRepository ?? MockAuthRepository()
        self.currentUserProvider = currentUserProvider ?? MockCurrentUserProvider()
        self.projectImageStorage = projectImageStorage
        self.profileAvatarStorage = profileAvatarStorage
        self.backendMode = backendMode
        projects = initialProjects ?? MockData.projects
        feedbacks = initialFeedbacks ?? MockData.feedbacks
        starCoinBalance = max(
            0,
            UserDefaults.standard.integer(forKey: Self.starCoinBalanceKey)
        )
        starCoinWalletRevision = Int64(
            UserDefaults.standard.integer(forKey: Self.starCoinWalletRevisionKey)
        )
        rewardedCoinEventKeys = Set(
            UserDefaults.standard.stringArray(forKey: Self.rewardedCoinEventsKey) ?? []
        )
        if let data = UserDefaults.standard.data(forKey: Self.feedbackDraftsKey),
           let drafts = try? JSONDecoder().decode([FeedbackDraft].self, from: data) {
            feedbackDrafts = drafts
        }
    }

    func load() async {
        guard projectLoadState != .loading else { return }
        projectLoadState = .loading

        accountStatus = await currentUserProvider.accountStatus()
        currentUserID = await currentUserProvider.currentUserID()
        await loadCurrentProfile()
        await loadMembership()
        await loadModerationState()
        if membershipTier.isMember {
            accountStatus = .registered
        }
        if accountStatus == .registered {
            await loadProjectSlotStatus(reportsErrors: false)
        } else {
            projectSlotStatus = .base
        }

        do {
            let loadedProjects = try await projectRepository.fetchProjects()
            projects = loadedProjects
            projectLoadState = .loaded
            openPendingDeepLinkIfPossible()
            if accountStatus == .registered {
                await loadNotifications()
                startObservingNotifications()
            } else {
                resetNotifications()
            }
        } catch {
            let appError = map(error)
            projectLoadState = .error(appError)
            errorMessage = appError.userMessage
        }
    }

    func loadFeedbacks(for projectID: UUID) async {
        guard feedbackLoadStates[projectID] != .loading else { return }
        feedbackLoadStates[projectID] = .loading

        do {
            let fetchedFeedbacks = try await feedbackRepository.fetchFeedbacks(projectID: projectID)
            let remoteFeedbacks = await hydrateFeedbacks(fetchedFeedbacks)
            let optimistic = feedbacks.filter {
                $0.projectID == projectID && optimisticFeedbackIDs.contains($0.id)
            }
            let privateOwned = feedbacks.filter {
                $0.projectID == projectID
                    && ownedFeedbackIDs.contains($0.id)
                    && !$0.isPublic
            }

            feedbacks.removeAll { $0.projectID == projectID }
            feedbacks.append(contentsOf: remoteFeedbacks)
            for feedback in optimistic + privateOwned
            where !feedbacks.contains(where: { $0.id == feedback.id }) {
                feedbacks.append(feedback)
            }
            let projectFeedbackIDs = feedbacks
                .filter { $0.projectID == projectID }
                .map(\.id)
            if let persistedLikes = try? await feedbackRepository.fetchLikedFeedbackIDs(
                feedbackIDs: projectFeedbackIDs
            ) {
                likedFeedbackIDs.formUnion(persistedLikes)
            }
            if let receipts = try? await feedbackRepository.fetchCreatorReceipts(
                feedbackIDs: projectFeedbackIDs
            ) {
                applyCreatorReceipts(receipts)
            }
            feedbackLoadStates[projectID] = .loaded
        } catch {
            let appError = map(error)
            feedbackLoadStates[projectID] = .error(appError)
            if feedbacks(for: projectID).isEmpty {
                errorMessage = appError.userMessage
            }
        }
    }

    func feedbacks(for projectID: UUID) -> [Feedback] {
        feedbacks
            .filter {
                $0.projectID == projectID
                    && $0.isPublic
                    && $0.isVisible()
                    && !($0.senderID.map(blockedProfileIDs.contains) ?? false)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var unreadNotificationCount: Int {
        notifications.lazy.filter { !$0.isRead }.count
    }

    func loadNotifications() async {
        guard accountStatus == .registered else {
            resetNotifications()
            return
        }
        guard notificationLoadState != .loading else { return }
        notificationLoadState = .loading

        do {
            notifications = try await notificationRepository.fetchNotifications()
                .sorted { $0.createdAt > $1.createdAt }
            notificationLoadState = .loaded
        } catch {
            notificationLoadState = .error(map(error))
        }
    }

    func loadAnnouncements() async {
        guard announcementLoadState != .loading else { return }
        announcementLoadState = .loading
        do {
            announcements = try await announcementRepository.fetchPublishedAnnouncements()
            announcementLoadState = .loaded
        } catch {
            let appError = map(error)
            announcementLoadState = .error(appError)
        }
    }

    var receivedQuestions: [PocoQuestion] {
        questions
            .filter { $0.isReceived(by: currentUserID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var sentQuestions: [PocoQuestion] {
        questions
            .filter { $0.isSent(by: currentUserID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var pendingReceivedQuestionCount: Int {
        receivedQuestions.lazy.filter { $0.effectiveStatus == .pending }.count
    }

    func loadQuestions() async {
        guard accountStatus == .registered else {
            questions = []
            qAndALoadState = .idle
            return
        }
        guard qAndALoadState != .loading else { return }
        qAndALoadState = .loading
        do {
            questions = try await qAndARepository.fetchQuestions()
            qAndALoadState = .loaded
        } catch {
            let appError = map(error)
            qAndALoadState = .error(appError)
            errorMessage = appError.userMessage
        }
    }

    func sendQuestion(
        to creatorID: UUID,
        projectID: UUID?,
        message: String
    ) async -> Result<PocoQuestion, AppError> {
        do {
            let question = try await qAndARepository.sendQuestion(
                creatorID: creatorID,
                projectID: projectID,
                message: message
            )
            mergeQuestion(question)
            return .success(question)
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func answerQuestion(id: UUID, answer: String) async -> Result<Void, AppError> {
        do {
            mergeQuestion(try await qAndARepository.answerQuestion(id: id, answer: answer))
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func updateQuestion(id: UUID, message: String) async -> Result<Void, AppError> {
        do {
            mergeQuestion(try await qAndARepository.updateQuestion(id: id, message: message))
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func withdrawQuestion(id: UUID) async -> Result<Void, AppError> {
        do {
            mergeQuestion(try await qAndARepository.withdrawQuestion(id: id))
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func reportQuestion(
        id: UUID,
        reason: FeedbackReportReason,
        details: String?
    ) async -> Result<Void, AppError> {
        do {
            try await qAndARepository.reportQuestion(id: id, reason: reason, details: details)
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    private func mergeQuestion(_ question: PocoQuestion) {
        if let index = questions.firstIndex(where: { $0.id == question.id }) {
            questions[index] = question
        } else {
            questions.insert(question, at: 0)
        }
    }

    func startObservingNotifications() {
        guard accountStatus == .registered, notificationRealtimeTask == nil else { return }
        notificationRealtimeTask = Task { [weak self, notificationRepository = self.notificationRepository] in
            defer { self?.notificationRealtimeTask = nil }
            let stream = await notificationRepository.observeNotifications()
            do {
                for try await notification in stream {
                    guard !Task.isCancelled else { return }
                    self?.mergeNotification(notification)
                }
            } catch is CancellationError {
                return
            } catch {
                // The inbox remains usable with the last successful snapshot.
                // A later load or app activation can restore the subscription.
            }
        }
    }

    func openNotification(_ notification: PocoNotification) async -> Feedback? {
        let previousReadAt = notification.readAt
        setNotificationRead(id: notification.id, at: previousReadAt ?? .now)

        do {
            let readAt = try await notificationRepository.markRead(id: notification.id)
            setNotificationRead(id: notification.id, at: readAt)
        } catch {
            setNotificationRead(id: notification.id, at: previousReadAt)
            errorMessage = map(error).userMessage
        }

        guard let feedbackID = notification.feedbackID else { return nil }
        if let feedback = feedbacks.first(where: { $0.id == feedbackID }) {
            return feedback
        }

        do {
            let fetched = try await feedbackRepository.fetchFeedback(id: feedbackID)
            let hydrated = await hydrateFeedbacks([fetched]).first ?? fetched
            if let index = feedbacks.firstIndex(where: { $0.id == hydrated.id }) {
                feedbacks[index] = hydrated
            } else {
                feedbacks.append(hydrated)
            }
            if let receipt = try? await feedbackRepository.fetchCreatorReceipts(
                feedbackIDs: [hydrated.id]
            ) {
                applyCreatorReceipts(receipt)
            }
            return feedbacks.first { $0.id == hydrated.id }
        } catch {
            errorMessage = map(error).userMessage
            return nil
        }
    }

    private func mergeNotification(_ notification: PocoNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index] = notification
        } else {
            notifications.append(notification)
        }
        notifications.sort { $0.createdAt > $1.createdAt }
    }

    private func setNotificationRead(id: UUID, at readAt: Date?) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].readAt = readAt
    }

    private func resetNotifications() {
        notificationRealtimeTask?.cancel()
        notificationRealtimeTask = nil
        notifications.removeAll()
        notificationLoadState = .idle
    }

    var sentFeedbacks: [Feedback] {
        feedbacks
            .filter { ownedFeedbackIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var likedFeedbacks: [Feedback] {
        feedbacks
            .filter {
                likedFeedbackIDs.contains($0.id)
                    && !($0.senderID.map(blockedProfileIDs.contains) ?? false)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func loadMyActivity() async {
        guard activityLoadState != .loading else { return }
        activityLoadState = .loading

        do {
            async let ownedRequest = moderationRepository.fetchOwnedFeedbacks()
            async let likedRequest = feedbackRepository.fetchLikedFeedbacks()
            let (owned, liked) = try await (ownedRequest, likedRequest)

            ownedFeedbackIDs.formUnion(owned.map(\.id))
            likedFeedbackIDs.formUnion(liked.map(\.id))

            var uniqueFeedbacks: [UUID: Feedback] = [:]
            for feedback in owned + liked {
                uniqueFeedbacks[feedback.id] = feedback
            }
            let hydrated = await hydrateFeedbacks(Array(uniqueFeedbacks.values))
            mergeActivityFeedbacks(hydrated)

            if let receipts = try? await feedbackRepository.fetchCreatorReceipts(
                feedbackIDs: hydrated.map(\.id)
            ) {
                applyCreatorReceipts(receipts)
            }
            activityLoadState = .loaded
        } catch {
            let appError = map(error)
            activityLoadState = .error(appError)
            errorMessage = appError.userMessage
        }
    }

    func loadMemberRewards() async {
        guard canCreateProjects, memberRewardLoadState != .loading else { return }
        memberRewardLoadState = .loading

        if activityLoadState == .idle {
            await loadMyActivity()
        }

        do {
            let snapshot = try await memberRewardRepository.fetchRewards(
                signals: achievementSignals
            )
            memberRewardSnapshot = snapshot
            applyWallet(
                balance: snapshot.starCoinBalance,
                revision: snapshot.walletRevision
            )
            memberRewardLoadState = .loaded
        } catch {
            let appError = map(error)
            memberRewardLoadState = .error(appError)
            errorMessage = appError.userMessage
        }
    }

    func claimDailyLoginBonus() async -> Result<DailyLoginBonusClaim, AppError> {
        guard canCreateProjects else { return .failure(.unauthorized) }
        do {
            let claim = try await memberRewardRepository.claimDailyLoginBonus()
            lastDailyLoginClaim = claim
            applyWallet(balance: claim.starCoinBalance, revision: claim.walletRevision)
            memberRewardSnapshot = MemberRewardSnapshot(
                loginStreak: claim.loginStreak,
                lastClaimedDay: claim.claimedDay,
                starCoinBalance: claim.starCoinBalance,
                walletRevision: claim.walletRevision,
                unlockedStamps: memberRewardSnapshot.unlockedStamps
            )
            await loadMemberRewards()
            return .success(claim)
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func project(id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    func starStoreItem(id: String?) -> StarStoreItem? {
        guard let id else { return nil }
        return starStoreItems.first { $0.id == id }
    }

    func ownedQuantity(for itemID: String) -> Int {
        ownedStarItemQuantities[itemID, default: 0]
    }

    func projectDecoration(for projectID: UUID) -> ProjectDecoration {
        projectDecorations[projectID] ?? .empty
    }

    func loadStarStore(reportsErrors: Bool = true) async {
        guard starStoreLoadState != .loading else { return }
        starStoreLoadState = .loading
        do {
            starStoreItems = try await starStoreRepository.fetchCatalog()
            ownedStarItemQuantities = canCreateProjects
                ? try await starStoreRepository.fetchOwnedItemQuantities()
                : [:]
            starStoreLoadState = .loaded
        } catch {
            let appError = map(error)
            starStoreLoadState = .error(appError)
            if reportsErrors {
                errorMessage = appError.userMessage
            }
        }
    }

    func loadProjectDecoration(projectID: UUID) async {
        if starStoreItems.isEmpty {
            await loadStarStore(reportsErrors: false)
        }
        do {
            projectDecorations[projectID] = try await starStoreRepository
                .fetchProjectDecoration(projectID: projectID)
        } catch {
            // Decoration loading must never hide the project or interrupt a drop.
        }
    }

    func purchaseStarStoreItem(_ item: StarStoreItem) async -> Result<Bool, AppError> {
        guard canCreateProjects else { return .failure(.unauthorized) }
        do {
            let result = try await starStoreRepository.purchaseItem(
                id: item.id,
                requestID: UUID()
            )
            applyWallet(balance: result.balance, revision: result.walletRevision)
            ownedStarItemQuantities[result.itemID] = result.ownedQuantity
            return .success(result.purchased)
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func loadProjectSlotStatus(reportsErrors: Bool = true) async {
        guard accountStatus == .registered else {
            projectSlotStatus = .base
            return
        }
        do {
            let status = try await starStoreRepository.fetchProjectSlotStatus()
            projectSlotStatus = status
            applyWallet(balance: status.balance, revision: status.walletRevision)
        } catch {
            let appError = map(error)
            if reportsErrors {
                errorMessage = appError.userMessage
            }
        }
    }

    func redeemNextProjectSlot() async -> Result<ProjectSlotRedemptionResult, AppError> {
        guard role == .user, projectSlotStatus.nextSlotCost != nil else {
            return .failure(.projectSlotRedemptionUnavailable)
        }
        do {
            let result = try await starStoreRepository.redeemProjectSlot(requestID: UUID())
            projectSlotStatus = result.status
            applyWallet(
                balance: result.status.balance,
                revision: result.status.walletRevision
            )
            return .success(result)
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func equipProjectBackground(
        projectID: UUID,
        itemID: String?
    ) async -> Result<Void, AppError> {
        guard canCreateProjects,
              currentUserProjects.contains(where: { $0.id == projectID }) else {
            return .failure(.unauthorized)
        }
        do {
            try await starStoreRepository.equipProjectBackground(
                projectID: projectID,
                itemID: itemID
            )
            await loadProjectDecoration(projectID: projectID)
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func equipProjectBadge(
        projectID: UUID,
        slot: Int,
        itemID: String?
    ) async -> Result<Void, AppError> {
        guard canCreateProjects,
              currentUserProjects.contains(where: { $0.id == projectID }) else {
            return .failure(.unauthorized)
        }
        do {
            try await starStoreRepository.equipProjectBadge(
                projectID: projectID,
                slot: slot,
                itemID: itemID
            )
            await loadProjectDecoration(projectID: projectID)
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func giftBadge(
        _ item: StarStoreItem,
        to recipient: Creator
    ) async -> Result<BadgeGiftResult, AppError> {
        guard accountStatus == .registered else { return .failure(.unauthorized) }
        guard recipient.id != currentUserID else { return .failure(.cannotGiftToSelf) }
        guard item.kind == .profileBadge else { return .failure(.invalidInput) }
        do {
            let result = try await starStoreRepository.giftBadge(
                itemID: item.id,
                recipientID: recipient.id,
                requestID: UUID()
            )
            if result.senderQuantity > 0 {
                ownedStarItemQuantities[item.id] = result.senderQuantity
            } else {
                ownedStarItemQuantities[item.id] = nil
            }
            return .success(result)
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func ownFeedbackCount(for projectID: UUID) -> Int {
        ownFeedbackCountsByProject[projectID]
            ?? feedbacks.lazy.filter {
                $0.projectID == projectID && self.ownedFeedbackIDs.contains($0.id)
            }.count
    }

    func canSubmitFeedback(to projectID: UUID) -> Bool {
        ownFeedbackCount(for: projectID) < PocoLimits.feedbacksPerProject
    }

    func refreshOwnFeedbackCount(for projectID: UUID) async {
        if let count = try? await moderationRepository.fetchOwnFeedbackCount(
            projectID: projectID
        ) {
            ownFeedbackCountsByProject[projectID] = count
        }
    }

    func submit(_ feedback: Feedback) async -> Result<Void, AppError> {
        var feedback = feedback
        if feedback.senderID == nil, canCreateProjects, feedback.publishesProfile {
            feedback.senderID = currentUserID
        }
        if let senderID = feedback.senderID,
           let profile = profileCache[senderID]
                ?? (currentProfile?.id == senderID ? currentProfile : nil) {
            feedback.senderAvatarName = profile.avatarName
            feedback.senderAvatarURL = profile.avatarURL
        }
        let isNew = !feedbacks.contains(where: { $0.id == feedback.id })
        let currentOwnFeedbackCount = ownFeedbackCount(for: feedback.projectID)
        if isNew, currentOwnFeedbackCount >= PocoLimits.feedbacksPerProject {
            return .failure(.feedbackLimitReached)
        }
        if isNew {
            feedbacks.append(feedback)
            ownedFeedbackIDs.insert(feedback.id)
            ownFeedbackCountsByProject[feedback.projectID] = currentOwnFeedbackCount + 1
            optimisticFeedbackIDs.insert(feedback.id)
            if let index = projects.firstIndex(where: { $0.id == feedback.projectID }) {
                projects[index].feedbackCount += 1
            }
        }

        do {
            try await feedbackRepository.submitFeedback(feedback)
            optimisticFeedbackIDs.remove(feedback.id)
            claimStarCoinReward(
                eventKey: "feedback-delivered:\(feedback.id.uuidString)"
            )
            refreshAchievementProgressInBackground()
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = "送信できませんでした。もう一度試してください。"
            return .failure(appError)
        }
    }

    var currentFeedbackDrafts: [FeedbackDraft] {
        feedbackDrafts
            .filter { $0.ownerKey == feedbackDraftOwnerKey }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func feedbackDraft(for projectID: UUID) -> FeedbackDraft? {
        currentFeedbackDrafts.first { $0.projectID == projectID }
    }

    func saveFeedbackDraft(
        projectID: UUID,
        message: String,
        nickname: String,
        isPublic: Bool,
        publishesProfile: Bool
    ) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            discardFeedbackDraft(for: projectID)
            return
        }
        let draft = FeedbackDraft(
            projectID: projectID,
            message: message,
            nickname: nickname,
            isPublic: isPublic,
            publishesProfile: publishesProfile,
            updatedAt: .now,
            ownerKey: feedbackDraftOwnerKey
        )
        feedbackDrafts.removeAll {
            $0.projectID == projectID && $0.ownerKey == feedbackDraftOwnerKey
        }
        feedbackDrafts.append(draft)
        persistFeedbackDrafts()
    }

    func discardFeedbackDraft(for projectID: UUID) {
        let priorCount = feedbackDrafts.count
        feedbackDrafts.removeAll {
            $0.projectID == projectID && $0.ownerKey == feedbackDraftOwnerKey
        }
        if priorCount != feedbackDrafts.count {
            persistFeedbackDrafts()
        }
    }

    private var feedbackDraftOwnerKey: String {
        currentUserID?.uuidString ?? "local-guest"
    }

    private func persistFeedbackDrafts() {
        guard let data = try? JSONEncoder().encode(feedbackDrafts) else { return }
        UserDefaults.standard.set(data, forKey: Self.feedbackDraftsKey)
    }

    func like(_ feedback: Feedback) async {
        guard !likedFeedbackIDs.contains(feedback.id) else { return }
        let isCreatorLike = canMarkReceived(feedback)
        likedFeedbackIDs.insert(feedback.id)

        do {
            try await feedbackRepository.likeFeedback(id: feedback.id)
            if let index = feedbacks.firstIndex(where: { $0.id == feedback.id }) {
                feedbacks[index].likes += 1
            }
            if isCreatorLike {
                let receivedAt: Date
                if backendMode == .mock {
                    receivedAt = (try? await feedbackRepository.markReceivedByCreator(
                        feedbackID: feedback.id
                    )) ?? .now
                } else {
                    // Supabase creates the creator heart atomically from the
                    // normal Like insertion. Realtime later confirms it.
                    receivedAt = .now
                }
                applyCreatorReceipts([feedback.id: receivedAt])
            }
            refreshAchievementProgressInBackground()
        } catch AppError.alreadyLiked {
            // The backend unique constraint is the source of truth. Keep the
            // button selected without incrementing the displayed count again.
            likedFeedbackIDs.insert(feedback.id)
        } catch {
            likedFeedbackIDs.remove(feedback.id)
            errorMessage = map(error).userMessage
        }
    }

    var isPocoMember: Bool {
        role == .pro
    }

    var role: PocoRole {
        if membershipTier.isMember { return .pro }
        return accountStatus == .registered ? .user : .guest
    }

    var capabilities: AppCapabilities {
        .forRole(role)
    }

    var maximumProfileLinkCount: Int {
        role == .pro ? 10 : 5
    }

    var canCreateProjects: Bool {
        capabilities.canCreateProject
    }

    var onboardingStateToken: String {
        "\(currentUserID?.uuidString ?? "guest"):\(role.rawValue)"
    }

    func presentOnboardingIfNeeded() {
        guard onboardingGuideRequest == nil,
              accountStatus == .registered,
              let currentUserID else { return }
        let guide: PocoOnboardingGuide = role == .pro ? .pro : .member
        guard PocoOnboardingProgress.shouldPresent(guide, userID: currentUserID) else { return }
        onboardingGuideRequest = guide
    }

    func completeOnboarding(_ guide: PocoOnboardingGuide) {
        if let currentUserID {
            PocoOnboardingProgress.complete(guide, userID: currentUserID)
        }
        onboardingGuideRequest = nil
    }

    func replayOnboarding() {
        guard accountStatus == .registered else { return }
        onboardingGuideRequest = role == .pro ? .pro : .member
    }

    func claimStarCoinReward(eventKey: String) {
        guard let event = StarCoinEvent(eventKey: eventKey),
              rewardedCoinEventKeys.insert(event.eventKey).inserted else { return }

        persistRewardedCoinEventKeys()
        Task {
            do {
                let award = try await serverAuthorityService.claimStarCoinReward(event)
                applyWallet(balance: award.balance, revision: award.walletRevision)
            } catch {
                // A failed request can be retried by the next matching user
                // interaction. Coin errors never interrupt the bubble UX.
                rewardedCoinEventKeys.remove(event.eventKey)
                persistRewardedCoinEventKeys()
            }
        }
    }

    private var achievementSignals: AchievementSignals {
        AchievementSignals(
            sentFeedbackCount: sentFeedbacks.count,
            longestFeedbackStreak: PocoCalendar.longestConsecutiveDayStreak(
                sentFeedbacks.map(\.createdAt)
            ),
            uniqueProjectCount: Set(sentFeedbacks.map(\.projectID)).count,
            projectCount: currentUserProjects.count,
            likedFeedbackCount: likedFeedbackIDs.count,
            receivedLikeCount: sentFeedbacks.reduce(0) { $0 + $1.likes },
            creatorHeartCount: sentFeedbacks.filter { $0.creatorReceivedAt != nil }.count
        )
    }

    /// Achievement evaluation never delays the action that earned it. The
    /// server remains authoritative, then the inbox is refreshed so the newly
    /// unlocked stamp appears as a notification in the same session.
    private func refreshAchievementProgressInBackground() {
        guard accountStatus == .registered else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.loadMemberRewards()
            await self.loadNotifications()
        }
    }

    private func persistStarCoinBalance() {
        UserDefaults.standard.set(starCoinBalance, forKey: Self.starCoinBalanceKey)
        UserDefaults.standard.set(
            starCoinWalletRevision,
            forKey: Self.starCoinWalletRevisionKey
        )
    }

    private func applyWallet(balance: Int, revision: Int64) {
        guard revision >= starCoinWalletRevision else { return }
        starCoinBalance = max(0, balance)
        starCoinWalletRevision = revision
        persistStarCoinBalance()
    }

    private func persistRewardedCoinEventKeys() {
        UserDefaults.standard.set(
            Array(rewardedCoinEventKeys),
            forKey: Self.rewardedCoinEventsKey
        )
    }

    private func resetCachedStarCoins() {
        starCoinBalance = 0
        starCoinWalletRevision = 0
        starStoreItems = []
        ownedStarItemQuantities = [:]
        projectDecorations = [:]
        projectSlotStatus = .base
        starStoreLoadState = .idle
        rewardedCoinEventKeys.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.starCoinBalanceKey)
        UserDefaults.standard.removeObject(forKey: Self.starCoinWalletRevisionKey)
        UserDefaults.standard.removeObject(forKey: Self.rewardedCoinEventsKey)
    }

    var maximumProjectCount: Int {
        switch role {
        case .guest: 0
        case .user: projectSlotStatus.freeProjectLimit
        case .pro: 30
        }
    }

    var canCreateAnotherProject: Bool {
        canCreateProjects && currentUserProjects.count < maximumProjectCount
    }

    var currentUserProjects: [Project] {
        guard let currentUserID else { return [] }
        return projects.filter { $0.creator.id == currentUserID }
    }

    var currentDisplayName: String {
        if let currentProfile { return currentProfile.name }
        if backendMode == .mock { return "そらのひつじ" }
        return canCreateProjects ? "Pocoユーザー" : "Pocoゲスト"
    }

    var memberLikeSummary: MemberLikeSummary {
        guard let currentUserID else {
            return MemberLikeSummary(projectLikes: 0, feedbackLikes: 0)
        }

        let ownedProjectIDs = Set(
            projects.lazy
                .filter { $0.creator.id == currentUserID }
                .map(\.id)
        )
        return MemberLikeSummary(
            projectLikes: feedbacks.lazy
                .filter { ownedProjectIDs.contains($0.projectID) }
                .reduce(0) { $0 + $1.likes },
            feedbackLikes: feedbacks.lazy
                .filter { self.ownedFeedbackIDs.contains($0.id) }
                .reduce(0) { $0 + $1.likes }
        )
    }

    func canMarkReceived(_ feedback: Feedback) -> Bool {
        guard feedback.creatorReceivedAt == nil,
              let currentUserID,
              let project = project(id: feedback.projectID) else { return false }
        return project.creator.id == currentUserID && project.relationship == .creator
    }

    func creatorLikeDisplayName(for feedback: Feedback) -> String? {
        guard feedback.creatorReceivedAt != nil,
              let project = project(id: feedback.projectID),
              project.relationship == .creator else { return nil }
        return project.creator.name
    }

    func owns(_ feedback: Feedback) -> Bool {
        ownedFeedbackIDs.contains(feedback.id)
    }

    func canHideAsCreator(_ feedback: Feedback) -> Bool {
        guard let currentUserID,
              let project = project(id: feedback.projectID) else { return false }
        return project.creator.id == currentUserID && !owns(feedback)
    }

    func report(
        _ feedback: Feedback,
        reason: FeedbackReportReason,
        details: String?
    ) async -> Result<Void, AppError> {
        let normalizedDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await moderationRepository.reportFeedback(
                id: feedback.id,
                reason: reason,
                details: normalizedDetails?.isEmpty == false ? normalizedDetails : nil
            )
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func submitRightsHolderRequest(
        for project: Project,
        requesterName: String,
        requesterEmail: String,
        relationship: RightsHolderRelationship,
        details: String
    ) async -> Result<UUID, AppError> {
        let normalizedName = requesterName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = requesterEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedName.isEmpty,
              normalizedName.count <= 80,
              normalizedEmail.count <= 254,
              Self.isPlausibleEmail(normalizedEmail),
              !normalizedDetails.isEmpty,
              normalizedDetails.count <= 1_000 else {
            return .failure(.invalidInput)
        }

        do {
            let requestID = try await rightsHolderRequestRepository.submit(
                RightsHolderRequest(
                    projectID: project.id,
                    requesterName: normalizedName,
                    requesterEmail: normalizedEmail,
                    relationship: relationship,
                    details: normalizedDetails
                )
            )
            return .success(requestID)
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    private static func isPlausibleEmail(_ value: String) -> Bool {
        guard let atIndex = value.lastIndex(of: "@"),
              atIndex != value.startIndex else { return false }
        let domainStart = value.index(after: atIndex)
        guard domainStart < value.endIndex else { return false }
        let domain = value[domainStart...]
        return domain.contains(".") && !value.contains(where: { $0.isWhitespace })
    }

    func deleteOwnFeedback(_ feedback: Feedback) async -> Result<Void, AppError> {
        guard owns(feedback) else { return .failure(.unauthorized) }
        do {
            try await moderationRepository.deleteOwnFeedback(id: feedback.id)
            let currentCount = ownFeedbackCount(for: feedback.projectID)
            ownFeedbackCountsByProject[feedback.projectID] = accountStatus == .guest
                ? currentCount
                : max(0, currentCount - 1)
            removeFeedbackFromLocalState(feedback)
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func hideAsCreator(_ feedback: Feedback) async -> Result<Void, AppError> {
        guard canHideAsCreator(feedback) else { return .failure(.unauthorized) }
        do {
            try await moderationRepository.hideFeedbackAsCreator(id: feedback.id)
            removeFeedbackFromLocalState(feedback)
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func block(_ creator: Creator) async -> Result<Void, AppError> {
        guard creator.id != currentUserID else { return .failure(.unauthorized) }
        do {
            try await moderationRepository.blockProfile(id: creator.id)
            blockedProfileIDs.insert(creator.id)
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func activatePreviewMembership() {
        guard backendMode == .mock else { return }
        registerPreviewAccount()
        UserDefaults.standard.set(true, forKey: "poco.previewMembership")
        membershipTier = .pocoMember
    }

    func registerPreviewAccount(
        displayName: String = "そらのひつじ",
        avatarName: String? = BuiltInAvatar.cat.rawValue,
        avatarImageData: Data? = nil
    ) {
        guard backendMode == .mock else { return }
        UserDefaults.standard.set(true, forKey: "poco.previewRegisteredAccount")
        accountStatus = .registered
        let profileID = currentUserID ?? MockData.previewUser.id
        currentUserID = profileID
        currentAvatarImageData = avatarImageData
        if let avatarImageData {
            UserDefaults.standard.set(avatarImageData, forKey: Self.mockAvatarImageDataKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.mockAvatarImageDataKey)
        }
        currentProfile = Creator(
            id: profileID,
            name: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarName: avatarImageData == nil ? avatarName : nil,
            handle: currentProfile?.handle ?? CreatorHandle.generated(for: profileID),
            profileLinks: currentProfile?.profileLinks ?? []
        )
        if let currentProfile {
            profileCache[profileID] = currentProfile
            applyProfile(currentProfile)
        }
        Task { [weak self] in
            guard let self else { return }
            await self.loadProjectSlotStatus(reportsErrors: false)
            await self.loadNotifications()
            self.startObservingNotifications()
        }
    }

    func signInWithApple(
        identityToken: String,
        rawNonce: String,
        displayName: String?,
        appleFullName: String?,
        email: String?,
        avatarName: String?,
        avatarImageData: Data?
    ) async {
        guard authenticationState != .authenticating else { return }
        authenticationState = .authenticating

        do {
            let account = try await authRepository.signInWithApple(
                credential: AppleIdentityCredential(
                    identityToken: identityToken,
                    rawNonce: rawNonce,
                    displayName: displayName,
                    appleFullName: appleFullName,
                    email: email
                )
            )
            currentUserID = account.id
            accountStatus = .registered
            let existingProfile = try? await profileRepository.fetchProfile(id: account.id)
            let normalizedDisplayName = account.displayName?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let profileName: String
            if let normalizedDisplayName, !normalizedDisplayName.isEmpty {
                profileName = normalizedDisplayName
            } else {
                profileName = existingProfile?.name ?? "Pocoユーザー"
            }
            var selectedAvatarName = avatarName ?? existingProfile?.avatarName
            var avatarURL = avatarName == nil ? existingProfile?.avatarURL : nil
            currentAvatarImageData = nil

            if let avatarImageData, let profileAvatarStorage {
                do {
                    let compressedData = try await Task.detached(priority: .userInitiated) {
                        try ProjectImageProcessor.compressedJPEG(
                            from: avatarImageData,
                            maximumDimension: 512,
                            quality: 0.82
                        )
                    }.value
                    avatarURL = try await profileAvatarStorage.uploadProfileAvatar(
                        compressedData,
                        userID: account.id
                    )
                    currentAvatarImageData = compressedData
                    selectedAvatarName = nil
                } catch {
                    errorMessage = "登録は完了しましたが、プロフィール画像を保存できませんでした。"
                }
            }

            let profile = Creator(
                id: account.id,
                name: profileName,
                avatarName: selectedAvatarName,
                avatarURL: avatarURL,
                handle: existingProfile?.handle ?? CreatorHandle.generated(for: account.id),
                profileLinks: existingProfile?.profileLinks ?? []
            )
            currentProfile = profile
            profileCache[account.id] = profile
            applyProfile(profile)

            try? await profileRepository.saveProfile(profile)

            await loadMembership()
            await loadProjectSlotStatus(reportsErrors: false)
            await loadNotifications()
            startObservingNotifications()
            authenticationState = .authenticated
        } catch {
            let message = map(error).userMessage
            authenticationState = .error(message)
            errorMessage = message
        }
    }

    func reportAppleSignInFailure(_ message: String) {
        authenticationState = .error(message)
    }

    func updateProfile(
        displayName: String,
        handle: String,
        avatarName: String?,
        avatarImageData: Data?,
        profileLinks: [ProfileSocialLink]
    ) async -> Result<Void, AppError> {
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHandle = CreatorHandle.normalize(handle)
        guard canCreateProjects,
              let userID = currentUserID,
              !normalizedName.isEmpty,
              normalizedName.count <= 80,
              CreatorHandle.isValid(normalizedHandle),
              profileLinks.count <= maximumProfileLinkCount else {
            return .failure(.unauthorized)
        }

        let previousProfile = currentProfile
        var selectedAvatarName = avatarName ?? previousProfile?.avatarName
        var avatarURL = avatarName == nil ? previousProfile?.avatarURL : nil
        var displayImageData: Data?

        do {
            if let avatarImageData {
                let compressedData = try await Task.detached(priority: .userInitiated) {
                    try ProjectImageProcessor.compressedJPEG(
                        from: avatarImageData,
                        maximumDimension: 512,
                        quality: 0.82
                    )
                }.value
                displayImageData = compressedData
                selectedAvatarName = nil
                if let profileAvatarStorage {
                    avatarURL = try await profileAvatarStorage.uploadProfileAvatar(
                        compressedData,
                        userID: userID
                    )
                } else {
                    avatarURL = nil
                }
            }

            let profile = Creator(
                id: userID,
                name: normalizedName,
                avatarName: selectedAvatarName,
                avatarURL: avatarURL,
                handle: normalizedHandle,
                profileLinks: profileLinks
            )
            try await profileRepository.saveProfile(profile)
            currentProfile = profile
            currentAvatarImageData = displayImageData
            if backendMode == .mock {
                if let displayImageData {
                    UserDefaults.standard.set(
                        displayImageData,
                        forKey: Self.mockAvatarImageDataKey
                    )
                } else {
                    UserDefaults.standard.removeObject(forKey: Self.mockAvatarImageDataKey)
                }
            }
            profileCache[userID] = profile
            applyProfile(profile)

            if let previousURL = previousProfile?.avatarURL,
               previousURL != avatarURL,
               let profileAvatarStorage {
                try? await profileAvatarStorage.deleteProfileAvatar(at: previousURL)
            }
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func loadPublicProfile(id: UUID) async -> Creator? {
        if let cached = profileCache[id], !cached.profileLinks.isEmpty {
            return cached
        }
        do {
            let profile = try await profileRepository.fetchProfile(id: id)
            profileCache[id] = profile
            applyProfile(profile)
            if currentProfile?.id == id {
                currentProfile = profile
            }
            return profile
        } catch {
            return profileCache[id]
        }
    }

    func signOut() async {
        do {
            try await authRepository.signOut()
            await applySignedOutState()
        } catch {
            let message = map(error).userMessage
            authenticationState = .error(message)
            errorMessage = message
        }
    }

    @discardableResult
    func deleteAccount() async -> Bool {
        guard accountStatus == .registered,
              accountDeletionState != .deleting else {
            return false
        }

        accountDeletionState = .deleting
        do {
            try await authRepository.deleteAccount()
            await applySignedOutState()
            clearAccountScopedPreferences()
            accountDeletionState = .deleted
            return true
        } catch {
            let message = map(error).userMessage
            accountDeletionState = .error(message)
            errorMessage = message
            return false
        }
    }

    func resetAccountDeletionState() {
        accountDeletionState = .idle
    }

    private func applySignedOutState() async {
        notificationRealtimeTask?.cancel()
        notificationRealtimeTask = nil
        accountStatus = await currentUserProvider.accountStatus()
        currentUserID = await currentUserProvider.currentUserID()
        currentProfile = nil
        currentAvatarImageData = nil
        profileCache.removeAll()
        membershipTier = .guest
        likedFeedbackIDs.removeAll()
        ownedFeedbackIDs.removeAll()
        ownFeedbackCountsByProject.removeAll()
        blockedProfileIDs.removeAll()
        activityLoadState = .idle
        memberRewardLoadState = .idle
        memberRewardSnapshot = .empty
        lastDailyLoginClaim = nil
        authenticationState = .idle
        resetNotifications()
        resetCachedStarCoins()
    }

    private func clearAccountScopedPreferences() {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys.filter { key in
            key.hasPrefix("poco.member")
                || key.hasPrefix("poco.profile")
                || key.hasPrefix("poco.onboarding")
                || key.hasPrefix("poco.settings.")
                || key.hasPrefix("poco.preview")
                || key.hasPrefix("poco.reward")
                || key.hasPrefix("poco.mockReward")
        }
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }

    func resetPreviewMembership() {
        guard backendMode == .mock else { return }
        UserDefaults.standard.set(false, forKey: "poco.previewMembership")
        UserDefaults.standard.set(false, forKey: "poco.previewRegisteredAccount")
        membershipTier = .guest
        accountStatus = .guest
        currentProfile = nil
        currentAvatarImageData = nil
        profileCache.removeAll()
        activityLoadState = .idle
        memberRewardLoadState = .idle
        memberRewardSnapshot = .empty
        lastDailyLoginClaim = nil
        resetNotifications()
        resetCachedStarCoins()
    }

    func loadMembershipOffer() async {
        guard backendMode == .supabase, membershipPurchaseState != .loading else { return }
        membershipPurchaseState = .loading
        do {
            membershipOffer = try await membershipPurchaseService.fetchOffer()
            membershipPurchaseState = .idle
        } catch {
            membershipPurchaseState = .error(map(error).userMessage)
        }
    }

    func purchaseMembership() async {
        guard canCreateProjects else {
            membershipPurchaseState = .error("Poco Proになるにはユーザー登録が必要です。")
            return
        }
        membershipPurchaseState = .purchasing
        do {
            switch try await membershipPurchaseService.purchase() {
            case .purchased(let entitlement):
                membershipPurchaseState = .purchased
                await syncMembershipEntitlement(entitlement)
            case .pending:
                membershipPurchaseState = .error("購入の承認を待っています。")
            case .cancelled:
                membershipPurchaseState = .idle
            }
        } catch {
            membershipPurchaseState = .error(map(error).userMessage)
        }
    }

    func restoreMembership() async {
        guard canCreateProjects else {
            membershipPurchaseState = .error("購入を復元するにはユーザー登録が必要です。")
            return
        }
        membershipPurchaseState = .loading
        do {
            if let entitlement = try await membershipPurchaseService.restore() {
                membershipPurchaseState = .purchased
                await syncMembershipEntitlement(entitlement)
            } else {
                membershipPurchaseState = .error("復元できる購入が見つかりませんでした。")
            }
        } catch {
            membershipPurchaseState = .error(map(error).userMessage)
        }
    }

    private func syncMembershipEntitlement(_ entitlement: MembershipEntitlement) async {
        membershipSyncState = .syncing
        do {
            try await serverAuthorityService.syncMembershipEntitlement(entitlement)
            membershipSyncState = .synced
            await loadMembership()
        } catch {
            // StoreKit already verified this device transaction. A webhook or
            // later restore can reconcile the server entitlement.
            membershipSyncState = .deferred
        }
    }

    func createProject(
        title: String,
        creatorName: String,
        category: ProjectCategory,
        relationship: ProjectRelationship,
        purpose: ProjectPurpose,
        contentRating: ProjectContentRating,
        acceptsQuestions: Bool,
        description: String,
        externalURL: URL?,
        imageData: [Data]
    ) async -> Result<Project, AppError> {
        guard canCreateProjects else {
            let error = AppError.unauthorized
            errorMessage = "作品を作るにはユーザー登録が必要です。"
            return .failure(error)
        }
        guard canCreateAnotherProject else {
            let error = AppError.projectLimitReached
            errorMessage = error.userMessage
            return .failure(error)
        }
        guard let creatorID = await currentUserProvider.currentUserID() else {
            let error = AppError.unauthorized
            errorMessage = error.userMessage
            return .failure(error)
        }

        let projectID = UUID()
        var uploadedImageURLs: [URL] = []
        var createdProject: Project?

        do {
            let creator = Creator(
                id: creatorID,
                name: currentProfile?.id == creatorID
                    ? currentProfile?.name ?? currentDisplayName
                    : currentDisplayName,
                avatarName: currentProfile?.id == creatorID ? currentProfile?.avatarName : nil,
                avatarURL: currentProfile?.id == creatorID ? currentProfile?.avatarURL : nil,
                handle: currentProfile?.id == creatorID ? currentProfile?.handle : nil
            )
            var project = Project(
                id: projectID,
                title: title,
                creator: creator,
                authorName: creatorName,
                category: category,
                description: description,
                imageName: nil,
                imageURL: nil,
                externalURL: externalURL,
                feedbackCount: 0,
                createdAt: .now,
                relationship: relationship,
                purpose: purpose,
                verificationStatus: .unverified,
                contentRating: contentRating,
                acceptsQuestions: acceptsQuestions
            )

            // The database row is created first so Storage RLS can verify that
            // this project ID really belongs to the uploader.
            try await projectRepository.createProject(project)
            createdProject = project

            if !imageData.isEmpty, let projectImageStorage {
                for data in imageData.prefix(membershipTier.isMember ? 3 : 1) {
                    let compressedData = try await Task.detached(priority: .userInitiated) {
                        try ProjectImageProcessor.compressedJPEG(from: data)
                    }.value
                    let imageURL = try await projectImageStorage.uploadProjectImage(
                        compressedData,
                        projectID: projectID,
                        creatorID: creatorID,
                        imageID: UUID()
                    )
                    uploadedImageURLs.append(imageURL)
                }
                project.setArtworkURLs(uploadedImageURLs)
                try await projectRepository.updateProject(project)
                createdProject = project
            }

            projects.insert(project, at: 0)
            refreshAchievementProgressInBackground()
            return .success(project)
        } catch {
            if let projectImageStorage {
                for imageURL in uploadedImageURLs {
                    try? await projectImageStorage.deleteProjectImage(at: imageURL)
                }
            }
            if createdProject != nil {
                try? await projectRepository.deleteProject(id: projectID)
            }
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func updateProject(
        _ existingProject: Project,
        title: String,
        creatorName: String,
        category: ProjectCategory,
        relationship: ProjectRelationship,
        purpose: ProjectPurpose,
        contentRating: ProjectContentRating,
        acceptsQuestions: Bool,
        description: String,
        externalURL: URL?,
        retainedImageURLs: [URL],
        newImageData: [Data]
    ) async -> Result<Project, AppError> {
        guard canCreateProjects,
              let creatorID = await currentUserProvider.currentUserID(),
              creatorID == existingProject.creator.id else {
            let error = AppError.unauthorized
            errorMessage = error.userMessage
            return .failure(error)
        }

        let oldImageURLs = existingProject.artworkURLs
        var uploadedImageURLs: [URL] = []

        do {
            if !newImageData.isEmpty, let projectImageStorage {
                let maximumCount = membershipTier.isMember
                    ? 3
                    : max(1, existingProject.artworkURLs.count)
                let uploadCapacity = max(0, maximumCount - retainedImageURLs.count)
                for data in newImageData.prefix(uploadCapacity) {
                    let compressedData = try await Task.detached(priority: .userInitiated) {
                        try ProjectImageProcessor.compressedJPEG(from: data)
                    }.value
                    let imageURL = try await projectImageStorage.uploadProjectImage(
                        compressedData,
                        projectID: existingProject.id,
                        creatorID: creatorID,
                        imageID: UUID()
                    )
                    uploadedImageURLs.append(imageURL)
                }
            }

            var updatedProject = existingProject
            updatedProject.title = title
            updatedProject.authorName = creatorName
            updatedProject.category = category
            updatedProject.description = description
            updatedProject.externalURL = externalURL
            updatedProject.relationship = relationship
            updatedProject.purpose = purpose
            updatedProject.verificationStatus = relationship == existingProject.relationship
                ? existingProject.verificationStatus
                : .unverified
            updatedProject.contentRating = contentRating
            updatedProject.acceptsQuestions = acceptsQuestions
            updatedProject.isContentLocked = false
            let maximumCount = membershipTier.isMember
                ? 3
                : max(1, existingProject.artworkURLs.count)
            updatedProject.setArtworkURLs(
                Array((retainedImageURLs + uploadedImageURLs).prefix(maximumCount))
            )

            try await projectRepository.updateProject(updatedProject)
            if let index = projects.firstIndex(where: { $0.id == updatedProject.id }) {
                projects[index] = updatedProject
            }

            if let projectImageStorage {
                let retained = Set(updatedProject.artworkURLs.map(\.absoluteString))
                for oldImageURL in oldImageURLs where !retained.contains(oldImageURL.absoluteString) {
                    try? await projectImageStorage.deleteProjectImage(at: oldImageURL)
                }
            }
            return .success(updatedProject)
        } catch {
            if let projectImageStorage {
                for uploadedImageURL in uploadedImageURLs {
                    try? await projectImageStorage.deleteProjectImage(at: uploadedImageURL)
                }
            }
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func deleteProject(_ project: Project) async -> Result<Void, AppError> {
        guard canCreateProjects,
              let creatorID = await currentUserProvider.currentUserID(),
              creatorID == project.creator.id else {
            let error = AppError.unauthorized
            errorMessage = error.userMessage
            return .failure(error)
        }

        do {
            try await projectRepository.deleteProject(id: project.id)
            stopObservingFeedbacks(for: project.id)
            projects.removeAll { $0.id == project.id }
            feedbacks.removeAll { $0.projectID == project.id }
            notifications.removeAll { $0.projectID == project.id }
            feedbackLoadStates[project.id] = nil
            ownFeedbackCountsByProject[project.id] = nil
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = appError.userMessage
            return .failure(appError)
        }
    }

    func startObservingFeedbacks(for projectID: UUID) {
        guard realtimeTasks[projectID] == nil else { return }
        let repository = feedbackRepository

        realtimeTasks[projectID] = Task { [weak self] in
            guard let self else { return }
            let stream = await repository.observeFeedbacks(projectID: projectID)
            do {
                for try await feedback in stream {
                    guard !Task.isCancelled else { break }
                    let hydrated = await self.hydrateFeedbacks([feedback]).first ?? feedback
                    self.mergeRealtimeFeedback(hydrated)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                if self.feedbacks(for: projectID).isEmpty {
                    self.errorMessage = self.map(error).userMessage
                }
            }
        }


        realtimeReceiptTasks[projectID] = Task { [weak self] in
            guard let self else { return }
            let stream = await repository.observeCreatorReceipts(projectID: projectID)
            do {
                for try await receipt in stream {
                    guard !Task.isCancelled else { break }
                    guard self.feedbacks.contains(where: {
                        $0.id == receipt.feedbackID && $0.projectID == projectID
                    }) else { continue }
                    self.applyCreatorReceipts([receipt.feedbackID: receipt.createdAt])
                }
            } catch {
                // Feedbacks remain usable if the optional receipt stream drops.
            }
        }
    }

    func stopObservingFeedbacks(for projectID: UUID) {
        realtimeTasks[projectID]?.cancel()
        realtimeTasks[projectID] = nil
        realtimeReceiptTasks[projectID]?.cancel()
        realtimeReceiptTasks[projectID] = nil
    }

    @discardableResult
    func open(url: URL) -> Bool {
        guard let id = ProjectDeepLink.projectID(from: url) else { return false }

        selectedTab = .home
        if project(id: id) != nil {
            deepLinkResolutionTask?.cancel()
            pendingDeepLinkProjectID = nil
            homePath = [id]
            isResolvingDeepLink = false
        } else {
            pendingDeepLinkProjectID = id
            isResolvingDeepLink = true
            resolveDeepLinkProject(id)
        }
        return true
    }

    private func resolveDeepLinkProject(_ id: UUID) {
        deepLinkResolutionTask?.cancel()
        let repository = projectRepository

        deepLinkResolutionTask = Task { [weak self] in
            do {
                let resolvedProject = try await repository.fetchProject(id: id)
                guard !Task.isCancelled, let self else { return }
                if let index = self.projects.firstIndex(where: { $0.id == id }) {
                    self.projects[index] = resolvedProject
                } else {
                    self.projects.insert(resolvedProject, at: 0)
                }
                self.pendingDeepLinkProjectID = nil
                self.selectedTab = .home
                self.homePath = [id]
                self.isResolvingDeepLink = false
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.pendingDeepLinkProjectID = nil
                self.isResolvingDeepLink = false
                self.errorMessage = self.map(error).userMessage
            }
        }
    }

    private func mergeRealtimeFeedback(_ feedback: Feedback) {
        if let index = feedbacks.firstIndex(where: { $0.id == feedback.id }) {
            feedbacks[index] = feedback
            optimisticFeedbackIDs.remove(feedback.id)
            return
        }

        feedbacks.append(feedback)
        if let index = projects.firstIndex(where: { $0.id == feedback.projectID }) {
            projects[index].feedbackCount += 1
        }
    }

    private func mergeActivityFeedbacks(_ values: [Feedback]) {
        for value in values {
            if let index = feedbacks.firstIndex(where: { $0.id == value.id }) {
                var merged = value
                merged.creatorReceivedAt = feedbacks[index].creatorReceivedAt
                feedbacks[index] = merged
            } else {
                feedbacks.append(value)
            }
        }
    }

    private func applyCreatorReceipts(_ receipts: [UUID: Date]) {
        guard !receipts.isEmpty else { return }
        for index in feedbacks.indices {
            guard let project = project(id: feedbacks[index].projectID),
                  project.relationship == .creator,
                  let receivedAt = receipts[feedbacks[index].id] else { continue }
            feedbacks[index].creatorReceivedAt = receivedAt
            // A creator heart promotes an ephemeral guest message into a
            // permanent received message. The database trigger remains
            // the source of truth; this keeps optimistic UI consistent.
            feedbacks[index].expiresAt = nil
        }
    }

    private func loadModerationState() async {
        async let owned = try? moderationRepository.fetchOwnedFeedbackIDs()
        async let blocked = try? moderationRepository.fetchBlockedProfileIDs()
        ownedFeedbackIDs = await owned ?? []
        blockedProfileIDs = await blocked ?? []
    }

    private func removeFeedbackFromLocalState(_ feedback: Feedback) {
        feedbacks.removeAll { $0.id == feedback.id }
        likedFeedbackIDs.remove(feedback.id)
        ownedFeedbackIDs.remove(feedback.id)
        if let index = projects.firstIndex(where: { $0.id == feedback.projectID }) {
            projects[index].feedbackCount = max(0, projects[index].feedbackCount - 1)
        }
    }

    private func loadMembership() async {
        guard let currentUserID else {
            membershipTier = .guest
            return
        }

        do {
            membershipTier = try await membershipRepository.fetchMembership(userID: currentUserID)
        } catch {
            membershipTier = .guest
        }
    }

    private func loadCurrentProfile() async {
        guard accountStatus == .registered, let currentUserID else {
            currentProfile = nil
            currentAvatarImageData = nil
            return
        }
        currentProfile = try? await profileRepository.fetchProfile(id: currentUserID)
        currentAvatarImageData = backendMode == .mock
            ? UserDefaults.standard.data(forKey: Self.mockAvatarImageDataKey)
            : nil
        if let currentProfile {
            profileCache[currentUserID] = currentProfile
            applyProfile(currentProfile)
        }
    }

    private func hydrateFeedbacks(_ values: [Feedback]) async -> [Feedback] {
        let senderIDs = Set(values.compactMap(\.senderID))
        let missingIDs = senderIDs.filter { profileCache[$0] == nil }
        let repository = profileRepository

        let orderedMissingIDs = Array(missingIDs)
        for start in stride(from: 0, to: orderedMissingIDs.count, by: 8) {
            let end = min(start + 8, orderedMissingIDs.count)
            let batch = orderedMissingIDs[start..<end]
            await withTaskGroup(of: (UUID, Creator?).self) { group in
                for id in batch {
                    group.addTask {
                        (id, try? await repository.fetchProfile(id: id))
                    }
                }
                for await (id, profile) in group {
                    if let profile {
                        profileCache[id] = profile
                    }
                }
            }
        }

        return values.map { value in
            guard let senderID = value.senderID,
                  let profile = profileCache[senderID] else { return value }
            var hydrated = value
            hydrated.senderAvatarName = profile.avatarName
            hydrated.senderAvatarURL = profile.avatarURL
            hydrated.senderHandle = profile.handle
            return hydrated
        }
    }

    private func applyProfile(_ profile: Creator) {
        for index in feedbacks.indices where feedbacks[index].senderID == profile.id {
            feedbacks[index].senderAvatarName = profile.avatarName
            feedbacks[index].senderAvatarURL = profile.avatarURL
            feedbacks[index].senderHandle = profile.handle
        }
        for index in projects.indices where projects[index].creator.id == profile.id {
            projects[index].creator = profile
        }
    }

    private func openPendingDeepLinkIfPossible() {
        guard let id = pendingDeepLinkProjectID,
              project(id: id) != nil else { return }
        deepLinkResolutionTask?.cancel()
        pendingDeepLinkProjectID = nil
        selectedTab = .home
        homePath = [id]
        isResolvingDeepLink = false
    }

    private func map(_ error: any Error) -> AppError {
        (error as? AppError) ?? .unknown(error.localizedDescription)
    }
}

enum AppTab: Hashable {
    case home
    case create
    case notifications
    case myPage
}
