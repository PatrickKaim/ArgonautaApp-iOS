import SwiftUI
import PhotosUI
import UIKit

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EventPhotosViewModel()
    @State private var capturedImage: UIImage?
    @State private var caption = ""
    @State private var showImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false

    var onUploadComplete: (() async -> Void)?

    private var hasCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let image = capturedImage {
                    previewPhase(image)
                } else {
                    Color.clear
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
        .onAppear { openCapture() }
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePickerView(image: $capturedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoFallbackPicker(image: $capturedImage)
        }
        .onChange(of: showImagePicker) { _, isShowing in
            if !isShowing && capturedImage == nil { dismiss() }
        }
        .onChange(of: showPhotoPicker) { _, isShowing in
            if !isShowing && capturedImage == nil { dismiss() }
        }
    }

    private func openCapture() {
        if hasCamera {
            showImagePicker = true
        } else {
            showPhotoPicker = true
        }
    }

    // MARK: - Preview

    private func previewPhase(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
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

            HStack(spacing: 16) {
                Button {
                    capturedImage = nil
                    caption = ""
                    openCapture()
                } label: {
                    Text("Opnieuw")
                        .font(ArgoTheme.font(size: 15, weight: .semibold))
                        .foregroundStyle(ArgoTheme.interactiveAccent)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(ArgoTheme.tertiaryFill)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(viewModel.isUploading)

                Button {
                    Task { await uploadAndDismiss(image) }
                } label: {
                    Text("Plaatsen")
                        .font(ArgoTheme.font(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(ArgoTheme.blueNormal)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(viewModel.isUploading)
            }
            .padding(.bottom, 24)
        }
        .padding(.top, 8)
    }

    private func uploadAndDismiss(_ image: UIImage) async {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else { return }
        await viewModel.upload(imageData: jpegData, caption: caption)
        if viewModel.uploadError == nil {
            await onUploadComplete?()
            dismiss()
        }
    }
}

// MARK: - UIImagePickerController Wrapper

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Simulator fallback: PhotosPicker in een sheet

struct PhotoFallbackPicker: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(ArgoTheme.font(size: 56))
                        .foregroundStyle(ArgoTheme.interactiveAccent)
                    Text("Kies een foto")
                        .font(.argoSubheadline)
                        .foregroundStyle(ArgoTheme.interactiveAccent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Foto kiezen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuleren") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        image = uiImage
                        dismiss()
                    }
                }
            }
        }
    }
}
