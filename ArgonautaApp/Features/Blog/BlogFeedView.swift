import SwiftUI

struct BlogFeedView: View {
    @State private var viewModel = BlogViewModel()

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                LoadingView(message: "Nieuws laden...")
            } else if viewModel.posts.isEmpty {
                EmptyStateView(icon: "newspaper", title: "Geen berichten")
            } else {
                ForEach(viewModel.posts) { post in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(post.title).font(.argoSubheadline).lineLimit(2)
                        if let date = post.publishedAt {
                            Text(date.shortDateString).font(.argoCaption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Nieuws")
        .refreshable { await viewModel.loadPosts() }
        .task { await viewModel.loadPosts() }
    }
}
