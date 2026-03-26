import SwiftUI

struct MyBlogsView: View {
    @State private var blogs: [MyBlogItem] = []
    @State private var isLoading = false
    @State private var editorItem: BlogEditorItem?

    private let meteor = MeteorService.shared

    var body: some View {
        Group {
            if isLoading && blogs.isEmpty {
                ProgressView("Laden...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if blogs.isEmpty {
                emptyState
            } else {
                blogList
            }
        }
        .background(ArgoTheme.groupedBackground)
        .navigationTitle("Mijn artikelen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorItem = BlogEditorItem(blogId: nil)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(ArgoTheme.font(size: 20))
                        .foregroundStyle(ArgoTheme.interactiveAccent)
                }
            }
        }
        .task { await loadBlogs() }
        .refreshable { await loadBlogs() }
        .sheet(item: $editorItem) { item in
            BlogEditorView(editBlogId: item.blogId) {
                await loadBlogs()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(ArgoTheme.font(size: 40))
                .foregroundStyle(ArgoTheme.iconAccent)
            Text("Nog geen artikelen")
                .font(.argoSubheadline)
                .foregroundStyle(.secondary)
            Button {
                editorItem = BlogEditorItem(blogId: nil)
            } label: {
                Text("Schrijf je eerste artikel")
                    .font(ArgoTheme.font(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ArgoTheme.blueNormal)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var blogList: some View {
        List {
            ForEach(blogs) { blog in
                Button {
                    editorItem = BlogEditorItem(blogId: blog.id)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(blog.title)
                                .font(ArgoTheme.font(size: 15, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(blog.updatedAt, style: .date)
                                .font(ArgoTheme.font(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        statusBadge(blog.status)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        let (label, color) = statusInfo(status)
        Text(label)
            .font(ArgoTheme.font(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }

    private func statusInfo(_ status: String) -> (String, Color) {
        switch status {
        case "draft": ("Concept", .gray)
        case "pending_review": ("In review", .orange)
        case "published": ("Gepubliceerd", .green)
        case "rejected": ("Afgewezen", .red)
        default: (status, .gray)
        }
    }

    private func loadBlogs() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let result = try await meteor.call("blogs.listByAuthor") as? [[String: Any]] else { return }
            blogs = result.compactMap { doc -> MyBlogItem? in
                guard let id = doc["_id"] as? String,
                      let title = doc["headerTitle"] as? String,
                      let status = doc["status"] as? String else { return nil }
                let updatedAt: Date
                if let date = doc["updatedAt"] as? Date {
                    updatedAt = date
                } else if let ts = doc["updatedAt"] as? Double {
                    updatedAt = Date(timeIntervalSince1970: ts / 1000)
                } else {
                    updatedAt = Date()
                }
                return MyBlogItem(id: id, title: title, status: status, updatedAt: updatedAt)
            }
        } catch {
            // Silently fail
        }
    }
}

private struct MyBlogItem: Identifiable {
    let id: String
    let title: String
    let status: String
    let updatedAt: Date
}

private struct BlogEditorItem: Identifiable {
    let id = UUID()
    let blogId: String?
}
