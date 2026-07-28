import Foundation

@MainActor
enum AppEnvironment {
    static func makeStore(bundle: Bundle = .main) -> PocoStore {
        let configuration = AppConfiguration.load(from: bundle)

        if configuration.backendMode == .supabase,
           let client = try? SupabaseClientProvider.makeClient(configuration: configuration) {
            let authenticatedUserProvider = SupabaseCurrentUserProvider(client: client)
            let creatorUserProvider = DevelopmentCurrentUserProvider(
                authenticatedProvider: authenticatedUserProvider,
                fallbackUserID: configuration.developmentUserID
            )
            return PocoStore(
                projectRepository: SupabaseProjectRepository(client: client),
                feedbackRepository: SupabaseFeedbackRepository(
                    client: client,
                    currentUserProvider: authenticatedUserProvider
                ),
                profileRepository: SupabaseProfileRepository(client: client),
                membershipRepository: SupabaseMembershipRepository(client: client),
                memberRewardRepository: SupabaseMemberRewardRepository(
                    client: client,
                    currentUserProvider: authenticatedUserProvider
                ),
                moderationRepository: SupabaseModerationRepository(
                    client: client,
                    currentUserProvider: authenticatedUserProvider
                ),
                membershipPurchaseService: StoreKitMembershipService(
                    productID: configuration.membershipProductID
                ),
                membershipEntitlementSynchronizer: configuration.membershipSyncFunction.map {
                    SupabaseMembershipEntitlementSynchronizer(client: client, functionName: $0)
                },
                authRepository: SupabaseAuthRepository(client: client),
                currentUserProvider: creatorUserProvider,
                projectImageStorage: SupabaseProjectImageStorage(client: client),
                profileAvatarStorage: SupabaseProfileAvatarStorage(client: client),
                backendMode: .supabase,
                initialProjects: [],
                initialFeedbacks: []
            )
        }

        let store = PocoStore(
            membershipRepository: MockMembershipRepository(),
            memberRewardRepository: MockMemberRewardRepository(),
            membershipPurchaseService: DisabledMembershipPurchaseService(),
            authRepository: MockAuthRepository(),
            backendMode: .mock,
            initialProjects: MockData.projects,
            initialFeedbacks: MockData.feedbacks
        )
        if configuration.backendMode == .supabase {
            store.errorMessage = AppError.configuration.userMessage
        }
        return store
    }
}
