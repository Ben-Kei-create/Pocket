import SwiftUI

struct QAndAView: View {
    @Environment(PocoStore.self) private var store
    @State private var selection = QAndAListKind.received
    @State private var showsRegistration = false
    let showsNavigationChrome: Bool

    init(showsNavigationChrome: Bool = true) {
        self.showsNavigationChrome = showsNavigationChrome
    }

    var body: some View {
        Group {
            if showsNavigationChrome {
                NavigationStack { content }
            } else {
                content
            }
        }
        .sheet(isPresented: $showsRegistration) {
            RegistrationGateView(context: .account)
        }
    }

    private var content: some View {
        Group {
            if store.accountStatus != .registered {
                VStack(spacing: 0) {
                    PocoCharacterView(
                        size: 132,
                        expression: .question,
                        isInteractive: false
                    )
                    ContentUnavailableView {
                        Label("Q&A", systemImage: "questionmark.bubble")
                    } actions: {
                        Button("ユーザー登録する") { showsRegistration = true }
                            .buttonStyle(PocoPrimaryButtonStyle())
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Picker("表示", selection: $selection) {
                        ForEach(QAndAListKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, PocoTheme.pagePadding)

                    questionList
                }
                .padding(.top, 12)
            }
        }
        .background(PocoTheme.background)
        .navigationTitle("Q&A")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: store.accountStatus) {
            await store.loadQuestions()
            if store.receivedQuestions.isEmpty, !store.sentQuestions.isEmpty {
                selection = .sent
            }
        }
    }

    @ViewBuilder
    private var questionList: some View {
        if store.qAndALoadState == .loading && displayedQuestions.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if displayedQuestions.isEmpty {
            Spacer()
            PocoCharacterView(
                size: 116,
                expression: .question,
                isInteractive: false
            )
            ContentUnavailableView(
                selection.emptyTitle,
                systemImage: selection == .received ? "tray" : "paperplane"
            )
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(displayedQuestions) { question in
                        NavigationLink {
                            QAndADetailView(questionID: question.id)
                        } label: {
                            QAndARow(question: question, kind: selection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PocoTheme.pagePadding)
                .padding(.bottom, 28)
            }
            .refreshable { await store.loadQuestions() }
        }
    }

    private var displayedQuestions: [PocoQuestion] {
        switch selection {
        case .received: store.receivedQuestions
        case .sent: store.sentQuestions
        }
    }
}

private enum QAndAListKind: String, CaseIterable, Identifiable {
    case received
    case sent

    var id: Self { self }
    var title: String { self == .received ? "届いた質問" : "送った質問" }
    var emptyTitle: String { self == .received ? "質問はまだありません" : "送った質問はありません" }
}

private struct QAndARow: View {
    let question: PocoQuestion
    let kind: QAndAListKind

    private var person: Creator {
        kind == .received ? question.sender : question.creator
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProfileAvatarView(creator: person, size: 34)
                Text(person.name)
                    .pocoFont(.subheadline, weight: .medium)
                    .foregroundStyle(.primary)
                Spacer()
                QAndAStatusBadge(status: question.effectiveStatus)
            }

            Text(question.message)
                .pocoFont(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                if let title = question.projectTitle {
                    Text(title).lineLimit(1)
                }
                Spacer()
                Text(question.createdAt, style: .date)
            }
            .pocoFont(.caption)
            .foregroundStyle(PocoTheme.secondaryText)
        }
        .padding(16)
        .pocoCard()
        .accessibilityElement(children: .combine)
    }
}

struct QAndAStatusBadge: View {
    let status: PocoQuestionStatus

    var body: some View {
        Text(status.title)
            .pocoFont(.caption2, weight: .medium)
            .foregroundStyle(status == .pending ? PocoTheme.primary : PocoTheme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                (status == .pending ? PocoTheme.bubble(.pink) : PocoTheme.cardBackground),
                in: Capsule()
            )
    }
}
