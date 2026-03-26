import Foundation
import Observation
import MeteorDDPKit

@Observable
final class BarDutyViewModel {
    var groupName: String?
    var openSlots: [Slot] = []
    var assignedSlots: [Slot] = []
    var isLoading = false
    var errorMessage: String?

    private let meteor = MeteorService.shared
    private var sub: DDPSubscription?
    private var observeTask: Task<Void, Never>?

    struct Slot: Identifiable {
        let id: String
        let date: Date
        let groupId: String
        let assignedUserId: String?
        let assignedName: String?
        let reserveCount: Int
        let isMySlot: Bool
        let isMyReserve: Bool
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil

        let now = Date()
        let cal = Calendar.current
        let start = cal.date(byAdding: .month, value: -1, to: now) ?? now
        let end = cal.date(byAdding: .month, value: 12, to: now) ?? now

        let formatter = ISO8601DateFormatter()
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)

        sub = try? await meteor.subscribe("barDuty.forMember", params: [startStr, endStr])
        try? await sub?.waitUntilReady()
        syncFromCollections()
        startObserving()
        isLoading = false
    }

    func signUp(slot: Slot) async {
        do {
            let query: [String: Any] = ["date": slot.date, "groupId": slot.groupId]
            _ = try await meteor.call("barDuty.signUp", params: [query])
            syncFromCollections()
        } catch {
            errorMessage = parseError(error)
        }
    }

    func signOff(slot: Slot) async {
        do {
            let query: [String: Any] = ["date": slot.date, "groupId": slot.groupId]
            _ = try await meteor.call("barDuty.signOff", params: [query])
            syncFromCollections()
        } catch {
            errorMessage = parseError(error)
        }
    }

    func signUpAsReserve(slot: Slot) async {
        do {
            let query: [String: Any] = ["date": slot.date, "groupId": slot.groupId]
            _ = try await meteor.call("barDuty.signUpAsReserve", params: [query])
            syncFromCollections()
        } catch {
            errorMessage = parseError(error)
        }
    }

    func removeReserve(slot: Slot) async {
        do {
            let query: [String: Any] = ["date": slot.date, "groupId": slot.groupId]
            _ = try await meteor.call("barDuty.removeReserve", params: [query])
            syncFromCollections()
        } catch {
            errorMessage = parseError(error)
        }
    }

    private func parseError(_ error: Error) -> String {
        let desc = error.localizedDescription
        if desc.contains("niet bij de groep") { return "Je hoort niet bij de groep die aan de beurt is." }
        if desc.contains("al iemand") { return "Er staat al iemand ingepland. Meld je aan als reserve." }
        if desc.contains("al aangemeld") { return "Je bent al aangemeld." }
        return desc
    }

    private func syncFromCollections() {
        let userId = meteor.userId ?? ""
        let today = Calendar.current.startOfDay(for: Date())

        // Groep
        if let groupCol = meteor.collection("bar_duty_groups"),
           let firstGroup = groupCol.documents.values.first {
            groupName = firstGroup["name"] as? String
        }

        guard let col = meteor.collection("bar_duty_slots") else {
            openSlots = []
            assignedSlots = []
            return
        }

        let allSlots: [Slot] = Array(col.documents.values).compactMap { doc in
            guard let id = doc["_id"] as? String,
                  let date = doc["date"] as? Date,
                  date >= today else { return nil }

            let assignedUserId = doc["assignedUserId"] as? String
            let reserves = doc["reserveUserIds"] as? [String] ?? []
            let groupId = doc["groupId"] as? String ?? ""

            return Slot(
                id: id, date: date, groupId: groupId,
                assignedUserId: assignedUserId,
                assignedName: doc["assignedDisplayName"] as? String,
                reserveCount: reserves.count,
                isMySlot: assignedUserId == userId,
                isMyReserve: reserves.contains(userId)
            )
        }.sorted { $0.date < $1.date }

        openSlots = allSlots.filter { $0.assignedUserId == nil }
        assignedSlots = allSlots.filter { $0.assignedUserId != nil }
    }

    private func startObserving() {
        observeTask?.cancel()
        guard let col = meteor.collection("bar_duty_slots") else { return }
        observeTask = Task { [weak self] in
            for await _ in col.events {
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .milliseconds(200))
                self?.syncFromCollections()
            }
        }
    }
}
