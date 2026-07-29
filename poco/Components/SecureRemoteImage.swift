import ImageIO
import SwiftUI
import UIKit

enum SecureRemoteImagePhase {
    case empty
    case success(Image)
    case failure
}

struct SecureRemoteImage<Content: View>: View {
    let url: URL
    var maximumBytes = 6_291_456
    var maximumPixelSize: CGFloat = 1_600
    @ViewBuilder let content: (SecureRemoteImagePhase) -> Content

    @State private var loadedImage: UIImage?
    @State private var failed = false

    var body: some View {
        content(phase)
            .task(id: url) {
                loadedImage = nil
                failed = false
                guard let data = await RemoteAvatarDataCache.shared.data(
                    for: url,
                    maximumBytes: maximumBytes
                ), let image = RemoteImageDecoder.decode(
                    data,
                    maximumPixelSize: maximumPixelSize
                ) else {
                    failed = true
                    return
                }
                guard !Task.isCancelled else { return }
                loadedImage = image
            }
    }

    private var phase: SecureRemoteImagePhase {
        if let loadedImage {
            return .success(Image(uiImage: loadedImage))
        }
        return failed ? .failure : .empty
    }
}

nonisolated enum RemoteImageDecoder {
    static func decode(
        _ data: Data,
        maximumPixelSize: CGFloat
    ) -> UIImage? {
        guard maximumPixelSize > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                0,
                nil
              ) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }

        let pixelCount = width.int64Value * height.int64Value
        guard width.intValue > 0,
              height.intValue > 0,
              pixelCount <= 40_000_000 else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maximumPixelSize),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
}
