import Foundation
import Observation
import UIKit
import MeteorDDPKit
import UserNotifications

/// Lid-notificaties via DDP-publicatie `notifications.active` (zelfde als webapp).
@Observable
final class NotificationsViewModel {
    struct Item: Identifiable {
        let id: String
        let title: String
        let body: String
        let type: String
        let createdAt: Date?
    }

    var items: [Item] = []
    var unreadCount: Int { items.count }
    var isLoading = false

    private let meteor = MeteorService.shared
    private var sub: DDPSubscription?
    private var observeTask: Task<Void, Never>?

    func start() async {
        isLoading = true
        defer { isLoading = false }

        sub = try? await meteor.subscribe("notifications.active", params: [])
        try? await sub?.waitUntilReady()
        syncFromCollections()
        startObserving()
    }

    func stop() {
        observeTask?.cancel()
        observeTask = nil
        sub = nil
    }

    func dismiss(id: String) async {
        do {
            _ = try await meteor.call("notifications.dismiss", params: [id])
            syncFromCollections()
        } catch {
            print("[Notifications] dismiss fout: \(error)")
        }
    }

    func dismissAll() async {
        do {
            _ = try await meteor.call("notifications.dismissAll", params: [])
            syncFromCollections()
        } catch {
            print("[Notifications] dismissAll fout: \(error)")
        }
    }

    private func syncFromCollections() {
        let uid = meteor.userId ?? ""
        var dismissed = Set<String>()
        if let dCol = meteor.collection("notification_dismissals") {
            for doc in dCol.documents.values {
                guard (doc["userId"] as? String) == uid,
                      let nid = doc["notificationId"] as? String else { continue }
                dismissed.insert(nid)
            }
        }

        guard let nCol = meteor.collection("notifications") else {
            items = []
            return
        }

        let now = Date()
        items = nCol.documents.values.compactMap { doc -> Item? in
            guard let id = doc["_id"] as? String else { return nil }
            guard !dismissed.contains(id) else { return nil }

            if let exp = doc["expiresAt"] as? Date, exp <= now { return nil }
            if let exp = parseDate(doc["expiresAt"]), exp <= now { return nil }

            let title = doc["title"] as? String ?? ""
            let body = doc["body"] as? String ?? ""
            let type = doc["type"] as? String ?? "message"
            let createdAt = doc["createdAt"] as? Date ?? parseDate(doc["createdAt"])
            return Item(id: id, title: title, body: body, type: type, createdAt: createdAt)
        }
        .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }

        // Icoon-badge op het thuisscherm = zelfde aantal als het bel-icoon (DDP).
        // Voor een badge terwijl de app nog nooit is geopend: zie server APN (push.enabled).
        let count = items.count
        Task { @MainActor in
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
                if let error {
                    print("[Notifications] setBadgeCount error: \(error)")
                }
            }
        }
    }

    /// Fallback als Meteor datums als dict binnenkomen.
    private func parseDate(_ value: Any?) -> Date? {
        if let d = value as? Date { return d }
        if let t = value as? TimeInterval { return Date(timeIntervalSince1970: t) }
        return nil
    }

    /// Eén observable collectie: twee parallelle `for await`-loops op `col.events` kan MeteorDDPKit laten vastlopen
    /// waardoor andere subscriptions (kalender, wallet) niet meer updaten.
    private func startObserving() {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            await self?.observeCollectionEvents("notifications")
        }
    }

    private func observeCollectionEvents(_ name: String) async {
        guard let col = meteor.collection(name) else { return }
        for await _ in col.events {
            guard !Task.isCancelled else { break }
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run { [weak self] in self?.syncFromCollections() }
        }
    }
}
