import Foundation
import Observation
import MeteorDDPKit

/// Beheer van belangrijke mededelingen (narrowcasting / display) — zelfde API als CMS-web.
@Observable
final class DisplayAnnouncementsAdminViewModel {
    struct Row: Identifiable, Hashable {
        let id: String
        let text: String
        let sortOrder: Int
        let active: Bool
    }

    var rows: [Row] = []
    var newText = ""
    var editingId: String?
    var editingText = ""
    var errorMessage: String?
    var isBusy = false

    private let meteor = MeteorService.shared
    private var sub: DDPSubscription?
    private var observeTask: Task<Void, Never>?

    func start() async {
        sub = try? await meteor.subscribe("displayAnnouncements.admin", params: [])
        try? await sub?.waitUntilReady()
        syncFromCollection()
        startObserving()
    }

    func stop() {
        observeTask?.cancel()
        observeTask = nil
        sub = nil
    }

    func add() async {
        let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        do {
            let doc: [String: Any] = ["text": t]
            _ = try await meteor.call("displayAnnouncements.insert", params: [doc])
            newText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginEdit(_ row: Row) {
        editingId = row.id
        editingText = row.text
    }

    func cancelEdit() {
        editingId = nil
        editingText = ""
    }

    func saveEdit() async {
        guard let id = editingId else { return }
        let t = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        do {
            let setDict: [String: Any] = ["text": t]
            let modifier: [String: Any] = ["$set": setDict]
            _ = try await meteor.call("displayAnnouncements.update", params: [id, modifier])
            cancelEdit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(id: String) async {
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        do {
            _ = try await meteor.call("displayAnnouncements.remove", params: [id])
            if editingId == id { cancelEdit() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncFromCollection() {
        guard let col = meteor.collection("display_announcements") else {
            rows = []
            return
        }
        rows = col.documents.values.compactMap { doc -> Row? in
            guard let id = doc["_id"] as? String else { return nil }
            let text = doc["text"] as? String ?? ""
            let sortOrder = doc["sortOrder"] as? Int ?? 0
            let active = doc["active"] as? Bool ?? true
            return Row(id: id, text: text, sortOrder: sortOrder, active: active)
        }
        .sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.id < $1.id
        }
    }

    private func startObserving() {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            await self?.observeCollectionEvents("display_announcements")
        }
    }

    private func observeCollectionEvents(_ name: String) async {
        guard let col = meteor.collection(name) else { return }
        for await _ in col.events {
            guard !Task.isCancelled else { break }
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run { [weak self] in
                self?.syncFromCollection()
            }
        }
    }
}
