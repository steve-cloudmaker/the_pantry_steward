@preconcurrency import AVFoundation
import SwiftUI

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

@MainActor
final class ScannerViewController: UIViewController {
    var onScan: ((String) -> Void)?
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.sously.barcode.capture")
    private var metadataDelegate: MetadataDelegate?
    private var didEmit = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        (view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer)?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else { return }
        captureSession.addOutput(output)

        let delegate = MetadataDelegate { [weak self] value in
            Task { @MainActor in
                self?.handleScan(value)
            }
        }
        metadataDelegate = delegate
        output.setMetadataObjectsDelegate(delegate, queue: sessionQueue)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .qr]

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        sessionQueue.async { [captureSession] in
            captureSession.startRunning()
        }
    }

    private func handleScan(_ value: String) {
        guard !didEmit else { return }
        didEmit = true
        sessionQueue.async { [captureSession] in
            captureSession.stopRunning()
        }
        onScan?(value)
    }
}

/// Delegate runs on the capture queue; hops to the main actor for UI updates.
private final class MetadataDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    private let onCode: @Sendable (String) -> Void

    init(onCode: @escaping @Sendable (String) -> Void) {
        self.onCode = onCode
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        onCode(value)
    }
}
