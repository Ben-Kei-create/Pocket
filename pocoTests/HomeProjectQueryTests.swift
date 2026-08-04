import XCTest
@testable import poco

final class HomeProjectQueryTests: XCTestCase {
    private let baseDate = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Normal

    func testNewestOrdersByCreatedAtDescending() {
        let old = makeProject(id: 1, createdOffset: -100)
        let newest = makeProject(id: 2, createdOffset: 100)
        let middle = makeProject(id: 3, createdOffset: 0)

        XCTAssertEqual(
            query(feed: .newest).execute(projects: [old, newest, middle]).map(\.id),
            [newest.id, middle.id, old.id]
        )
    }

    func testRecommendedOrdersByFeedbackCountThenCreatedAt() {
        let popularOld = makeProject(id: 1, feedbackCount: 50, createdOffset: -100)
        let popularNew = makeProject(id: 2, feedbackCount: 50, createdOffset: 100)
        let quiet = makeProject(id: 3, feedbackCount: 2, createdOffset: 200)

        XCTAssertEqual(
            query(feed: .recommended).execute(projects: [quiet, popularOld, popularNew]).map(\.id),
            [popularNew.id, popularOld.id, quiet.id]
        )
    }

    func testCategoryFilterReturnsOnlySelectedCategory() {
        let book = makeProject(id: 1, category: .book)
        let game = makeProject(id: 2, category: .game)

        let result = query(category: .category(.game)).execute(projects: [book, game])

        XCTAssertEqual(result.map(\.id), [game.id])
    }

    func testSearchMatchesTitle() {
        let target = makeProject(id: 1, title: "森のこえ")
        let other = makeProject(id: 2, title: "星の子")

        XCTAssertEqual(query(searchText: "森").execute(projects: [other, target]).map(\.id), [target.id])
    }

    func testSearchMatchesCreditedAuthorAndAccountOwner() {
        let credited = makeProject(id: 1, authorName: "Hoshiko", creatorName: "登録担当")
        let owner = makeProject(id: 2, authorName: "別の作者", creatorName: "Tetra Games")

        XCTAssertEqual(query(searchText: "hoshiko").execute(projects: [owner, credited]).map(\.id), [credited.id])
        XCTAssertEqual(query(searchText: "Tetra").execute(projects: [credited, owner]).map(\.id), [owner.id])
    }

    func testSearchMatchesNormalizedCreatorHandle() {
        let target = makeProject(id: 1, handle: "forest_creator")

        XCTAssertEqual(query(searchText: "@FOREST").execute(projects: [target]).map(\.id), [target.id])
    }

    func testSearchMatchesDescriptionAndCategoryTitle() {
        let target = makeProject(id: 1, category: .manga, description: "宇宙を旅する物語")

        XCTAssertEqual(query(searchText: "旅する").execute(projects: [target]).map(\.id), [target.id])
        XCTAssertEqual(query(searchText: "マンガ").execute(projects: [target]).map(\.id), [target.id])
    }

    func testCategoryIsAppliedBeforeSearch() {
        let book = makeProject(id: 1, title: "同じ題名", category: .book)
        let game = makeProject(id: 2, title: "同じ題名", category: .game)

        let result = query(category: .category(.book), searchText: "同じ").execute(projects: [game, book])

        XCTAssertEqual(result.map(\.id), [book.id])
    }

    // MARK: - Boundary

    func testWhitespaceOnlySearchBehavesAsEmptySearch() {
        let first = makeProject(id: 1, createdOffset: -1)
        let second = makeProject(id: 2, createdOffset: 1)

        XCTAssertEqual(
            query(searchText: " \n\t ").execute(projects: [first, second]).map(\.id),
            [second.id, first.id]
        )
    }

    func testEmptyInputReturnsEmptyOutput() {
        XCTAssertTrue(query().execute(projects: []).isEmpty)
    }

    func testSingleProjectIsPreserved() {
        let only = makeProject(id: 1)

        XCTAssertEqual(query().execute(projects: [only]).map(\.id), [only.id])
    }

    func testEqualSortValuesHaveDeterministicUUIDOrder() {
        let highID = makeProject(id: 2, feedbackCount: 10)
        let lowID = makeProject(id: 1, feedbackCount: 10)

        XCTAssertEqual(
            query(feed: .recommended).execute(projects: [highID, lowID]).map(\.id),
            [lowID.id, highID.id]
        )
    }

    func testExtremeFeedbackCountsSortWithoutOverflow() {
        let maximum = makeProject(id: 1, feedbackCount: .max)
        let minimum = makeProject(id: 2, feedbackCount: .min)

        XCTAssertEqual(
            query(feed: .recommended).execute(projects: [minimum, maximum]).map(\.id),
            [maximum.id, minimum.id]
        )
    }

    // MARK: - Abnormal and defensive

    func testUnknownSearchReturnsNoProjects() {
        let project = makeProject(id: 1)

        XCTAssertTrue(query(searchText: "一致しない検索語").execute(projects: [project]).isEmpty)
    }

    func testAtSignOnlyDoesNotMatchMissingHandle() {
        let project = makeProject(id: 1, handle: nil)

        XCTAssertTrue(query(searchText: "@").execute(projects: [project]).isEmpty)
    }

    func testDuplicateProjectIDsAreRemovedBeforeRendering() {
        let first = makeProject(id: 1, title: "先に取得した作品")
        let duplicate = makeProject(id: 1, title: "重複した作品")
        let other = makeProject(id: 2)

        let result = query().execute(projects: [first, duplicate, other])

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(Set(result.map(\.id)), Set([first.id, other.id]))
        XCTAssertEqual(result.first(where: { $0.id == first.id })?.title, first.title)
    }

    private func query(
        feed: HomeProjectFeed = .newest,
        category: HomeProjectCategoryFilter = .all,
        searchText: String = ""
    ) -> HomeProjectQuery {
        HomeProjectQuery(feed: feed, category: category, searchText: searchText)
    }

    private func makeProject(
        id: Int,
        title: String = "作品",
        authorName: String? = nil,
        creatorName: String = "クリエイター",
        handle: String? = "creator",
        category: ProjectCategory = .book,
        description: String = "説明",
        feedbackCount: Int = 0,
        createdOffset: TimeInterval = 0
    ) -> Project {
        let uuid = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!
        return Project(
            id: uuid,
            title: title,
            creator: Creator(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                name: creatorName,
                avatarName: nil,
                handle: handle
            ),
            authorName: authorName,
            category: category,
            description: description,
            imageName: nil,
            feedbackCount: feedbackCount,
            createdAt: baseDate.addingTimeInterval(createdOffset)
        )
    }
}
