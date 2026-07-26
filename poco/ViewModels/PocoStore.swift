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

    private let projectRepository: any ProjectRepository
    private let feedbackRepository: any FeedbackRepository

    init(
        projectRepository: (any ProjectRepository)? = nil,
        feedbackRepository: (any FeedbackRepository)? = nil
    ) {
        self.projectRepository = projectRepository ?? MockProjectRepository()
        self.feedbackRepository = feedbackRepository ?? MockFeedbackRepository()
        projects = MockData.projects
        feedbacks = MockData.feedbacks
    }

    func feedbacks(for projectID: UUID) -> [Feedback] {
        feedbacks
            .filter { $0.projectID == projectID && $0.isPublic }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func project(id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    func submit(_ feedback: Feedback) async {
        do {
            try await feedbackRepository.submitFeedback(feedback)
            feedbacks.append(feedback)
            if let index = projects.firstIndex(where: { $0.id == feedback.projectID }) {
                projects[index].feedbackCount += 1
            }
        } catch {
            errorMessage = "感想を保存できませんでした。もう一度お試しください。"
        }
    }

    func like(_ feedback: Feedback) async {
        do {
            try await feedbackRepository.likeFeedback(id: feedback.id)
            if let index = feedbacks.firstIndex(where: { $0.id == feedback.id }) {
                feedbacks[index].likes += 1
            }
        } catch {
            errorMessage = "いいねを保存できませんでした。"
        }
    }

    func createProject(
        title: String,
        creatorName: String,
        category: ProjectCategory,
        description: String
    ) async {
        let creator = Creator(id: UUID(), name: creatorName, avatarName: nil)
        let project = Project(
            id: UUID(),
            title: title,
            creator: creator,
            category: category,
            description: description,
            imageName: nil,
            feedbackCount: 0,
            createdAt: .now
        )

        do {
            try await projectRepository.createProject(project)
            projects.insert(project, at: 0)
        } catch {
            errorMessage = "作品を保存できませんでした。"
        }
    }

    func open(url: URL) {
        guard url.scheme?.lowercased() == "poco",
              url.host?.lowercased() == "project",
              let value = url.pathComponents.dropFirst().first,
              let id = UUID(uuidString: value),
              project(id: id) != nil else { return }

        selectedTab = .home
        homePath = [id]
    }
}

enum AppTab: Hashable {
    case home
    case create
    case myPage
}
