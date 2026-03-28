import Foundation

extension Notification.Name {
    /// Server weer bereikbaar (HTTP); DDP is opnieuw verbonden — views kunnen data verversen.
    static let meteorConnectionRestored = Notification.Name("meteorConnectionRestored")
}
