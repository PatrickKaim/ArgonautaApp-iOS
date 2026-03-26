import Foundation
import Observation
import MeteorDDPKit

@Observable
final class WalletViewModel {
    var balance: Int = 0
    var cardCode: String?
    var recentTransactions: [Transaction] = []
    var isLoading = false

    private let meteor = MeteorService.shared
    private var walletSub: DDPSubscription?
    private var cardsSub: DDPSubscription?
    private var txSub: DDPSubscription?

    struct Transaction: Identifiable {
        let id: String
        let type: String
        let amount: Int
        let desc: String
        let date: Date
    }

    func loadData() async {
        isLoading = true

        walletSub = try? await meteor.subscribe("wallet.own")
        try? await walletSub?.waitUntilReady()

        cardsSub = try? await meteor.subscribe("wallet.ownCards")
        try? await cardsSub?.waitUntilReady()

        txSub = try? await meteor.subscribe("wallet.ownTransactions", params: [20])
        try? await txSub?.waitUntilReady()

        syncFromCollections()
        isLoading = false
    }

    private func syncFromCollections() {
        if let col = meteor.collection("wallets"), let doc = Array(col.documents.values).first {
            balance = (doc["balance"] as? Int) ?? Int(doc["balance"] as? Double ?? 0)
        }

        if let col = meteor.collection("wallet_cards") {
            let activeCard = Array(col.documents.values).first { ($0["active"] as? Bool) == true }
            cardCode = activeCard?["cardCode"] as? String
        }

        if let col = meteor.collection("wallet_transactions") {
            recentTransactions = Array(col.documents.values).compactMap { doc -> Transaction? in
                guard let id = doc["_id"] as? String, let type = doc["type"] as? String,
                      let date = doc["createdAt"] as? Date else { return nil }
                let amount = (doc["amount"] as? Int) ?? Int(doc["amount"] as? Double ?? 0)
                return Transaction(id: id, type: type, amount: amount, desc: doc["description"] as? String ?? type, date: date)
            }.sorted { $0.date > $1.date }
        }
    }
}
