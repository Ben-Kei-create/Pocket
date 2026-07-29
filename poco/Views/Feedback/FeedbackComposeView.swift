import SwiftUI

struct FeedbackComposeView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let onDrop: (Feedback) -> Void

    @State private var message = ""
    @State private var nickname = ""
    @State private var isPublic = true
    @State private var showsFeedbackLimitAlert = false
    @AppStorage("poco.guestNickname") private var savedGuestNickname = ""
    @FocusState private var focusedField: Field?

    private let limit = 500

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(project.title)
                            .pocoFont(.headline, weight: .medium)
                        Text("\(project.category.creatorPrefix)：\(project.creator.name)")
                            .pocoFont(.subheadline)
                            .foregroundStyle(PocoTheme.secondaryText)
                    }

                    messageEditor

                    VStack(alignment: .leading, spacing: 9) {
                        Text("あなたの名前（ニックネーム）")
                            .pocoFont(.subheadline, weight: .medium)
                        TextField("例：そらのひつじ", text: $nickname)
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .nickname)
                            .padding(16)
                            .pocoCard(cornerRadius: PocoTheme.cornerSmall)
                    }

                    Toggle(isOn: $isPublic) {
                        Label("みんなに公開する", systemImage: "globe")
                            .pocoFont(.subheadline, weight: .medium)
                    }
                    .padding(17)
                    .pocoCard(cornerRadius: PocoTheme.cornerSmall)

                    Button(action: makeFeedback) {
                        Label("フキダシをおとす", systemImage: "bubble.left.fill")
                    }
                    .buttonStyle(PocoPrimaryButtonStyle())
                    .disabled(trimmedMessage.isEmpty || trimmedNickname.isEmpty)
                    .opacity(trimmedMessage.isEmpty || trimmedNickname.isEmpty ? 0.48 : 1)
                    .accessibilityHint("次の画面でフキダシを落とします")

                    Text("送信するとフキダシをPocoに追加できます")
                        .pocoFont(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
                .padding(PocoTheme.pagePadding)
            }
            .background(PocoTheme.groupedBackground)
            .navigationTitle("感想を送る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
            .onChange(of: message) { _, newValue in
                if newValue.count > limit {
                    message = String(newValue.prefix(limit))
                }
            }
            .onAppear {
                if nickname.isEmpty {
                    nickname = store.canCreateProjects
                        ? store.currentDisplayName
                        : savedGuestNickname
                }
                focusedField = .message
            }
            .alert("感想は3件までです", isPresented: $showsFeedbackLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("同じ作品へ送れる感想は、1人につき3件までです。")
            }
        }
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

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeFeedback() {
        guard store.canSubmitFeedback(to: project.id) else {
            showsFeedbackLimitAlert = true
            return
        }
        focusedField = nil
        if !store.canCreateProjects {
            savedGuestNickname = trimmedNickname
        }
        let colorIndex = abs(trimmedMessage.hashValue) % BubbleColor.allCases.count
        let senderID = store.canCreateProjects ? store.currentUserID : nil
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
            senderAvatarURL: senderID == nil ? nil : store.currentProfile?.avatarURL
        )
        onDrop(feedback)
    }

    private enum Field {
        case message
        case nickname
    }
}
