import Foundation

@MainActor
enum PocoDateFormatting {
    static let feedbackTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy年M月d日 HH時mm分ss秒"
        return formatter
    }()
}
