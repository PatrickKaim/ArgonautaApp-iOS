import SwiftUI

/// Fallback: 8-cijferige code uit e-mail (als Universal Link / magic link faalt).
struct EmailCodeLoginView: View {
    @Environment(AppState.self) private var appState
    let email: String
    let onBack: () -> Void

    @State private var code = ""
    @State private var isRequestingCode = false
    @State private var isVerifying = false
    @State private var infoMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                Image(systemName: "number.circle.fill")
                    .font(ArgoTheme.font(size: 56))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    Text("Code uit e-mail")
                        .font(.argoTitle)
                        .foregroundStyle(.white)

                    Text("Vraag een code aan. Je ontvangt een mail met 8 cijfers. Plak die hier en tik op Verifiëren.")
                        .font(.argoSubheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                Text(email)
                    .font(.argoCaption)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)

                Button {
                    Task { await requestCode() }
                } label: {
                    if isRequestingCode {
                        ProgressView().tint(ArgoTheme.interactiveAccent)
                    } else {
                        Text("Code aanvragen")
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
                .disabled(isRequestingCode || isVerifying)
                .padding(.horizontal, 32)

                TextField("", text: $code, prompt: Text("8 cijfers").foregroundStyle(.secondary))
                    .font(.argoBody.monospacedDigit())
                    .foregroundStyle(.primary)
                    .tint(ArgoTheme.interactiveAccent)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding(14)
                    .background(ArgoTheme.adaptiveSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ArgoTheme.adaptiveBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 32)
                    .onChange(of: code) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits.count > 8 {
                            code = String(digits.prefix(8))
                        } else if digits != newValue {
                            code = digits
                        }
                    }

                if let infoMessage {
                    Text(infoMessage)
                        .font(.argoCaption)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.argoCaption)
                        .foregroundStyle(.red.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    Task { await verify() }
                } label: {
                    if isVerifying {
                        ProgressView().tint(ArgoTheme.interactiveAccent)
                    } else {
                        Text("Verifiëren")
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
                .disabled(isVerifying || isRequestingCode || code.count != 8)
                .opacity(code.count == 8 ? 1 : 0.55)
                .padding(.horizontal, 32)

                Button {
                    onBack()
                } label: {
                    Text("Terug")
                        .font(.argoSubheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func requestCode() async {
        isRequestingCode = true
        errorMessage = nil
        infoMessage = nil
        defer { isRequestingCode = false }
        do {
            try await appState.requestEmailLoginCode(email: email)
            infoMessage = "Als dit adres bij ons bekend is, is er zojuist een code gestuurd. Controleer je inbox."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func verify() async {
        isVerifying = true
        errorMessage = nil
        defer { isVerifying = false }
        do {
            try await appState.verifyEmailLoginCode(email: email, code: code)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
