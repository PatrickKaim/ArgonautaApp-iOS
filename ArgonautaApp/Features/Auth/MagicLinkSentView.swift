import SwiftUI

struct MagicLinkSentView: View {
    @Environment(AppState.self) private var appState
    let email: String
    let challengeId: String
    let onBack: () -> Void
    let onResend: () -> Void

    @State private var pollingTask: Task<Void, Never>?
    @State private var isPolling = true
    @State private var isExpired = false
    @State private var isResending = false
    @State private var dots = ""

    private let expirySeconds = 15 * 60

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "envelope.open.fill")
                .font(ArgoTheme.font(size: 64))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                Text("Check je e-mail")
                    .font(.argoTitle)
                    .foregroundStyle(.white)

                Text("We hebben een inloglink gestuurd naar\n\(email)")
                    .font(.argoSubheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            if isExpired {
                VStack(spacing: 12) {
                    Text("De link is verlopen")
                        .font(.argoSubheadline)
                        .foregroundStyle(.white.opacity(0.8))

                    Button {
                        isResending = true
                        onResend()
                        isExpired = false
                        isPolling = true
                        startPolling()
                        isResending = false
                    } label: {
                        if isResending {
                            ProgressView().tint(ArgoTheme.interactiveAccent)
                        } else {
                            Text("Opnieuw versturen")
                                .font(.argoHeadline)
                                .foregroundStyle(ArgoTheme.interactiveAccent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ArgoTheme.adaptiveSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("Wachten op verificatie\(dots)")
                        .font(.argoCaption)
                        .foregroundStyle(.white.opacity(0.6))
                    if let err = appState.lastMagicLinkError, !err.isEmpty {
                        Text(err)
                            .font(.argoCaption)
                            .foregroundStyle(.red.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        Text("Tip: open de link in Safari als het opnieuw misgaat — dan wordt de server wel eerst aangeroepen.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }

            Spacer()

            Button {
                pollingTask?.cancel()
                onBack()
            } label: {
                Text("Terug naar inloggen")
                    .font(.argoSubheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.bottom, 40)
        }
        .onAppear { startPolling() }
        .onDisappear { pollingTask?.cancel() }
        .task { await animateDots() }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            let startTime = Date()
            while !Task.isCancelled {
                if Date().timeIntervalSince(startTime) > Double(expirySeconds) {
                    isPolling = false
                    isExpired = true
                    return
                }
                do {
                    let status = try await appState.checkLoginChallenge(challengeId: challengeId)
                    if status == .completed {
                        return
                    } else if status == .expired {
                        isPolling = false
                        isExpired = true
                        return
                    }
                } catch {}
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func animateDots() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            dots = dots.count >= 3 ? "" : dots + "."
        }
    }
}
