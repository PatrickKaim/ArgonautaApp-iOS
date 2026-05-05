import Foundation
import Observation
import MeteorDDPKit

/// Open boodschappenlijsten (`clubhouse.shoppingLists` + Minimongo `clubhouse_shopping_lists` / `clubhouse_shopping_list_items`).
@Observable
final class ShoppingListsViewModel {
    struct ShoppingListSummary: Identifiable, Hashable {
        let id: String
        let title: String
        let kindLabel: String
        let lineCount: Int
        let updatedAt: Date?
    }

    var lists: [ShoppingListSummary] = []
    var isLoading = false
    var errorMessage: String?

    private let meteor = MeteorService.shared
    private var sub: DDPSubscription?
    private var observeTask: Task<Void, Never>?

    func start() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            sub = try await meteor.subscribe("clubhouse.shoppingLists", params: [])
            try await sub?.waitUntilReady()
            syncFromCollections()
            startObserving()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        observeTask?.cancel()
        observeTask = nil
        sub = nil
    }

    func createList(title: String) async {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        do {
            _ = try await meteor.call("clubhouse.shopping.createList", params: [["title": t]])
            syncFromCollections()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncFromCollections() {
        guard let listsCol = meteor.collection("clubhouse_shopping_lists") else {
            lists = []
            return
        }
        let itemsCol = meteor.collection("clubhouse_shopping_list_items")
        var countByList = [String: Int]()
        if let itemsCol {
            for doc in itemsCol.documents.values {
                guard let lid = meteorId(doc["listId"]) else { continue }
                countByList[lid, default: 0] += 1
            }
        }

        var out: [ShoppingListSummary] = []
        for doc in listsCol.documents.values {
            guard let id = meteorId(doc) else { continue }
            let title = (doc["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let supplierName = (doc["supplierName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let display = title ?? supplierName ?? "—"
            let kind = doc["listKind"] as? String
            let kindLabel: String
            switch kind {
            case "event": kindLabel = "Evenement"
            case "custom": kindLabel = "Ad-hoc"
            default: kindLabel = "Leverancier"
            }
            let updated = doc["updatedAt"] as? Date ?? parseDate(doc["updatedAt"])
            out.append(
                ShoppingListSummary(
                    id: id,
                    title: display,
                    kindLabel: kindLabel,
                    lineCount: countByList[id] ?? 0,
                    updatedAt: updated
                )
            )
        }
        lists = out.sorted { ($0.title).localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func startObserving() {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self?.observeLoop(collection: "clubhouse_shopping_lists") }
                group.addTask { await self?.observeLoop(collection: "clubhouse_shopping_list_items") }
            }
        }
    }

    private func observeLoop(collection name: String) async {
        guard let col = meteor.collection(name) else { return }
        for await _ in col.events {
            guard !Task.isCancelled else { break }
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run { [weak self] in self?.syncFromCollections() }
        }
    }

    private func parseDate(_ value: Any?) -> Date? {
        if let d = value as? Date { return d }
        if let t = value as? TimeInterval { return Date(timeIntervalSince1970: t) }
        return nil
    }
}

func meteorId(_ doc: [String: Any]) -> String? {
    if let s = doc["_id"] as? String { return s }
    if let s = doc["_id"] { return String(describing: s) }
    return nil
}

func meteorId(_ value: Any?) -> String? {
    if let s = value as? String { return s }
    if let v = value { return String(describing: v) }
    return nil
}

func meteorInt(_ value: Any?) -> Int {
    if let i = value as? Int { return i }
    if let n = value as? NSNumber { return n.intValue }
    if let d = value as? Double { return Int(d) }
    return 0
}
