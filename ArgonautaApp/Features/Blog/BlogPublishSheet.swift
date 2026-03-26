import SwiftUI

struct BlogPublishSheet: View {
    @Binding var isPresented: Bool
    let canPublishDirectly: Bool
    let isPublishing: Bool
    var onPublish: (BlogVisibility) async -> Bool

    @State private var visibility: BlogVisibility = .publicAccess

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Zichtbaarheid")
                        .font(ArgoTheme.font(size: 16, weight: .bold))

                    Picker("Zichtbaarheid", selection: $visibility) {
                        Text("Publiek").tag(BlogVisibility.publicAccess)
                        Text("Alleen leden").tag(BlogVisibility.membersOnly)
                    }
                    .pickerStyle(.segmented)
                }

                if !canPublishDirectly {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(ArgoTheme.interactiveAccent)
                        Text("Je artikel wordt beoordeeld door een moderator voordat het gepubliceerd wordt.")
                            .font(ArgoTheme.font(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(ArgoTheme.tertiaryFill)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Spacer()

                Button {
                    Task {
                        let success = await onPublish(visibility)
                        if success { isPresented = false }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isPublishing {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(canPublishDirectly ? "Nu publiceren" : "Indienen ter review")
                            .font(ArgoTheme.font(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ArgoTheme.blueNormal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isPublishing)
            }
            .padding(20)
            .navigationTitle("Publiceren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Annuleer") { isPresented = false }
                        .font(ArgoTheme.font(size: 15))
                }
            }
        }
        .presentationDetents([.medium])
    }
}
