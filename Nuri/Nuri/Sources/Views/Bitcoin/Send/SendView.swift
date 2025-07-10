import SwiftUI
import AVFoundation

struct SendView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation
    @State private var scanError: String? = nil
    @State private var scannedAddress: String? = nil

    private let validator = BitcoinAddressValidator()
    private let lightningValidator = LightningInvoiceValidator()

    var body: some View {
        NavigationStack {
            ZStack {
                QRScannerView { result in
                    switch result {
                    case .success(let code):
                        guard scannedAddress == nil else { return }
                        if validator.isValid(address: code) || lightningValidator.isValid(invoice: code) {
                            scannedAddress = code
                        } else {
                            scanError = "Not a valid Bitcoin address"
                        }
                    case .failure(let err):
                        scanError = err.localizedDescription
                    }
                }
                .ignoresSafeArea()

                // Overlay mask (square window)
                GeometryReader { proxy in
                    Color.black.opacity(0.5)
                        .mask(
                            Rectangle()
                                .overlay(
                                    Rectangle()
                                        .frame(width: proxy.size.width*0.7,
                                               height: proxy.size.width*0.7)
                                        .blendMode(.destinationOut)
                                )
                        )
                        .compositingGroup()
                }
                .ignoresSafeArea()
                VStack {
                    Text("Scan a bitcoin or lightning QR code")
                        .foregroundStyle(Color.white)
                        .padding(.top, 120)
                    Spacer()
                    if let error = scanError {
                        Text(error).foregroundColor(.red)
                    }
                    NavigationLink(destination: SetAmountView(recipientAddress: scannedAddress ?? ""), isActive: Binding(get: { scannedAddress != nil }, set: { _ in })) { EmptyView() }.hidden()
                    Button(action: {
                        if let text = UIPasteboard.general.string, (validator.isValid(address: text) || lightningValidator.isValid(invoice: text)) {
                            scannedAddress = text
                        } else {
                            scanError = "Clipboard does not contain a valid address"
                        }
                    }) {
                        NuriButton(icon: "copy-icon-black", title: "Paste from Clipboard")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                VStack(spacing:0) {
                    NuriHeader<AnyView, AnyView>.logo(title: "Send Bitcoin", onClose: {
                        navigation.isSendViewPresented = false
                    })
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#E0E0E0").opacity(0.9))
                    Spacer()
                }
            }
        }
    }
}

// MARK: - QRScannerView
private struct QRScannerView: UIViewControllerRepresentable {
    enum ScanResult {
        case success(String)
        case failure(Error)
    }

    var onScan: (ScanResult) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}

    final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onScan: ((ScanResult) -> Void)?

        private let session = AVCaptureSession()

        override func viewDidLoad() {
            super.viewDidLoad()
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                onScan?(.failure(NSError(domain: "camera", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera not available"])))
                return
            }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)

            session.startRunning()
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  first.type == .qr,
                  let string = first.stringValue else { return }
            onScan?(.success(string))
        }
    }
}

#Preview {
    Text("Test")
        .sheet(isPresented: .constant(true)) {
            SendView()
        }
}
