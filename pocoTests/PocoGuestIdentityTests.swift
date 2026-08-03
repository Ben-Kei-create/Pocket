import XCTest
@testable import poco

final class PocoGuestIdentityTests: XCTestCase {
    func testDefaultGuestDisplayNameIsAnonymous() {
        XCTAssertEqual(PocoGuestIdentity.displayName, "名無し")
    }
}
