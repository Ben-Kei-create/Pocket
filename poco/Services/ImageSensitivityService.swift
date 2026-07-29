import Foundation
import SensitiveContentAnalysis
import UIKit

nonisolated enum ImageSensitivityResult: Equatable, Sendable {
    case safe
    case sensitive
    case unavailable
}

nonisolated enum ImageSensitivityService {
    static func analyze(_ data: Data) async -> ImageSensitivityResult {
        guard let image = UIImage(data: data),
              let cgImage = image.cgImage else {
            return .unavailable
        }

        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else {
            return .unavailable
        }

        do {
            let analysis = try await analyzer.analyzeImage(cgImage)
            return analysis.isSensitive ? .sensitive : .safe
        } catch {
            // This is an optional, on-device first pass. A disabled policy or
            // analysis failure must never be treated as proof that media is safe.
            return .unavailable
        }
    }
}
