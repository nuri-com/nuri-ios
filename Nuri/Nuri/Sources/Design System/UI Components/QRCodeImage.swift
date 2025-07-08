import SwiftUI
import CoreImage.CIFilterBuiltins

public struct QRCodeImage: View {
    private let text: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        if let uiImage = generateQRCode() {
            Image(uiImage: uiImage)
                .interpolation(.none)
                .resizable()
        } else {
            Color.gray // fallback
        }
    }

    private func generateQRCode() -> UIImage? {
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        if let outputImage = filter.outputImage {
            let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            if let cgimg = context.createCGImage(scaled, from: scaled.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }
}

#if DEBUG
#Preview {
    QRCodeImage(text: "https://example.com")
        .frame(width: 150, height: 150)
        .previewLayout(.sizeThatFits)
}
#endif 