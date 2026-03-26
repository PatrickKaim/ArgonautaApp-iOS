import SwiftUI
import PhotosUI

struct BlogEditorView: View {
    var editBlogId: String?
    var onDismiss: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = BlogEditorViewModel()
    @State private var showBlockPicker = false
    @State private var insertIndex: Int?
    @State private var showPublishSheet = false
    @State private var showImageSourcePicker = false
    @State private var imageBlockIndex: Int?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var showSaveConfirmation = false
    @State private var showHeaderImageSource = false
    @State private var showHeaderCamera = false
    @State private var showHeaderPhotoPicker = false
    @State private var headerPhotoItem: PhotosPickerItem?
    @State private var headerCapturedImage: UIImage?

    private enum ImageTarget { case header, block }

    private var titleEmpty: Bool {
        viewModel.headerTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var showErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerImageSection
                    titleSection
                    addBlockButton(at: -1)
                    blocksSection
                }
                .padding(.bottom, 40)
            }
            .background(ArgoTheme.groupedBackground)
            .navigationTitle(editBlogId != nil ? "Bewerken" : "Nieuw artikel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuleer") { dismiss() }
                        .font(ArgoTheme.font(size: 15))
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !viewModel.isPublished {
                        Button {
                            Task {
                                await viewModel.save()
                                showSaveConfirmation = true
                            }
                        } label: {
                            Text("Opslaan")
                                .font(ArgoTheme.font(size: 15))
                        }
                        .disabled(titleEmpty || viewModel.isSaving)
                    }

                    if viewModel.isPublished {
                        Button {
                            Task {
                                let success = await viewModel.updatePublished()
                                if success {
                                    await onDismiss?()
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("Bijwerken")
                                .font(ArgoTheme.font(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(ArgoTheme.blueNormal)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(titleEmpty || viewModel.isSaving)
                    } else {
                        Button {
                            showPublishSheet = true
                        } label: {
                            Text("Plaatsen")
                                .font(ArgoTheme.font(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(ArgoTheme.blueNormal)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(titleEmpty || viewModel.isSaving)
                    }
                }
            }
            .task {
                if let editBlogId {
                    await viewModel.loadBlog(id: editBlogId)
                }
            }
            .sheet(isPresented: $showBlockPicker) {
                BlogBlockPickerSheet { blockType in
                    if blockType == .image {
                        let idx = insertIndex
                        viewModel.addBlock(.image, at: idx)
                        let newIndex = (idx != nil) ? (idx! + 1) : viewModel.blocks.count - 1
                        imageBlockIndex = newIndex
                        showImageSourcePicker = true
                    } else {
                        viewModel.addBlock(blockType, at: insertIndex)
                    }
                }
            }
            .sheet(isPresented: $showPublishSheet) {
                BlogPublishSheet(
                    isPresented: $showPublishSheet,
                    canPublishDirectly: viewModel.canPublishDirectly,
                    isPublishing: viewModel.isPublishing
                ) { visibility in
                    let success = await viewModel.publish(visibility: visibility)
                    if success {
                        await onDismiss?()
                        dismiss()
                    }
                    return success
                }
            }
            .confirmationDialog("Foto toevoegen", isPresented: $showImageSourcePicker) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Camera") { showCamera = true }
                }
                Button("Fotobibliotheek") { showPhotoPicker = true }
                Button("Annuleer", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePickerView(image: $capturedImage, sourceType: .camera)
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: capturedImage) { _, newImage in
                if let newImage, let idx = imageBlockIndex, viewModel.blocks.indices.contains(idx) {
                    viewModel.blocks[idx].localImage = newImage
                    capturedImage = nil
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data),
                       let idx = imageBlockIndex, viewModel.blocks.indices.contains(idx) {
                        viewModel.blocks[idx].localImage = uiImage
                    }
                    selectedPhotoItem = nil
                }
            }
            .confirmationDialog("Header afbeelding", isPresented: $showHeaderImageSource) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Camera") { showHeaderCamera = true }
                }
                Button("Fotobibliotheek") { showHeaderPhotoPicker = true }
                Button("Annuleer", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showHeaderCamera) {
                ImagePickerView(image: $headerCapturedImage, sourceType: .camera)
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showHeaderPhotoPicker, selection: $headerPhotoItem, matching: .images)
            .onChange(of: headerCapturedImage) { _, newImage in
                if let newImage {
                    viewModel.headerImage = newImage
                    viewModel.headerImageMediaId = nil
                    headerCapturedImage = nil
                    Task { await viewModel.uploadHeaderImage(newImage) }
                }
            }
            .onChange(of: headerPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        viewModel.headerImage = uiImage
                        viewModel.headerImageMediaId = nil
                        await viewModel.uploadHeaderImage(uiImage)
                    }
                    headerPhotoItem = nil
                }
            }
            .alert("Opgeslagen", isPresented: $showSaveConfirmation) {
                Button("OK") {}
            } message: {
                Text("Je concept is opgeslagen.")
            }
            .alert("Fout", isPresented: showErrorBinding) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .overlay {
                if viewModel.isSaving || viewModel.isPublishing {
                    ArgoTheme.scrimLight
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView(viewModel.isPublishing ? "Publiceren..." : "Opslaan...")
                                .padding(20)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                }
            }
        }
    }

    // MARK: - Header Image

    private var headerImageSection: some View {
        Button { showHeaderImageSource = true } label: {
            ZStack {
                if let localImage = viewModel.headerImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                } else if let urlStr = viewModel.headerImageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            headerImagePlaceholder
                        }
                    }
                    .frame(height: 200)
                    .clipped()
                } else {
                    headerImagePlaceholder
                }

                if viewModel.isUploadingHeaderImage {
                    Color.black.opacity(0.45)
                    ProgressView()
                        .tint(.white)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: viewModel.headerImage != nil || viewModel.headerImageUrl != nil
                              ? "pencil.circle.fill" : "photo.badge.plus")
                            .font(ArgoTheme.font(size: 24))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                            .padding(12)
                    }
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 0))
        }
        .buttonStyle(.plain)
    }

    private var headerImagePlaceholder: some View {
        Rectangle()
            .fill(ArgoTheme.tertiaryFill)
            .frame(height: 200)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(ArgoTheme.font(size: 32))
                        .foregroundStyle(ArgoTheme.iconAccent)
                    Text("Header afbeelding toevoegen")
                        .font(ArgoTheme.font(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
    }

    // MARK: - Title

    private var titleSection: some View {
        TextField("Geef je artikel een titel...", text: $viewModel.headerTitle, axis: .vertical)
            .font(ArgoTheme.font(size: 22, weight: .bold))
            .foregroundStyle(ArgoTheme.editorTitle)
            .lineLimit(1...4)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    // MARK: - Blocks

    private var blocksSection: some View {
        ForEach(viewModel.blocks) { block in
            VStack(spacing: 0) {
                if let idx = viewModel.blocks.firstIndex(where: { $0.id == block.id }) {
                    BlockWrapperView(
                        block: Binding(
                            get: { viewModel.blocks.first(where: { $0.id == block.id }) ?? block },
                            set: { newValue in
                                if let i = viewModel.blocks.firstIndex(where: { $0.id == block.id }) {
                                    viewModel.blocks[i] = newValue
                                }
                            }
                        ),
                        onDelete: {
                            withAnimation {
                                viewModel.blocks.removeAll(where: { $0.id == block.id })
                            }
                        },
                        onPickImage: {
                            if let i = viewModel.blocks.firstIndex(where: { $0.id == block.id }) {
                                imageBlockIndex = i
                                showImageSourcePicker = true
                            }
                        }
                    )
                    .padding(.horizontal, 12)

                    addBlockButton(at: idx)
                }
            }
        }
    }

    // MARK: - Add Block Button

    private func addBlockButton(at index: Int) -> some View {
        Button {
            insertIndex = index < 0 ? nil : index
            showBlockPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(ArgoTheme.font(size: 16))
                Text("Blok toevoegen")
                    .font(ArgoTheme.font(size: 13))
            }
            .foregroundStyle(ArgoTheme.interactiveAccent.opacity(0.85))
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
