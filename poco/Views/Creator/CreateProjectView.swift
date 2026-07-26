import PhotosUI
import SwiftUI

struct CreateProjectView: View {
    @Environment(PocoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var creatorName = ""
    @State private var category = ProjectCategory.book
    @State private var projectDescription = ""
    @State private var isPhotoPickerPresented = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isSaving = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !creatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !projectDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
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
                    selectedImage = image
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            await store.createProject(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                creatorName: creatorName.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                description: projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            isSaving = false
            dismiss()
        }
    }
}
