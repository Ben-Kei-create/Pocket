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
                membershipPurchaseService: StoreKitMembershipService(
                    productID: configuration.membershipProductID
                ),
                currentUserProvider: creatorUserProvider,
                projectImageStorage: SupabaseProjectImageStorage(client: client),
                backendMode: .supabase,
                initialProjects: [],
                initialFeedbacks: []
            )
        }

        let store = PocoStore(
            membershipRepository: MockMembershipRepository(),
            membershipPurchaseService: DisabledMembershipPurchaseService(),
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
