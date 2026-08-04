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
    @State private var retainedImageURLs: [URL]
    @State private var pendingImages: [PendingProjectImage] = []
    @State private var cropCandidate: ProjectImageCropCandidate?
    @State private var isSaving = false
    @State private var isAnalyzingImage = false
    @State private var saveErrorMessage: String?
    @State private var hasAgreedToPublishingRules: Bool
    @State private var showsPublishingRules = false

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
        _retainedImageURLs = State(initialValue: project?.artworkURLs ?? [])
        _hasAgreedToPublishingRules = State(initialValue: project != nil)
    }

    private var isEditing: Bool { project != nil }

    private var imageLimit: Int {
        store.membershipTier.isMember ? 3 : max(1, project?.artworkURLs.count ?? 0)
    }

    private var imageCount: Int { retainedImageURLs.count + pendingImages.count }

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
                    Text("見つけてもらう方法")
                } footer: {
                    Text("どちらもHomeに掲載され、専用URLとQRコードを使えます。")
                }

                Section {
                    Toggle("Q&Aを受け取る", isOn: $acceptsQuestions)
                } header: {
                    Text("Q&A")
                } footer: {
                    Text(qAndAFooter)
                }

                Section("作品画像") {
                    ProjectImageSelectionEditor(
                        retainedImageURLs: $retainedImageURLs,
                        pendingImages: $pendingImages,
                        isPhotoPickerPresented: $isPhotoPickerPresented,
                        selectedPhoto: $selectedPhoto,
                        imageLimit: imageLimit,
                        isPocoPro: store.membershipTier.isMember,
                        isAnalyzingImage: isAnalyzingImage
                    )
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
                        saveErrorMessage = "露骨な性的表現を含む可能性がある画像は、対象区分にかかわらず登録できません。"
                        return
                    }
                    selectedPhoto = nil
                    cropCandidate = ProjectImageCropCandidate(image: image)
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
            .sheet(item: $cropCandidate) { candidate in
                ProjectImageCropperView(image: candidate.image) { image, data in
                    guard imageCount < imageLimit else { return }
                    pendingImages.append(PendingProjectImage(image: image, data: data))
                }
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
                    retainedImageURLs: retainedImageURLs,
                    newImageData: pendingImages.map(\.data)
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
                    imageData: pendingImages.map(\.data)
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
                Text(purpose.discoveryLabel)
                    .pocoFont(.caption2, weight: .bold)
                    .foregroundStyle(isSelected ? PocoTheme.primary : PocoTheme.tertiaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        (isSelected ? PocoTheme.primary : Color.secondary).opacity(0.10),
                        in: Capsule()
                    )
            }

            Spacer(minLength: 8)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? PocoTheme.primary : Color.secondary.opacity(0.45))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct PendingProjectImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let data: Data
}

private struct ProjectImageCropCandidate: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ProjectImageSelectionEditor: View {
    @Binding var retainedImageURLs: [URL]
    @Binding var pendingImages: [PendingProjectImage]
    @Binding var isPhotoPickerPresented: Bool
    @Binding var selectedPhoto: PhotosPickerItem?

    let imageLimit: Int
    let isPocoPro: Bool
    let isAnalyzingImage: Bool

    private var imageCount: Int {
        retainedImageURLs.count + pendingImages.count
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                retainedTiles
                pendingTiles
                if imageCount < imageLimit {
                    addButton
                }
            }
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhoto,
            matching: .images
        )

        HStack {
            Text("\(imageCount)/\(imageLimit)枚")
            Spacer()
            if isPocoPro {
                Label("Poco Proは3枚まで", systemImage: "sparkles")
            } else {
                Text("Poco Proは3枚まで")
            }
        }
        .pocoFont(.caption)
        .foregroundStyle(PocoTheme.secondaryText)

        if isAnalyzingImage {
            ProgressView("画像を確認しています…")
        }
    }

    @ViewBuilder
    private var retainedTiles: some View {
        ForEach(retainedImageURLs, id: \.self) { url in
            let index = retainedImageURLs.firstIndex(of: url) ?? 0
            ProjectImageEditTile(index: index, imageURL: url) {
                retainedImageURLs.removeAll { $0 == url }
            }
        }
    }

    @ViewBuilder
    private var pendingTiles: some View {
        ForEach(pendingImages) { item in
            let pendingIndex = pendingImages.firstIndex { $0.id == item.id } ?? 0
            ProjectImageEditTile(
                index: retainedImageURLs.count + pendingIndex,
                image: item.image
            ) {
                pendingImages.removeAll { $0.id == item.id }
            }
        }
    }

    private var addButton: some View {
        Button {
            isPhotoPickerPresented = true
        } label: {
            VStack(spacing: 7) {
                Image(systemName: "plus")
                    .pocoFont(.title3, weight: .bold)
                Text("追加")
                    .pocoFont(.caption, weight: .medium)
            }
            .foregroundStyle(PocoTheme.primary)
            .frame(width: 92, height: 92)
            .background(PocoTheme.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ProjectImageEditTile: View {
    let index: Int
    var imageURL: URL?
    var image: UIImage?
    let onDelete: () -> Void

    init(index: Int, imageURL: URL, onDelete: @escaping () -> Void) {
        self.index = index
        self.imageURL = imageURL
        image = nil
        self.onDelete = onDelete
    }

    init(index: Int, image: UIImage, onDelete: @escaping () -> Void) {
        self.index = index
        imageURL = nil
        self.image = image
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let imageURL {
                    SecureRemoteImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        case .empty: ProgressView()
                        case .failure: Image(systemName: "photo")
                        }
                    }
                }
            }
            .frame(width: 92, height: 92)
            .background(PocoTheme.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if index == 0 {
                    Text("メイン")
                        .pocoFont(.caption2, weight: .bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(PocoTheme.primary, in: Capsule())
                        .padding(6)
                }
            }

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .pocoFixedFont(size: 10, weight: .bold)
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 25)
                    .background(.black.opacity(0.58), in: Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            .accessibilityLabel("画像\(index + 1)を削除")
        }
    }
}

private struct ProjectImageCropperView: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let onComplete: (UIImage, Data) -> Void

    @State private var zoom: CGFloat = 1
    @State private var settledZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero
    @State private var previewSide: CGFloat = 1
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let side = min(proxy.size.width - 32, proxy.size.height - 130)
                VStack(spacing: 22) {
                    Spacer(minLength: 0)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .scaleEffect(zoom)
                        .offset(offset)
                        .frame(width: side, height: side)
                        .clipped()
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(.white, lineWidth: 3)
                                .shadow(color: .black.opacity(0.18), radius: 5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .simultaneousGesture(magnificationGesture(side: side))
                        .simultaneousGesture(dragGesture(side: side))
                        .onAppear { previewSide = side }
                        .onChange(of: side) { _, value in
                            previewSide = value
                            offset = clampedOffset(offset, zoom: zoom, side: value)
                            settledOffset = offset
                        }

                    Label("ピンチで拡大・ドラッグで位置調整", systemImage: "arrow.up.left.and.arrow.down.right")
                        .pocoFont(.subheadline, weight: .medium)
                        .foregroundStyle(PocoTheme.secondaryText)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
            }
            .background(Color.black.opacity(0.94).ignoresSafeArea())
            .navigationTitle("画像を調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決定") { completeCrop() }
                        .fontWeight(.semibold)
                }
            }
            .alert("画像を調整できませんでした", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func magnificationGesture(side: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(max(settledZoom * value, 1), 4)
                offset = clampedOffset(offset, zoom: zoom, side: side)
            }
            .onEnded { _ in
                settledZoom = zoom
                offset = clampedOffset(offset, zoom: zoom, side: side)
                settledOffset = offset
            }
    }

    private func dragGesture(side: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: settledOffset.width + value.translation.width,
                    height: settledOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed, zoom: zoom, side: side)
            }
            .onEnded { _ in
                settledOffset = offset
            }
    }

    private func clampedOffset(_ value: CGSize, zoom: CGFloat, side: CGFloat) -> CGSize {
        guard let cgImage = image.cgImage else { return .zero }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let baseScale = max(side / width, side / height)
        let maxX = max(0, (width * baseScale * zoom - side) / 2)
        let maxY = max(0, (height * baseScale * zoom - side) / 2)
        return CGSize(
            width: min(max(value.width, -maxX), maxX),
            height: min(max(value.height, -maxY), maxY)
        )
    }

    private func completeCrop() {
        do {
            let result = try ProjectImageProcessor.croppedSquareJPEG(
                from: image,
                previewSide: previewSide,
                zoom: zoom,
                offset: offset
            )
            onComplete(result.image, result.data)
            dismiss()
        } catch {
            errorMessage = AppError.storage.userMessage
        }
    }
}
