import Foundation

nonisolated enum AppError: Error, Equatable, Sendable {
    case network
    case unauthorized
    case notFound
    case decoding
    case storage
    case configuration
    case alreadyLiked
    case feedbackLimitReached
    case projectLimitReached
    case handleUnavailable
    case purchase
    case unknown(String?)

    var userMessage: String {
        switch self {
        case .network:
            "ネットワークに接続できませんでした。もう一度お試しください。"
        case .unauthorized:
            "この操作にはログインが必要です。"
        case .notFound:
            "データが見つかりませんでした。"
        case .decoding:
            "データを読み込めませんでした。"
        case .storage:
            "画像を保存できませんでした。"
        case .configuration:
            "バックエンドの設定を確認してください。"
        case .alreadyLiked:
            "このフキダシにはいいね済みです。"
        case .feedbackLimitReached:
            "この作品へ送れる感想は3件までです。"
        case .projectLimitReached:
            "現在のプランで作成できる作品数の上限に達しました。"
        case .handleUnavailable:
            "このクリエイターIDは使用されています。別のIDをお試しください。"
        case .purchase:
            "購入を完了できませんでした。もう一度お試しください。"
        case .unknown:
            "問題が発生しました。もう一度お試しください。"
        }
    }
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        userMessage
    }
}

nonisolated enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case error(AppError)
}
