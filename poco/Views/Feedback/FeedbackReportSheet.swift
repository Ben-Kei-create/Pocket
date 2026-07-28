import SwiftUI

struct FeedbackReportSheet: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let feedback: Feedback
    let onSubmitted: () -> Void

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

                Section {
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                        .onChange(of: details) { _, newValue in
                            if newValue.count > 500 {
                                details = String(newValue.prefix(500))
                            }
                        }
                } header: {
                    Text("補足（任意）")
                } footer: {
                    Text("個人情報は書かないでください。\(details.count)/500")
                }

                Section {
                    Text("通報したことは投稿者には通知されません。安全確認のためPoco運営が内容を確認します。")
                        .font(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                }
            }
            .navigationTitle("フキダシを通報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("送信") {
                        submit()
                    }
                    .disabled(isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    ProgressView()
                        .padding(18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            let result = await store.report(feedback, reason: reason, details: details)
            isSubmitting = false
            if case .success = result {
                dismiss()
                onSubmitted()
            }
        }
    }
}
