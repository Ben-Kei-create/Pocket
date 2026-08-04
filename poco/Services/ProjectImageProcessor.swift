import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum ProjectImageProcessor {
    @MainActor
    static func croppedSquareJPEG(
        from image: UIImage,
        previewSide: CGFloat,
        zoom: CGFloat,
        offset: CGSize,
        maximumDimension: CGFloat = 1_600
    ) throws -> (image: UIImage, data: Data) {
        guard previewSide > 0,
              zoom >= 1,
              let cgImage = image.cgImage else {
            throw AppError.storage
        }

        let sourceWidth = CGFloat(cgImage.width)
        let sourceHeight = CGFloat(cgImage.height)
        let baseScale = max(previewSide / sourceWidth, previewSide / sourceHeight)
        let displayScale = baseScale * zoom
        let cropLength = min(previewSide / displayScale, min(sourceWidth, sourceHeight))
        let originX = min(
            max(0, sourceWidth / 2 - (previewSide / 2 + offset.width) / displayScale),
            sourceWidth - cropLength
        )
        let originY = min(
            max(0, sourceHeight / 2 - (previewSide / 2 + offset.height) / displayScale),
            sourceHeight - cropLength
        )
        let cropRect = CGRect(
            x: originX,
            y: originY,
            width: cropLength,
            height: cropLength
        ).integral
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            throw AppError.storage
        }

        let cropped = UIImage(cgImage: croppedCGImage, scale: 1, orientation: .up)
        let outputSide = min(maximumDimension, CGFloat(croppedCGImage.width))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSide, height: outputSide),
            format: format
        )
        let resized = renderer.image { _ in
            cropped.draw(in: CGRect(x: 0, y: 0, width: outputSide, height: outputSide))
        }
        guard let data = resized.jpegData(compressionQuality: 0.82),
              data.count <= 6_291_456 else {
            throw AppError.storage
        }
        return (resized, data)
    }

    nonisolated static func compressedJPEG(
        from sourceData: Data,
        maximumDimension: Int = 1_600,
        quality: Double = 0.8
    ) throws -> Data {
        guard !sourceData.isEmpty,
              sourceData.count <= 25_000_000,
              maximumDimension > 0,
              quality > 0,
              quality <= 1,
              let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                0,
                nil
              ) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.intValue > 0,
              height.intValue > 0,
              width.int64Value * height.int64Value <= 80_000_000,
              let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumDimension
                ] as CFDictionary
              ) else {
            throw AppError.storage
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw AppError.storage
        }

        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw AppError.storage
        }
        let data = output as Data
        guard data.count <= 6_291_456 else { throw AppError.storage }
        return data
    }
}
