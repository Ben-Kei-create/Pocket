import SwiftUI
import UIKit

struct StarStoreArtworkView: View {
    let item: StarStoreItem
    var size: CGFloat = 68

    var body: some View {
        Group {
            if item.kind == .projectBackground {
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .fill(item.decorationColor)
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .fill(.white.opacity(0.8))
                            .frame(width: size * 0.22)
                            .blur(radius: 1)
                            .padding(size * 0.16)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                            .stroke(.white.opacity(0.75), lineWidth: 1)
                    }
            } else if let imageName = item.imageAssetName,
                      UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: item.systemSymbolName ?? "seal.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(PocoTheme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PocoTheme.bubble(.yellow).opacity(0.58), in: Circle())
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.06), radius: 7, y: 3)
        .accessibilityHidden(true)
    }
}

extension StarStoreItem {
    var decorationColor: Color {
        appearanceValue.flatMap(Color.init(pocoHex:)) ?? PocoTheme.background
    }
}
