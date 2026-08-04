import Foundation

@MainActor
enum PocoOnboardingProgress {
    private static let memberVersion = 1
    private static let proVersion = 1

    static func shouldPresent(
        _ guide: PocoOnboardingGuide,
        userID: UUID,
        defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.integer(forKey: key(for: guide, userID: userID)) < version(for: guide)
    }

    static func complete(
        _ guide: PocoOnboardingGuide,
        userID: UUID,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(version(for: guide), forKey: key(for: guide, userID: userID))
        if guide == .pro {
            defaults.set(memberVersion, forKey: key(for: .member, userID: userID))
        }
    }

    private static func key(for guide: PocoOnboardingGuide, userID: UUID) -> String {
        "poco.onboarding.\(guide.rawValue).\(userID.uuidString.lowercased())"
    }

    private static func version(for guide: PocoOnboardingGuide) -> Int {
        switch guide {
        case .member: memberVersion
        case .pro: proVersion
        }
    }
}
