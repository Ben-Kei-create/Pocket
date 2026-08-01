import SwiftUI

struct QAndADetailView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let questionID: UUID

    @State private var answer = ""
    @State private var isSubmitting = false
    @State private var showsReport = false
    @State private var showsWithdrawConfirmation = false
    @State private var showsBlockConfirmation = false

    private var question: PocoQuestion? {
        store.questions.first { $0.id == questionID }
    }

    var body: some View {
        Group {
            if let question {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        profileLink(question)
                        messageCard(question)

                        if let answer = question.answer {
                            answerCard(answer)
                        }

                        if canAnswer(question) {
                            answerComposer(question)
                        }

                        if canWithdraw(question) {
                            Button("質問を取り下げる", role: .destructive) {
                                showsWithdrawConfirmation = true
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(PocoTheme.pagePadding)
                    .padding(.bottom, 24)
                }
                .toolbar { actionMenu }
                .sheet(isPresented: $showsReport) {
                    QAndAReportSheet(questionID: question.id)
                }
                .confirmationDialog(
                    "質問を取り下げますか？",
                    isPresented: $showsWithdrawConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("取り下げる", role: .destructive) { withdraw(question) }
                }
                .confirmationDialog(
                    "このユーザーをブロックしますか？",
                    isPresented: $showsBlockConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("ブロック", role: .destructive) { block(otherPerson(question)) }
                }
            } else {
                ContentUnavailableView("質問が見つかりません", systemImage: "questionmark.bubble")
            }
        }
        .background(PocoTheme.background)
        .navigationTitle("Q&A")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ToolbarContentBuilder
    private var actionMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("通報", systemImage: "exclamationmark.bubble") {
                    showsReport = true
                }
                Button("このユーザーをブロック", systemImage: "hand.raised", role: .destructive) {
                    showsBlockConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("その他の操作")
        }
    }

    private func profileLink(_ question: PocoQuestion) -> some View {
        let person = otherPerson(question)
        return NavigationLink {
            PublicProfileView(creator: person)
        } label: {
            HStack(spacing: 12) {
                ProfileAvatarView(creator: person, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name).pocoFont(.headline, weight: .medium)
                    if let handle = person.handle {
                        Text("@\(handle)")
                            .pocoFont(.caption)
                            .foregroundStyle(PocoTheme.secondaryText)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .pocoFont(.caption, weight: .bold)
                    .foregroundStyle(PocoTheme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }

    private func messageCard(_ question: PocoQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                QAndAStatusBadge(status: question.effectiveStatus)
                Spacer()
                Text(question.createdAt, format: .dateTime.year().month().day().hour().minute())
                    .pocoFont(.caption2)
                    .foregroundStyle(PocoTheme.secondaryText)
            }
            Text(question.message)
                .pocoFont(.body)
                .lineSpacing(5)
            if let title = question.projectTitle {
                Label(title, systemImage: "shippingbox")
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pocoCard()
    }

    private func answerCard(_ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("回答")
                .pocoFont(.caption, weight: .medium)
                .foregroundStyle(PocoTheme.primary)
            Text(answer)
                .pocoFont(.body)
                .lineSpacing(4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PocoTheme.bubble(.yellow).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: PocoTheme.cornerMedium, style: .continuous))
    }

    private func answerComposer(_ question: PocoQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $answer)
                .frame(minHeight: 132)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(PocoTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: PocoTheme.cornerSmall, style: .continuous))
                .onChange(of: answer) { _, value in
                    if value.count > PocoQuestionLimits.answerLength {
                        answer = String(value.prefix(PocoQuestionLimits.answerLength))
                    }
                }
            HStack {
                Text("\(answer.count)/\(PocoQuestionLimits.answerLength)")
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
                Spacer()
                Button("回答する") { submitAnswer(question) }
                    .buttonStyle(.borderedProminent)
                    .tint(PocoTheme.primary)
                    .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
    }

    private func otherPerson(_ question: PocoQuestion) -> Creator {
        question.isReceived(by: store.currentUserID) ? question.sender : question.creator
    }

    private func canAnswer(_ question: PocoQuestion) -> Bool {
        question.isReceived(by: store.currentUserID) && question.effectiveStatus == .pending
    }

    private func canWithdraw(_ question: PocoQuestion) -> Bool {
        question.isSent(by: store.currentUserID) && question.effectiveStatus == .pending
    }

    private func submitAnswer(_ question: PocoQuestion) {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            let result = await store.answerQuestion(id: question.id, answer: answer)
            isSubmitting = false
            if case .success = result { answer = "" }
        }
    }

    private func withdraw(_ question: PocoQuestion) {
        Task { _ = await store.withdrawQuestion(id: question.id) }
    }

    private func block(_ creator: Creator) {
        Task {
            if case .success = await store.block(creator) {
                dismiss()
            }
        }
    }
}

private struct QAndAReportSheet: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let questionID: UUID

    @State private var reason = FeedbackReportReason.harassment
    @State private var details = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("理由") {
                    Picker("通報理由", selection: $reason) {
                        ForEach(FeedbackReportReason.allCases) { reason in
                            Text(reason.title).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("補足（任意）") {
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                        .onChange(of: details) { _, value in
                            if value.count > 500 { details = String(value.prefix(500)) }
                        }
                }
            }
            .navigationTitle("質問を通報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("送信") { submit() }.disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            let result = await store.reportQuestion(
                id: questionID,
                reason: reason,
                details: details
            )
            isSubmitting = false
            if case .success = result { dismiss() }
        }
    }
}
