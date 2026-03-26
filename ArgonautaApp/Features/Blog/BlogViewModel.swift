import Foundation
import Observation
import MeteorDDPKit

@Observable
final class BlogViewModel {
    var posts: [BlogPost] = []
    var isLoading = false

    private let meteor = MeteorService.shared
    private var blogSub: DDPSubscription?
    private var observeTask: Task<Void, Never>?

    struct BlogPost: Identifiable {
        let id: String
        let title: String
        let imageUrl: String?
        let authorName: String?
        let publishedAt: Date?
    }

    func loadPosts() async {
        isLoading = true
        blogSub = try? await meteor.subscribe("blogs.published", params: [50])
        try? await blogSub?.waitUntilReady()
        await fetchPosts()
        startObserving()
        isLoading = false
    }

    private func fetchPosts() async {
        guard let result = try? await meteor.call("blogs.listPublic", params: [50]) as? [[String: Any]] else { return }
        posts = result.compactMap { doc -> BlogPost? in
            guard let id = doc["_id"] as? String, let title = doc["headerTitle"] as? String else { return nil }
            let rawUrl = doc["headerImageSquare"] as? String ?? doc["headerImageUrl"] as? String
            return BlogPost(id: id, title: title, imageUrl: URLResolver.resolve(rawUrl),
                            authorName: (doc["author"] as? [String: Any])?["name"] as? String,
                            publishedAt: doc["publishedAt"] as? Date)
        }
    }

    private func startObserving() {
        observeTask?.cancel()
        guard let col = meteor.collection("blogs") else { return }
        observeTask = Task { [weak self] in
            for await _ in col.events {
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .milliseconds(300))
                await self?.fetchPosts()
            }
        }
    }
}
