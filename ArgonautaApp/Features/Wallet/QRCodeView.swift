import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let code: String
    var size: CGFloat = 200

    var body: some View {
        if let image = generateQRCode(from: code) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: "qrcode")
                .font(ArgoTheme.font(size: size * 0.5))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }

    nonisolated private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }
        let scale = (size * 3) / ciImage.extent.width
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
