import Foundation

nonisolated enum ProjectDeepLink {
    static func projectID(from url: URL, bundle: Bundle = .main) -> UUID? {
        if url.scheme?.lowercased() == "poco",
           url.host?.lowercased() == "project" {
            return url.pathComponents.dropFirst().first.flatMap(UUID.init(uuidString:))
        }

        guard url.scheme?.lowercased() == "https",
              let configuredHost = publicBaseURL(bundle: bundle)?.host?.lowercased(),
              url.host?.lowercased() == configuredHost else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 2,
              ["project", "p"].contains(components[0].lowercased()) else { return nil }
        return UUID(uuidString: components[1])
    }

    static func url(projectID: UUID, bundle: Bundle = .main) -> URL {
        if let baseURL = publicBaseURL(bundle: bundle) {
            return baseURL
                .appendingPathComponent("project")
                .appendingPathComponent(projectID.uuidString)
        }
        return URL(string: "poco://project/\(projectID.uuidString)")!
    }

    private static func publicBaseURL(bundle: Bundle) -> URL? {
        guard let value = bundle.object(forInfoDictionaryKey: "PocoPublicBaseURL") as? String,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
    }
}
