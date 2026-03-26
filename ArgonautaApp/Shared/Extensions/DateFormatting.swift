import Foundation

extension Date {
    nonisolated var shortDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateStyle = .medium
        return f.string(from: self)
    }

    nonisolated var longDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateStyle = .long
        return f.string(from: self)
    }

    nonisolated var timeString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.timeStyle = .short
        return f.string(from: self)
    }

    nonisolated var calendarDayString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "EE d MMM"
        return f.string(from: self)
    }

    nonisolated var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    nonisolated var startOfMonth: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: self)
        return cal.date(from: comps) ?? self
    }

    nonisolated var endOfMonth: Date {
        let cal = Calendar.current
        return cal.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? self
    }
}
