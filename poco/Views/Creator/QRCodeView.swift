import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct QRCodeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let project: Project
    @State private var destination: QRCodeDestination = .installedApp
    @State private var showsSavedConfirmation = false
    @State private var showsCopiedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text(project.title)
                    .pocoFont(.title2, weight: .bold)
                    .multilineTextAlignment(.center)

                Picker("QRコードの種類", selection: $destination) {
                    ForEach(QRCodeDestination.allCases) { destination in
                        Label(destination.title, systemImage: destination.symbolName)
                            .tag(destination)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityHint("アプリ用とインストール用のQRコードを切り替えます")

                VStack(spacing: 8) {
                    Label(destination.heading, systemImage: destination.symbolName)
                        .pocoFont(.headline, weight: .bold)
                        .foregroundStyle(PocoTheme.primary)

                    Text(destination.caption)
                        .pocoFont(.caption)
                        .foregroundStyle(PocoTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }

                QRCodeImage(data: selectedURL.absoluteString)
                    .id(destination)
                    .frame(width: 260, height: 260)
                    .padding(22)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.07), radius: 18, y: 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .accessibilityLabel("\(project.title)の\(destination.accessibilityName)")

                Text(selectedURL.absoluteString)
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
                        copyProjectLink()
                    } label: {
                        Label("リンクをコピー", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(PocoSecondaryButtonStyle())

                    ShareLink(item: selectedURL) {
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: destination)
        .alert("写真に保存しました", isPresented: $showsSavedConfirmation) {
            Button("OK", role: .cancel) {}
        }
        .overlay(alignment: .top) {
            if showsCopiedConfirmation {
                Label("リンクをコピーしました", systemImage: "checkmark.circle.fill")
                    .pocoFont(.subheadline, weight: .bold)
                    .foregroundStyle(PocoTheme.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    private var selectedURL: URL {
        switch destination {
        case .installedApp:
            project.deepLinkURL
        case .appStore:
            PocoAppStoreLink.url()
        }
    }

    private func copyProjectLink() {
        UIPasteboard.general.url = selectedURL
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: "リンクをコピーしました")

        withAnimation(.easeOut(duration: 0.2)) {
            showsCopiedConfirmation = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeIn(duration: 0.2)) {
                showsCopiedConfirmation = false
            }
        }
    }

    private func saveQRCode() {
        guard let image = QRCodeGenerator.makeImage(
            from: selectedURL.absoluteString,
            scale: 12
        ) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showsSavedConfirmation = true
    }
}

private enum QRCodeDestination: String, CaseIterable, Identifiable {
    case installedApp
    case appStore

    var id: Self { self }

    var title: String {
        switch self {
        case .installedApp: "アプリで開く"
        case .appStore: "インストール"
        }
    }

    var heading: String {
        switch self {
        case .installedApp: "Pocoを持っている人用"
        case .appStore: "Pocoをまだ持っていない人用"
        }
    }

    var caption: String {
        switch self {
        case .installedApp: "読み取ると、この作品の感想ページが開きます。"
        case .appStore: "読み取ると、App StoreのPoco検索が開きます。"
        }
    }

    var symbolName: String {
        switch self {
        case .installedApp: "iphone"
        case .appStore: "arrow.down.app"
        }
    }

    var accessibilityName: String {
        switch self {
        case .installedApp: "アプリ用QRコード"
        case .appStore: "インストール用QRコード"
        }
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
