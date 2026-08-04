import XCTest
@testable import poco

final class ProjectDeepLinkTests: XCTestCase {
    private let projectID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!

    func testProjectURLUsesCustomScheme() {
        XCTAssertEqual(
            ProjectDeepLink.url(projectID: projectID).absoluteString,
            "poco://project/10000000-0000-0000-0000-000000000001"
        )
    }

    func testCustomSchemeReturnsProjectID() {
        let url = URL(string: "poco://project/10000000-0000-0000-0000-000000000001")!

        XCTAssertEqual(ProjectDeepLink.projectID(from: url), projectID)
    }

    func testMalformedProjectURLIsRejected() {
        XCTAssertNil(ProjectDeepLink.projectID(from: URL(string: "poco://project/not-a-uuid")!))
        XCTAssertNil(ProjectDeepLink.projectID(from: URL(string: "poco://other/\(projectID)")!))
        XCTAssertNil(
            ProjectDeepLink.projectID(
                from: URL(string: "https://ben-kei-create.github.io/project/\(projectID)")!
            )
        )
    }

    func testAppStoreFallbackUsesAppleHost() {
        XCTAssertEqual(PocoAppStoreLink.url(bundle: testBundle()).host, "apps.apple.com")
    }

    private func testBundle() -> Bundle {
        Bundle(for: Self.self)
    }
}
