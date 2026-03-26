import SwiftUI

struct PhotoPreviewSheet: View {
    @Binding var image: UIImage?
    var onUploadComplete: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EventPhotosViewModel()
    @State private var caption = ""

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    previewContent(image)
                } else {
                    Color.clear
                        .onAppear { dismiss() }
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuleren") { dismiss() }
                }
            }
        }
    }

    private func previewContent(_ uiImage: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

            TextField("Schrijf een bijschrift...", text: $caption, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)

            if viewModel.isUploading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Uploaden...")
                        .font(.argoBody)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = viewModel.uploadError {
                Text(error)
                    .font(.argoCaption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }

            Spacer()

            Button {
                Task { await uploadAndDismiss(uiImage) }
            } label: {
                Text("Plaatsen")
                    .font(ArgoTheme.font(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ArgoTheme.blueNormal)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.isUploading)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .padding(.top, 8)
    }

    private func uploadAndDismiss(_ uiImage: UIImage) async {
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.8) else { return }
        await viewModel.upload(imageData: jpegData, caption: caption)
        if viewModel.uploadError == nil {
            await onUploadComplete?()
            dismiss()
        }
    }
}
