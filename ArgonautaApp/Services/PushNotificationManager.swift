import Foundation
import UIKit
import UserNotifications

/// Registreert het APNs device token bij de Meteor-server (`push.registerToken`).
/// Vereist: Push Notifications capability in Xcode + `Meteor.settings.private.push` op de server.
enum PushNotificationManager {
    private static let tokenKey = "apns_device_token_hex"

    static var storedTokenHex: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    /// Vraag toestemming en registreer voor remote notifications (na login).
    static func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// Bewaar token en stuur naar server als er een ingelogde gebruiker is.
    static func didRegisterDeviceToken(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: tokenKey)
        Task { await syncTokenWithServer() }
    }

    /// Roep aan na login / connect zodat het token gekoppeld wordt aan de user.
    static func syncTokenWithServer() async {
        guard let token = storedTokenHex else { return }
        guard MeteorService.shared.userId != nil else { return }
        guard MeteorService.shared.isConnected else { return }
        do {
            _ = try await MeteorService.shared.call("push.registerToken", params: [token, "ios"])
        } catch {
            // Token kan vóór login binnenkomen; bij volgende login opnieuw proberen.
            print("[Push] push.registerToken mislukt: \(error.localizedDescription)")
        }
    }
}
