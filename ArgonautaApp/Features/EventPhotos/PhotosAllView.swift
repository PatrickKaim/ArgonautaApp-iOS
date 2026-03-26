import SwiftUI
import PhotosUI

struct PhotosAllView: View {
    @State private var viewModel = EventPhotosViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var showPreview = false

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.photos.isEmpty {
                LoadingView(message: "Foto's laden...")
            } else if viewModel.photos.isEmpty {
                EmptyStateView(icon: "camera.fill", title: "Nog geen foto's",
                               subtitle: "Deel foto's met andere leden.")
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                    ForEach(viewModel.photos) { photo in
                        NavigationLink(value: HomeRoute.photoDetail(dashboardPhoto(from: photo))) {
                            photoCell(photo)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .background(ArgoTheme.groupedBackground)
        .navigationTitle("Foto's")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    pickedImage = uiImage
                    showPreview = true
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            PhotoPreviewSheet(image: $pickedImage) {
                await viewModel.loadFeed()
            }
        }
        .refreshable { await viewModel.loadFeed() }
        .task { await viewModel.loadFeed() }
    }

    private func photoCell(_ photo: EventPhotosViewModel.Photo) -> some View {
        AsyncImage(url: URL(string: photo.imageUrl)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Rectangle().fill(ArgoTheme.tertiaryFill)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }

    private func dashboardPhoto(from photo: EventPhotosViewModel.Photo) -> DashboardViewModel.Photo {
        DashboardViewModel.Photo(id: photo.id, imageUrl: photo.imageUrl, thumbnailUrl: nil,
                                  caption: photo.caption, authorName: photo.authorName, createdAt: photo.createdAt)
    }
}
