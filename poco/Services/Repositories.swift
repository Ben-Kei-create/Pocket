import Foundation

@MainActor
protocol ProjectRepository {
    func fetchProjects() async throws -> [Project]
    func createProject(_ project: Project) async throws
}

@MainActor
protocol FeedbackRepository {
    func fetchFeedbacks(projectID: UUID) async throws -> [Feedback]
    func submitFeedback(_ feedback: Feedback) async throws
    func likeFeedback(id: UUID) async throws
}

@MainActor
final class MockProjectRepository: ProjectRepository {
    private var projects: [Project]

    init(projects: [Project]? = nil) {
        self.projects = projects ?? MockData.projects
    }

    func fetchProjects() async throws -> [Project] {
        projects.sorted { $0.createdAt > $1.createdAt }
    }

    func createProject(_ project: Project) async throws {
        projects.insert(project, at: 0)
    }
}

@MainActor
final class MockFeedbackRepository: FeedbackRepository {
    private var feedbacks: [Feedback]

    init(feedbacks: [Feedback]? = nil) {
        self.feedbacks = feedbacks ?? MockData.feedbacks
    }

    func fetchFeedbacks(projectID: UUID) async throws -> [Feedback] {
        feedbacks
            .filter { $0.projectID == projectID && $0.isPublic }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func submitFeedback(_ feedback: Feedback) async throws {
        feedbacks.append(feedback)
    }

    func likeFeedback(id: UUID) async throws {
        guard let index = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        feedbacks[index].likes += 1
    }
}
