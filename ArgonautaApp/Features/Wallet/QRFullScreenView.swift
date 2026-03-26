import SwiftUI

struct QRFullScreenView: View {
    let cardCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var previousBrightness: CGFloat = 0.5

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                QRCodeView(code: cardCode, size: 280)
                Text("Scan bij de bar").font(.argoHeadline).foregroundStyle(ArgoTheme.interactiveAccent)
                Text(cardCode).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()

                Button { dismiss() } label: {
                    Text("Sluiten").font(.argoSubheadline).foregroundStyle(.white)
                        .padding(.horizontal, 40).padding(.vertical, 12)
                        .background(ArgoTheme.blueNormal)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            let screen = currentScreen
            previousBrightness = screen?.brightness ?? 0.5
            screen?.brightness = 1.0
        }
        .onDisappear {
            currentScreen?.brightness = previousBrightness
        }
    }

    private var currentScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
    }
}
