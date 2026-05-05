import Foundation
import Observation
import MeteorDDPKit

@Observable
final class CalendarViewModel {
    private(set) var items: [CalendarItem] = []
    var showBarDuties = true

    /// Maandrooster (stippen per dag).
    private var monthEventSub: DDPSubscription?
    private var monthBarDutySub: DDPSubscription?
    /// Rollend venster voor de onderlijst (komende 30 dagen).
    private var windowEventSub: DDPSubscription?
    private var windowBarDutySub: DDPSubscription?
    private var owhSub: DDPSubscription?
    private let meteor = MeteorService.shared

    enum ItemKind: Equatable {
        case event
        case barDuty
        case owhTraining
    }

    struct CalendarItem: Identifiable, Hashable {
        let id: String
        let title: String
        let kind: ItemKind
        let start: Date?
        let end: Date?
        let subtitle: String?
        let assignedUserId: String?
        let isMySlot: Bool
        /// Publieke detailpagina (`/events/:slug`); ontbreekt bij sommige interne items.
        let detailSlug: String?
        /// Bij terugkerende afspraken: master-event-id voor `events.getPublic` + `occurrence`.
        let masterEventId: String?

        static func == (lhs: CalendarItem, rhs: CalendarItem) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    /// Route naar `CalendarEventDetailView` (alleen zinvol voor `.event`).
    struct EventDetailRoute: Hashable {
        let slugOrId: String
        let occurrence: String?
    }

    func eventDetailRoute(for item: CalendarItem) -> EventDetailRoute? {
        guard item.kind == .event else { return nil }
        if let master = item.masterEventId, let start = item.start {
            let cal = Calendar.current
            let y = cal.component(.year, from: start)
            let m = cal.component(.month, from: start)
            let d = cal.component(.day, from: start)
            let occ = String(format: "%04d-%02d-%02d", y, m, d)
            return EventDetailRoute(slugOrId: master, occurrence: occ)
        }
        let key = item.detailSlug ?? item.id
        return EventDetailRoute(slugOrId: key, occurrence: nil)
    }

    func loadMonth(_ month: Date) async {
        let start = month.startOfMonth
        let end = month.endOfMonth

        async let e: () = loadMonthEvents(start: start, end: end)
        async let b: () = loadMonthBarDuties(start: start, end: end)
        async let o: () = loadOWHTrainings()
        _ = await (e, b, o)
    }

    /// Aparte range zodat de maand-publicatie niet wordt overschreven door het 30-dagenvenster.
    func loadUpcomingWindow(now: Date = Date()) async {
        let cal = Calendar.current
        let dayStart = now.startOfDay
        guard let lastInclusiveDay = cal.date(byAdding: .day, value: 30, to: dayStart) else { return }
        let rangeEnd = endOfCalendarDay(lastInclusiveDay)

        async let we: () = loadWindowEvents(start: dayStart, end: rangeEnd)
        async let wb: () = loadWindowBarDuties(start: dayStart, end: rangeEnd)
        _ = await (we, wb)
    }

    private func loadMonthEvents(start: Date, end: Date) async {
        monthEventSub = try? await meteor.subscribe("events.calendar", params: [start, end])
        try? await monthEventSub?.waitUntilReady()
        syncAll()
    }

    private func loadMonthBarDuties(start: Date, end: Date) async {
        monthBarDutySub = try? await meteor.subscribe("barDuty.calendar", params: [start, end])
        try? await monthBarDutySub?.waitUntilReady()
        syncAll()
    }

    private func loadWindowEvents(start: Date, end: Date) async {
        windowEventSub = try? await meteor.subscribe("events.calendar", params: [start, end])
        try? await windowEventSub?.waitUntilReady()
        syncAll()
    }

    private func loadWindowBarDuties(start: Date, end: Date) async {
        windowBarDutySub = try? await meteor.subscribe("barDuty.calendar", params: [start, end])
        try? await windowBarDutySub?.waitUntilReady()
        syncAll()
    }

    private func loadOWHTrainings() async {
        owhSub = try? await meteor.subscribe("owhTraining.upcoming")
        try? await owhSub?.waitUntilReady()
        syncAll()
    }

    /// Einde van de kalenderdag (23:59:59) voor inclusieve server `$lte`-ranges.
    private func endOfCalendarDay(_ date: Date) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        return cal.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    private func syncAll() {
        var allItems: [CalendarItem] = []
        let userId = meteor.userId ?? ""

        if let col = meteor.collection("events") {
            let eventItems = Array(col.documents.values).compactMap { doc -> CalendarItem? in
                guard let id = doc["_id"] as? String, let title = doc["title"] as? String else { return nil }
                let detailSlug = doc["detailSlug"] as? String
                let masterEventId = doc["masterEventId"] as? String
                return CalendarItem(
                    id: id, title: title, kind: .event,
                    start: doc["start"] as? Date, end: doc["end"] as? Date,
                    subtitle: nil, assignedUserId: nil, isMySlot: false,
                    detailSlug: detailSlug, masterEventId: masterEventId
                )
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
                return CalendarItem(
                    id: id, title: title, kind: .barDuty,
                    start: date, end: nil,
                    subtitle: groupName, assignedUserId: assignedId,
                    isMySlot: assignedId == userId,
                    detailSlug: nil, masterEventId: nil
                )
            }
            allItems.append(contentsOf: barItems)
        }

        if let col = meteor.collection("owh_trainings") {
            let owhItems = Array(col.documents.values).compactMap { doc -> CalendarItem? in
                guard let id = doc["_id"] as? String, let date = doc["date"] as? Date else { return nil }
                let startTime = doc["startTime"] as? String ?? ""
                let endTime = doc["endTime"] as? String ?? ""
                let timeStr = !startTime.isEmpty ? "\(startTime) - \(endTime)" : nil
                return CalendarItem(
                    id: id, title: "OWH Training", kind: .owhTraining,
                    start: date, end: nil,
                    subtitle: timeStr, assignedUserId: nil, isMySlot: false,
                    detailSlug: nil, masterEventId: nil
                )
            }
            allItems.append(contentsOf: owhItems)
        }

        items = dedupeCalendarItems(allItems)
    }

    /// Twee subscriptions kunnen dezelfde document-id tweemaal in `allItems` leveren voordat de merge op de server zichtbaar is.
    private func dedupeCalendarItems(_ all: [CalendarItem]) -> [CalendarItem] {
        var seen = Set<String>()
        var out: [CalendarItem] = []
        for item in all {
            if seen.insert(item.id).inserted {
                out.append(item)
            }
        }
        return out
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

    /// Activiteiten vanaf vandaag tot en met 30 dagen vooruit (zelfde dag volgende maand).
    func upcomingItemsNext30Days(referenceNow: Date = Date()) -> [CalendarItem] {
        let cal = Calendar.current
        let dayStart = referenceNow.startOfDay
        guard let endExclusive = cal.date(byAdding: .day, value: 31, to: dayStart) else { return [] }

        return filteredItems.filter { item in
            guard let s = item.start else { return false }
            return s >= dayStart && s < endExclusive
        }.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }

    private var filteredItems: [CalendarItem] {
        items.filter { item in
            if item.kind == .barDuty && !showBarDuties { return false }
            return true
        }
    }
}
