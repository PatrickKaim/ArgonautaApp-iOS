import Foundation
import Observation
import MeteorDDPKit

@Observable
final class CalendarViewModel {
    private(set) var items: [CalendarItem] = []
    var showBarDuties = true

    private var eventSub: DDPSubscription?
    private var barDutySub: DDPSubscription?
    private var owhSub: DDPSubscription?
    private let meteor = MeteorService.shared

    enum ItemKind: Equatable {
        case event
        case barDuty
        case owhTraining
    }

    struct CalendarItem: Identifiable {
        let id: String
        let title: String
        let kind: ItemKind
        let start: Date?
        let end: Date?
        let subtitle: String?
        let assignedUserId: String?
        let isMySlot: Bool
    }

    func loadMonth(_ month: Date) async {
        let start = month.startOfMonth
        let end = month.endOfMonth

        async let e: () = loadEvents(start: start, end: end)
        async let b: () = loadBarDuties(start: start, end: end)
        async let o: () = loadOWHTrainings()
        _ = await (e, b, o)
    }

    private func loadEvents(start: Date, end: Date) async {
        eventSub = try? await meteor.subscribe("events.calendar", params: [start, end])
        try? await eventSub?.waitUntilReady()
        syncAll()
    }

    private func loadBarDuties(start: Date, end: Date) async {
        barDutySub = try? await meteor.subscribe("barDuty.calendar", params: [start, end])
        try? await barDutySub?.waitUntilReady()
        syncAll()
    }

    private func loadOWHTrainings() async {
        owhSub = try? await meteor.subscribe("owhTraining.upcoming")
        try? await owhSub?.waitUntilReady()
        syncAll()
    }

    private func syncAll() {
        var allItems: [CalendarItem] = []
        let userId = meteor.userId ?? ""

        if let col = meteor.collection("events") {
            let eventItems = Array(col.documents.values).compactMap { doc -> CalendarItem? in
                guard let id = doc["_id"] as? String, let title = doc["title"] as? String else { return nil }
                return CalendarItem(id: id, title: title, kind: .event,
                                    start: doc["start"] as? Date, end: doc["end"] as? Date,
                                    subtitle: nil, assignedUserId: nil, isMySlot: false)
            }
            allItems.append(contentsOf: eventItems)
        }

        if let col = meteor.collection("bar_duty_slots") {
            let barItems = Array(col.documents.values).compactMap { doc -> CalendarItem? in
                guard let id = doc["_id"] as? String, let date = doc["date"] as? Date else { return nil }
                let assignedId = doc["assignedUserId"] as? String
                let assignedName = doc["assignedDisplayName"] as? String
                let groupName = doc["groupName"] as? String ?? ""
                let title = assignedName != nil ? "Bardienst: \(assignedName!)" : "Bardienst (open)"
                return CalendarItem(id: id, title: title, kind: .barDuty,
                                    start: date, end: nil,
                                    subtitle: groupName, assignedUserId: assignedId,
                                    isMySlot: assignedId == userId)
            }
            allItems.append(contentsOf: barItems)
        }

        if let col = meteor.collection("owh_trainings") {
            let owhItems = Array(col.documents.values).compactMap { doc -> CalendarItem? in
                guard let id = doc["_id"] as? String, let date = doc["date"] as? Date else { return nil }
                let startTime = doc["startTime"] as? String ?? ""
                let endTime = doc["endTime"] as? String ?? ""
                let timeStr = !startTime.isEmpty ? "\(startTime) - \(endTime)" : nil
                return CalendarItem(id: id, title: "OWH Training", kind: .owhTraining,
                                    start: date, end: nil,
                                    subtitle: timeStr, assignedUserId: nil, isMySlot: false)
            }
            allItems.append(contentsOf: owhItems)
        }

        items = allItems
    }

    // MARK: - Sign up / Sign off bardienst

    func signUp(slotId: String) async {
        _ = try? await meteor.call("barDuty.signUp", params: [slotId])
        syncAll()
    }

    func signOff(slotId: String) async {
        _ = try? await meteor.call("barDuty.signOff", params: [slotId])
        syncAll()
    }

    // MARK: - Calendar helpers

    func daysInMonth(_ month: Date) -> [Date] {
        let cal = Calendar(identifier: .iso8601)
        let start = month.startOfMonth
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }

        var weekday = cal.component(.weekday, from: start) - cal.firstWeekday
        if weekday < 0 { weekday += 7 }

        var days: [Date] = []
        for i in stride(from: weekday - 1, through: 0, by: -1) {
            if let date = cal.date(byAdding: .day, value: -i - 1, to: start) { days.append(date) }
        }
        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: start) { days.append(date) }
        }
        while days.count < 42 {
            if let last = days.last, let next = cal.date(byAdding: .day, value: 1, to: last) {
                days.append(next)
            } else { break }
        }
        return days
    }

    func hasItems(on date: Date) -> Bool {
        filteredItems.contains { item in
            guard let start = item.start else { return false }
            return Calendar.current.isDate(start, inSameDayAs: date)
        }
    }

    func itemKinds(on date: Date) -> Set<ItemKind> {
        var kinds = Set<ItemKind>()
        for item in filteredItems {
            guard let start = item.start, Calendar.current.isDate(start, inSameDayAs: date) else { continue }
            kinds.insert(item.kind)
        }
        return kinds
    }

    func items(on date: Date) -> [CalendarItem] {
        filteredItems.filter { item in
            guard let start = item.start else { return false }
            return Calendar.current.isDate(start, inSameDayAs: date)
        }.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }

    private var filteredItems: [CalendarItem] {
        items.filter { item in
            if item.kind == .barDuty && !showBarDuties { return false }
            return true
        }
    }
}
