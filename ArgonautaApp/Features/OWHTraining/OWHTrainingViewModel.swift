import Foundation
import Observation
import MeteorDDPKit

@Observable
final class OWHTrainingViewModel {
    var trainings: [Training] = []
    var isLoading = false
    var attendees: [String: TrainingAttendees] = [:]
    var selectedTypes: [String: [String]] = [:]
    var loadingTraining: Set<String> = []

    private let meteor = MeteorService.shared
    private var sub: DDPSubscription?
    private var observeTask: Task<Void, Never>?

    static let trainingTypes = ["kracht", "techniek", "strategie", "wedstrijd_spel"]

    static let typeLabels: [String: String] = [
        "kracht": "Kracht",
        "techniek": "Techniek",
        "strategie": "Strategie",
        "wedstrijd_spel": "Wedstrijd/spel",
        "geen_voorkeur": "Geen voorkeur",
    ]

    static let pollTypeIds = trainingTypes + ["geen_voorkeur"]

    struct Training: Identifiable {
        let id: String
        let date: Date
        let startTime: String
        let endTime: String
        var isSignedUp: Bool
        var signupTypes: [String]
        let attendeeCount: Int?
    }

    struct AttendeeInfo: Identifiable {
        let id: String
        let name: String
        let imageUrl: String?
        var userId: String { id }
    }

    struct TrainingAttendees {
        var totalAttendees: Int
        var byType: [String: [AttendeeInfo]]
    }

    func loadData() async {
        isLoading = true
        sub = try? await meteor.subscribe("owhTraining.upcoming")
        try? await sub?.waitUntilReady()
        syncFromCollections()
        await loadAttendees()
        startObserving()
        isLoading = false
    }

    func isAttending(_ trainingId: String) -> Bool {
        trainings.first(where: { $0.id == trainingId })?.isSignedUp ?? false
    }

    func setAttending(trainingId: String, on: Bool) async {
        loadingTraining.insert(trainingId)
        defer { loadingTraining.remove(trainingId) }

        do {
            if on {
                let types = selectedTypes[trainingId] ?? []
                _ = try await meteor.call("owhTraining.signup", params: [["trainingId": trainingId, "types": types]])
            } else {
                _ = try await meteor.call("owhTraining.cancelSignup", params: [["trainingId": trainingId]])
                selectedTypes[trainingId] = []
            }
            syncFromCollections()
            await loadAttendees()
        } catch {
            print("[OWH] signup error: \(error)")
        }
    }

    func toggleType(trainingId: String, typeId: String) async {
        var current = selectedTypes[trainingId] ?? []
        if current.contains(typeId) {
            current.removeAll { $0 == typeId }
        } else {
            current.append(typeId)
        }
        selectedTypes[trainingId] = current

        guard isAttending(trainingId) else { return }

        loadingTraining.insert(trainingId)
        defer { loadingTraining.remove(trainingId) }

        do {
            _ = try await meteor.call("owhTraining.updateSignup", params: [["trainingId": trainingId, "types": current]])
            syncFromCollections()
            await loadAttendees()
        } catch {
            print("[OWH] updateSignup error: \(error)")
        }
    }

    private func syncFromCollections() {
        let userId = meteor.userId ?? ""
        guard let col = meteor.collection("owh_trainings") else { return }
        let signupCol = meteor.collection("owh_training_signups")
        let now = Date()

        let signupDocs = signupCol.map { Array($0.documents.values) } ?? []

        trainings = Array(col.documents.values).compactMap { doc -> Training? in
            guard let id = meteorId(doc["_id"]), !id.isEmpty,
                  let date = doc["date"] as? Date,
                  date >= Calendar.current.startOfDay(for: now) else { return nil }

            let mySignup = signupDocs.first {
                meteorId($0["trainingId"]) == id && meteorId($0["userId"]) == userId
            }
            let isSignedUp = mySignup != nil
            let signupTypes = (mySignup?["types"] as? [String]) ?? []
            let count = signupDocs.filter { meteorId($0["trainingId"]) == id }.count

            if isSignedUp && selectedTypes[id] == nil {
                selectedTypes[id] = signupTypes
            }

            return Training(
                id: id, date: date,
                startTime: doc["startTime"] as? String ?? "",
                endTime: doc["endTime"] as? String ?? "",
                isSignedUp: isSignedUp,
                signupTypes: signupTypes,
                attendeeCount: count
            )
        }.sorted { $0.date < $1.date }
    }

    private func loadAttendees() async {
        let ids = trainings.map { $0.id }
        guard !ids.isEmpty else { return }

        do {
            guard let result = try await meteor.call("owhTraining.getAttendeesForTrainings", params: [ids]) as? [String: Any] else { return }

            var newAttendees: [String: TrainingAttendees] = [:]
            for (trainingId, value) in result {
                guard let dict = value as? [String: Any] else { continue }
                let total = dict["totalAttendees"] as? Int ?? 0
                var byType: [String: [AttendeeInfo]] = [:]

                if let byTypeDict = dict["byType"] as? [String: [[String: Any]]] {
                    for (typeId, users) in byTypeDict {
                        byType[typeId] = users.compactMap { u in
                            guard let uid = meteorId(u["userId"]),
                                  let name = u["name"] as? String else { return nil }
                            return AttendeeInfo(id: uid, name: name, imageUrl: u["imageUrl"] as? String)
                        }
                    }
                }
                newAttendees[trainingId] = TrainingAttendees(totalAttendees: total, byType: byType)
            }
            attendees = newAttendees
            reconcileFromPoll()
        } catch {
            print("[OWH] loadAttendees error: \(error)")
        }
    }

    /// Poll (RPC) en minimongo kunnen uit de pas lopen: `isSignedUp` + typekeuzes gelijk trekken met de poll.
    private func reconcileFromPoll() {
        let userId = meteor.userId ?? ""
        guard !userId.isEmpty else { return }

        var newSel = selectedTypes
        let next: [Training] = trainings.map { t in
            guard let att = attendees[t.id] else { return t }
            let inPoll = userListedInPoll(att, userId: userId)
            var nt = t
            if inPoll, !t.isSignedUp {
                nt = Training(
                    id: t.id,
                    date: t.date,
                    startTime: t.startTime,
                    endTime: t.endTime,
                    isSignedUp: true,
                    signupTypes: t.signupTypes,
                    attendeeCount: t.attendeeCount
                )
            }
            guard nt.isSignedUp else { return nt }
            if let derived = deriveTypesFromPoll(att: att, userId: userId) {
                newSel[t.id] = derived
                if nt.signupTypes != derived {
                    nt = Training(
                        id: nt.id,
                        date: nt.date,
                        startTime: nt.startTime,
                        endTime: nt.endTime,
                        isSignedUp: nt.isSignedUp,
                        signupTypes: derived,
                        attendeeCount: nt.attendeeCount
                    )
                }
            }
            return nt
        }

        selectedTypes = newSel
        trainings = next
    }

    /// `nil` = poll geeft geen zichtbare typeverdeling voor jou; dan UI-types niet overschrijven.
    private func deriveTypesFromPoll(att: TrainingAttendees, userId: String) -> [String]? {
        let hits = Self.trainingTypes.filter { tid in
            (att.byType[tid] ?? []).contains(where: { $0.userId == userId })
        }
        if !hits.isEmpty { return hits }
        if (att.byType["geen_voorkeur"] ?? []).contains(where: { $0.userId == userId }) {
            return []
        }
        return nil
    }

    private func userListedInPoll(_ att: TrainingAttendees, userId: String) -> Bool {
        for (_, users) in att.byType {
            if users.contains(where: { $0.userId == userId }) { return true }
        }
        return false
    }

    private func startObserving() {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            guard let self else { return }
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.observeCollection(name: "owh_trainings") }
                group.addTask { await self.observeCollection(name: "owh_training_signups") }
            }
        }
    }

    private func observeCollection(name: String) async {
        guard let col = meteor.collection(name) else { return }
        for await _ in col.events {
            guard !Task.isCancelled else { break }
            try? await Task.sleep(for: .milliseconds(280))
            syncFromCollections()
            await loadAttendees()
        }
    }
}
