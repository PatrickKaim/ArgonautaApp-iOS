import Foundation
import Observation

/// Typen — zelfde strings als `NOTIFICATION_TYPES` op de server.
enum NotificationComposeKind: String, CaseIterable, Identifiable {
    case message = "message"
    case calendarEvent = "calendar_event"
    case openingHours = "opening_hours"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .message: "Bericht"
        case .calendarEvent: "Kalender event"
        case .openingHours: "Openingstijden"
        }
    }
}

enum NotificationEventVisibility: String, CaseIterable, Identifiable {
    case publicVisibility = "public"
    case members = "members"
    case board = "board"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .publicVisibility: "Openbaar"
        case .members: "Leden"
        case .board: "Bestuur"
        }
    }
}

enum NotificationOhLocation: String, CaseIterable, Identifiable {
    case clubhouse = "clubhouse"
    case pool = "pool"
    case both = "both"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clubhouse: "Clubhuis"
        case .pool: "Zwembad"
        case .both: "Beide"
        }
    }
}

/// Verstuurt clubbrede notificaties via `notifications.insert` — zelfde payload als CMS-web.
@Observable
final class NotificationsComposeViewModel {
    var kind: NotificationComposeKind = .message

    var titleText = ""
    var bodyText = ""

    // Kalender event
    var eventStart = Date()
    var hasEventEnd = false
    var eventEnd = Date().addingTimeInterval(3600)
    var eventVisibility: NotificationEventVisibility = .members
    var eventDescriptionText = ""

    // Openingstijden
    var ohLocation: NotificationOhLocation = .clubhouse
    var ohDateText = ""
    var ohReasonText = ""
    var ohHoursText = ""

    var isSending = false
    var errorMessage: String?
    var successMessage: String?

    private let meteor = MeteorService.shared

    func send() async {
        errorMessage = nil
        successMessage = nil
        let t = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !b.isEmpty else {
            errorMessage = "Vul een titel en een bericht in."
            return
        }

        var doc: [String: Any] = [
            "type": kind.rawValue,
            "title": t,
            "body": b,
        ]

        switch kind {
        case .message:
            break
        case .calendarEvent:
            var event: [String: Any] = [
                "start": eventStart,
                "visibility": eventVisibility.rawValue,
            ]
            if hasEventEnd {
                event["end"] = eventEnd
            }
            let desc = eventDescriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !desc.isEmpty {
                event["description"] = desc
            }
            doc["event"] = event
        case .openingHours:
            let dateStr = ohDateText.trimmingCharacters(in: .whitespacesAndNewlines)
            let reasonStr = ohReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
            let hoursStr = ohHoursText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !dateStr.isEmpty, !reasonStr.isEmpty, !hoursStr.isEmpty else {
                errorMessage = "Vul datum, reden en tijden in bij openingstijden."
                return
            }
            doc["openingHours"] = [
                "location": ohLocation.rawValue,
                "date": dateStr,
                "reason": reasonStr,
                "hours": hoursStr,
            ]
        }

        isSending = true
        defer { isSending = false }
        do {
            _ = try await meteor.call("notifications.insert", params: [doc])
            successMessage = "De notificatie is verstuurd."
            resetAfterSend()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetAfterSend() {
        titleText = ""
        bodyText = ""
        eventStart = Date()
        hasEventEnd = false
        eventEnd = Date().addingTimeInterval(3600)
        eventVisibility = .members
        eventDescriptionText = ""
        ohLocation = .clubhouse
        ohDateText = ""
        ohReasonText = ""
        ohHoursText = ""
    }
}
