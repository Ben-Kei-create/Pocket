import Foundation

nonisolated enum PocoQuestionStatus: String, Codable, Sendable {
    case pending
    case answered
    case expired
    case withdrawn
    case removedByAdmin = "removed_by_admin"

    var title: String {
        switch self {
        case .pending: "回答待ち"
        case .answered: "回答済み"
        case .expired: "期限切れ"
        case .withdrawn: "取り下げ済み"
        case .removedByAdmin: "非表示"
        }
    }
}

nonisolated struct PocoQuestion: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let projectID: UUID?
    let projectTitle: String?
    let sender: Creator
    let creator: Creator
    var message: String
    var answer: String?
    var status: PocoQuestionStatus
    let createdAt: Date
    var answeredAt: Date?
    var withdrawnAt: Date?

    var effectiveStatus: PocoQuestionStatus {
        if status == .pending,
           createdAt.addingTimeInterval(30 * 24 * 60 * 60) <= .now {
            return .expired
        }
        return status
    }

    func isReceived(by userID: UUID?) -> Bool {
        creator.id == userID
    }

    func isSent(by userID: UUID?) -> Bool {
        sender.id == userID
    }
}

nonisolated enum PocoQuestionLimits {
    static let messageLength = 500
    static let answerLength = 1_000
    static let rollingDayCount = 3
    static let pendingCount = 3
}
