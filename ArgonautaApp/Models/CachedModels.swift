import Foundation
import SwiftData

@Model
final class CachedEvent {
    @Attribute(.unique) var id: String
    var title: String
    var start: Date
    var end: Date?
    var eventDescription: String?
    var visibility: String

    init(id: String, title: String, start: Date, end: Date? = nil,
         eventDescription: String? = nil, visibility: String = "public") {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.eventDescription = eventDescription
        self.visibility = visibility
    }
}

@Model
final class CachedWalletData {
    @Attribute(.unique) var userId: String
    var balance: Int
    var cardCode: String?
    var lastUpdated: Date

    init(userId: String, balance: Int = 0, cardCode: String? = nil) {
        self.userId = userId
        self.balance = balance
        self.cardCode = cardCode
        self.lastUpdated = Date()
    }
}
