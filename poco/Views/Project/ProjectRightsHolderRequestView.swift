import SwiftUI

struct ProjectRightsHolderRequestView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let project: Project

    @State private var requesterName = ""
    @State private var requesterEmail = ""
    @State private var relationship = RightsHolderRelationship.rightsHolder
    @State private var details = ""
    @State private var confirmsAccuracy = false
    @State private var isSubmitting = false
    @State private var showsSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("対象作品", value: project.title)
                    LabeledContent("登録区分", value: project.relationship.badgeTitle(
                        verificationStatus: project.verificationStatus
                    ))
                } header: {
                    Text("申請対象")
                } footer: {
                    Text("作品ページは申請だけで自動削除されません。Poco運営が内容を確認します。")
                }

                Section("申請者") {
                    TextField("氏名または団体名", text: $requesterName)
                        .textContentType(.name)
                    TextField("連絡先メールアドレス", text: $requesterEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("作品との関係", selection: $relationship) {
                        ForEach(RightsHolderRelationship.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                }

                Section {
                    TextEditor(text: $details)
                        .frame(minHeight: 150)
                        .onChange(of: details) { _, newValue in
                            if newValue.count > 1_000 {
                                details = String(newValue.prefix(1_000))
                            }
                        }
                } header: {
                    Text("権利関係と申請理由")
                } footer: {
                    Text("権利を確認できる情報と、希望する対応を書いてください。個人番号やパスワードは入力しないでください。\(details.count)/1,000")
                }

                Section {
                    Toggle("申請内容が正確で、正当な立場から申請します", isOn: $confirmsAccuracy)
                } footer: {
                    Text("氏名、メールアドレス、申請内容は審査と連絡のためにだけ使用し、一般ユーザーには公開しません。")
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Label("削除申請を送信", systemImage: "checkmark.shield")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .navigationTitle("権利に関する申請")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: dismiss.callAsFunction)
                }
            }
            .task {
                if requesterName.isEmpty, store.canCreateProjects {
                    requesterName = store.currentDisplayName
                }
            }
            .alert("申請を受け付けました", isPresented: $showsSuccess) {
                Button("閉じる") { dismiss() }
            } message: {
                Text("Poco運営が確認し、必要に応じて入力されたメールアドレスへご連絡します。")
            }
            .alert(
                "送信できませんでした",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? AppError.unknown(nil).userMessage)
            }
        }
    }

    private var canSubmit: Bool {
        confirmsAccuracy
            && !requesterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !requesterEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSubmit, !isSubmitting else { return }
        isSubmitting = true
        Task {
            let result = await store.submitRightsHolderRequest(
                for: project,
                requesterName: requesterName,
                requesterEmail: requesterEmail,
                relationship: relationship,
                details: details
            )
            isSubmitting = false
            switch result {
            case .success:
                showsSuccess = true
            case .failure(let error):
                errorMessage = error.userMessage
            }
        }
    }
}
