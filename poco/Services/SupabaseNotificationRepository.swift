import Foundation
import Supabase

final class SupabaseNotificationRepository: NotificationRepository, Sendable {
    private let client: SupabaseClient
    private let currentUserProvider: any CurrentUserProvider

    init(client: SupabaseClient, currentUserProvider: any CurrentUserProvider) {
        self.client = client
        self.currentUserProvider = currentUserProvider
    }

    nonisolated func fetchNotifications() async throws -> [PocoNotification] {
        guard await currentUserProvider.accountStatus() == .registered else { return [] }
        do {
            let rows: [NotificationDTO] = try await client
                .from("notifications")
                .select()
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            return rows.map(\.domainModel)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func markRead(id: UUID) async throws -> Date {
        guard await currentUserProvider.accountStatus() == .registered else {
            throw AppError.unauthorized
        }
        do {
            let readAt: Date = try await client
                .rpc(
                    "mark_notification_read",
                    params: MarkNotificationReadParameters(notificationID: id)
                )
                .execute()
                .value
            return readAt
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    nonisolated func observeNotifications(
    ) async -> AsyncThrowingStream<PocoNotification, any Error> {
        guard await currentUserProvider.accountStatus() == .registered,
              let userID = await currentUserProvider.currentUserID() else {
            return AsyncThrowingStream { continuation in continuation.finish() }
        }

        let client = client
        return AsyncThrowingStream { continuation in
            let task = Task {
                let channel = client.channel("notifications:\(userID.uuidString)")
                let insertions = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "notifications",
                    filter: .eq("recipient_id", value: userID)
                )

                do {
                    try await channel.subscribeWithError()
                    for await insertion in insertions {
                        try Task.checkCancellation()
                        let dto = try insertion.decodeRecord(
                            as: NotificationDTO.self,
                            decoder: DatabaseCoding.decoder()
                        )
                        continuation.yield(dto.domainModel)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: SupabaseErrorMapper.map(error))
                }

                await client.removeChannel(channel)
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
