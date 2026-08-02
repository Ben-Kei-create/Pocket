import PhotosUI
import SwiftUI

struct CreateProjectView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let project: Project?
    var onProjectLimitReached: () -> Void

    @State private var title: String
    @State private var creatorName: String
    @State private var category: ProjectCategory
    @State private var contentRating: ProjectContentRating
    @State private var relationship: ProjectRelationship
    @State private var purpose: ProjectPurpose
    @State private var acceptsQuestions: Bool
    @State private var projectDescription: String
    @State private var externalURLText: String
    @State private var isPhotoPickerPresented = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var isSaving = false
    @State private var isAnalyzingImage = false
    @State private var saveErrorMessage: String?
    @State private var hasAgreedToPublishingRules: Bool
    @State private var showsPublishingRules = false
    @State private var removesExistingImage = false

    init(
        project: Project? = nil,
        onProjectLimitReached: @escaping () -> Void = {}
    ) {
        self.project = project
        self.onProjectLimitReached = onProjectLimitReached
        _title = State(initialValue: project?.title ?? "")
        _creatorName = State(initialValue: project?.creditedAuthorName ?? "")
        _category = State(initialValue: project?.category ?? .book)
        _contentRating = State(initialValue: project?.contentRating ?? .general)
        _relationship = State(initialValue: project?.relationship ?? .creator)
        _purpose = State(initialValue: project?.purpose ?? .standard)
        _acceptsQuestions = State(initialValue: project?.acceptsQuestions ?? false)
        _projectDescription = State(initialValue: project?.description ?? "")
        _externalURLText = State(initialValue: project?.externalURL?.absoluteString ?? "")
        _hasAgreedToPublishingRules = State(initialValue: project != nil)
    }

    private var isEditing: Bool { project != nil }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !creatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !projectDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (isEditing || hasAgreedToPublishingRules)
            && !isAnalyzingImage
            && isExternalURLValid
    }

    private var isExternalURLValid: Bool {
        externalURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || PocoExternalURL.normalized(from: externalURLText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(ProjectRelationship.allCases) { option in
                        Button {
                            relationship = option
                        } label: {
                            ProjectRelationshipOptionRow(
                                relationship: option,
                                isSelected: relationship == option
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(
                            relationship == option ? .isSelected : []
                        )
                    }
                } header: {
                    Text("この作品との関係")
                } footer: {
                    Text("権利者との関係を選びます。確認状況は作品ページ下部に表示されます。")
                }

                Section {
                    ForEach(ProjectPurpose.allCases) { option in
                        Button {
                            purpose = option
                        } label: {
                            ProjectPurposeOptionRow(
                                purpose: option,
                                isSelected: purpose == option
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(purpose == option ? .isSelected : [])
                    }
                } header: {
                    Text("このページの使い方")
                } footer: {
                    Text("作品との関係とは別に、公開方法を選びます。")
                }

                Section {
                    Toggle("Q&Aを受け取る", isOn: $acceptsQuestions)
                } header: {
                    Text("Q&A")
                } footer: {
                    Text(qAndAFooter)
                }

                Section("作品画像") {
                    Button {
                        isPhotoPickerPresented = true
                    } label: {
                        HStack(spacing: 14) {
                            Group {
                                if let selectedImage {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .scaledToFill()
                                } else if !removesExistingImage,
                                          let imageURL = project?.imageURL {
                                    SecureRemoteImage(url: imageURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        case .empty:
                                            ProgressView()
                                        case .failure:
                                            Image(systemName: "photo.badge.plus")
                                                .foregroundStyle(PocoTheme.primary)
                                        }
                                    }
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .pocoFont(.title2)
                                        .foregroundStyle(PocoTheme.primary)
                                }
                            }
                            .frame(width: 62, height: 62)
                            .background(PocoTheme.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            if isAnalyzingImage {
                                ProgressView("画像を確認しています…")
                            } else {
                                Text(
                                    selectedImage != nil
                                        || (!removesExistingImage && project?.imageURL != nil)
                                        ? "画像を変更"
                                        : "画像を選ぶ"
                                )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .photosPicker(
                        isPresented: $isPhotoPickerPresented,
                        selection: $selectedPhoto,
                        matching: .images
                    )

                    if selectedImage != nil || (!removesExistingImage && project?.imageURL != nil) {
                        Button("画像を削除", role: .destructive) {
                            selectedPhoto = nil
                            selectedImage = nil
                            selectedImageData = nil
                            removesExistingImage = true
                        }
                    }
                }

                Section("作品情報") {
                    TextField("作品名", text: $title)
                    TextField("作品の作者名・制作名義", text: $creatorName)
                    Picker("カテゴリ", selection: $category) {
                        ForEach(ProjectCategory.allCases) { category in
                            Label(category.title, systemImage: category.symbolName)
                                .tag(category)
                        }
                    }
                    Picker("対象区分", selection: $contentRating) {
                        ForEach(ProjectContentRating.allCases) { rating in
                            Label(rating.title, systemImage: rating.symbolName)
                                .tag(rating)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(contentRating.explanation)
                            .pocoFont(.caption)
                            .foregroundStyle(PocoTheme.secondaryText)
                        if contentRating == .mature {
                            Text("Web側で閲覧を許可したユーザー以外には、画像と内容を表示しません。")
                                .pocoFont(.caption, weight: .medium)
                                .foregroundStyle(PocoTheme.primary)
                        }
                    }
                    TextField("作品の説明", text: $projectDescription, axis: .vertical)
                        .lineLimit(4...8)

                    VStack(alignment: .leading, spacing: 5) {
                        TextField("作品URL（公式サイト・販売ページなど）", text: $externalURLText)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.URL)
                            .onChange(of: externalURLText) { _, value in
                                if value.count > PocoExternalURL.maximumLength {
                                    externalURLText = String(value.prefix(PocoExternalURL.maximumLength))
                                }
                            }
                        Text(
                            isExternalURLValid
                                ? "任意。https:// は省略できます。"
                                : "HTTPSの正しいURLを入力してください。"
                        )
                        .pocoFont(.caption)
                        .foregroundStyle(isExternalURLValid ? PocoTheme.tertiaryText : Color.red)
                    }
                }

                Section(isEditing ? "登録ルール" : "公開前の確認") {
                    if isEditing {
                        Label("作品登録時に同意済みです", systemImage: "checkmark.shield.fill")
                            .foregroundStyle(PocoTheme.secondaryText)
                    } else {
                        Toggle(isOn: $hasAgreedToPublishingRules) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("作品登録のルールに同意する")
                                Text("なりすましをせず、画像や文章の権利を守ります")
                                    .pocoFont(.caption)
                                    .foregroundStyle(PocoTheme.secondaryText)
                            }
                        }
                    }

                    Button("ルールを確認する") {
                        showsPublishingRules = true
                    }
                }

                Section {
                    Text(
                        isEditing
                            ? "作品専用URLとQRコードは変更されません。"
                            : "保存後、作品専用のURLとQRコードが作成されます。"
                    )
                        .pocoFont(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                }
            }
            .navigationTitle(isEditing ? "作品を編集" : "新しい作品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("キャンセル")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid || isSaving)
                    .accessibilityLabel("作品を保存")
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    isAnalyzingImage = true
                    defer { isAnalyzingImage = false }
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let sanitizedData = try? ProjectImageProcessor.compressedJPEG(
                            from: data
                          ),
                          let image = RemoteImageDecoder.decode(
                            sanitizedData,
                            maximumPixelSize: 1_600
                          ) else { return }
                    guard await ImageSensitivityService.analyze(sanitizedData) != .sensitive else {
                        selectedPhoto = nil
                        selectedImageData = nil
                        selectedImage = nil
                        saveErrorMessage = "露骨な性的表現を含む可能性がある画像は、対象区分にかかわらず登録できません。"
                        return
                    }
                    selectedImageData = sanitizedData
                    selectedImage = image
                    removesExistingImage = false
                }
            }
            .onChange(of: relationship) { oldValue, newValue in
                if oldValue != .fan, newValue == .fan {
                    acceptsQuestions = false
                }
            }
            .alert(
                "作品を保存できませんでした",
                isPresented: Binding(
                    get: { saveErrorMessage != nil },
                    set: { if !$0 { saveErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .sheet(isPresented: $showsPublishingRules) {
                ProjectPublishingGuidelinesView()
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() {
        isSaving = true
        Task {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanCreatorName = creatorName.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanDescription = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            let externalURL = PocoExternalURL.normalized(from: externalURLText)
            let result: Result<Project, AppError>
            if let project {
                result = await store.updateProject(
                    project,
                    title: cleanTitle,
                    creatorName: cleanCreatorName,
                    category: category,
                    relationship: relationship,
                    purpose: purpose,
                    contentRating: contentRating,
                    acceptsQuestions: acceptsQuestions,
                    description: cleanDescription,
                    externalURL: externalURL,
                    imageData: selectedImageData,
                    removesExistingImage: removesExistingImage
                )
            } else {
                result = await store.createProject(
                    title: cleanTitle,
                    creatorName: cleanCreatorName,
                    category: category,
                    relationship: relationship,
                    purpose: purpose,
                    contentRating: contentRating,
                    acceptsQuestions: acceptsQuestions,
                    description: cleanDescription,
                    externalURL: externalURL,
                    imageData: selectedImageData
                )
            }
            isSaving = false
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                if error == .projectLimitReached {
                    onProjectLimitReached()
                } else {
                    saveErrorMessage = error.userMessage
                }
            }
        }
    }

    private var qAndAFooter: String {
        switch relationship {
        case .creator:
            "この作品についての質問が届きます。"
        case .authorized:
            "質問に答えられる場合のみオンにします。"
        case .fan:
            "著作者ではなく、感想箱の作成者として質問を受け取ります。"
        }
    }
}

private struct ProjectRelationshipOptionRow: View {
    let relationship: ProjectRelationship
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: relationship.symbolName)
                .pocoFont(.title3)
                .foregroundStyle(isSelected ? PocoTheme.primary : PocoTheme.secondaryText)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(relationship.title)
                    .pocoFont(.body, weight: .medium)
                    .foregroundStyle(.primary)
                Text(relationship.explanation)
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? PocoTheme.primary : Color.secondary.opacity(0.45))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct ProjectPurposeOptionRow: View {
    let purpose: ProjectPurpose
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: purpose.symbolName)
                .pocoFont(.title3)
                .foregroundStyle(isSelected ? PocoTheme.primary : PocoTheme.secondaryText)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(purpose.title)
                    .pocoFont(.body, weight: .medium)
                    .foregroundStyle(.primary)
                Text(purpose.explanation)
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? PocoTheme.primary : Color.secondary.opacity(0.45))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
