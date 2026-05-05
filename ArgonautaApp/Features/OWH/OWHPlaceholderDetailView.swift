import SwiftUI

/// Tijdelijk scherm tot competities/uitslagen inhoud krijgen.
struct OWHPlaceholderDetailView: View {
    let title: String
    let message: String

    var body: some View {
        ScrollView {
            Text(message)
                .font(ArgoTheme.font(size: 15))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(ArgoTheme.groupedBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
