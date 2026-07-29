import AVFoundation
import SwiftUI

struct QRCodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (URL) -> Void

    @State private var scannerError: String?
    @State private var showsManualEntry = false
    @State private var manualURL = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    CameraQRCodeScanner(
                        onCode: handleScannedValue,
                        onError: { scannerError = $0 }
                    )

                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white, style: StrokeStyle(lineWidth: 3, dash: [12, 8]))
                        .frame(width: 246, height: 246)
                        .shadow(color: .black.opacity(0.18), radius: 8)
                        .accessibilityHidden(true)

                    VStack {
                        Spacer()
                        Text("作品のQRコードを枠の中に入れてください")
                            .pocoFont(.subheadline, weight: .medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.58), in: Capsule())
                            .padding(.bottom, 26)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 12) {
                    if let scannerError {
                        Label(scannerError, systemImage: "camera.fill")
                            .pocoFont(.caption)
                            .foregroundStyle(PocoTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    Button(showsManualEntry ? "URL入力を閉じる" : "URLを入力して開く") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsManualEntry.toggle()
                        }
                    }
                    .pocoFont(.subheadline, weight: .medium)
                    .foregroundStyle(PocoTheme.primary)

                    if showsManualEntry {
                        HStack(spacing: 10) {
                            TextField("poco://project/…", text: $manualURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .textFieldStyle(.roundedBorder)

                            Button("開く") {
                                _ = handleScannedValue(manualURL)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PocoTheme.primary)
                            .disabled(manualURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(PocoTheme.pagePadding)
                .background(PocoTheme.background)
            }
            .background(Color.black)
            .navigationTitle("QRコードを読み取る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
        }
    }

    @discardableResult
    private func handleScannedValue(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalized),
              ProjectDeepLink.projectID(from: url) != nil else {
            scannerError = "Pocoの作品QRコードを読み取ってください。"
            return false
        }
        dismiss()
        Task { @MainActor in
            await Task.yield()
            onScan(url)
        }
        return true
    }
}

private struct CameraQRCodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Bool
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> CameraQRCodeScannerViewController {
        CameraQRCodeScannerViewController(onCode: onCode, onError: onError)
    }

    func updateUIViewController(
        _ uiViewController: CameraQRCodeScannerViewController,
        context: Context
    ) {}
}

@MainActor
private final class CameraQRCodeScannerViewController: UIViewController,
    AVCaptureMetadataOutputObjectsDelegate {
    private let captureSession = AVCaptureSession()
    private let onCode: (String) -> Bool
    private let onError: (String) -> Void
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasDeliveredCode = false

    init(onCode: @escaping (String) -> Bool, onError: @escaping (String) -> Void) {
        self.onCode = onCode
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestCameraAndStartIfPossible()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func requestCameraAndStartIfPossible() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    configureAndStart()
                } else {
                    onError("カメラへのアクセスを許可するとQRコードを読み取れます。")
                }
            }
        case .denied, .restricted:
            onError("設定アプリでPocoのカメラアクセスを許可してください。")
        @unknown default:
            onError("カメラを利用できません。URL入力をお試しください。")
        }
    }

    private func configureAndStart() {
        guard captureSession.inputs.isEmpty else {
            if !captureSession.isRunning { captureSession.startRunning() }
            return
        }

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            onError("この端末ではカメラを開始できません。")
            return
        }

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else {
            onError("QRコードの読み取りを開始できません。")
            return
        }

        captureSession.beginConfiguration()
        captureSession.addInput(input)
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        captureSession.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        captureSession.startRunning()
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let value = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue
        else { return }
        Task { @MainActor [weak self] in
            guard let self, !self.hasDeliveredCode else { return }
            guard self.onCode(value) else { return }
            self.hasDeliveredCode = true
            self.captureSession.stopRunning()
        }
    }
}
