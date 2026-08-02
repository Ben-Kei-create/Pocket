import SwiftUI

struct ProfileEditView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var handle = ""
    @State private var avatarName: String?
    @State private var avatarImageData: Data?
    @State private var profileLinks: [EditableProfileLink] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoadInitialValues = false

    private var normalizedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedHandle: String { CreatorHandle.normalize(handle) }

    private var canSave: Bool {
        !normalizedName.isEmpty
            && CreatorHandle.isValid(normalizedHandle)
            && normalizedProfileLinks != nil
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

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("外部リンク")
                                .pocoFont(.headline, weight: .medium)
                            Spacer()
                            Text("\(profileLinks.count)/\(store.maximumProfileLinkCount)")
                                .pocoFont(.caption).monospacedDigit()
                                .foregroundStyle(PocoTheme.tertiaryText)
                        }

                        ForEach($profileLinks) { $link in
                            ProfileLinkEditRow(link: $link) {
                                profileLinks.removeAll { $0.id == link.id }
                            }
                        }

                        if profileLinks.count < store.maximumProfileLinkCount {
                            Menu {
                                ForEach(ProfileLinkService.allCases) { service in
                                    Button {
                                        profileLinks.append(
                                            EditableProfileLink(service: service)
                                        )
                                    } label: {
                                        Label(service.title, systemImage: service.symbolName)
                                    }
                                }
                            } label: {
                                Label("リンクを追加", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(PocoTheme.primary)
                        }

                        if normalizedProfileLinks == nil {
                            Text(linkValidationMessage)
                                .pocoFont(.caption)
                                .foregroundStyle(.red)
                        }
                    }

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
                profileLinks = (store.currentProfile?.profileLinks ?? []).map {
                    EditableProfileLink(
                        service: $0.service,
                        value: $0.url.absoluteString
                    )
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var previewCreator: Creator? {
        var creator = store.currentProfile ?? Creator(
            id: store.currentUserID ?? UUID(),
            name: normalizedName.isEmpty ? store.currentDisplayName : normalizedName
        )
        if let avatarName {
            creator.avatarName = avatarName
            creator.avatarURL = nil
        } else if avatarImageData != nil {
            creator.avatarName = nil
            creator.avatarURL = nil
        }
        return creator
    }

    private func save() {
        guard !isSaving, let normalizedProfileLinks else { return }
        isSaving = true
        errorMessage = nil
        Task {
            let result = await store.updateProfile(
                displayName: normalizedName,
                handle: normalizedHandle,
                avatarName: avatarName,
                avatarImageData: avatarImageData,
                profileLinks: normalizedProfileLinks
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

    private var normalizedProfileLinks: [ProfileSocialLink]? {
        guard profileLinks.count <= store.maximumProfileLinkCount else { return nil }
        var links: [ProfileSocialLink] = []
        for editableLink in profileLinks {
            let value = editableLink.value
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty,
                  let link = ProfileSocialLink(
                    service: editableLink.service,
                    value: value
                  ) else {
                return nil
            }
            links.append(link)
        }
        return links
    }

    private var linkValidationMessage: String {
        normalizedProfileLinks == nil
            ? "サービスに対応する正しいHTTPS URLを入力してください。"
            : ""
    }
}

private struct EditableProfileLink: Identifiable, Equatable {
    let id: UUID
    var service: ProfileLinkService
    var value: String

    init(
        id: UUID = UUID(),
        service: ProfileLinkService,
        value: String = ""
    ) {
        self.id = id
        self.service = service
        self.value = value
    }
}

private struct ProfileLinkEditRow: View {
    @Binding var link: EditableProfileLink
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    Picker("種類", selection: $link.service) {
                        ForEach(ProfileLinkService.allCases) { service in
                            Label(service.title, systemImage: service.symbolName)
                                .tag(service)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        ProfileLinkIcon(service: link.service)
                            .frame(width: 24)
                        Text(link.service.title)
                            .pocoFont(.subheadline, weight: .medium)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("\(link.service.title)のリンクを削除")
            }

            TextField(link.service.placeholder, text: $link.value)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.URL)
                .onChange(of: link.value) { _, value in
                    if value.count > PocoExternalURL.maximumLength {
                        link.value = String(value.prefix(PocoExternalURL.maximumLength))
                    }
                }
        }
        .padding(14)
        .background(PocoTheme.cardBackground)
        .clipShape(
            RoundedRectangle(cornerRadius: PocoTheme.cornerSmall, style: .continuous)
        )
    }
}
