import Foundation
import Supabase

final class SupabaseProjectImageStorage: ProjectImageStorage, Sendable {
    private let client: SupabaseClient
    private let bucket = "project-images"

    init(client: SupabaseClient) {
        self.client = client
    }

    nonisolated func uploadProjectImage(
        _ data: Data,
        projectID: UUID,
        creatorID: UUID
    ) async throws -> URL {
        let path = [
            "projects",
            creatorID.uuidString.lowercased(),
            projectID.uuidString.lowercased(),
            "\(UUID().uuidString.lowercased()).jpg"
        ].joined(separator: "/")

        do {
            try await client.storage
                .from(bucket)
                .upload(
                    path,
                    data: data,
                    options: FileOptions(
                        cacheControl: "31536000",
                        contentType: "image/jpeg",
                        upsert: false
                    )
                )
            return try client.storage
                .from(bucket)
                .getPublicURL(path: path)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}
