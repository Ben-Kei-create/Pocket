import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ProjectImageProcessor {
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
