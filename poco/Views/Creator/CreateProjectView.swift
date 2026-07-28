import PhotosUI
import SwiftUI

struct CreateProjectView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var creatorName = ""
    @State private var category = ProjectCategory.book
    @State private var relationship = ProjectRelationship.creator
    @State private var projectDescription = ""
    @State private var isPhotoPickerPresented = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var hasAgreedToPublishingRules = false
    @State private var showsPublishingRules = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !creatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !projectDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && hasAgreedToPublishingRules
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
                    Text("選んだ区分は作品ページにも表示されます。本人確認が済むまでは「未確認」と表示されます。")
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
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.title2)
                                        .foregroundStyle(PocoTheme.primary)
                                }
                            }
                            .frame(width: 62, height: 62)
                            .background(PocoTheme.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text(selectedImage == nil ? "画像を選ぶ" : "画像を変更")
                        }
                    }
                    .buttonStyle(.plain)
                    .photosPicker(
                        isPresented: $isPhotoPickerPresented,
                        selection: $selectedPhoto,
                        matching: .images
                    )
                }

                Section("作品情報") {
                    TextField("作品名", text: $title)
                    TextField("作者名・クリエイター名", text: $creatorName)
                    Picker("カテゴリ", selection: $category) {
                        ForEach(ProjectCategory.allCases) { category in
                            Label(category.title, systemImage: category.symbolName)
                                .tag(category)
                        }
                    }
                    TextField("作品の説明", text: $projectDescription, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("公開前の確認") {
                    Toggle(isOn: $hasAgreedToPublishingRules) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("作品登録のルールに同意する")
                            Text("なりすましをせず、画像や文章の権利を守ります")
                                .font(.caption)
                                .foregroundStyle(PocoTheme.secondaryText)
                        }
                    }

                    Button("ルールを確認する") {
                        showsPublishingRules = true
                    }
                }

                Section {
                    Text("保存後、作品専用のURLとQRコードが作成されます。")
                        .font(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                }
            }
            .navigationTitle("新しい作品")
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
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    selectedImageData = data
                    selectedImage = image
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
        }
    }

    private func save() {
        isSaving = true
        Task {
            let result = await store.createProject(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                creatorName: creatorName.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                relationship: relationship,
                description: projectDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                imageData: selectedImageData
            )
            isSaving = false
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                saveErrorMessage = error.userMessage
            }
        }
    }
}

private struct ProjectRelationshipOptionRow: View {
    let relationship: ProjectRelationship
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: relationship.symbolName)
                .font(.title3)
                .foregroundStyle(isSelected ? PocoTheme.primary : PocoTheme.secondaryText)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(relationship.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(relationship.explanation)
                    .font(.caption)
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
