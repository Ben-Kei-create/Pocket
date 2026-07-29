import Foundation
import Supabase

enum SupabaseErrorMapper {
    nonisolated static func map(_ error: any Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        if error is DecodingError {
            return .decoding
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return .network
            default:
                return .unknown(urlError.localizedDescription)
            }
        }
        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "42501", "PGRST301":
                return .unauthorized
            case "PGRST116", "P0002":
                return .notFound
            case "P0003":
                return .feedbackLimitReached
            case "P0004":
                return .projectLimitReached
            case "P0006":
                return .requestAlreadySubmitted
            case "P0007":
                return .rateLimited
            case "22023":
                return .invalidInput
            default:
                return .unknown(postgrestError.message)
            }
        }
        if error is StorageError {
            return .storage
        }
        return .unknown(error.localizedDescription)
    }
}
