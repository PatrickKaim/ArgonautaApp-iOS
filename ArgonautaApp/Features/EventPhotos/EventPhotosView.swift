import SwiftUI
import PhotosUI

struct EventPhotosView: View {
    @State private var viewModel = EventPhotosViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var caption = ""

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.photos.isEmpty {
                LoadingView(message: "Foto's laden...")
            } else if viewModel.photos.isEmpty {
                EmptyStateView(icon: "camera.fill", title: "Nog geen foto's", subtitle: "Deel foto's bij evenementen met andere leden.")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                    ForEach(viewModel.photos) { photo in
                        AsyncImage(url: URL(string: photo.imageUrl)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(ArgoTheme.tertiaryFill)
                        }
                        .frame(minHeight: 120)
                        .clipped()
                    }
                }
            }
        }
        .background(ArgoTheme.groupedBackground)
        .navigationTitle("Foto's")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                    await viewModel.upload(imageData: data, caption: "")
                }
            }
        }
        .refreshable { await viewModel.loadFeed() }
        .task { await viewModel.loadFeed() }
    }
}
