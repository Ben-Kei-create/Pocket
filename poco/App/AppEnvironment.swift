import Foundation

@MainActor
enum AppEnvironment {
    static func makeStore(bundle: Bundle = .main) -> PocoStore {
        let configuration = AppConfiguration.load(from: bundle)

        if configuration.backendMode == .supabase,
           let client = try? SupabaseClientProvider.makeClient(configuration: configuration) {
            let authenticatedUserProvider = SupabaseCurrentUserProvider(client: client)
            #if DEBUG
            let developmentUserID = configuration.developmentUserID
            #else
            let developmentUserID: UUID? = nil
            #endif
            let creatorUserProvider = DevelopmentCurrentUserProvider(
                authenticatedProvider: authenticatedUserProvider,
                fallbackUserID: developmentUserID
            )
            let serverAuthorityService = SupabaseServerAuthorityService(
                client: client,
                membershipFunctionName: configuration.membershipSyncFunction
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
                starStoreRepository: SupabaseStarStoreRepository(
                    client: client,
                    currentUserProvider: authenticatedUserProvider
                ),
                moderationRepository: SupabaseModerationRepository(
                    client: client,
                    currentUserProvider: authenticatedUserProvider
                ),
                notificationRepository: SupabaseNotificationRepository(
                    client: client,
                    currentUserProvider: authenticatedUserProvider
                ),
                rightsHolderRequestRepository: SupabaseRightsHolderRequestRepository(
                    client: client,
                    currentUserProvider: authenticatedUserProvider
                ),
                membershipPurchaseService: StoreKitMembershipService(
                    productID: configuration.membershipProductID
                ),
                serverAuthorityService: serverAuthorityService,
                authRepository: SupabaseAuthRepository(client: client),
                currentUserProvider: creatorUserProvider,
                projectImageStorage: SupabaseProjectImageStorage(client: client),
                profileAvatarStorage: SupabaseProfileAvatarStorage(client: client),
                backendMode: .supabase,
                initialProjects: [],
                initialFeedbacks: []
            )
        }

        #if DEBUG
        let store = PocoStore(
            membershipRepository: MockMembershipRepository(),
            memberRewardRepository: MockMemberRewardRepository(),
            starStoreRepository: MockStarStoreRepository(),
            membershipPurchaseService: DisabledMembershipPurchaseService(),
            serverAuthorityService: MockServerAuthorityService(),
            authRepository: MockAuthRepository(),
            backendMode: .mock,
            initialProjects: MockData.projects,
            initialFeedbacks: MockData.feedbacks
        )
        if configuration.backendMode == .supabase {
            store.errorMessage = AppError.configuration.userMessage
        }
        return store
        #else
        let unavailable = UnavailableBackendServices()
        let store = PocoStore(
            projectRepository: unavailable,
            feedbackRepository: unavailable,
            profileRepository: unavailable,
            membershipRepository: unavailable,
            memberRewardRepository: unavailable,
            starStoreRepository: unavailable,
            moderationRepository: unavailable,
            notificationRepository: unavailable,
            rightsHolderRequestRepository: unavailable,
            membershipPurchaseService: DisabledMembershipPurchaseService(),
            serverAuthorityService: unavailable,
            authRepository: unavailable,
            currentUserProvider: unavailable,
            backendMode: .supabase,
            initialProjects: [],
            initialFeedbacks: []
        )
        store.errorMessage = AppError.configuration.userMessage
        return store
        #endif
    }
}
