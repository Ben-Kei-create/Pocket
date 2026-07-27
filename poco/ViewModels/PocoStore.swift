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
    private(set) var currentUserID: UUID?
    private(set) var likedFeedbackIDs: Set<UUID> = []
    private(set) var projectLoadState: LoadState = .idle
    private(set) var feedbackLoadStates: [UUID: LoadState] = [:]
    let backendMode: BackendMode

    private let projectRepository: any ProjectRepository
    private let feedbackRepository: any FeedbackRepository
    private let profileRepository: any ProfileRepository
    private let membershipRepository: any MembershipRepository
    private let currentUserProvider: any CurrentUserProvider
    private let projectImageStorage: (any ProjectImageStorage)?
    private var realtimeTasks: [UUID: Task<Void, Never>] = [:]
    private var optimisticFeedbackIDs: Set<UUID> = []
    private var pendingDeepLinkProjectID: UUID?

    init(
        projectRepository: (any ProjectRepository)? = nil,
        feedbackRepository: (any FeedbackRepository)? = nil,
        profileRepository: (any ProfileRepository)? = nil,
        membershipRepository: (any MembershipRepository)? = nil,
        currentUserProvider: (any CurrentUserProvider)? = nil,
        projectImageStorage: (any ProjectImageStorage)? = nil,
        backendMode: BackendMode = .mock,
        initialProjects: [Project]? = nil,
        initialFeedbacks: [Feedback]? = nil
    ) {
        self.projectRepository = projectRepository ?? MockProjectRepository()
        self.feedbackRepository = feedbackRepository ?? MockFeedbackRepository()
        self.profileRepository = profileRepository ?? MockProfileRepository()
        self.membershipRepository = membershipRepository ?? MockMembershipRepository()
        self.currentUserProvider = currentUserProvider ?? MockCurrentUserProvider()
        self.projectImageStorage = projectImageStorage
        self.backendMode = backendMode
        projects = initialProjects ?? MockData.projects
        feedbacks = initialFeedbacks ?? MockData.feedbacks
    }

    func load() async {
        guard projectLoadState != .loading else { return }
        projectLoadState = .loading

        currentUserID = await currentUserProvider.currentUserID()
        await loadMembership()

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
            let remoteFeedbacks = try await feedbackRepository.fetchFeedbacks(projectID: projectID)
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
        if feedback.senderID == nil {
            feedback.senderID = currentUserID
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
        UserDefaults.standard.set(true, forKey: "poco.previewMembership")
        membershipTier = .pocoMember
    }

    func resetPreviewMembership() {
        guard backendMode == .mock else { return }
        UserDefaults.standard.set(false, forKey: "poco.previewMembership")
        membershipTier = .guest
    }

    func createProject(
        title: String,
        creatorName: String,
        category: ProjectCategory,
        description: String,
        imageData: Data?
    ) async -> Result<Project, AppError> {
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

            let creator = Creator(id: creatorID, name: creatorName, avatarName: nil)
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
            let stream = await repository.observeFeedbacks(projectID: projectID)
            do {
                for try await feedback in stream {
                    guard !Task.isCancelled else { break }
                    self?.mergeRealtimeFeedback(feedback)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                if self?.feedbacks(for: projectID).isEmpty == true {
                    self?.errorMessage = self?.map(error).userMessage
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
