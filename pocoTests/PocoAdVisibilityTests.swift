import XCTest
@testable import poco

final class PocoAdVisibilityTests: XCTestCase {
    func testGuestSeesAds() {
        XCTAssertTrue(AppCapabilities.forRole(.guest).shouldShowAds)
    }

    func testFreeRegisteredUserSeesAds() {
        XCTAssertTrue(AppCapabilities.forRole(.user).shouldShowAds)
    }

    func testPocoProDoesNotSeeAds() {
        XCTAssertFalse(AppCapabilities.forRole(.pro).shouldShowAds)
    }
}
