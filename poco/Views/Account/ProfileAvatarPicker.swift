import PhotosUI
import SwiftUI
import UIKit

struct ProfileAvatarPicker: View {
    @Binding var avatarName: String?
    @Binding var avatarImageData: Data?

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var showsSensitiveImageAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("プロフィール画像")
                    .pocoFont(.subheadline, weight: .medium)
                Spacer()
                Text("Poco＋自分の写真")
                    .pocoFont(.caption)
                    .foregroundStyle(PocoTheme.tertiaryText)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BuiltInAvatar.selectableCases) { avatar in
                        Button {
                            avatarName = avatar.rawValue
                            avatarImageData = nil
                            selectedPhoto = nil
                        } label: {
                            avatarImage(avatar.companionAssetName)
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
                      let sanitizedData = try? ProjectImageProcessor.compressedJPEG(
                        from: data,
                        maximumDimension: 1_024,
                        quality: 0.82
                      ),
                      RemoteImageDecoder.decode(
                        sanitizedData,
                        maximumPixelSize: 1_024
                      ) != nil else { return }
                guard await ImageSensitivityService.analyze(sanitizedData) != .sensitive else {
                    showsSensitiveImageAlert = true
                    selectedPhoto = nil
                    return
                }
                avatarImageData = sanitizedData
                avatarName = nil
            }
        }
        .alert("この画像は使用できません", isPresented: $showsSensitiveImageAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("安全に利用できるプロフィール画像を選んでください。")
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
                        .pocoFont(.title3, weight: .medium)
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
