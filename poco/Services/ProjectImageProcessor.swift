import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ProjectImageProcessor {
    nonisolated static func compressedJPEG(
        from sourceData: Data,
        maximumDimension: Int = 1_600,
        quality: Double = 0.8
    ) throws -> Data {
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
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
        return output as Data
    }
}
