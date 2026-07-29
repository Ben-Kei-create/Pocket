import SwiftUI

struct ProfileEditView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var handle = ""
    @State private var avatarName: String?
    @State private var avatarImageData: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoadInitialValues = false

    private var normalizedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedHandle: String { CreatorHandle.normalize(handle) }

    private var canSave: Bool {
        !normalizedName.isEmpty && CreatorHandle.isValid(normalizedHandle)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ProfileAvatarView(
                        creator: previewCreator,
                        localImageData: avatarImageData,
                        size: 96
                    )

                    VStack(alignment: .leading, spacing: 9) {
                        Text("表示名")
                            .pocoFont(.subheadline, weight: .medium)
                        TextField("Pocoで使う名前", text: $displayName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .padding(16)
                            .pocoCard(cornerRadius: PocoTheme.cornerSmall)
                            .onChange(of: displayName) { _, value in
                                if value.count > 80 {
                                    displayName = String(value.prefix(80))
                                }
                            }
                        Text("\(displayName.count)/80")
                            .pocoFont(.caption).monospacedDigit()
                            .foregroundStyle(PocoTheme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("クリエイターID")
                            .pocoFont(.subheadline, weight: .medium)
                        HStack(spacing: 6) {
                            Text("@")
                                .foregroundStyle(PocoTheme.secondaryText)
                            TextField("poco_creator", text: $handle)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(16)
                        .pocoCard(cornerRadius: PocoTheme.cornerSmall)
                        Text("半角英小文字・数字・_ を3〜24文字。作品検索に使われます。")
                            .pocoFont(.caption)
                            .foregroundStyle(
                                handle.isEmpty || CreatorHandle.isValid(normalizedHandle)
                                    ? PocoTheme.tertiaryText
                                    : Color.red
                            )
                    }

                    ProfileAvatarPicker(
                        avatarName: $avatarName,
                        avatarImageData: $avatarImageData
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .pocoFont(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("プロフィールを保存", systemImage: "checkmark")
                        }
                    }
                    .buttonStyle(PocoPrimaryButtonStyle())
                    .disabled(isSaving || !canSave)
                    .opacity(canSave ? 1 : 0.48)
                }
                .padding(PocoTheme.pagePadding)
            }
            .background(PocoTheme.groupedBackground)
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: dismiss.callAsFunction)
                        .disabled(isSaving)
                }
            }
            .onAppear {
                guard !didLoadInitialValues else { return }
                didLoadInitialValues = true
                displayName = store.currentDisplayName
                handle = store.currentProfile?.handle ?? ""
                avatarName = store.currentProfile?.avatarName
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var previewCreator: Creator? {
        guard var creator = store.currentProfile else { return nil }
        if let avatarName {
            creator.avatarName = avatarName
            creator.avatarURL = nil
        }
        return creator
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            let result = await store.updateProfile(
                displayName: normalizedName,
                handle: normalizedHandle,
                avatarName: avatarName,
                avatarImageData: avatarImageData
            )
            isSaving = false
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                errorMessage = error.userMessage
            }
        }
    }
}
