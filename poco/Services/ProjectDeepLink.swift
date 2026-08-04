import Foundation

nonisolated enum ProjectDeepLink {
    static func projectID(from url: URL) -> UUID? {
        if url.scheme?.lowercased() == "poco",
           url.host?.lowercased() == "project" {
            return url.pathComponents.dropFirst().first.flatMap(UUID.init(uuidString:))
        }
        return nil
    }

    static func url(projectID: UUID) -> URL {
        return URL(string: "poco://project/\(projectID.uuidString)")!
    }
}

nonisolated enum PocoAppStoreLink {
    static func url(bundle: Bundle = .main) -> URL {
        if let value = bundle.object(forInfoDictionaryKey: "PocoAppStoreURL") as? String,
           let configuredURL = URL(
               string: value.trimmingCharacters(in: .whitespacesAndNewlines)
           ),
           configuredURL.scheme?.lowercased() == "https",
           configuredURL.host?.lowercased() == "apps.apple.com" {
            return configuredURL
        }

        // App Store record公開後はPOCO_APP_STORE_URLを正式なアプリURLへ差し替えます。
        return URL(string: "https://apps.apple.com/jp/search?term=Poco")!
    }
}
