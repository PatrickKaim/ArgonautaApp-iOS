import Foundation
import Observation
import MeteorDDPKit

@Observable
final class ShoppingListViewModel {
    var activeItems: [ShoppingItem] = []
    var completedItems: [ShoppingItem] = []
    var isLoading = false

    private let meteor = MeteorService.shared
    private var sub: DDPSubscription?

    struct ShoppingItem: Identifiable {
        let id: String
        let name: String
        let isCompleted: Bool
    }

    func loadData() async {
        isLoading = true
        sub = try? await meteor.subscribe("shoppingList.active")
        try? await sub?.waitUntilReady()
        syncFromCollections()
        isLoading = false
    }

    func addItem(name: String) async {
        guard !name.isEmpty else { return }
        _ = try? await meteor.call("shoppingList.add", params: [["name": name]])
        syncFromCollections()
    }

    func complete(itemId: String) async {
        _ = try? await meteor.call("shoppingList.complete", params: [itemId])
        syncFromCollections()
    }

    private func syncFromCollections() {
        guard let col = meteor.collection("shopping_list") else { return }
        let all = Array(col.documents.values).compactMap { doc -> ShoppingItem? in
            guard let id = doc["_id"] as? String, let name = doc["name"] as? String else { return nil }
            return ShoppingItem(id: id, name: name, isCompleted: doc["completedAt"] != nil)
        }
        activeItems = all.filter { !$0.isCompleted }.sorted { $0.name < $1.name }
        completedItems = all.filter { $0.isCompleted }
    }
}
