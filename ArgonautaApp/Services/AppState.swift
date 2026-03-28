import SwiftUI
import UIKit
import UserNotifications
import Observation
import Foundation

enum ChallengeStatus {
    case pending
    case completed
    case expired
}

@Observable
final class AppState {
    static let shared = AppState()

    enum AuthStatus: Equatable {
        case unknown
        case loggedOut
        case loggedIn
    }

    /// Geen token in Keychain → meteen login tonen i.p.v. lang LaunchScreen + `unknown`.
    private(set) var authStatus: AuthStatus = KeychainService.getToken() == nil ? .loggedOut : .unknown
    private(set) var isOWHMember = false
    private(set) var canManageClubhouse = false
    private(set) var canManageCMS = false
    private(set) var displayName = ""

    /// Laatste fout bij openen van een magic link (Universal Link / handoff); voor feedback op het wachtscherm.
    private(set) var lastMagicLinkError: String?

    /// `nil` = eerste check nog bezig; `true`/`false` na HTTP-ping (zelfde host als WebSocket, geen DDP).
    private(set) var serverReachable: Bool?

    /// Verhoogt na DDP-reconnect (optioneel voor `.onChange` in views).
    private(set) var dataRefreshGeneration: Int = 0

    private let meteor = MeteorService.shared
    private var previousServerReachable: Bool?
    private var reachabilityTask: Task<Void, Never>?
    private var reachabilityStarted = false

    private init() {}

    /// Periodieke check: eerste meting gebeurt in `initialize()`; daarna elke minuut.
    func startReachabilityMonitoring() {
        guard !reachabilityStarted else { return }
        reachabilityStarted = true
        reachabilityTask = Task { @MainActor [weak self] in
            await self?.runReachabilityLoop()
        }
    }

    /// Updates op MainActor zodat `@Observable` + SwiftUI de login-banner betrouwbaar verversen.
    @MainActor
    private func runReachabilityLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { break }
            let ok = await checkServerReachability()
            await applyServerReachability(ok)
        }
    }

    /// Eén directe check (bijv. na terugkeren naar de app).
    func refreshServerReachability() async {
        let ok = await checkServerReachability()
        await applyServerReachability(ok)
    }

    /// Zet `serverReachable`; bij overgang offline → online, of HTTP OK maar DDP nog dood: opnieuw verbinden.
    private func applyServerReachability(_ ok: Bool) async {
        await MainActor.run {
            let was = self.previousServerReachable
            self.previousServerReachable = ok
            self.serverReachable = ok
            // Geen reconnect bij eerste meting (was == nil): `resumeMeteorSessionAfterLaunch` doet de eerste connect.
            let ddpDeadWhileHttpOk = ok && was == true && !self.meteor.isConnected
            let cameBackOnline = ok && was == false
            if cameBackOnline || ddpDeadWhileHttpOk,
               self.authStatus == .loggedIn,
               KeychainService.getToken() != nil {
                Task { await self.reconnectMeteorAfterRecovery() }
            }
        }
    }

    /// HTTP zegt weer OK terwijl DDP nog een dode socket heeft — `forceReconnect` + profiel + notificatie voor tab-data.
    private func reconnectMeteorAfterRecovery() async {
        guard await MainActor.run(body: { self.authStatus == .loggedIn }) else { return }
        guard KeychainService.getToken() != nil else { return }
        await meteor.forceReconnect()
        await loadUserProfile()
        await MainActor.run {
            self.dataRefreshGeneration += 1
            NotificationCenter.default.post(name: .meteorConnectionRestored, object: nil)
        }
    }

    /// HTTP GET naar de Meteor-host (localhost:3000 of productie); **geen** `ddp.connect()` — die kit lekt bij refused soms de continuation.
    func checkServerReachability() async -> Bool {
        await meteor.pingServerHTTP()
    }

    func initialize() async {
        startReachabilityMonitoring()

        // Vóór login/main UI: eerste HTTP-ping synchroon (achtergrondtask was te laat → `serverReachable` bleef `nil`).
        let firstOk = await checkServerReachability()
        await applyServerReachability(firstOk)

        guard KeychainService.getToken() != nil else {
            await MainActor.run { self.authStatus = .loggedOut }
            return
        }

        // Geen `await meteor.connect()` hier: bij offline server kan DDP `connect()` vastlopen → splash blijft op `.unknown`.
        await MainActor.run { self.authStatus = .loggedIn }
        Task { await self.resumeMeteorSessionAfterLaunch() }
    }

    /// DDP-sessie na cold start; faalt mee als server weg is (token ongeldig → uitloggen).
    private func resumeMeteorSessionAfterLaunch() async {
        await meteor.connect()
        let uid = await MainActor.run { self.meteor.userId }
        if uid == nil {
            await MainActor.run {
                self.authStatus = .loggedOut
                KeychainService.clearAll()
                self.isOWHMember = false
                self.canManageClubhouse = false
                self.canManageCMS = false
                self.displayName = ""
            }
            return
        }
        await loadUserProfile()
    }

    /// Fallback: 8-cijferige code per e-mail (zelfde als magic link qua account).
    func requestEmailLoginCode(email: String) async throws {
        _ = try await meteor.call("auth.requestEmailLoginCode", params: [email, "nl"])
    }

    func verifyEmailLoginCode(email: String, code: String) async throws {
        var verifyResult: Any?
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                if attempt > 0 { try await Task.sleep(for: .milliseconds(500)) }
                verifyResult = try await meteor.call("auth.verifyEmailLoginCode", params: [email, code])
                lastError = nil
                break
            } catch {
                lastError = error
                if Self.isTransientConnectionError(error), attempt < 2 { continue }
                throw error
            }
        }
        guard let dict = verifyResult as? [String: Any], let loginToken = dict["loginToken"] as? String else {
            throw lastError ?? MeteorServiceError.notConnected
        }
        try await Task.sleep(for: .milliseconds(300))
        for attempt in 0..<3 {
            do {
                if attempt > 0 { try await Task.sleep(for: .milliseconds(500)) }
                try await loginWithToken(loginToken)
                return
            } catch {
                if Self.isTransientConnectionError(error), attempt < 2 { continue }
                throw error
            }
        }
    }

    /// Stuur magic link naar e-mail, retourneert challengeId voor polling
    func sendMagicLink(email: String) async throws -> String? {
        await MainActor.run { lastMagicLinkError = nil }
        let result = try await meteor.call("auth.sendMagicLink", params: [email, "nl", "ios"])
        let dict = result as? [String: Any]
        return dict?["challengeId"] as? String
    }

    /// Poll de server om te checken of de magic link is geklikt
    func checkLoginChallenge(challengeId: String) async throws -> ChallengeStatus {
        let result = try await meteor.call("auth.checkLoginChallenge", params: [challengeId])
        guard let dict = result as? [String: Any], let status = dict["status"] as? String else {
            return .expired
        }
        switch status {
        case "completed":
            if let loginToken = dict["loginToken"] as? String {
                try await loginWithToken(loginToken)
            }
            return .completed
        case "pending":
            return .pending
        default:
            return .expired
        }
    }

    /// Verifieer magic link token direct via DDP (Universal Links)
    func verifyMagicLinkToken(_ token: String) async throws {
        // 1) RPC — bij "connection abort" / netwerkflap opnieuw (token is dan nog niet verbruikt).
        var verifyResult: Any?
        var verifyLastError: Error?
        for attempt in 0..<3 {
            do {
                if attempt > 0 { try await Task.sleep(for: .milliseconds(500)) }
                verifyResult = try await meteor.call("auth.verifyMagicLinkToken", params: [token])
                verifyLastError = nil
                break
            } catch {
                verifyLastError = error
                if Self.isTransientConnectionError(error), attempt < 2 { continue }
                throw error
            }
        }
        guard let dict = verifyResult as? [String: Any], let loginToken = dict["loginToken"] as? String else {
            throw verifyLastError ?? MeteorServiceError.notConnected
        }
        // Korte pauze na RPC: sommige WebSocket-stacks laten de verbinding even onstabiel; direct `login` erna geeft ECONNABORTED.
        try await Task.sleep(for: .milliseconds(300))
        // 2) Client-login met zelfde resume token — apart retry (verify is al geslaagd).
        for attempt in 0..<3 {
            do {
                if attempt > 0 { try await Task.sleep(for: .milliseconds(500)) }
                try await loginWithToken(loginToken)
                return
            } catch {
                if Self.isTransientConnectionError(error), attempt < 2 { continue }
                throw error
            }
        }
    }

    /// ECONNABORTED / NSURLError / "Software caused connection abort" — vaak tijdelijk na app-switch of TLS.
    private static func isTransientConnectionError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut, NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed, NSURLErrorNotConnectedToInternet:
                return true
            default:
                break
            }
        }
        if ns.domain == NSPOSIXErrorDomain, ns.code == 53 { return true }
        let d = error.localizedDescription.lowercased()
        if d.contains("connection abort") || d.contains("software caused connection abort") { return true }
        if d.contains("network connection lost") { return true }
        return false
    }

    /// Universal Link / browsing activity: zelfde als `verifyMagicLinkToken`, maar zet `lastMagicLinkError` i.p.v. te slikken.
    func consumeMagicLinkFromUniversalLink(_ token: String) async {
        await MainActor.run { lastMagicLinkError = nil }
        do {
            try await verifyMagicLinkToken(token)
        } catch {
            await MainActor.run {
                lastMagicLinkError = error.localizedDescription
            }
        }
    }

    /// Login met een Meteor resume token
    func loginWithToken(_ token: String) async throws {
        if meteor.client == nil {
            await meteor.connect(token: token)
        } else {
            try await meteor.loginWithToken(token)
        }
        authStatus = .loggedIn
        await loadUserProfile()
    }

    func logout() async {
        await meteor.logout()
        authStatus = .loggedOut
        isOWHMember = false
        canManageClubhouse = false
        canManageCMS = false
        displayName = ""
        await MainActor.run {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        }
    }

    private func loadUserProfile() async {
        if let result = try? await meteor.call("users.getOwnCapabilities") as? [String: Any] {
            isOWHMember = result["isOWH"] as? Bool ?? false
            canManageClubhouse = result["canManageClubhouse"] as? Bool ?? false
            canManageCMS = result["canManageCMS"] as? Bool ?? false
            displayName = result["displayName"] as? String ?? ""
        }
    }
}
