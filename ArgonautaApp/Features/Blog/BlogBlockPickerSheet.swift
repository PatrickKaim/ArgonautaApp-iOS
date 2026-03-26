import SwiftUI

struct BlogBlockPickerSheet: View {
    var onSelect: (BlogBlockType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(BlogBlockType.allCases) { blockType in
                    Button {
                        onSelect(blockType)
                        dismiss()
                    } label: {
                        Label {
                            Text(blockType.label)
                                .font(ArgoTheme.font(size: 16))
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: blockType.icon)
                                .font(ArgoTheme.font(size: 18))
                                .foregroundStyle(ArgoTheme.interactiveAccent)
                                .frame(width: 32)
                        }
                    }
                }
            }
            .navigationTitle("Blok toevoegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Annuleer") { dismiss() }
                        .font(ArgoTheme.font(size: 15))
                }
            }
        }
        .presentationDetents([.medium])
    }
}
