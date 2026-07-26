import Foundation

enum BackendMode: String, Sendable {
    case mock
    case supabase
}

struct AppConfiguration: Sendable {
    let backendMode: BackendMode
    let supabaseURL: URL?
    let supabaseAnonKey: String?
    let developmentUserID: UUID?

    var hasValidSupabaseCredentials: Bool {
        guard let supabaseURL,
              supabaseURL.scheme == "https",
              supabaseURL.host != nil,
              let supabaseAnonKey,
              !supabaseAnonKey.isEmpty,
              !supabaseAnonKey.contains("YOUR_") else {
            return false
        }
        return true
    }

    static func load(from bundle: Bundle = .main) -> AppConfiguration {
        let backendValue = bundle.object(forInfoDictionaryKey: "PocoBackend") as? String
        let urlValue = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String
        let keyValue = bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String
        let developmentUserValue = bundle.object(
            forInfoDictionaryKey: "PocoDevelopmentUserID"
        ) as? String

        return AppConfiguration(
            backendMode: BackendMode(rawValue: backendValue?.lowercased() ?? "") ?? .mock,
            supabaseURL: urlValue.flatMap(URL.init(string:)),
            supabaseAnonKey: keyValue?.trimmingCharacters(in: .whitespacesAndNewlines),
            developmentUserID: developmentUserValue.flatMap(UUID.init(uuidString:))
        )
    }
}
