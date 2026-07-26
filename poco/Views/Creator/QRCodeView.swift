import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct QRCodeView: View {
    let project: Project
    @State private var showsSavedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 8) {
                    Text(project.title)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("このQRコードから感想を送れます")
                        .font(.subheadline)
                        .foregroundStyle(PocoTheme.secondaryText)
                }

                QRCodeImage(data: project.deepLinkURL.absoluteString)
                    .frame(width: 260, height: 260)
                    .padding(22)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.07), radius: 18, y: 8)
                    .accessibilityLabel("\(project.title)のQRコード")

                Text(project.deepLinkURL.absoluteString)
                    .font(.caption.monospaced())
                    .foregroundStyle(PocoTheme.secondaryText)
                    .textSelection(.enabled)

                VStack(spacing: 12) {
                    Button {
                        saveQRCode()
                    } label: {
                        Label("QRコードを保存", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(PocoPrimaryButtonStyle())

                    Button {
                        UIPasteboard.general.url = project.deepLinkURL
                    } label: {
                        Label("リンクをコピー", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(PocoSecondaryButtonStyle())

                    ShareLink(item: project.deepLinkURL) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PocoSecondaryButtonStyle())
                }
            }
            .padding(PocoTheme.pagePadding)
        }
        .background(PocoTheme.background)
        .navigationTitle("作品を共有")
        .navigationBarTitleDisplayMode(.inline)
        .alert("写真に保存しました", isPresented: $showsSavedConfirmation) {
            Button("OK", role: .cancel) {}
        }
    }

    private func saveQRCode() {
        guard let image = QRCodeGenerator.makeImage(
            from: project.deepLinkURL.absoluteString,
            scale: 12
        ) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showsSavedConfirmation = true
    }
}

struct QRCodeImage: View {
    let data: String

    var body: some View {
        Group {
            if let image = QRCodeGenerator.makeImage(from: data) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

enum QRCodeGenerator {
    private static let context = CIContext()

    static func makeImage(from string: String, scale: CGFloat = 8) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage?.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        ), let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
