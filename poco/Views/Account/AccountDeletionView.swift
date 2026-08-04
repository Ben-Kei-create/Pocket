import SwiftUI

struct AccountDeletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PocoStore.self) private var store
    @State private var confirmationText = ""
    @State private var showsFinalConfirmation = false
    @State private var errorMessage: String?
    @FocusState private var isConfirmationFocused: Bool

    private var isDeleting: Bool {
        store.accountDeletionState == .deleting
    }

    private var canDelete: Bool {
        confirmationText == "削除" && !isDeleting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("作品、プロフィール、Q&Aなど、アカウントに紐づくデータを削除します。")
                    Text("安全確認が必要な通報記録は、内容を非公開にしたうえで一定期間保持する場合があります。")
                        .foregroundStyle(PocoTheme.secondaryText)
                }

                Section {
                    TextField("削除", text: $confirmationText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isConfirmationFocused)
                        .accessibilityLabel("確認のため削除と入力")
                } header: {
                    Text("「削除」と入力")
                }

                Section {
                    Button("アカウントを削除", role: .destructive) {
                        showsFinalConfirmation = true
                    }
                    .disabled(!canDelete)
                    .frame(maxWidth: .infinity)
                    .accessibilityHint("この操作は取り消せません")
                }
            }
            .navigationTitle("アカウントを削除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .disabled(isDeleting)
                }
            }
            .interactiveDismissDisabled(isDeleting)
            .confirmationDialog(
                "本当に削除しますか？",
                isPresented: $showsFinalConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除する", role: .destructive) {
                    Task {
                        let deleted = await store.deleteAccount()
                        if deleted {
                            dismiss()
                        } else if case .error(let message) = store.accountDeletionState {
                            errorMessage = message
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("元に戻すことはできません。")
            }
            .alert(
                "削除できませんでした",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK") {
                    store.resetAccountDeletionState()
                }
            } message: {
                Text(errorMessage ?? AppError.accountDeletion.userMessage)
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.08)
                            .ignoresSafeArea()
                        ProgressView("削除中")
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("アカウントを削除中")
                }
            }
            .onAppear {
                store.resetAccountDeletionState()
                isConfirmationFocused = true
            }
        }
    }
}
