import SwiftUI

struct ProfileEditView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var avatarName: String?
    @State private var avatarImageData: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoadInitialValues = false

    private var normalizedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
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
                            .font(.subheadline.weight(.semibold))
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
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(PocoTheme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    ProfileAvatarPicker(
                        avatarName: $avatarName,
                        avatarImageData: $avatarImageData
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
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
                    .disabled(isSaving || normalizedName.isEmpty)
                    .opacity(normalizedName.isEmpty ? 0.48 : 1)
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
