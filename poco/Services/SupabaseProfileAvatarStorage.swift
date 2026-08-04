import Foundation
import Supabase

final class SupabaseProfileAvatarStorage: ProfileAvatarStorage, Sendable {
    private let client: SupabaseClient
    private let bucket = "profile-avatars"

    init(client: SupabaseClient) {
        self.client = client
    }

    nonisolated func uploadProfileAvatar(
        _ data: Data,
        userID: UUID
    ) async throws -> URL {
        let path = [
            "profiles",
            userID.uuidString.lowercased(),
            "avatar.jpg"
        ].joined(separator: "/")

        do {
            try await client.storage
                .from(bucket)
                .upload(
                    path,
                    data: data,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )
            let publicURL = try client.storage
                .from(bucket)
                .getPublicURL(path: path)
            return versioned(publicURL)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func deleteProfileAvatar(at url: URL) async throws {
        let marker = "/object/public/\(bucket)/"
        guard let range = url.path.range(of: marker) else {
            throw AppError.storage
        }
        let path = String(url.path[range.upperBound...])
        guard !path.isEmpty else { throw AppError.storage }

        do {
            try await client.storage
                .from(bucket)
                .remove(paths: [path])
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    private nonisolated func versioned(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.queryItems = [URLQueryItem(name: "v", value: UUID().uuidString.lowercased())]
        return components.url ?? url
    }
}
