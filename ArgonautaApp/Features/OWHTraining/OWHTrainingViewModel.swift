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
            guard let id = doc["_id"] as? String,
                  let date = doc["date"] as? Date,
                  date >= Calendar.current.startOfDay(for: now) else { return nil }

            let mySignup = signupDocs.first {
                $0["trainingId"] as? String == id && $0["userId"] as? String == userId
            }
            let isSignedUp = mySignup != nil
            let signupTypes = (mySignup?["types"] as? [String]) ?? []
            let count = signupDocs.filter { $0["trainingId"] as? String == id }.count

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
                            guard let uid = u["userId"] as? String,
                                  let name = u["name"] as? String else { return nil }
                            return AttendeeInfo(id: uid, name: name, imageUrl: u["imageUrl"] as? String)
                        }
                    }
                }
                newAttendees[trainingId] = TrainingAttendees(totalAttendees: total, byType: byType)
            }
            attendees = newAttendees
        } catch {
            print("[OWH] loadAttendees error: \(error)")
        }
    }

    private func startObserving() {
        observeTask?.cancel()
        guard let col = meteor.collection("owh_trainings") else { return }
        observeTask = Task { [weak self] in
            for await _ in col.events {
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .milliseconds(300))
                self?.syncFromCollections()
                await self?.loadAttendees()
            }
        }
    }
}
