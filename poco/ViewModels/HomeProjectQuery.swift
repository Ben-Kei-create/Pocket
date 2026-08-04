import Foundation

nonisolated enum HomeProjectCategoryFilter: Hashable, Identifiable, CaseIterable, Sendable {
    case all
    case category(ProjectCategory)

    static let allCases: [HomeProjectCategoryFilter] =
        [.all] + ProjectCategory.allCases.map(HomeProjectCategoryFilter.category)

    var id: String { title }

    var title: String {
        switch self {
        case .all:
            "すべて"
        case .category(let category):
            category.title
        }
    }
}

nonisolated enum HomeProjectFeed: String, CaseIterable, Identifiable, Sendable {
    case newest
    case recommended

    var id: Self { self }

    var title: String {
        switch self {
        case .newest:
            "新着"
        case .recommended:
            "おすすめ"
        }
    }
}

/// HOMEに表示する作品を、カテゴリ・検索・フィード順の順に整形する純粋なQuery。
/// Repositoryが一時的に重複行を返しても、SwiftUIの`ForEach`へ重複IDを渡さない。
nonisolated struct HomeProjectQuery: Sendable {
    let feed: HomeProjectFeed
    let category: HomeProjectCategoryFilter
    let searchText: String

    func execute(projects: [Project]) -> [Project] {
        let uniqueProjects = deduplicated(projects)
        let categoryProjects = switch category {
        case .all:
            uniqueProjects
        case .category(let category):
            uniqueProjects.filter { $0.category == category }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let handleQuery = CreatorHandle.normalize(query)
        let searchedProjects = query.isEmpty ? categoryProjects : categoryProjects.filter { project in
            project.title.localizedStandardContains(query)
                || project.creditedAuthorName.localizedStandardContains(query)
                || project.creator.name.localizedStandardContains(query)
                || (!handleQuery.isEmpty
                    && (project.creator.handle?.localizedStandardContains(handleQuery) ?? false))
                || project.description.localizedStandardContains(query)
                || project.category.title.localizedStandardContains(query)
        }

        return searchedProjects.sorted(by: precedes)
    }

    private func deduplicated(_ projects: [Project]) -> [Project] {
        var seen = Set<UUID>()
        return projects.filter { seen.insert($0.id).inserted }
    }

    private func precedes(_ first: Project, _ second: Project) -> Bool {
        switch feed {
        case .newest:
            if first.createdAt != second.createdAt {
                return first.createdAt > second.createdAt
            }
        case .recommended:
            if first.feedbackCount != second.feedbackCount {
                return first.feedbackCount > second.feedbackCount
            }
            if first.createdAt != second.createdAt {
                return first.createdAt > second.createdAt
            }
        }

        // 同値時も順序を固定し、再描画でカードが入れ替わらないようにする。
        return first.id.uuidString < second.id.uuidString
    }
}
