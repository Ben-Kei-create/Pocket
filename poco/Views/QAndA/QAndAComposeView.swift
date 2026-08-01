import SwiftUI

struct QAndAComposeView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let project: Project

    @State private var message = ""
    @State private var isSubmitting = false
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ProfileAvatarView(creator: project.creator, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.creator.name)
                                .pocoFont(.headline, weight: .medium)
                            Text(project.title)
                                .pocoFont(.caption)
                                .foregroundStyle(PocoTheme.secondaryText)
                        }
                    }
                }

                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 180)
                        .onChange(of: message) { _, value in
                            if value.count > PocoQuestionLimits.messageLength {
                                message = String(value.prefix(PocoQuestionLimits.messageLength))
                            }
                        }
                } footer: {
                    Text("\(message.count)/\(PocoQuestionLimits.messageLength)")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .navigationTitle("質問する")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("送る") { submit() }
                        .disabled(
                            message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || isSubmitting
                                || project.creator.id == store.currentUserID
                        )
                }
            }
            .overlay {
                if submitted {
                    Label("送信しました", systemImage: "checkmark.circle.fill")
                        .pocoFont(.headline, weight: .medium)
                        .foregroundStyle(PocoTheme.primary)
                        .padding(18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            let result = await store.sendQuestion(
                to: project.creator.id,
                projectID: project.id,
                message: message
            )
            isSubmitting = false
            if case .success = result {
                submitted = true
                try? await Task.sleep(for: .milliseconds(650))
                dismiss()
            }
        }
    }
}
