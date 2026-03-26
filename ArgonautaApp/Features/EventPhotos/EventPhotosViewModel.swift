import Foundation
import Observation
import MeteorDDPKit

@Observable
final class EventPhotosViewModel {
    var photos: [Photo] = []
    var isLoading = false
    var isUploading = false
    var uploadError: String?

    private let meteor = MeteorService.shared
    private var feedSub: DDPSubscription?

    struct Photo: Identifiable {
        let id: String
        let imageUrl: String
        let caption: String?
        let authorName: String?
        let createdAt: Date
    }

    func loadFeed() async {
        isLoading = true
        feedSub = try? await meteor.subscribe("eventPhotos.feed", params: [50])
        try? await feedSub?.waitUntilReady()
        syncFromCollections()
        isLoading = false
    }

    func upload(imageData: Data, caption: String) async {
        isUploading = true
        uploadError = nil
        let base64 = imageData.base64EncodedString()
        do {
            _ = try await meteor.call("eventPhotos.upload", params: [
                ["imageData": base64, "caption": caption] as [String: Any]
            ])
        } catch {
            uploadError = "Upload mislukt: \(error.localizedDescription)"
        }
        await loadFeed()
        isUploading = false
    }

    private func syncFromCollections() {
        guard let col = meteor.collection("event_photos") else { return }

        photos = Array(col.documents.values).compactMap { doc -> Photo? in
            guard let id = doc["_id"] as? String,
                  let rawUrl = doc["imageUrl"] as? String,
                  let imageUrl = URLResolver.resolve(rawUrl) else { return nil }

            let createdAt: Date
            if let date = doc["createdAt"] as? Date {
                createdAt = date
            } else if let timestamp = doc["createdAt"] as? Double {
                createdAt = Date(timeIntervalSince1970: timestamp / 1000)
            } else if let timestamp = doc["createdAt"] as? Int {
                createdAt = Date(timeIntervalSince1970: Double(timestamp) / 1000)
            } else {
                createdAt = Date()
            }

            return Photo(id: id, imageUrl: imageUrl, caption: doc["caption"] as? String,
                         authorName: doc["authorName"] as? String, createdAt: createdAt)
        }.sorted { $0.createdAt > $1.createdAt }
    }
}
