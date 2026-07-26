import Foundation
import Supabase

enum SupabaseClientProvider {
    static func makeClient(configuration: AppConfiguration) throws -> SupabaseClient {
        guard configuration.backendMode == .supabase,
              configuration.hasValidSupabaseCredentials,
              let url = configuration.supabaseURL,
              let anonKey = configuration.supabaseAnonKey else {
            throw AppError.configuration
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }
}
