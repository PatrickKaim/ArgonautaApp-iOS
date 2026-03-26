import Foundation
import Observation
import MeteorDDPKit

@Observable
final class DashboardViewModel {
    var announcements: [Announcement] = []
    var recentPhotos: [Photo] = []
    var recentPosts: [BlogPost] = []
    var isLoading = false

    private let meteor = MeteorService.shared
    private var photoSub: DDPSubscription?
    private var blogSub: DDPSubscription?
    private var blogObserveTask: Task<Void, Never>?

    struct Announcement: Identifiable {
        let id: String
        let text: String
    }

    struct Photo: Identifiable, Hashable {
        let id: String
        let imageUrl: String
        let thumbnailUrl: String?
        let caption: String?
        let authorName: String?
        let createdAt: Date
    }

    struct BlogPost: Identifiable, Hashable {
        let id: String
        let title: String
        let imageUrl: String?
        let authorName: String?
        let publishedAt: Date?
    }

    func loadData() async {
        isLoading = true
        async let a: () = loadAnnouncements()
        async let p: () = loadPhotos()
        async let b: () = loadBlogPosts()
        _ = await (a, p, b)
        isLoading = false
    }

    private func loadAnnouncements() async {
        guard let result = try? await meteor.call("displayAnnouncements.getActive") as? [[String: Any]] else { return }
        announcements = result.compactMap { doc in
            guard let id = doc["_id"] as? String, let text = doc["text"] as? String else { return nil }
            return Announcement(id: id, text: text)
        }
    }

    private func loadPhotos() async {
        photoSub = try? await meteor.subscribe("eventPhotos.feed", params: [9])
        try? await photoSub?.waitUntilReady()

        guard let col = meteor.collection("event_photos") else { return }
        recentPhotos = Array(col.documents.values).compactMap { doc -> Photo? in
            guard let id = doc["_id"] as? String, let rawUrl = doc["imageUrl"] as? String,
                  let imageUrl = URLResolver.resolve(rawUrl),
                  let createdAt = doc["createdAt"] as? Date else { return nil }
            return Photo(id: id, imageUrl: imageUrl,
                         thumbnailUrl: URLResolver.resolve(doc["thumbnailUrl"] as? String),
                         caption: doc["caption"] as? String,
                         authorName: doc["authorName"] as? String, createdAt: createdAt)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private func loadBlogPosts() async {
        blogSub = try? await meteor.subscribe("blogs.published", params: [3])
        try? await blogSub?.waitUntilReady()

        await fetchBlogPosts()
        startBlogObserving()
    }

    private func fetchBlogPosts() async {
        guard let result = try? await meteor.call("blogs.listPublic", params: [3]) as? [[String: Any]] else { return }
        recentPosts = result.compactMap { doc -> BlogPost? in
            guard let id = doc["_id"] as? String, let title = doc["headerTitle"] as? String else { return nil }
            let rawUrl = doc["headerImageSquare"] as? String ?? doc["headerImageUrl"] as? String
            return BlogPost(id: id, title: title, imageUrl: URLResolver.resolve(rawUrl),
                            authorName: (doc["author"] as? [String: Any])?["name"] as? String,
                            publishedAt: doc["publishedAt"] as? Date)
        }
    }

    private func startBlogObserving() {
        blogObserveTask?.cancel()
        guard let col = meteor.collection("blogs") else { return }
        blogObserveTask = Task { [weak self] in
            for await _ in col.events {
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .milliseconds(300))
                await self?.fetchBlogPosts()
            }
        }
    }
}
