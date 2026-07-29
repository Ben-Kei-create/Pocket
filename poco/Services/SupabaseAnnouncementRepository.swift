import Foundation
import Supabase

final class SupabaseAnnouncementRepository: AnnouncementRepository, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    nonisolated func fetchPublishedAnnouncements() async throws -> [AppAnnouncement] {
        do {
            let rows: [AppAnnouncementDTO] = try await client
                .from("app_announcements")
                .select("id,kind,title,message,published_at")
                .eq("is_published", value: true)
                .order("published_at", ascending: false)
                .limit(50)
                .execute()
                .value
            return rows.map(\.domainModel)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}
