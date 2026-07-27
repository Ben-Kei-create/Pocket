import Foundation
import Observation

@MainActor
@Observable
final class PocoStore {
    var projects: [Project]
    var feedbacks: [Feedback]
    var selectedTab = AppTab.home
    var homePath: [UUID] = []
    var errorMessage: String?
    private(set) var membershipTier: MembershipTier = .guest
    private(set) var accountStatus: AccountStatus = .guest
    private(set) var currentUserID: UUID?
    private(set) var currentProfile: Creator?
    private(set) var currentAvatarImageData: Data?
    private(set) var likedFeedbackIDs: Set<UUID> = []
    private(set) var membershipOffer: MembershipOffer?
    private(set) var membershipPurchaseState: MembershipPurchaseState = .idle
    private(set) var membershipSyncState: MembershipSyncState = .idle
    private(set) var authenticationState: AuthenticationState = .idle
    private(set) var projectLoadState: LoadState = .idle
    private(set) var feedbackLoadStates: [UUID: LoadState] = [:]
    let backendMode: BackendMode

    private let projectRepository: any ProjectRepository
    private let feedbackRepository: any FeedbackRepository
    private let profileRepository: any ProfileRepository
    private let membershipRepository: any MembershipRepository
    private let membershipPurchaseService: any MembershipPurchaseService
    private let membershipEntitlementSynchronizer: (any MembershipEntitlementSynchronizing)?
    private let authRepository: any AuthRepository
    private let currentUserProvider: any CurrentUserProvider
    private let projectImageStorage: (any ProjectImageStorage)?
    private let profileAvatarStorage: (any ProfileAvatarStorage)?
    private var realtimeTasks: [UUID: Task<Void, Never>] = [:]
    private var profileCache: [UUID: Creator] = [:]
    private var optimisticFeedbackIDs: Set<UUID> = []
    private var pendingDeepLinkProjectID: UUID?

    init(
        projectRepository: (any ProjectRepository)? = nil,
        feedbackRepository: (any FeedbackRepository)? = nil,
        profileRepository: (any ProfileRepository)? = nil,
        membershipRepository: (any MembershipRepository)? = nil,
        membershipPurchaseService: (any MembershipPurchaseService)? = nil,
        membershipEntitlementSynchronizer: (any MembershipEntitlementSynchronizing)? = nil,
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
        self.membershipPurchaseService = membershipPurchaseService ?? DisabledMembershipPurchaseService()
        self.membershipEntitlementSynchronizer = membershipEntitlementSynchronizer
        self.authRepository = authRepository ?? MockAuthRepository()
        self.currentUserProvider = currentUserProvider ?? MockCurrentUserProvider()
        self.projectImageStorage = projectImageStorage
        self.profileAvatarStorage = profileAvatarStorage
        self.backendMode = backendMode
        projects = initialProjects ?? MockData.projects
        feedbacks = initialFeedbacks ?? MockData.feedbacks
    }

    func load() async {
        guard projectLoadState != .loading else { return }
        projectLoadState = .loading

        accountStatus = await currentUserProvider.accountStatus()
        currentUserID = await currentUserProvider.currentUserID()
        await loadCurrentProfile()
        await loadMembership()
        if membershipTier.isMember {
            accountStatus = .registered
        }

        do {
            let loadedProjects = try await projectRepository.fetchProjects()
            projects = loadedProjects
            projectLoadState = .loaded
            openPendingDeepLinkIfPossible()
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

            feedbacks.removeAll { $0.projectID == projectID }
            feedbacks.append(contentsOf: remoteFeedbacks)
            for feedback in optimistic where !feedbacks.contains(where: { $0.id == feedback.id }) {
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
            .filter { $0.projectID == projectID && $0.isPublic }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func project(id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    func submit(_ feedback: Feedback) async -> Result<Void, AppError> {
        var feedback = feedback
        if feedback.senderID == nil, canCreateProjects {
            feedback.senderID = currentUserID
        }
        if let senderID = feedback.senderID,
           let profile = profileCache[senderID]
                ?? (currentProfile?.id == senderID ? currentProfile : nil) {
            feedback.senderAvatarName = profile.avatarName
            feedback.senderAvatarURL = profile.avatarURL
        }
        let isNew = !feedbacks.contains(where: { $0.id == feedback.id })
        if isNew {
            feedbacks.append(feedback)
            optimisticFeedbackIDs.insert(feedback.id)
            if let index = projects.firstIndex(where: { $0.id == feedback.projectID }) {
                projects[index].feedbackCount += 1
            }
        }

        do {
            try await feedbackRepository.submitFeedback(feedback)
            optimisticFeedbackIDs.remove(feedback.id)
            return .success(())
        } catch {
            let appError = map(error)
            errorMessage = "送信できませんでした。もう一度試してください。"
            return .failure(appError)
        }
    }

    func like(_ feedback: Feedback) async {
        guard !likedFeedbackIDs.contains(feedback.id) else { return }
        likedFeedbackIDs.insert(feedback.id)

        do {
            try await feedbackRepository.likeFeedback(id: feedback.id)
            if let index = feedbacks.firstIndex(where: { $0.id == feedback.id }) {
                feedbacks[index].likes += 1
            }
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
        membershipTier.isMember
    }

    var canCreateProjects: Bool {
        accountStatus.canCreateProjects
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
                .filter { $0.senderID == currentUserID }
                .reduce(0) { $0 + $1.likes }
        )
    }

    func activatePreviewMembership() {
        guard backendMode == .mock else { return }
        registerPreviewAccount()
        UserDefaults.standard.set(true, forKey: "poco.previewMembership")
        membershipTier = .pocoMember
    }

    func registerPreviewAccount(
        avatarName: String? = BuiltInAvatar.cat.rawValue,
        avatarImageData: Data? = nil
    ) {
        guard backendMode == .mock else { return }
        UserDefaults.standard.set(true, forKey: "poco.previewRegisteredAccount")
        accountStatus = .registered
        let profileID = currentUserID ?? MockData.forestCreator.id
        currentUserID = profileID
        currentAvatarImageData = avatarImageData
        currentProfile = Creator(
            id: profileID,
            name: currentProfile?.name ?? "そらのひつじ",
            avatarName: avatarImageData == nil ? avatarName : nil
        )
        if let currentProfile {
            profileCache[profileID] = currentProfile
            applyProfile(currentProfile)
        }
    }

    func signInWithApple(
        identityToken: String,
        rawNonce: String,
        displayName: String?,
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
                    displayName: displayName
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
                avatarURL: avatarURL
            )
            currentProfile = profile
            profileCache[account.id] = profile
            applyProfile(profile)

            try? await profileRepository.saveProfile(profile)

            await loadMembership()
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
        avatarName: String?,
        avatarImageData: Data?
    ) async -> Result<Void, AppError> {
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canCreateProjects,
              let userID = currentUserID,
              !normalizedName.isEmpty,
              normalizedName.count <= 80 else {
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
                avatarURL: avatarURL
            )
            try await profileRepository.saveProfile(profile)
            currentProfile = profile
            currentAvatarImageData = displayImageData
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

    func signOut() async {
        do {
            try await authRepository.signOut()
            accountStatus = await currentUserProvider.accountStatus()
            currentUserID = await currentUserProvider.currentUserID()
            currentProfile = nil
            currentAvatarImageData = nil
            profileCache.removeAll()
            membershipTier = .guest
            likedFeedbackIDs.removeAll()
            authenticationState = .idle
        } catch {
            let message = map(error).userMessage
            authenticationState = .error(message)
            errorMessage = message
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
            membershipPurchaseState = .error("Pocoメンバーになるにはユーザー登録が必要です。")
            return
        }
        membershipPurchaseState = .purchasing
        do {
            switch try await membershipPurchaseService.purchase() {
            case .purchased(let entitlement):
                membershipTier = .pocoMember
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
                membershipTier = .pocoMember
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
        guard let membershipEntitlementSynchronizer else {
            membershipSyncState = .deferred
            return
        }

        membershipSyncState = .syncing
        do {
            try await membershipEntitlementSynchronizer.sync(entitlement)
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
        description: String,
        imageData: Data?
    ) async -> Result<Project, AppError> {
        guard canCreateProjects else {
            let error = AppError.unauthorized
            errorMessage = "作品を作るにはユーザー登録が必要です。"
            return .failure(error)
        }
        guard let creatorID = await currentUserProvider.currentUserID() else {
            let error = AppError.unauthorized
            errorMessage = error.userMessage
            return .failure(error)
        }

        let projectID = UUID()
        var imageURL: URL?

        do {
            if let imageData, let projectImageStorage {
                let compressedData = try await Task.detached(priority: .userInitiated) {
                    try ProjectImageProcessor.compressedJPEG(from: imageData)
                }.value
                imageURL = try await projectImageStorage.uploadProjectImage(
                    compressedData,
                    projectID: projectID,
                    creatorID: creatorID
                )
            }

            let creator = Creator(
                id: creatorID,
                name: creatorName,
                avatarName: currentProfile?.id == creatorID ? currentProfile?.avatarName : nil,
                avatarURL: currentProfile?.id == creatorID ? currentProfile?.avatarURL : nil
            )
            let project = Project(
                id: projectID,
                title: title,
                creator: creator,
                category: category,
                description: description,
                imageName: nil,
                imageURL: imageURL,
                feedbackCount: 0,
                createdAt: .now
            )

            try await projectRepository.createProject(project)
            projects.insert(project, at: 0)
            return .success(project)
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
    }

    func stopObservingFeedbacks(for projectID: UUID) {
        realtimeTasks[projectID]?.cancel()
        realtimeTasks[projectID] = nil
    }

    func open(url: URL) {
        guard url.scheme?.lowercased() == "poco",
              url.host?.lowercased() == "project",
              let value = url.pathComponents.dropFirst().first,
              let id = UUID(uuidString: value) else { return }

        selectedTab = .home
        if project(id: id) != nil {
            homePath = [id]
        } else {
            pendingDeepLinkProjectID = id
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
        guard backendMode == .supabase, let currentUserID else { return }
        currentProfile = try? await profileRepository.fetchProfile(id: currentUserID)
        currentAvatarImageData = nil
        if let currentProfile {
            profileCache[currentUserID] = currentProfile
        }
    }

    private func hydrateFeedbacks(_ values: [Feedback]) async -> [Feedback] {
        let senderIDs = Set(values.compactMap(\.senderID))
        let missingIDs = senderIDs.filter { profileCache[$0] == nil }
        let repository = profileRepository

        await withTaskGroup(of: (UUID, Creator?).self) { group in
            for id in missingIDs {
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

        return values.map { value in
            guard let senderID = value.senderID,
                  let profile = profileCache[senderID] else { return value }
            var hydrated = value
            hydrated.senderAvatarName = profile.avatarName
            hydrated.senderAvatarURL = profile.avatarURL
            return hydrated
        }
    }

    private func applyProfile(_ profile: Creator) {
        for index in feedbacks.indices where feedbacks[index].senderID == profile.id {
            feedbacks[index].senderAvatarName = profile.avatarName
            feedbacks[index].senderAvatarURL = profile.avatarURL
        }
        for index in projects.indices where projects[index].creator.id == profile.id {
            projects[index].creator = profile
        }
    }

    private func openPendingDeepLinkIfPossible() {
        guard let id = pendingDeepLinkProjectID,
              project(id: id) != nil else { return }
        pendingDeepLinkProjectID = nil
        selectedTab = .home
        homePath = [id]
    }

    private func map(_ error: any Error) -> AppError {
        (error as? AppError) ?? .unknown(error.localizedDescription)
    }
}

enum AppTab: Hashable {
    case home
    case create
    case myPage
}
