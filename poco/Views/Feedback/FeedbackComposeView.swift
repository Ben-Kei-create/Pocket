import SwiftUI

struct FeedbackComposeView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let onDrop: (Feedback) -> Void

    @State private var message = ""
    @State private var nickname = ""
    @State private var isPublic = true
    @State private var publishesProfile = false
    @State private var hasLoadedDraft = false
    @State private var didSubmit = false
    @State private var showsFeedbackLimitAlert = false
    @FocusState private var focusedField: Field?

    private let limit = 500

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(project.title)
                            .pocoFont(.headline, weight: .medium)
                        Text("\(project.category.creatorPrefix)：\(project.creditedAuthorName)")
                            .pocoFont(.subheadline)
                            .foregroundStyle(PocoTheme.secondaryText)
                    }

                    projectSummary

                    messageEditor

                    nicknameSection

                    Toggle(isOn: $isPublic) {
                        Label("みんなに公開する", systemImage: "globe")
                            .pocoFont(.subheadline, weight: .medium)
                    }
                    .padding(17)
                    .pocoCard(cornerRadius: PocoTheme.cornerSmall)

                    if store.canCreateProjects && isPublic {
                        Toggle(isOn: $publishesProfile) {
                            Label("名前とプロフィールを表示する", systemImage: "person.crop.circle")
                                .pocoFont(.subheadline, weight: .medium)
                        }
                        .padding(17)
                        .pocoCard(cornerRadius: PocoTheme.cornerSmall)
                        .accessibilityHint("オフにすると名無しとして表示され、プロフィールには移動できません")
                    }

                    Button(action: makeFeedback) {
                        Label("フキダシをおとす", systemImage: "bubble.left.fill")
                    }
                    .buttonStyle(PocoPrimaryButtonStyle())
                    .disabled(trimmedMessage.isEmpty || trimmedNickname.isEmpty)
                    .opacity(trimmedMessage.isEmpty || trimmedNickname.isEmpty ? 0.48 : 1)
                    .accessibilityHint("次の画面でフキダシを落とします")

                    if !store.canCreateProjects {
                        Text("ゲストの感想は通常24時間後に消えます")
                        .pocoFont(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(PocoTheme.pagePadding)
            }
            .background(PocoTheme.groupedBackground)
            .navigationTitle("感想を送る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        saveDraftIfNeeded()
                        dismiss()
                    }
                }
            }
            .onChange(of: message) { _, newValue in
                if newValue.count > limit {
                    message = String(newValue.prefix(limit))
                }
                saveDraftIfNeeded()
            }
            .onChange(of: nickname) { _, _ in
                saveDraftIfNeeded()
            }
            .onChange(of: isPublic) { _, newValue in
                if !newValue {
                    publishesProfile = false
                    replaceProfileNameWithAnonymousName()
                }
                saveDraftIfNeeded()
            }
            .onChange(of: publishesProfile) { _, newValue in
                if !newValue {
                    replaceProfileNameWithAnonymousName()
                } else if nickname == "名無し" {
                    nickname = store.currentDisplayName
                }
                saveDraftIfNeeded()
            }
            .onAppear {
                if let draft = store.feedbackDraft(for: project.id) {
                    message = draft.message
                    nickname = store.canCreateProjects
                        ? draft.nickname
                        : PocoGuestIdentity.displayName
                    isPublic = draft.isPublic
                    publishesProfile = draft.publishesProfile
                } else if nickname.isEmpty {
                    nickname = store.canCreateProjects
                        ? "名無し"
                        : PocoGuestIdentity.displayName
                }
                hasLoadedDraft = true
                focusedField = .message
            }
            .onDisappear {
                if !didSubmit {
                    saveDraftIfNeeded()
                }
            }
            .alert("感想は3件までです", isPresented: $showsFeedbackLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("同じ作品へ送れる感想は、1人につき3件までです。")
            }
        }
    }

    private var projectSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("この作品について")
                .pocoFont(.subheadline, weight: .medium)
            Text(project.description)
                .pocoFont(.subheadline)
                .foregroundStyle(PocoTheme.secondaryText)
                .lineSpacing(4)

            if let externalURL = project.externalURL {
                Link(destination: externalURL) {
                    Label("作品ページを開く", systemImage: "arrow.up.right")
                        .pocoFont(.caption, weight: .medium)
                        .foregroundStyle(PocoTheme.primary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pocoCard(cornerRadius: PocoTheme.cornerSmall)
    }

    private var messageEditor: some View {
        ZStack(alignment: .topLeading) {
            if message.isEmpty {
                Text("作品を見て感じたことを書いてみよう。")
                    .foregroundStyle(PocoTheme.tertiaryText)
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $message)
                .focused($focusedField, equals: .message)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 210)

            Text("\(message.count)/\(limit)")
                .pocoFont(.caption).monospacedDigit()
                .foregroundStyle(PocoTheme.secondaryText)
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .allowsHitTesting(false)
        }
        .pocoCard()
        .accessibilityLabel("感想")
    }

    @ViewBuilder
    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(store.canCreateProjects ? "あなたの名前（ニックネーム）" : "投稿者")
                .pocoFont(.subheadline, weight: .medium)

            if store.canCreateProjects {
                TextField("例：そらのひつじ", text: $nickname)
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .nickname)
                    .padding(16)
                    .pocoCard(cornerRadius: PocoTheme.cornerSmall)

                if !publishesProfile {
                    Text("フキダシからプロフィールには移動できません")
                        .pocoFont(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.dashed")
                        .foregroundStyle(PocoTheme.secondaryText)
                    Text(PocoGuestIdentity.displayName)
                        .pocoFont(.body, weight: .medium)
                    Spacer()
                    Text("ゲスト")
                        .pocoFont(.caption, weight: .medium)
                        .foregroundStyle(PocoTheme.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(PocoTheme.bubble(.pink), in: Capsule())
                }
                .padding(16)
                .pocoCard(cornerRadius: PocoTheme.cornerSmall)

            }
        }
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNickname: String {
        store.canCreateProjects
            ? nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            : PocoGuestIdentity.displayName
    }

    private func makeFeedback() {
        guard store.canSubmitFeedback(to: project.id) else {
            showsFeedbackLimitAlert = true
            return
        }
        focusedField = nil
        let colorIndex = abs(trimmedMessage.hashValue) % BubbleColor.allCases.count
        let showsProfile = store.canCreateProjects && isPublic && publishesProfile
        let senderID = showsProfile ? store.currentUserID : nil
        let feedback = Feedback(
            id: UUID(),
            projectID: project.id,
            message: trimmedMessage,
            nickname: trimmedNickname,
            isPublic: isPublic,
            createdAt: .now,
            likes: 0,
            bubbleColor: BubbleColor.allCases[colorIndex],
            senderID: senderID,
            senderAvatarName: senderID == nil ? nil : store.currentProfile?.avatarName,
            senderAvatarURL: senderID == nil ? nil : store.currentProfile?.avatarURL,
            publishesProfile: showsProfile,
            expiresAt: store.canCreateProjects ? nil : Date.now.addingTimeInterval(24 * 60 * 60)
        )
        didSubmit = true
        store.discardFeedbackDraft(for: project.id)
        onDrop(feedback)
    }

    private func replaceProfileNameWithAnonymousName() {
        let currentName = store.currentDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || nickname.trimmingCharacters(in: .whitespacesAndNewlines) == currentName {
            nickname = "名無し"
        }
    }

    private func saveDraftIfNeeded() {
        guard hasLoadedDraft, !didSubmit else { return }
        store.saveFeedbackDraft(
            projectID: project.id,
            message: message,
            nickname: nickname,
            isPublic: isPublic,
            publishesProfile: store.canCreateProjects && isPublic && publishesProfile
        )
    }

    private enum Field {
        case message
        case nickname
    }
}
