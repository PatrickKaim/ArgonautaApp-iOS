import SwiftUI

/// Geen werkende DDP-verbinding: informeer de gebruiker en bied de publieke website als alternatief.
struct NetworkUnsupportedView: View {
    @Environment(\.openURL) private var openURL

    private static let publicWebsite = URL(string: "https://argonauta.nl")!

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(ArgoTheme.font(size: 56))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                Text("Geen verbinding met de server")
                    .font(.argoTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Dit netwerk of apparaat ondersteunt het gebruik van deze app niet. Je kunt Argonauta wel via de website gebruiken.")
                    .font(.argoSubheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button {
                openURL(Self.publicWebsite)
            } label: {
                Text("Open website")
                    .font(.argoHeadline)
                    .foregroundStyle(ArgoTheme.interactiveAccent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ArgoTheme.adaptiveSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ArgoTheme.adaptiveBorder, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()
        }
    }
}

#Preview {
    ZStack {
        ArgoTheme.blueNormal.ignoresSafeArea()
        NetworkUnsupportedView()
    }
}
