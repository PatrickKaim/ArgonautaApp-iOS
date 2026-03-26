import SwiftUI

struct LoadingView: View {
    var message: String = "Laden..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ArgoTheme.interactiveAccent)
            Text(message)
                .font(.argoBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
