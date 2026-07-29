import SwiftUI
import UIKit

struct ProfileAvatarView: View {
    let creator: Creator?
    var localImageData: Data? = nil
    var size: CGFloat = 58

    var body: some View {
        Group {
            if let localImageData,
               let image = UIImage(data: localImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let avatarName = creator?.avatarName,
                      BuiltInAvatar(rawValue: avatarName) != nil {
                Image(avatarName)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL = creator?.avatarURL {
                SecureRemoteImage(
                    url: avatarURL,
                    maximumBytes: 2_097_152,
                    maximumPixelSize: max(256, size * 3)
                ) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(.white.opacity(0.9), lineWidth: size < 30 ? 0.75 : 2)
        }
        .shadow(
            color: Color.black.opacity(0.08),
            radius: size < 30 ? 1 : 5,
            y: size < 30 ? 0.5 : 2
        )
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Circle()
            .fill(PocoTheme.bubble(.lavender))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(.white)
            }
    }
}
