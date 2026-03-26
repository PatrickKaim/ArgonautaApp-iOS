import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMagicLinkSent = false
    @State private var challengeId: String?

    var body: some View {
        ZStack {
            ArgoTheme.blueNormal.ignoresSafeArea()

            if showMagicLinkSent, let challengeId {
                MagicLinkSentView(
                    email: email,
                    challengeId: challengeId,
                    onBack: { showMagicLinkSent = false },
                    onResend: { Task { await sendMagicLink() } }
                )
                .transition(.move(edge: .trailing))
            } else {
                loginForm
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showMagicLinkSent)
    }

    private var loginForm: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 60)
                ArgoLogo(size: 100)

                Text("Argonauta")
                    .font(.argoTitle)
                    .foregroundStyle(.white)

                VStack(spacing: 16) {
                    TextField("", text: $email, prompt: Text("E-mailadres").foregroundStyle(.secondary))
                        .font(.argoBody)
                        .foregroundStyle(.primary)
                        .tint(ArgoTheme.interactiveAccent)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(ArgoTheme.adaptiveSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ArgoTheme.adaptiveBorder, lineWidth: 1)
                        )
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.argoCaption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    Button {
                        Task { await sendMagicLink() }
                    } label: {
                        if isLoading {
                            ProgressView().tint(ArgoTheme.interactiveAccent)
                        } else {
                            Text("Stuur magic link")
                                .font(.argoHeadline)
                                .foregroundStyle(ArgoTheme.interactiveAccent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ArgoTheme.adaptiveSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ArgoTheme.adaptiveBorder, lineWidth: 1)
                    )
                    .disabled(isLoading || email.isEmpty)
                    .opacity(email.isEmpty ? 0.6 : 1)

                    Text("We sturen een inloglink naar je e-mail.\nGeen wachtwoord nodig.")
                        .font(.argoCaption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func sendMagicLink() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await appState.sendMagicLink(email: email)
            challengeId = result
            showMagicLinkSent = true
        } catch {
            errorMessage = "Versturen mislukt: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
