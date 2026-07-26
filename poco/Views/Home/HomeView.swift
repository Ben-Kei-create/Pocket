import SwiftUI

struct HomeView: View {
    @Environment(PocoStore.self) private var store
    @State private var selectedCategory: CategoryFilter = .all
    @State private var showsNotifications = false

    private var visibleProjects: [Project] {
        switch selectedCategory {
        case .all:
            store.projects
        case .category(let category):
            store.projects.filter { $0.category == category }
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

                    ForEach(visibleProjects) { project in
                        NavigationLink(value: project.id) {
                            ProjectCard(project: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PocoTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .background(PocoTheme.background)
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
