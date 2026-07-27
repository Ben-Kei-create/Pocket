import Foundation
import Supabase

final class SupabaseProjectRepository: ProjectRepository, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    nonisolated func fetchProjects() async throws -> [Project] {
        do {
            let rows: [ProjectQueryDTO] = try await client
                .from("projects_with_feedback_count")
                .select()
                .eq("is_published", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows.map(\.domainModel)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func fetchProjects(creatorID: UUID) async throws -> [Project] {
        do {
            let rows: [ProjectQueryDTO] = try await client
                .from("projects_with_feedback_count")
                .select()
                .eq("creator_id", value: creatorID)
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows.map(\.domainModel)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func createProject(_ project: Project) async throws {
        do {
            try await client
                .from("projects")
                .insert(ProjectDTO(project: project))
                .execute()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}

final class SupabaseFeedbackRepository: FeedbackRepository, Sendable {
    private let client: SupabaseClient
    private let currentUserProvider: any CurrentUserProvider

    init(
        client: SupabaseClient,
        currentUserProvider: any CurrentUserProvider
    ) {
        self.client = client
        self.currentUserProvider = currentUserProvider
    }

    nonisolated func fetchFeedbacks(projectID: UUID) async throws -> [Feedback] {
        do {
            let rows: [FeedbackDTO] = try await client
                .from("feedbacks")
                .select()
                .eq("project_id", value: projectID)
                .eq("is_public", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows.map(\.domainModel)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func submitFeedback(_ feedback: Feedback) async throws {
        let senderID = await currentUserProvider.currentUserID()
        do {
            try await client
                .from("feedbacks")
                .insert(FeedbackDTO(feedback: feedback, senderID: senderID))
                .execute()
        } catch let error as PostgrestError where error.code == "23505" {
            // A retry after an ambiguous network response is idempotent by UUID.
            return
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func likeFeedback(id: UUID) async throws {
        guard let userID = await currentUserProvider.currentUserID() else {
            throw AppError.unauthorized
        }

        do {
            try await client
                .from("feedback_likes")
                .insert(
                    FeedbackLikeDTO(
                        id: UUID(),
                        feedbackID: id,
                        userID: userID
                    )
                )
                .execute()
        } catch let error as PostgrestError where error.code == "23505" {
            throw AppError.alreadyLiked
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func fetchLikedFeedbackIDs(feedbackIDs: [UUID]) async throws -> Set<UUID> {
        guard !feedbackIDs.isEmpty,
              let userID = await currentUserProvider.currentUserID() else {
            return []
        }

        do {
            let rows: [FeedbackLikeQueryDTO] = try await client
                .from("feedback_likes")
                .select("feedback_id")
                .eq("user_id", value: userID)
                .in("feedback_id", values: feedbackIDs.map(\.uuidString))
                .execute()
                .value
            return Set(rows.map(\.feedbackID))
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func observeFeedbacks(
        projectID: UUID
    ) async -> AsyncThrowingStream<Feedback, any Error> {
        let client = client
        return AsyncThrowingStream { continuation in
            let task = Task {
                let channel = client.channel("feedbacks:\(projectID.uuidString)")
                let insertions = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "feedbacks",
                    filter: .eq("project_id", value: projectID)
                )

                do {
                    try await channel.subscribeWithError()
                    for await insertion in insertions {
                        try Task.checkCancellation()
                        let dto = try insertion.decodeRecord(
                            as: FeedbackDTO.self,
                            decoder: DatabaseCoding.decoder()
                        )
                        if dto.isPublic {
                            continuation.yield(dto.domainModel)
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: SupabaseErrorMapper.map(error))
                }

                await client.removeChannel(channel)
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

final class SupabaseProfileRepository: ProfileRepository, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    nonisolated func fetchProfile(id: UUID) async throws -> Creator {
        do {
            let profile: ProfileDTO = try await client
                .from("profiles")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            return profile.domainModel
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func saveProfile(_ creator: Creator) async throws {
        do {
            try await client
                .from("profiles")
                .upsert(ProfileDTO(creator: creator), onConflict: "id")
                .execute()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}

actor SupabaseCurrentUserProvider: CurrentUserProvider {
    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func currentUserID() async -> UUID? {
        if let userID = client.auth.currentUser?.id {
            return userID
        }

        // Supabase anonymous auth gives each guest a stable identity. They can
        // like once per bubble without becoming a registered Poco member.
        return try? await client.auth.signInAnonymously().user.id
    }
}

struct DevelopmentCurrentUserProvider: CurrentUserProvider {
    let authenticatedProvider: any CurrentUserProvider
    let fallbackUserID: UUID?

    nonisolated func currentUserID() async -> UUID? {
        await authenticatedProvider.currentUserID() ?? fallbackUserID
    }
}

final class SupabaseMembershipRepository: MembershipRepository, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    nonisolated func fetchMembership(userID: UUID) async throws -> MembershipTier {
        do {
            let rows: [MembershipDTO] = try await client
                .from("memberships")
                .select("tier,status,current_period_end")
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value
            return rows.first?.membershipTier ?? .guest
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}

enum DatabaseCoding {
    nonisolated static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = try? Date(value, strategy: .iso8601) {
                return date
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Supabase timestamp"
            )
        }
        return decoder
    }
}
