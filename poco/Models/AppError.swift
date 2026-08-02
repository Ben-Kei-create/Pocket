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
    case invalidInput
    case requestAlreadySubmitted
    case rateLimited
    case purchase
    case insufficientStarCoins
    case itemAlreadyEquipped
    case projectSlotRedemptionUnavailable
    case questionDailyLimitReached
    case questionPendingLimitReached
    case questionUnavailable
    case projectQuestionsDisabled
    case accountDeletion
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
        case .invalidInput:
            "入力内容を確認してください。"
        case .requestAlreadySubmitted:
            "この作品についての申請はすでに受け付けています。"
        case .rateLimited:
            "短時間に多くの操作が行われました。時間をおいてお試しください。"
        case .purchase:
            "購入を完了できませんでした。もう一度お試しください。"
        case .insufficientStarCoins:
            "スターが足りません。もう少し集めてからお試しください。"
        case .itemAlreadyEquipped:
            "このバッジは、すでに別の枠へ飾っています。"
        case .projectSlotRedemptionUnavailable:
            "Poco Proでは30作品まで利用できるため、無料枠の購入はできません。"
        case .questionDailyLimitReached:
            "同じ相手へ送れる質問は24時間で3件までです。"
        case .questionPendingLimitReached:
            "同じ相手への回答待ちの質問は3件までです。"
        case .questionUnavailable:
            "この質問は回答または変更できません。"
        case .projectQuestionsDisabled:
            "この作品ではQ&Aを受け付けていません。"
        case .accountDeletion:
            "アカウントを削除できませんでした。時間をおいてもう一度お試しください。"
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
