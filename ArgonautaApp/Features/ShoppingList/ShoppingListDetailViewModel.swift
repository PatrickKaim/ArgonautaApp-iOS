import Foundation
import Observation
import MeteorDDPKit

/// Eén open boodschappenlijst: regels uit `clubhouse_shopping_list_items`, productnamen uit `clubhouse.products`.
@Observable
final class ShoppingListDetailViewModel {
    struct Line: Identifiable {
        let id: String
        let listId: String
        let displayName: String
        let unitSuffix: String
        let source: String
        let orderPackages: Int
        let suggestedPackages: Int
        let deferred: Bool
        let picked: Bool
        let isAdhoc: Bool
    }

    struct ProductOption: Identifiable, Hashable {
        let id: String
        let name: String
        let unit: String
    }

    let listId: String

    var listTitle: String = ""
    /// `supplier` (of legacy), `event`, `custom`
    var listKind: String?
    var supplierKey: String?
    var lines: [Line] = []
    var productOptions: [ProductOption] = []
    var isLoading = false
    var errorMessage: String?

    private let meteor = MeteorService.shared
    private var productsSub: DDPSubscription?
    private var observeTask: Task<Void, Never>?

    init(listId: String) {
        self.listId = listId
    }

    deinit {
        stop()
    }

    func start() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            productsSub = try await meteor.subscribe("clubhouse.products", params: [])
            try await productsSub?.waitUntilReady()
            syncListMeta()
            syncLines()
            syncProductOptions()
            startObserving()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        observeTask?.cancel()
        observeTask = nil
        productsSub = nil
    }

    func setPicked(itemId: String, picked: Bool) async {
        do {
            _ = try await meteor.call(
                "clubhouse.shopping.updateItem",
                params: [itemId, ["picked": picked]]
            )
            syncLines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDeferred(itemId: String, deferred: Bool) async {
        do {
            _ = try await meteor.call(
                "clubhouse.shopping.updateItem",
                params: [itemId, ["deferred": deferred]]
            )
            syncLines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateOrderQty(itemId: String, qty: Int) async {
        guard qty >= 0 else { return }
        do {
            _ = try await meteor.call(
                "clubhouse.shopping.updateItem",
                params: [itemId, ["orderPackages": qty]]
            )
            syncLines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addManualProduct(productId: String, orderPackages: Int) async {
        let q = max(1, orderPackages)
        do {
            _ = try await meteor.call(
                "clubhouse.shopping.addManualItem",
                params: [listId, productId, q]
            )
            syncLines()
            syncProductOptions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addAdhoc(label: String, orderPackages: Int) async {
        let t = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let q = max(1, orderPackages)
        do {
            _ = try await meteor.call(
                "clubhouse.shopping.addAdHocItem",
                params: [listId, ["label": t, "orderPackages": q]]
            )
            syncLines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeLine(itemId: String) async {
        do {
            _ = try await meteor.call("clubhouse.shopping.removeItem", params: [itemId])
            syncLines()
            syncProductOptions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var allowsAdhocLines: Bool {
        listKind == "event" || listKind == "custom"
    }

    var isSupplierStockList: Bool {
        guard let k = listKind else { return true }
        return k == "supplier"
    }

    private func syncListMeta() {
        guard let col = meteor.collection("clubhouse_shopping_lists"),
              let doc = col.documents.values.first(where: { meteorId($0) == listId })
        else {
            listTitle = ""
            listKind = nil
            supplierKey = nil
            return
        }
        let title = (doc["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let supplierName = (doc["supplierName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        listTitle = title ?? supplierName ?? "—"
        listKind = doc["listKind"] as? String
        supplierKey = doc["supplierKey"] as? String
    }

    private func syncLines() {
        syncListMeta()
        guard let col = meteor.collection("clubhouse_shopping_list_items") else {
            lines = []
            return
        }
        let products = productDocumentsById()
        var out: [Line] = []
        for doc in col.documents.values {
            guard meteorId(doc["listId"]) == listId else { continue }
            guard let id = meteorId(doc) else { continue }
            let source = doc["source"] as? String ?? "manual"
            let isAdhoc = source == "adhoc"
            let productId = doc["productId"] as? String
            let label = doc["label"] as? String
            let name: String
            let unit: String
            if isAdhoc {
                name = label ?? "—"
                unit = ""
            } else if let pid = productId, let p = products[pid] {
                name = p["name"] as? String ?? "—"
                unit = p["unit"] as? String ?? "stuks"
            } else {
                name = "—"
                unit = "stuks"
            }
            let order = meteorInt(doc["orderPackages"])
            let suggested = meteorInt(doc["suggestedPackages"])
            let deferred = (doc["deferred"] as? Bool) == true
            let picked = (doc["picked"] as? Bool) == true
            out.append(
                Line(
                    id: id,
                    listId: listId,
                    displayName: name,
                    unitSuffix: unit.isEmpty ? "" : " (\(unit))",
                    source: source,
                    orderPackages: order,
                    suggestedPackages: suggested,
                    deferred: deferred,
                    picked: picked,
                    isAdhoc: isAdhoc
                )
            )
        }
        lines = out.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func productDocumentsById() -> [String: [String: Any]] {
        guard let col = meteor.collection("clubhouse_products") else { return [:] }
        var m = [String: [String: Any]]()
        for doc in col.documents.values {
            if let id = meteorId(doc) {
                m[id] = doc
            }
        }
        return m
    }

    private func existingProductIdsOnList() -> Set<String> {
        guard let col = meteor.collection("clubhouse_shopping_list_items") else { return [] }
        var s = Set<String>()
        for doc in col.documents.values {
            guard meteorId(doc["listId"]) == listId else { continue }
            if let pid = doc["productId"] as? String { s.insert(pid) }
        }
        return s
    }

    private func syncProductOptions() {
        guard let pCol = meteor.collection("clubhouse_products") else {
            productOptions = []
            return
        }
        let taken = existingProductIdsOnList()
        var options: [ProductOption] = []
        for doc in pCol.documents.values {
            guard let id = meteorId(doc) else { continue }
            if taken.contains(id) { continue }
            let name = doc["name"] as? String ?? "—"
            let unit = doc["unit"] as? String ?? "stuks"
            if isSupplierStockList {
                guard let sk = supplierKey, supplierKeyFromProduct(doc) == sk else { continue }
            }
            options.append(ProductOption(id: id, name: name, unit: unit))
        }
        productOptions = options.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func startObserving() {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self?.observeLoop(collection: "clubhouse_shopping_list_items") }
                group.addTask { await self?.observeLoop(collection: "clubhouse_shopping_lists") }
                group.addTask { await self?.observeLoop(collection: "clubhouse_products") }
            }
        }
    }

    private func observeLoop(collection name: String) async {
        guard let col = meteor.collection(name) else { return }
        for await _ in col.events {
            guard !Task.isCancelled else { break }
            try? await Task.sleep(for: .milliseconds(120))
            await MainActor.run { [weak self] in
                self?.syncListMeta()
                self?.syncLines()
                self?.syncProductOptions()
            }
        }
    }
}

private func supplierKeyFromProduct(_ doc: [String: Any]) -> String? {
    if let sid = doc["supplierId"] as? String, !sid.isEmpty {
        return "id:\(sid)"
    }
    if let s = doc["supplier"] as? String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return "n:\(t.lowercased())" }
    }
    return nil
}
