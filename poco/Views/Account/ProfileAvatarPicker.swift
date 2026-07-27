import PhotosUI
import SwiftUI
import UIKit

struct ProfileAvatarPicker: View {
    @Binding var avatarName: String?
    @Binding var avatarImageData: Data?

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("プロフィール画像")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("5種＋自分の写真")
                    .font(.caption)
                    .foregroundStyle(PocoTheme.tertiaryText)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BuiltInAvatar.allCases) { avatar in
                        Button {
                            avatarName = avatar.rawValue
                            avatarImageData = nil
                            selectedPhoto = nil
                        } label: {
                            avatarImage(avatar.rawValue)
                                .overlay {
                                    selectionRing(isSelected: avatarName == avatar.rawValue)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(avatar.title)をプロフィール画像にする")
                        .accessibilityAddTraits(
                            avatarName == avatar.rawValue ? .isSelected : []
                        )
                    }

                    ZStack {
                        customPhotoOption
                            .overlay {
                                selectionRing(
                                    isSelected: avatarName == nil && avatarImageData != nil
                                )
                            }

                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Circle()
                                .fill(.clear)
                                .frame(width: 58, height: 58)
                        }
                        .accessibilityLabel("写真ライブラリからプロフィール画像を選ぶ")
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 2)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            isLoadingPhoto = true
            Task {
                defer { isLoadingPhoto = false }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      UIImage(data: data) != nil else { return }
                avatarImageData = data
                avatarName = nil
            }
        }
    }

    private func avatarImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: 58, height: 58)
            .clipShape(Circle())
    }

    @ViewBuilder
    private var customPhotoOption: some View {
        if isLoadingPhoto {
            Circle()
                .fill(PocoTheme.cardBackground)
                .frame(width: 58, height: 58)
                .overlay { ProgressView() }
        } else if let avatarImageData,
                  let image = UIImage(data: avatarImageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(PocoTheme.cardBackground)
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: "photo.badge.plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PocoTheme.primary)
                }
        }
    }

    private func selectionRing(isSelected: Bool) -> some View {
        Circle()
            .stroke(
                isSelected ? PocoTheme.primary : Color.gray.opacity(0.14),
                lineWidth: isSelected ? 3 : 1
            )
            .padding(-3)
    }
}
