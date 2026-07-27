import SwiftUI

struct HomeView: View {
    @Environment(PocoStore.self) private var store
    @State private var selectedCategory: CategoryFilter = .all
    @State private var showsNotifications = false
    @State private var searchText = ""

    private var visibleProjects: [Project] {
        let categoryProjects = switch selectedCategory {
        case .all:
            store.projects
        case .category(let category):
            store.projects.filter { $0.category == category }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return categoryProjects }
        return categoryProjects.filter { project in
            project.title.localizedStandardContains(query)
                || project.creator.name.localizedStandardContains(query)
                || project.description.localizedStandardContains(query)
                || project.category.title.localizedStandardContains(query)
        }
    }

    var body: some View {
        @Bindable var store = store

        NavigationStack(path: $store.homePath) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text("応援したいクリエイターの\nプロジェクトを選ぼう")
                        .font(.title2.weight(.bold))
                        .lineSpacing(4)
                        .padding(.top, 8)

                    categoryFilters
                        .padding(.vertical, 4)

                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !visibleProjects.isEmpty {
                        HStack {
                            Text("\(visibleProjects.count)件見つかりました")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PocoTheme.secondaryText)
                            Spacer()
                            Button("検索をクリア") {
                                searchText = ""
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PocoTheme.primary)
                        }
                    }

                    if visibleProjects.isEmpty {
                        projectLoadPlaceholder
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else {
                        ForEach(visibleProjects) { project in
                            NavigationLink(value: project.id) {
                                ProjectCard(project: project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, PocoTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .background(PocoTheme.background)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PocoAdPlacementView(placement: .home)
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "作品名・作者名・説明から検索"
            )
            .navigationTitle("Poco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsNotifications = true
                    } label: {
                        Image(systemName: "bell")
                            .overlay(alignment: .topTrailing) {
                                Circle()
                                    .fill(PocoTheme.primary)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 2, y: -1)
                            }
                    }
                    .accessibilityLabel("通知")
                }
            }
            .sheet(isPresented: $showsNotifications) {
                NotificationCenterView()
            }
            .navigationDestination(for: UUID.self) { id in
                if let project = store.project(id: id) {
                    ProjectDetailView(projectID: project.id)
                } else {
                    ContentUnavailableView("作品が見つかりません", systemImage: "questionmark.folder")
                }
            }
        }
    }

    @ViewBuilder
    private var projectLoadPlaceholder: some View {
        switch store.projectLoadState {
        case .idle, .loading:
            ProgressView("作品を読み込んでいます")
                .foregroundStyle(PocoTheme.secondaryText)
        case .error:
            ContentUnavailableView {
                Label("作品を読み込めませんでした", systemImage: "wifi.exclamationmark")
            } description: {
                Text("通信環境を確認して、もう一度お試しください。")
            } actions: {
                Button("もう一度試す") {
                    Task {
                        await store.load()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(PocoTheme.primary)
            }
        case .loaded:
            ContentUnavailableView {
                Label(
                    searchText.isEmpty
                        ? (selectedCategory == .all ? "作品はまだありません" : "このカテゴリの作品はありません")
                        : "検索に一致する作品がありません",
                    systemImage: searchText.isEmpty ? "books.vertical" : "magnifyingglass"
                )
            } actions: {
                if !searchText.isEmpty || selectedCategory != .all {
                    Button("条件をクリア") {
                        searchText = ""
                        selectedCategory = .all
                    }
                    .buttonStyle(.bordered)
                    .tint(PocoTheme.primary)
                }
            }
        }
    }

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CategoryFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = filter
                        }
                    } label: {
                        Text(filter.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedCategory == filter ? .white : PocoTheme.secondaryText)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 9)
                            .background(
                                selectedCategory == filter ? PocoTheme.primary : PocoTheme.cardBackground,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedCategory == filter ? .isSelected : [])
                }
            }
        }
    }
}

private struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("「森のこえ」に新しいフキダシが届きました")
                        Text("たった今")
                            .font(.caption)
                            .foregroundStyle(PocoTheme.secondaryText)
                    }
                } icon: {
                    Image(systemName: "bubble.left.fill")
                        .foregroundStyle(PocoTheme.primary)
                }

                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("あなたのフキダシにいいねがつきました")
                        Text("2時間前")
                            .font(.caption)
                            .foregroundStyle(PocoTheme.secondaryText)
                    }
                } icon: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(PocoTheme.primary)
                }
            }
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
        }
    }
}

private enum CategoryFilter: Hashable, Identifiable, CaseIterable {
    case all
    case category(ProjectCategory)

    static let allCases: [CategoryFilter] = [.all] + ProjectCategory.allCases.map(CategoryFilter.category)
    var id: String { title }
    var title: String {
        switch self {
        case .all: "すべて"
        case .category(let category): category.title
        }
    }
}
