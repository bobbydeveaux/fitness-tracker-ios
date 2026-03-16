import SwiftUI
import AVFoundation

// MARK: - BarcodeScannerView

/// A full-screen camera preview that detects EAN-13, EAN-8, UPC-A, and
/// QR-code barcodes using `AVCaptureSession`.
///
/// Calls `onBarcodeDetected` once with the first recognised code string and
/// then deactivates the session to prevent duplicate callbacks.
///
/// `onError` is called if camera access is denied or the device has no
/// suitable capture device (e.g. on simulator).
struct BarcodeScannerView: View {

    let onBarcodeDetected: (String) -> Void
    let onError: (String) -> Void

    var body: some View {
        BarcodeScannerRepresentable(
            onBarcodeDetected: onBarcodeDetected,
            onError: onError
        )
        .ignoresSafeArea()
        .overlay(alignment: .center) {
            // Viewfinder overlay
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 240, height: 160)
        }
        .overlay(alignment: .top) {
            Text("Align barcode within the frame")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.black.opacity(0.5), in: Capsule())
                .padding(.top, 60)
        }
    }
}

// MARK: - BarcodeScannerRepresentable

private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {

    let onBarcodeDetected: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let vc = BarcodeScannerViewController()
        vc.onBarcodeDetected = onBarcodeDetected
        vc.onError = onError
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}
}

// MARK: - BarcodeScannerViewController

private final class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var onBarcodeDetected: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didDetect = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    // MARK: - Setup

    private func setupSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureCaptureSession()
                    } else {
                        self?.onError?("Camera access denied. Please allow camera access in Settings.")
                    }
                }
            }
        default:
            onError?("Camera access denied. Please allow camera access in Settings.")
        }
    }

    private func configureCaptureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            onError?("No camera available on this device.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard captureSession.canAddInput(input) else { return }
            captureSession.addInput(input)

            let metadataOutput = AVCaptureMetadataOutput()
            guard captureSession.canAddOutput(metadataOutput) else { return }
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce, .qr, .code128]

            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.insertSublayer(previewLayer, at: 0)
            self.previewLayer = previewLayer

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        } catch {
            onError?("Failed to configure camera: \(error.localizedDescription)")
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didDetect else { return }
        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = metadata.stringValue else { return }

        didDetect = true
        captureSession.stopRunning()
        onBarcodeDetected?(value)
    }
}
