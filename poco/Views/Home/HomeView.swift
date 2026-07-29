import SwiftUI

struct HomeView: View {
    @Environment(PocoStore.self) private var store
    @State private var selectedCategory: CategoryFilter = .all
    @State private var showsNotifications = false
    @State private var showsScanner = false
    @State private var searchText = ""

    private var visibleProjects: [Project] {
        let categoryProjects = switch selectedCategory {
        case .all:
            store.projects
        case .category(let category):
            store.projects.filter { $0.category == category }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let handleQuery = CreatorHandle.normalize(query)
        guard !query.isEmpty else { return categoryProjects }
        return categoryProjects.filter { project in
            project.title.localizedStandardContains(query)
                || project.creator.name.localizedStandardContains(query)
                || (!handleQuery.isEmpty
                    && (project.creator.handle?.localizedStandardContains(handleQuery) ?? false))
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
                        .pocoFont(.title2, weight: .bold)
                        .lineSpacing(4)
                        .padding(.top, 8)

                    categoryFilters
                        .padding(.vertical, 4)

                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !visibleProjects.isEmpty {
                        HStack {
                            Text("\(visibleProjects.count)件見つかりました")
                                .pocoFont(.caption, weight: .medium)
                                .foregroundStyle(PocoTheme.secondaryText)
                            Spacer()
                            Button("検索をクリア") {
                                searchText = ""
                            }
                            .pocoFont(.caption, weight: .medium)
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
                prompt: "作品名・作者名・@クリエイターID"
            )
            .navigationTitle("Poco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showsScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                    .accessibilityLabel("作品のQRコードを読み取る")

                    Button {
                        showsNotifications = true
                    } label: {
                        Image(systemName: "bell")
                            .overlay(alignment: .topTrailing) {
                                if store.unreadNotificationCount > 0 {
                                    Circle()
                                        .fill(PocoTheme.primary)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 2, y: -1)
                                }
                            }
                    }
                    .accessibilityLabel(
                        store.unreadNotificationCount > 0
                            ? "通知、未読\(store.unreadNotificationCount)件"
                            : "通知"
                    )
                }
            }
            .sheet(isPresented: $showsNotifications) {
                NotificationCenterView()
            }
            .sheet(isPresented: $showsScanner) {
                QRCodeScannerSheet { url in
                    store.open(url: url)
                }
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
                            .pocoFont(.subheadline, weight: .medium)
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

struct NotificationCenterView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFeedback: Feedback?
    @State private var openingNotificationID: UUID?
    @State private var showsRegistration = false

    private var receivedFeedbackNotifications: [PocoNotification] {
        store.notifications.filter { $0.type == .newFeedback }
    }

    private var reactionNotifications: [PocoNotification] {
        store.notifications.filter {
            $0.type == .creatorHeart || $0.type == .feedbackLike
        }
    }

    private var serviceNotifications: [PocoNotification] {
        store.notifications.filter {
            $0.type == .moderation || $0.type == .system
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.accountStatus != .registered {
                    ContentUnavailableView {
                        Label("届いたことばを残そう", systemImage: "bell.badge")
                    } description: {
                        Text("登録すると、自分の作品へ届いた感想や、ことばへの共感をここで受け取れます。")
                    } actions: {
                        Button("無料で登録") {
                            showsRegistration = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PocoTheme.primary)
                    }
                } else if store.notificationLoadState == .loading && store.notifications.isEmpty {
                    ProgressView("届いたことばを読み込んでいます")
                } else if case .error = store.notificationLoadState,
                          store.notifications.isEmpty {
                    ContentUnavailableView {
                        Label("読み込めませんでした", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("通信環境を確認して、もう一度お試しください。")
                    } actions: {
                        Button("もう一度試す") {
                            Task { await store.loadNotifications() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PocoTheme.primary)
                    }
                } else if store.notifications.isEmpty {
                    ContentUnavailableView {
                        Label("まだ届いていません", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("作品への新しい感想や、あなたのことばへの反応がここに届きます。")
                    }
                } else {
                    List {
                        notificationSection(
                            "届いたことば",
                            notifications: receivedFeedbackNotifications
                        )
                        notificationSection(
                            "リアクション",
                            notifications: reactionNotifications
                        )
                        notificationSection(
                            "Pocoから",
                            notifications: serviceNotifications
                        )
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await store.loadNotifications()
                    }
                }
            }
            .background(PocoTheme.background)
            .navigationTitle("届いたことば")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
        }
        .task {
            await store.loadNotifications()
            store.startObservingNotifications()
        }
        .sheet(item: $selectedFeedback) { feedback in
            BubbleDetailSheet(feedbackID: feedback.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsRegistration) {
            RegistrationGateView(context: .account)
        }
    }

    @ViewBuilder
    private func notificationSection(
        _ title: String,
        notifications: [PocoNotification]
    ) -> some View {
        if !notifications.isEmpty {
            Section(title) {
                ForEach(notifications) { notification in
                    Button {
                        open(notification)
                    } label: {
                        NotificationInboxRow(
                            notification: notification,
                            isOpening: openingNotificationID == notification.id
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(openingNotificationID != nil)
                    .accessibilityHint(notification.destinationDescription ?? "通知を既読にします")
                }
            }
        }
    }

    private func open(_ notification: PocoNotification) {
        guard openingNotificationID == nil else { return }
        openingNotificationID = notification.id
        Task {
            selectedFeedback = await store.openNotification(notification)
            openingNotificationID = nil
        }
    }
}

private struct NotificationInboxRow: View {
    let notification: PocoNotification
    let isOpening: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(PocoTheme.primary.opacity(0.12))
                Image(systemName: notification.type.symbolName)
                    .pocoFont(.subheadline, weight: .medium)
                    .foregroundStyle(PocoTheme.primary)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(notification.title)
                        .pocoFont(
                            .subheadline,
                            weight: notification.isRead ? .medium : .bold
                        )
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !notification.isRead {
                        Circle()
                            .fill(PocoTheme.primary)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                }

                if let projectTitle = notification.projectTitle {
                    Text(projectTitle)
                        .pocoFont(.caption, weight: .medium)
                        .foregroundStyle(PocoTheme.primary)
                        .lineLimit(1)
                }

                if let preview = notification.messagePreview, !preview.isEmpty {
                    Text(preview)
                        .pocoFont(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                        .lineLimit(2)
                }

                Text(notification.createdAt, style: .relative)
                    .pocoFont(.caption2)
                    .foregroundStyle(PocoTheme.secondaryText)
            }

            if isOpening {
                ProgressView()
                    .controlSize(.small)
            } else if notification.feedbackID != nil {
                Image(systemName: "chevron.right")
                    .pocoFont(.caption, weight: .medium)
                    .foregroundStyle(PocoTheme.secondaryText.opacity(0.6))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            notification.isRead ? notification.title : "未読、\(notification.title)"
        )
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
