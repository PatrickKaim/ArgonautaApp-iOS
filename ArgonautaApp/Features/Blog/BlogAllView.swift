import SwiftUI

struct BlogAllView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = BlogViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                LoadingView(message: "Blog laden...")
            } else if viewModel.posts.isEmpty {
                EmptyStateView(icon: "newspaper", title: "Geen artikelen")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.posts) { post in
                        NavigationLink(value: HomeRoute.blogDetail(post.id)) {
                            BlogCard(title: post.title, imageUrl: post.imageUrl,
                                     authorName: post.authorName, publishedAt: post.publishedAt)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .background(ArgoTheme.groupedBackground)
        .navigationTitle("Blog")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await viewModel.loadPosts() }
        .task { await viewModel.loadPosts() }
    }
}
