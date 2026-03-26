import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(ArgoTheme.font(size: 48))
                .foregroundStyle(ArgoTheme.iconAccent)
            Text(title)
                .font(.argoHeadline)
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.argoBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
