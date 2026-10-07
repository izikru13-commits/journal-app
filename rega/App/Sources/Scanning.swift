import AVFoundation
import CoreNFC
import SwiftUI
import UIKit
import VisionKit

/// Full-screen QR scanner: VisionKit when supported, AVFoundation otherwise.
struct ScanKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCode: (String) -> Void
    @State private var handled = false

    init(onCode: @escaping (String) -> Void) {
        self.onCode = onCode
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            scanner.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("כוון את המצלמה אל קוד המפתח")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                Button("ביטול") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder private var scanner: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            DataScannerView(onCode: deliver)
        } else {
            AVScannerView(onCode: deliver)
        }
    }

    private func deliver(_ code: String) {
        guard !handled else { return }
        handled = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onCode(code)
    }
}

struct DataScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        if !controller.isScanning {
            try? controller.startScanning()
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case let .barcode(barcode) = item, let value = barcode.payloadStringValue {
                    onCode(value)
                    return
                }
            }
        }
    }
}

struct AVScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> AVScannerController {
        let controller = AVScannerController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ controller: AVScannerController, context: Context) {}
}

final class AVScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        preview = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let session = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = session
        DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        onCode?(code)
    }
}

/// Reads the UID of an NFC tag (NTAG stickers, MIFARE, ISO 15693 …) as a hex string.
final class NFCKeyReader: NSObject, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession?
    private var completion: ((Result<String, Error>) -> Void)?
    private var delivered = false

    enum ReaderError: Error {
        case unavailable
        case unreadable
    }

    static var isAvailable: Bool { NFCTagReaderSession.readingAvailable }

    func scan(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard Self.isAvailable, let session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil) else {
            completion(.failure(ReaderError.unavailable))
            return
        }
        self.completion = completion
        delivered = false
        self.session = session
        session.alertMessage = prompt
        session.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        deliver(.failure(error))
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { [weak self] error in
            guard error == nil, let id = Self.identifier(of: tag) else {
                session.invalidate(errorMessage: String(localized: "לא הצלחתי לקרוא את התג."))
                self?.deliver(.failure(ReaderError.unreadable))
                return
            }
            session.alertMessage = String(localized: "נקרא ✓")
            session.invalidate()
            self?.deliver(.success(KeyCodec.hex(id)))
        }
    }

    private static func identifier(of tag: NFCTag) -> Data? {
        switch tag {
        case let .miFare(t): return t.identifier
        case let .iso7816(t): return t.identifier
        case let .iso15693(t): return t.identifier
        case let .feliCa(t): return t.currentIDm
        @unknown default: return nil
        }
    }

    private func deliver(_ result: Result<String, Error>) {
        DispatchQueue.main.async {
            guard !self.delivered else { return }
            self.delivered = true
            self.completion?(result)
            self.completion = nil
            self.session = nil
        }
    }
}
