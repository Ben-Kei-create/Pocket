import Foundation

protocol ProjectRepository: Sendable {
    nonisolated func fetchProjects() async throws -> [Project]
    nonisolated func fetchProjects(creatorID: UUID) async throws -> [Project]
    nonisolated func fetchProject(id: UUID) async throws -> Project
    nonisolated func createProject(_ project: Project) async throws
    nonisolated func updateProject(_ project: Project) async throws
    nonisolated func deleteProject(id: UUID) async throws
}

protocol FeedbackRepository: Sendable {
    nonisolated func fetchFeedbacks(projectID: UUID) async throws -> [Feedback]
    nonisolated func fetchFeedback(id: UUID) async throws -> Feedback
    nonisolated func fetchLikedFeedbacks() async throws -> [Feedback]
    nonisolated func submitFeedback(_ feedback: Feedback) async throws
    nonisolated func likeFeedback(id: UUID) async throws
    nonisolated func fetchLikedFeedbackIDs(feedbackIDs: [UUID]) async throws -> Set<UUID>
    nonisolated func fetchCreatorReceipts(feedbackIDs: [UUID]) async throws -> [UUID: Date]
    nonisolated func markReceivedByCreator(feedbackID: UUID) async throws -> Date
    nonisolated func observeCreatorReceipts(
        projectID: UUID
    ) async -> AsyncThrowingStream<CreatorReceipt, any Error>
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
        creatorID: UUID,
        imageID: UUID
    ) async throws -> URL
    nonisolated func deleteProjectImage(at url: URL) async throws
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
    nonisolated func deleteAccount() async throws
}

protocol MembershipRepository: Sendable {
    func fetchMembership(userID: UUID) async throws -> MembershipTier
}

protocol MemberRewardRepository: Sendable {
    nonisolated func fetchRewards(
        signals: AchievementSignals
    ) async throws -> MemberRewardSnapshot
    nonisolated func claimDailyLoginBonus() async throws -> DailyLoginBonusClaim
}

protocol StarStoreRepository: Sendable {
    nonisolated func fetchCatalog() async throws -> [StarStoreItem]
    nonisolated func fetchOwnedItemQuantities() async throws -> [String: Int]
    nonisolated func fetchProjectDecoration(projectID: UUID) async throws -> ProjectDecoration
    nonisolated func purchaseItem(id: String, requestID: UUID) async throws
        -> StarStorePurchaseResult
    nonisolated func equipProjectBackground(
        projectID: UUID,
        itemID: String?
    ) async throws
    nonisolated func equipProjectBadge(
        projectID: UUID,
        slot: Int,
        itemID: String?
    ) async throws
    nonisolated func giftBadge(
        itemID: String,
        recipientID: UUID,
        requestID: UUID
    ) async throws -> BadgeGiftResult
    nonisolated func fetchProjectSlotStatus() async throws -> ProjectSlotStatus
    nonisolated func redeemProjectSlot(
        requestID: UUID
    ) async throws -> ProjectSlotRedemptionResult
}

protocol ModerationRepository: Sendable {
    nonisolated func fetchOwnedFeedbackIDs() async throws -> Set<UUID>
    nonisolated func fetchOwnedFeedbacks() async throws -> [Feedback]
    nonisolated func fetchOwnFeedbackCount(projectID: UUID) async throws -> Int
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

protocol NotificationRepository: Sendable {
    nonisolated func fetchNotifications() async throws -> [PocoNotification]
    nonisolated func markRead(id: UUID) async throws -> Date
    nonisolated func observeNotifications(
    ) async -> AsyncThrowingStream<PocoNotification, any Error>
}

protocol AnnouncementRepository: Sendable {
    nonisolated func fetchPublishedAnnouncements() async throws -> [AppAnnouncement]
}

protocol RightsHolderRequestRepository: Sendable {
    nonisolated func submit(_ request: RightsHolderRequest) async throws -> UUID
}

protocol QAndARepository: Sendable {
    nonisolated func fetchQuestions() async throws -> [PocoQuestion]
    nonisolated func sendQuestion(
        creatorID: UUID,
        projectID: UUID?,
        message: String
    ) async throws -> PocoQuestion
    nonisolated func updateQuestion(id: UUID, message: String) async throws -> PocoQuestion
    nonisolated func answerQuestion(id: UUID, answer: String) async throws -> PocoQuestion
    nonisolated func withdrawQuestion(id: UUID) async throws -> PocoQuestion
    nonisolated func reportQuestion(
        id: UUID,
        reason: FeedbackReportReason,
        details: String?
    ) async throws
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

    func fetchProject(id: UUID) async throws -> Project {
        guard let project = projects.first(where: { $0.id == id }) else {
            throw AppError.notFound
        }
        return project
    }

    func createProject(_ project: Project) async throws {
        projects.insert(project, at: 0)
    }

    func updateProject(_ project: Project) async throws {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else {
            throw AppError.notFound
        }
        projects[index] = project
    }

    func deleteProject(id: UUID) async throws {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound
        }
        projects.remove(at: index)
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
            .filter { $0.projectID == projectID && $0.isPublic && $0.isVisible() }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchFeedback(id: UUID) async throws -> Feedback {
        guard let feedback = feedbacks.first(where: { $0.id == id }) else {
            throw AppError.notFound
        }
        return feedback
    }

    func fetchLikedFeedbacks() async throws -> [Feedback] {
        let likedIDs = persistedLikedFeedbackIDs()
        return feedbacks
            .filter { likedIDs.contains($0.id) && $0.isPublic && $0.isVisible() }
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
        feedbacks[index].expiresAt = nil
        let receipt = CreatorReceipt(feedbackID: feedbackID, createdAt: receivedAt)
        for continuation in receiptObservers.values {
            continuation.yield(receipt)
        }
        return receivedAt
    }

    func observeCreatorReceipts(
        projectID: UUID
    ) async -> AsyncThrowingStream<CreatorReceipt, any Error> {
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
    nonisolated private static let persistedProfilesKey = "poco.mockProfiles"
    private var creators: [UUID: Creator]

    init(creators: [Creator]? = nil) {
        let values = creators ?? [
            MockData.forestCreator,
            MockData.tetraCreator,
            MockData.starFanCreator
        ] + Array(MockData.feedbackAuthors.values)
        self.creators = values.reduce(into: [:]) { creatorsByID, creator in
            creatorsByID[creator.id] = creator
        }
        if let data = UserDefaults.standard.data(forKey: Self.persistedProfilesKey),
           let persistedProfiles = try? JSONDecoder().decode([Creator].self, from: data) {
            for profile in persistedProfiles {
                self.creators[profile.id] = profile
            }
        }
    }

    func fetchProfile(id: UUID) async throws -> Creator {
        guard let creator = creators[id] else {
            throw AppError.notFound
        }
        return creator
    }

    func saveProfile(_ creator: Creator) async throws {
        creators[creator.id] = creator
        if let data = try? JSONEncoder().encode(Array(creators.values)) {
            UserDefaults.standard.set(data, forKey: Self.persistedProfilesKey)
        }
    }
}

struct MockCurrentUserProvider: CurrentUserProvider {
    let userID: UUID?

    init(userID: UUID? = MockData.previewUser.id) {
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

    init(userID: UUID = MockData.previewUser.id) {
        self.userID = userID
    }

    nonisolated func signInWithApple(
        credential: AppleIdentityCredential
    ) async throws -> AuthenticatedAccount {
        UserDefaults.standard.set(true, forKey: "poco.previewRegisteredAccount")
        return AuthenticatedAccount(
            id: userID,
            displayName: credential.displayName,
            email: credential.email
        )
    }

    nonisolated func signOut() async throws {
        UserDefaults.standard.set(false, forKey: "poco.previewMembership")
        UserDefaults.standard.set(false, forKey: "poco.previewRegisteredAccount")
    }

    nonisolated func deleteAccount() async throws {
        let defaults = UserDefaults.standard
        let pocoKeys = defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix("poco.")
        }
        for key in pocoKeys {
            defaults.removeObject(forKey: key)
        }
    }
}

actor MockMembershipRepository: MembershipRepository {
    func fetchMembership(userID: UUID) async throws -> MembershipTier {
        UserDefaults.standard.bool(forKey: "poco.previewMembership") ? .pocoMember : .guest
    }
}

actor MockMemberRewardRepository: MemberRewardRepository {
    nonisolated private static let streakKey = "poco.mockReward.loginStreak"
    nonisolated private static let lastClaimedDayKey = "poco.mockReward.lastClaimedDay"
    nonisolated private static let stampsKey = "poco.mockReward.stamps"
    nonisolated private static let achievementNotificationsKey =
        "poco.mockReward.achievementNotifications"

    func fetchRewards(signals: AchievementSignals) async throws -> MemberRewardSnapshot {
        var stamps = persistedStamps()
        let unlocked = unlockedStamps(for: signals)
        let newlyUnlocked = unlocked.subtracting(stamps)
        stamps.formUnion(unlocked)
        persist(stamps)
        queueNotifications(for: newlyUnlocked)
        return MemberRewardSnapshot(
            loginStreak: UserDefaults.standard.integer(forKey: Self.streakKey),
            lastClaimedDay: UserDefaults.standard.string(forKey: Self.lastClaimedDayKey),
            starCoinBalance: UserDefaults.standard.integer(forKey: "poco.starCoinBalance"),
            walletRevision: Int64(
                UserDefaults.standard.integer(forKey: "poco.starCoinWalletRevision")
            ),
            unlockedStamps: stamps
        )
    }

    func claimDailyLoginBonus() async throws -> DailyLoginBonusClaim {
        let today = PocoCalendar.todayKey()
        let defaults = UserDefaults.standard
        let lastClaimedDay = defaults.string(forKey: Self.lastClaimedDayKey)
        let claimed = lastClaimedDay != today
        var streak = defaults.integer(forKey: Self.streakKey)

        if claimed {
            streak = lastClaimedDay == PocoCalendar.yesterdayKey() ? streak + 1 : 1
            defaults.set(streak, forKey: Self.streakKey)
            defaults.set(today, forKey: Self.lastClaimedDayKey)
        }

        let awardedCoins = claimed ? Self.reward(for: streak) : 0
        let currentBalance = defaults.integer(forKey: "poco.starCoinBalance")
        let currentRevision = Int64(defaults.integer(forKey: "poco.starCoinWalletRevision"))
        let nextRevision = claimed ? currentRevision + 1 : currentRevision
        defaults.set(nextRevision, forKey: "poco.starCoinWalletRevision")
        return DailyLoginBonusClaim(
            awardedCoins: awardedCoins,
            starCoinBalance: currentBalance + awardedCoins,
            loginStreak: streak,
            claimed: claimed,
            claimedDay: today,
            walletRevision: nextRevision
        )
    }

    private func persistedStamps() -> Set<AchievementStamp> {
        let values = UserDefaults.standard.stringArray(forKey: Self.stampsKey) ?? []
        return Set(values.compactMap(AchievementStamp.init(rawValue:)))
    }

    private func persist(_ stamps: Set<AchievementStamp>) {
        UserDefaults.standard.set(stamps.map(\.rawValue), forKey: Self.stampsKey)
    }

    private func queueNotifications(for stamps: Set<AchievementStamp>) {
        guard !stamps.isEmpty else { return }
        let defaults = UserDefaults.standard
        var queued = Set(
            defaults.stringArray(forKey: Self.achievementNotificationsKey) ?? []
        )
        queued.formUnion(stamps.map(\.rawValue))
        defaults.set(queued.sorted(), forKey: Self.achievementNotificationsKey)
    }

    private func unlockedStamps(for signals: AchievementSignals) -> Set<AchievementStamp> {
        let loginStreak = UserDefaults.standard.integer(forKey: Self.streakKey)
        return Set(AchievementStamp.allCases.filter {
            $0.isUnlocked(signals: signals, loginStreak: loginStreak)
        })
    }

    nonisolated private static func reward(for streak: Int) -> Int {
        let cycle = [3, 3, 5, 3, 5, 7, 15]
        return cycle[max(0, streak - 1) % cycle.count]
    }
}

actor MockStarStoreRepository: StarStoreRepository {
    nonisolated static let catalog: [StarStoreItem] = [
        .init(
            id: "background_sakura", kind: .projectBackground,
            title: "さくらミルク", summary: "やさしい桜色で、ことばをふんわり包む背景です。",
            priceCoins: 80, assetName: "ProjectBackgroundSakura", appearanceValue: "#FFF2F4",
            requiresPro: false, sortOrder: 10
        ),
        .init(
            id: "background_lemon", kind: .projectBackground,
            title: "レモンクリーム", summary: "あたたかな光を感じる、淡い黄色の背景です。",
            priceCoins: 80, assetName: "ProjectBackgroundLemon", appearanceValue: "#FFF9E8",
            requiresPro: false, sortOrder: 20
        ),
        .init(
            id: "background_sky", kind: .projectBackground,
            title: "ソーダスカイ", summary: "晴れた空のように、ことばが軽やかに見える背景です。",
            priceCoins: 80, assetName: "ProjectBackgroundSky", appearanceValue: "#EEF8FF",
            requiresPro: false, sortOrder: 30
        ),
        .init(
            id: "background_mint", kind: .projectBackground,
            title: "ミスティミント", summary: "静かで落ち着いた、淡いミント色の背景です。",
            priceCoins: 80, assetName: "ProjectBackgroundMint", appearanceValue: "#EFFAF5",
            requiresPro: false, sortOrder: 40
        ),
        .init(
            id: "background_lavender", kind: .projectBackground,
            title: "ライラックミスト", summary: "少し特別な余韻を添える、淡い紫色の背景です。",
            priceCoins: 80, assetName: "ProjectBackgroundLavender", appearanceValue: "#F5F0FF",
            requiresPro: false, sortOrder: 50
        ),
        .init(
            id: "badge_first_light", kind: .profileBadge,
            title: "はじめの灯り", summary: "最初の一歩をそっと照らすバッジです。",
            priceCoins: 120, assetName: "BadgeFirstLight", appearanceValue: nil,
            requiresPro: false, sortOrder: 110
        ),
        .init(
            id: "badge_word_bouquet", kind: .profileBadge,
            title: "ことばの花束", summary: "届けたことばを花束のように飾るバッジです。",
            priceCoins: 180, assetName: "BadgeWordBouquet", appearanceValue: nil,
            requiresPro: false, sortOrder: 120
        ),
        .init(
            id: "badge_poco_heart", kind: .profileBadge,
            title: "Pocoハート", summary: "作品とことばを大切にする気持ちのバッジです。",
            priceCoins: 250, assetName: "PocoCreatorHeartReceived", appearanceValue: nil,
            requiresPro: false, sortOrder: 130
        )
    ]

    nonisolated private static let ownedKey = "poco.mockStarStore.owned"
    nonisolated private static let quantitiesKey = "poco.mockStarStore.quantities"
    nonisolated private static let giftRequestsKey = "poco.mockStarStore.giftRequests"
    nonisolated private static let revisionKey = "poco.starCoinWalletRevision"
    nonisolated private static let decorationPrefix = "poco.mockStarStore.decoration."
    nonisolated private static let extraProjectSlotsKey = "poco.mockProjectSlots.extra"
    nonisolated private static let projectSlotRequestsKey = "poco.mockProjectSlots.requests"

    func fetchCatalog() async throws -> [StarStoreItem] {
        Self.catalog.sorted { $0.sortOrder < $1.sortOrder }
    }

    func fetchOwnedItemQuantities() async throws -> [String: Int] {
        Self.ownedQuantities(defaults: .standard)
    }

    func fetchProjectDecoration(projectID: UUID) async throws -> ProjectDecoration {
        let defaults = UserDefaults.standard
        let prefix = Self.decorationPrefix + projectID.uuidString
        let background = defaults.string(forKey: prefix + ".background")
        var badges: [Int: String] = [:]
        for slot in 0..<3 {
            badges[slot] = defaults.string(forKey: prefix + ".badge.\(slot)")
        }
        return ProjectDecoration(
            backgroundItemID: background,
            badgeItemIDsBySlot: badges.compactMapValues { $0 }
        )
    }

    func purchaseItem(id: String, requestID: UUID) async throws -> StarStorePurchaseResult {
        guard let item = Self.catalog.first(where: { $0.id == id }) else {
            throw AppError.notFound
        }
        let defaults = UserDefaults.standard
        var quantities = Self.ownedQuantities(defaults: defaults)
        let currentBalance = max(0, defaults.integer(forKey: "poco.starCoinBalance"))
        let currentRevision = Int64(defaults.integer(forKey: Self.revisionKey))
        let currentQuantity = quantities[id, default: 0]
        guard item.kind == .profileBadge || currentQuantity == 0 else {
            return .init(
                itemID: id, balance: currentBalance, chargedCoins: 0,
                walletRevision: currentRevision, ownedQuantity: currentQuantity,
                purchased: false
            )
        }
        guard currentBalance >= item.priceCoins else { throw AppError.insufficientStarCoins }

        let nextBalance = currentBalance - item.priceCoins
        let nextRevision = currentRevision + 1
        quantities[id] = currentQuantity + 1
        Self.saveOwnedQuantities(quantities, defaults: defaults)
        defaults.set(nextBalance, forKey: "poco.starCoinBalance")
        defaults.set(nextRevision, forKey: Self.revisionKey)
        return .init(
            itemID: id, balance: nextBalance, chargedCoins: item.priceCoins,
            walletRevision: nextRevision, ownedQuantity: currentQuantity + 1,
            purchased: true
        )
    }

    func fetchProjectSlotStatus() async throws -> ProjectSlotStatus {
        Self.projectSlotStatus(defaults: .standard)
    }

    func redeemProjectSlot(requestID: UUID) async throws -> ProjectSlotRedemptionResult {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "poco.previewMembership") else {
            throw AppError.projectSlotRedemptionUnavailable
        }

        var requestIDs = Set(defaults.stringArray(forKey: Self.projectSlotRequestsKey) ?? [])
        if requestIDs.contains(requestID.uuidString) {
            return ProjectSlotRedemptionResult(
                status: Self.projectSlotStatus(defaults: defaults),
                chargedCoins: 0,
                redeemed: false
            )
        }

        let extraSlots = min(2, max(0, defaults.integer(forKey: Self.extraProjectSlotsKey)))
        guard extraSlots < 2 else {
            return ProjectSlotRedemptionResult(
                status: Self.projectSlotStatus(defaults: defaults),
                chargedCoins: 0,
                redeemed: false
            )
        }

        let cost = extraSlots == 0 ? 200 : 400
        let currentBalance = max(0, defaults.integer(forKey: "poco.starCoinBalance"))
        guard currentBalance >= cost else { throw AppError.insufficientStarCoins }

        let nextBalance = currentBalance - cost
        let nextRevision = Int64(defaults.integer(forKey: Self.revisionKey)) + 1
        defaults.set(extraSlots + 1, forKey: Self.extraProjectSlotsKey)
        defaults.set(nextBalance, forKey: "poco.starCoinBalance")
        defaults.set(nextRevision, forKey: Self.revisionKey)
        requestIDs.insert(requestID.uuidString)
        defaults.set(Array(requestIDs), forKey: Self.projectSlotRequestsKey)

        return ProjectSlotRedemptionResult(
            status: Self.projectSlotStatus(defaults: defaults),
            chargedCoins: cost,
            redeemed: true
        )
    }

    func equipProjectBackground(projectID: UUID, itemID: String?) async throws {
        try ensureOwned(itemID, kind: .projectBackground)
        let key = Self.decorationPrefix + projectID.uuidString + ".background"
        UserDefaults.standard.set(itemID, forKey: key)
    }

    func equipProjectBadge(projectID: UUID, slot: Int, itemID: String?) async throws {
        guard (0..<3).contains(slot) else { throw AppError.invalidInput }
        try ensureOwned(itemID, kind: .profileBadge)
        if let itemID {
            let equippedExcludingTarget = Self.equippedQuantity(
                itemID: itemID,
                excludingProjectID: projectID,
                slot: slot,
                defaults: .standard
            )
            let ownedQuantity = Self.ownedQuantities(defaults: .standard)[itemID, default: 0]
            guard equippedExcludingTarget < ownedQuantity else {
                throw AppError.itemAlreadyEquipped
            }
        }
        let key = Self.decorationPrefix + projectID.uuidString + ".badge.\(slot)"
        UserDefaults.standard.set(itemID, forKey: key)
    }

    private func ensureOwned(_ itemID: String?, kind: StarStoreItemKind) throws {
        guard let itemID else { return }
        guard Self.catalog.contains(where: { $0.id == itemID && $0.kind == kind }) else {
            throw AppError.invalidInput
        }
        let quantity = Self.ownedQuantities(defaults: .standard)[itemID, default: 0]
        guard quantity > 0 else { throw AppError.unauthorized }
    }

    func giftBadge(
        itemID: String,
        recipientID: UUID,
        requestID: UUID
    ) async throws -> BadgeGiftResult {
        guard recipientID != MockData.previewUser.id else { throw AppError.cannotGiftToSelf }
        guard Self.catalog.contains(where: { $0.id == itemID && $0.kind == .profileBadge }) else {
            throw AppError.invalidInput
        }
        let defaults = UserDefaults.standard
        var requestIDs = Set(defaults.stringArray(forKey: Self.giftRequestsKey) ?? [])
        if requestIDs.contains(requestID.uuidString) {
            return BadgeGiftResult(
                itemID: itemID,
                senderQuantity: Self.ownedQuantities(defaults: defaults)[itemID, default: 0],
                recipientQuantity: 0,
                gifted: false
            )
        }

        var quantities = Self.ownedQuantities(defaults: defaults)
        let equipped = Self.equippedQuantity(itemID: itemID, defaults: defaults)
        guard quantities[itemID, default: 0] > equipped else {
            throw AppError.insufficientBadgeQuantity
        }
        quantities[itemID, default: 0] -= 1
        if quantities[itemID] == 0 { quantities[itemID] = nil }
        Self.saveOwnedQuantities(quantities, defaults: defaults)
        requestIDs.insert(requestID.uuidString)
        defaults.set(Array(requestIDs), forKey: Self.giftRequestsKey)
        return BadgeGiftResult(
            itemID: itemID,
            senderQuantity: quantities[itemID, default: 0],
            recipientQuantity: 1,
            gifted: true
        )
    }

    nonisolated private static func ownedQuantities(defaults: UserDefaults) -> [String: Int] {
        if let stored = defaults.dictionary(forKey: quantitiesKey) {
            return stored.reduce(into: [:]) { result, pair in
                if let value = pair.value as? Int, value > 0 { result[pair.key] = value }
            }
        }
        return Dictionary(
            uniqueKeysWithValues: (defaults.stringArray(forKey: ownedKey) ?? []).map { ($0, 1) }
        )
    }

    nonisolated private static func saveOwnedQuantities(
        _ quantities: [String: Int],
        defaults: UserDefaults
    ) {
        defaults.set(quantities, forKey: quantitiesKey)
        defaults.set(Array(quantities.keys), forKey: ownedKey)
    }

    nonisolated private static func equippedQuantity(
        itemID: String,
        excludingProjectID: UUID? = nil,
        slot: Int? = nil,
        defaults: UserDefaults
    ) -> Int {
        let excludedKey = excludingProjectID.flatMap { projectID in
            slot.map { decorationPrefix + projectID.uuidString + ".badge.\($0)" }
        }
        return defaults.dictionaryRepresentation().reduce(into: 0) { count, pair in
            guard pair.key.hasPrefix(decorationPrefix), pair.key.contains(".badge."),
                  pair.key != excludedKey, pair.value as? String == itemID else { return }
            count += 1
        }
    }

    nonisolated private static func projectSlotStatus(
        defaults: UserDefaults
    ) -> ProjectSlotStatus {
        let extraSlots = min(2, max(0, defaults.integer(forKey: extraProjectSlotsKey)))
        return ProjectSlotStatus(
            freeProjectLimit: 3 + extraSlots,
            extraSlots: extraSlots,
            nextSlotNumber: extraSlots < 2 ? 4 + extraSlots : nil,
            nextSlotCost: extraSlots == 0 ? 200 : extraSlots == 1 ? 400 : nil,
            balance: max(0, defaults.integer(forKey: "poco.starCoinBalance")),
            walletRevision: Int64(defaults.integer(forKey: revisionKey))
        )
    }
}

actor MockModerationRepository: ModerationRepository {
    private var ownedFeedbackIDs: Set<UUID>
    private let projectByFeedbackID: [UUID: UUID]
    private var blockedProfileIDs: Set<UUID> = []

    init(ownedFeedbackIDs: Set<UUID>? = nil) {
        let feedbacks = MockData.feedbacks
        self.ownedFeedbackIDs = ownedFeedbackIDs ?? Set(
            feedbacks
                .filter { $0.senderID == MockData.previewUser.id }
                .prefix(2)
                .map(\.id)
        )
        projectByFeedbackID = Dictionary(
            uniqueKeysWithValues: feedbacks.map { ($0.id, $0.projectID) }
        )
    }

    func fetchOwnedFeedbackIDs() async throws -> Set<UUID> { ownedFeedbackIDs }

    func fetchOwnedFeedbacks() async throws -> [Feedback] {
        let feedbacks = MockData.feedbacks
        return feedbacks
            .filter { ownedFeedbackIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchOwnFeedbackCount(projectID: UUID) async throws -> Int {
        ownedFeedbackIDs.filter { projectByFeedbackID[$0] == projectID }.count
    }

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

actor MockRightsHolderRequestRepository: RightsHolderRequestRepository {
    private var submittedProjectIDs: Set<UUID> = []

    func submit(_ request: RightsHolderRequest) async throws -> UUID {
        guard submittedProjectIDs.insert(request.projectID).inserted else {
            throw AppError.requestAlreadySubmitted
        }
        return UUID()
    }
}

actor MockQAndARepository: QAndARepository {
    private var questions: [PocoQuestion]
    private let currentUserID: UUID

    init(
        currentUserID: UUID = MockData.previewUser.id,
        questions: [PocoQuestion]? = nil
    ) {
        self.currentUserID = currentUserID
        self.questions = questions ?? [
            PocoQuestion(
                id: UUID(uuidString: "71000000-0000-0000-0000-000000000001")!,
                projectID: MockData.forestProject.id,
                projectTitle: MockData.forestProject.title,
                sender: MockData.feedbackAuthors["はな"]!,
                creator: MockData.forestCreator,
                message: "森の色づかいは、どんな景色から思いついたのですか？",
                answer: nil,
                status: .pending,
                createdAt: Date(timeIntervalSinceNow: -7_200),
                answeredAt: nil,
                withdrawnAt: nil
            ),
            PocoQuestion(
                id: UUID(uuidString: "71000000-0000-0000-0000-000000000002")!,
                projectID: MockData.tetraProject.id,
                projectTitle: MockData.tetraProject.title,
                sender: MockData.previewUser,
                creator: MockData.tetraCreator,
                message: "音楽づくりで一番大切にしたことを知りたいです。",
                answer: "冒険の途中でも、帰る場所を思い出せる音にしました。",
                status: .answered,
                createdAt: Date(timeIntervalSinceNow: -86_400),
                answeredAt: Date(timeIntervalSinceNow: -43_200),
                withdrawnAt: nil
            )
        ]
    }

    func fetchQuestions() async throws -> [PocoQuestion] {
        expirePendingQuestions()
        return questions
            .filter { $0.sender.id == currentUserID || $0.creator.id == currentUserID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func sendQuestion(
        creatorID: UUID,
        projectID: UUID?,
        message: String
    ) async throws -> PocoQuestion {
        expirePendingQuestions()
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              normalized.count <= PocoQuestionLimits.messageLength,
              creatorID != currentUserID else {
            throw AppError.invalidInput
        }
        if let projectID {
            guard let project = MockData.projects.first(where: { $0.id == projectID }),
                  project.creator.id == creatorID,
                  project.acceptsQuestions else {
                throw AppError.projectQuestionsDisabled
            }
        }
        let recentCount = questions.filter {
            $0.sender.id == currentUserID
                && $0.creator.id == creatorID
                && $0.createdAt > Date.now.addingTimeInterval(-86_400)
        }.count
        guard recentCount < PocoQuestionLimits.rollingDayCount else {
            throw AppError.questionDailyLimitReached
        }
        let pendingCount = questions.filter {
            $0.sender.id == currentUserID
                && $0.creator.id == creatorID
                && $0.effectiveStatus == .pending
        }.count
        guard pendingCount < PocoQuestionLimits.pendingCount else {
            throw AppError.questionPendingLimitReached
        }
        guard let creator = MockData.projects.first(where: { $0.creator.id == creatorID })?.creator
                ?? MockData.feedbackAuthors.values.first(where: { $0.id == creatorID }) else {
            throw AppError.notFound
        }
        let project = projectID.flatMap { id in MockData.projects.first { $0.id == id } }
        let question = PocoQuestion(
            id: UUID(),
            projectID: project?.id,
            projectTitle: project?.title,
            sender: MockData.previewUser,
            creator: creator,
            message: normalized,
            answer: nil,
            status: .pending,
            createdAt: .now,
            answeredAt: nil,
            withdrawnAt: nil
        )
        questions.insert(question, at: 0)
        return question
    }

    func answerQuestion(id: UUID, answer: String) async throws -> PocoQuestion {
        expirePendingQuestions()
        guard let index = questions.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound
        }
        let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard questions[index].creator.id == currentUserID else { throw AppError.unauthorized }
        guard questions[index].effectiveStatus == .pending else {
            throw AppError.questionUnavailable
        }
        guard !normalized.isEmpty, normalized.count <= PocoQuestionLimits.answerLength else {
            throw AppError.invalidInput
        }
        questions[index].answer = normalized
        questions[index].status = .answered
        questions[index].answeredAt = .now
        return questions[index]
    }

    func updateQuestion(id: UUID, message: String) async throws -> PocoQuestion {
        expirePendingQuestions()
        guard let index = questions.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound
        }
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard questions[index].sender.id == currentUserID else { throw AppError.unauthorized }
        guard questions[index].effectiveStatus == .pending else {
            throw AppError.questionUnavailable
        }
        guard !normalized.isEmpty,
              normalized.count <= PocoQuestionLimits.messageLength else {
            throw AppError.invalidInput
        }
        questions[index].message = normalized
        return questions[index]
    }

    func withdrawQuestion(id: UUID) async throws -> PocoQuestion {
        expirePendingQuestions()
        guard let index = questions.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound
        }
        guard questions[index].sender.id == currentUserID else { throw AppError.unauthorized }
        guard questions[index].effectiveStatus == .pending else {
            throw AppError.questionUnavailable
        }
        questions[index].status = .withdrawn
        questions[index].withdrawnAt = .now
        return questions[index]
    }

    func reportQuestion(
        id: UUID,
        reason: FeedbackReportReason,
        details: String?
    ) async throws {
        guard questions.contains(where: { $0.id == id }) else { throw AppError.notFound }
    }

    private func expirePendingQuestions() {
        for index in questions.indices where questions[index].effectiveStatus == .expired {
            questions[index].status = .expired
        }
    }
}

struct DisabledProjectImageStorage: ProjectImageStorage {
    nonisolated func uploadProjectImage(
        _ data: Data,
        projectID: UUID,
        creatorID: UUID,
        imageID: UUID
    ) async throws -> URL {
        throw AppError.storage
    }

    nonisolated func deleteProjectImage(at url: URL) async throws {
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
