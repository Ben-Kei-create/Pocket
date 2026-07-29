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
                .rpc(
                    "browse_projects",
                    params: BrowseProjectsParameters(creatorID: nil)
                )
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
                .rpc(
                    "browse_projects",
                    params: BrowseProjectsParameters(creatorID: creatorID)
                )
                .execute()
                .value
            return rows.map(\.domainModel)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func fetchProject(id: UUID) async throws -> Project {
        do {
            let rows: [ProjectQueryDTO] = try await client
                .rpc(
                    "get_project",
                    params: GetProjectParameters(projectID: id)
                )
                .execute()
                .value
            guard let project = rows.first?.domainModel else {
                throw AppError.notFound
            }
            return project
        } catch let error as AppError {
            throw error
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

    nonisolated func updateProject(_ project: Project) async throws {
        do {
            let rows: [ProjectMutationResultDTO] = try await client
                .from("projects")
                .update(ProjectUpdateDTO(project: project))
                .eq("id", value: project.id)
                .select("id")
                .execute()
                .value
            guard rows.contains(where: { $0.id == project.id }) else {
                throw AppError.notFound
            }
        } catch let error as AppError {
            throw error
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func deleteProject(id: UUID) async throws {
        do {
            let rows: [ProjectMutationResultDTO] = try await client
                .rpc(
                    "soft_delete_project",
                    params: SoftDeleteProjectParameters(projectID: id)
                )
                .execute()
                .value
            guard rows.contains(where: { $0.id == id }) else {
                throw AppError.notFound
            }
        } catch let error as AppError {
            throw error
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}

nonisolated private struct SoftDeleteProjectParameters: Encodable, Sendable {
    let projectID: UUID

    enum CodingKeys: String, CodingKey {
        case projectID = "p_project_id"
    }
}

nonisolated private struct GetProjectParameters: Encodable, Sendable {
    let projectID: UUID

    enum CodingKeys: String, CodingKey {
        case projectID = "p_project_id"
    }
}

nonisolated private struct BrowseProjectsParameters: Encodable, Sendable {
    let creatorID: UUID?

    enum CodingKeys: String, CodingKey {
        case creatorID = "p_creator_id"
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
                .eq("moderation_status", value: "visible")
                .order("created_at", ascending: false)
                .limit(500)
                .execute()
                .value
            return rows.map(\.domainModel)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func fetchFeedback(id: UUID) async throws -> Feedback {
        do {
            let row: FeedbackDTO = try await client
                .from("feedbacks")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            return row.domainModel
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func fetchLikedFeedbacks() async throws -> [Feedback] {
        guard await currentUserProvider.currentUserID() != nil else { return [] }
        do {
            let rows: [FeedbackDTO] = try await client
                .rpc("my_liked_feedbacks")
                .execute()
                .value
            return rows.map(\.domainModel).sorted { $0.createdAt > $1.createdAt }
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func submitFeedback(_ feedback: Feedback) async throws {
        guard await currentUserProvider.currentUserID() != nil else {
            throw AppError.unauthorized
        }
        let publishesProfile = await currentUserProvider.accountStatus() == .registered
        do {
            try await client
                .rpc(
                    "submit_feedback",
                    params: SubmitFeedbackParameters(
                        feedbackID: feedback.id,
                        projectID: feedback.projectID,
                        nickname: feedback.nickname,
                        message: feedback.message,
                        isPublic: feedback.isPublic,
                        bubbleColor: feedback.bubbleColor.rawValue,
                        publishesProfile: publishesProfile
                    )
                )
                .execute()
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

    nonisolated func fetchCreatorReceipts(feedbackIDs: [UUID]) async throws -> [UUID: Date] {
        guard !feedbackIDs.isEmpty else { return [:] }

        do {
            let rows: [CreatorReceiptDTO] = try await client
                .from("feedback_creator_receipts")
                .select("feedback_id,created_at")
                .in("feedback_id", values: feedbackIDs.map(\.uuidString))
                .execute()
                .value
            return Dictionary(uniqueKeysWithValues: rows.map { ($0.feedbackID, $0.createdAt) })
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func markReceivedByCreator(feedbackID: UUID) async throws -> Date {
        do {
            let rows: [CreatorReceiptDTO] = try await client
                .from("feedback_creator_receipts")
                .insert(CreatorReceiptInsertDTO(feedbackID: feedbackID))
                .select("feedback_id,created_at")
                .execute()
                .value
            guard let createdAt = rows.first?.createdAt else {
                throw AppError.decoding
            }
            return createdAt
        } catch let error as PostgrestError where error.code == "23505" {
            let row: CreatorReceiptDTO = try await client
                .from("feedback_creator_receipts")
                .select("feedback_id,created_at")
                .eq("feedback_id", value: feedbackID)
                .single()
                .execute()
                .value
            return row.createdAt
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func observeCreatorReceipts(
        projectID: UUID
    ) async -> AsyncThrowingStream<CreatorReceipt, any Error> {
        let client = client
        return AsyncThrowingStream { continuation in
            let task = Task {
                let channel = client.channel(
                    "feedback-creator-receipts:\(projectID.uuidString)"
                )
                let insertions = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "feedback_creator_receipts",
                    filter: .eq("project_id", value: projectID)
                )

                do {
                    try await channel.subscribeWithError()
                    for await insertion in insertions {
                        try Task.checkCancellation()
                        let dto = try insertion.decodeRecord(
                            as: CreatorReceiptDTO.self,
                            decoder: DatabaseCoding.decoder()
                        )
                        continuation.yield(
                            CreatorReceipt(feedbackID: dto.feedbackID, createdAt: dto.createdAt)
                        )
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: SupabaseErrorMapper.map(error))
                }

                await client.removeChannel(channel)
            }

            continuation.onTermination = { _ in task.cancel() }
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
                        if dto.isPublic && dto.moderationStatus == "visible" {
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
        } catch let error as PostgrestError where error.code == "23505" {
            throw AppError.handleUnavailable
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}

final class SupabaseModerationRepository: ModerationRepository, Sendable {
    private let client: SupabaseClient
    private let currentUserProvider: any CurrentUserProvider

    init(client: SupabaseClient, currentUserProvider: any CurrentUserProvider) {
        self.client = client
        self.currentUserProvider = currentUserProvider
    }

    nonisolated func fetchOwnedFeedbackIDs() async throws -> Set<UUID> {
        guard await currentUserProvider.currentUserID() != nil else { return [] }
        do {
            let rows: [FeedbackOwnershipDTO] = try await client
                .from("feedback_ownership")
                .select("feedback_id")
                .execute()
                .value
            return Set(rows.map(\.feedbackID))
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func fetchOwnedFeedbacks() async throws -> [Feedback] {
        guard await currentUserProvider.currentUserID() != nil else { return [] }
        do {
            let rows: [FeedbackDTO] = try await client
                .rpc("my_feedbacks")
                .execute()
                .value
            return rows.map(\.domainModel).sorted { $0.createdAt > $1.createdAt }
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func fetchOwnFeedbackCount(projectID: UUID) async throws -> Int {
        guard await currentUserProvider.currentUserID() != nil else { return 0 }
        do {
            let count: Int = try await client
                .rpc(
                    "feedback_submission_count",
                    params: FeedbackProjectParameters(projectID: projectID)
                )
                .execute()
                .value
            return count
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func fetchBlockedProfileIDs() async throws -> Set<UUID> {
        guard let userID = await currentUserProvider.currentUserID() else { return [] }
        do {
            let rows: [UserBlockDTO] = try await client
                .from("user_blocks")
                .select("blocked_profile_id")
                .eq("blocker_id", value: userID)
                .execute()
                .value
            return Set(rows.map(\.blockedProfileID))
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func reportFeedback(
        id: UUID,
        reason: FeedbackReportReason,
        details: String?
    ) async throws {
        do {
            try await client
                .rpc(
                    "report_feedback",
                    params: ReportFeedbackParameters(
                        feedbackID: id,
                        reason: reason.rawValue,
                        details: details
                    )
                )
                .execute()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func deleteOwnFeedback(id: UUID) async throws {
        try await moderate(id: id, action: "delete_by_author")
    }

    nonisolated func hideFeedbackAsCreator(id: UUID) async throws {
        try await moderate(id: id, action: "hide_by_creator")
    }

    nonisolated func blockProfile(id: UUID) async throws {
        guard let userID = await currentUserProvider.currentUserID(), userID != id else {
            throw AppError.unauthorized
        }
        do {
            try await client
                .from("user_blocks")
                .upsert(
                    UserBlockInsertDTO(blockerID: userID, blockedProfileID: id),
                    onConflict: "blocker_id,blocked_profile_id"
                )
                .execute()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    private nonisolated func moderate(id: UUID, action: String) async throws {
        do {
            try await client
                .rpc(
                    "moderate_feedback",
                    params: ModerateFeedbackParameters(feedbackID: id, action: action)
                )
                .execute()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}

final class SupabaseRightsHolderRequestRepository: RightsHolderRequestRepository, Sendable {
    private let client: SupabaseClient
    private let currentUserProvider: any CurrentUserProvider

    init(client: SupabaseClient, currentUserProvider: any CurrentUserProvider) {
        self.client = client
        self.currentUserProvider = currentUserProvider
    }

    nonisolated func submit(_ request: RightsHolderRequest) async throws -> UUID {
        guard await currentUserProvider.currentUserID() != nil else {
            throw AppError.unauthorized
        }

        do {
            let rows: [RightsHolderRequestResultDTO] = try await client
                .rpc(
                    "submit_rights_holder_request",
                    params: SubmitRightsHolderRequestParameters(
                        projectID: request.projectID,
                        requesterName: request.requesterName,
                        requesterEmail: request.requesterEmail,
                        relationship: request.relationship.rawValue,
                        details: request.details
                    )
                )
                .execute()
                .value
            guard let requestID = rows.first?.requestID else {
                throw AppError.decoding
            }
            return requestID
        } catch let error as AppError {
            throw error
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
        await currentOrAnonymousUser()?.id
    }

    func accountStatus() async -> AccountStatus {
        guard let user = await currentOrAnonymousUser() else { return .guest }
        return user.isAnonymous ? .guest : .registered
    }

    private func currentOrAnonymousUser() async -> User? {
        if let user = client.auth.currentUser {
            return user
        }

        // Anonymous Auth gives a guest a stable identity for feedback and Likes.
        return try? await client.auth.signInAnonymously().user
    }
}

final class SupabaseAuthRepository: AuthRepository, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signInWithApple(
        credential: AppleIdentityCredential
    ) async throws -> AuthenticatedAccount {
        do {
            let credentials = OpenIDConnectCredentials(
                provider: .apple,
                idToken: credential.identityToken,
                nonce: credential.rawNonce
            )

            // Linking upgrades the anonymous account in place, preserving its
            // feedback ownership and one-like-per-user history.
            let session: Session
            if client.auth.currentUser?.isAnonymous == true {
                do {
                    session = try await client.auth.linkIdentityWithIdToken(
                        credentials: credentials
                    )
                } catch {
                    // A returning Apple user may already own this identity.
                    // In that case, sign into the existing account.
                    session = try await client.auth.signInWithIdToken(
                        credentials: credentials
                    )
                }
            } else {
                session = try await client.auth.signInWithIdToken(
                    credentials: credentials
                )
            }

            var metadata: [String: AnyJSON] = [:]
            if let displayName = credential.displayName, !displayName.isEmpty {
                metadata["display_name"] = .string(displayName)
            }
            if let appleFullName = credential.appleFullName, !appleFullName.isEmpty {
                metadata["apple_initial_full_name"] = .string(appleFullName)
            }
            if let email = credential.email, !email.isEmpty {
                // Apple only returns this value on the first authorization.
                // Keep the fallback in private Auth metadata, never profiles.
                metadata["apple_initial_email"] = .string(email)
            }
            if !metadata.isEmpty {
                _ = try? await client.auth.update(
                    user: UserAttributes(data: metadata)
                )
            }

            return AuthenticatedAccount(
                id: session.user.id,
                displayName: credential.displayName,
                email: session.user.email ?? credential.email
            )
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}

struct DevelopmentCurrentUserProvider: CurrentUserProvider {
    let authenticatedProvider: any CurrentUserProvider
    let fallbackUserID: UUID?

    nonisolated func currentUserID() async -> UUID? {
        let status = await authenticatedProvider.accountStatus()
        if status == .registered {
            return await authenticatedProvider.currentUserID()
        }
        if let fallbackUserID {
            return fallbackUserID
        }
        return await authenticatedProvider.currentUserID()
    }

    nonisolated func accountStatus() async -> AccountStatus {
        let authenticatedStatus = await authenticatedProvider.accountStatus()
        if authenticatedStatus == .registered || fallbackUserID != nil {
            return .registered
        }
        return .guest
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

final class SupabaseMemberRewardRepository: MemberRewardRepository, Sendable {
    private let client: SupabaseClient
    private let currentUserProvider: any CurrentUserProvider

    init(client: SupabaseClient, currentUserProvider: any CurrentUserProvider) {
        self.client = client
        self.currentUserProvider = currentUserProvider
    }

    nonisolated func fetchRewards(
        signals: AchievementSignals
    ) async throws -> MemberRewardSnapshot {
        guard let userID = await currentUserProvider.currentUserID(),
              await currentUserProvider.accountStatus() == .registered else {
            throw AppError.unauthorized
        }

        do {
            try await client
                .rpc("refresh_my_achievement_stamps")
                .execute()

            let progressRows: [MemberRewardProgressDTO] = try await client
                .from("member_reward_progress")
                .select(
                    "login_streak,last_login_bonus_day,star_coin_balance,wallet_revision"
                )
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value
            let stampRows: [AchievementStampDTO] = try await client
                .from("member_achievement_stamps")
                .select("stamp_key")
                .eq("user_id", value: userID)
                .execute()
                .value
            let progress = progressRows.first
            return MemberRewardSnapshot(
                loginStreak: progress?.loginStreak ?? 0,
                lastClaimedDay: progress?.lastLoginBonusDay,
                starCoinBalance: progress?.starCoinBalance ?? 0,
                walletRevision: progress?.walletRevision ?? 0,
                unlockedStamps: Set(
                    stampRows.compactMap { AchievementStamp(rawValue: $0.stampKey) }
                )
            )
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func claimDailyLoginBonus() async throws -> DailyLoginBonusClaim {
        guard await currentUserProvider.accountStatus() == .registered else {
            throw AppError.unauthorized
        }
        do {
            let rows: [DailyLoginBonusClaimDTO] = try await client
                .rpc("claim_daily_login_bonus")
                .execute()
                .value
            guard let claim = rows.first else { throw AppError.decoding }
            return claim.domainModel
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
