import Foundation
import Observation
import MeteorDDPKit

/// Serialiseert parallelle `connect()`-aanroepen zonder `NSLock` in async (Swift 6).
private actor ConnectCoordinator {
    private var inFlight: Task<Void, Never>?

    /// Tweede caller wacht op de eerste poging tot die klaar is.
    func run(_ operation: @escaping @Sendable () async -> Void) async {
        if let existing = inFlight {
            await existing.value
            return
        }
        let task = Task { await operation() }
        inFlight = task
        await task.value
        inFlight = nil
    }

    /// Bij disconnect/forceReconnect: anders blijft een vastgelopen `connect()` de coordinator blokkeren.
    func reset() {
        inFlight?.cancel()
        inFlight = nil
    }
}

@Observable
final class MeteorService {
    static let shared = MeteorService()

    private(set) var isConnected = false
    private(set) var isConnecting = false
    private(set) var userId: String?
    var connectionError: String?

    private(set) var client: DDPClient?
    private var stateTask: Task<Void, Never>?

    private let connectCoordinator = ConnectCoordinator()

    #if DEBUG
    /// - **Simulator op dezelfde Mac:** `ws://127.0.0.1:3000/websocket` (standaard).
    /// - **Fysieke iPhone:** `127.0.0.1` is op de telefoon de telefoon zelf — gebruik het **LAN-IP van je Mac**
    ///   (Terminal: `ipconfig getifaddr en0`) of zet in Xcode: Scheme → Run → Arguments → Environment Variables:
    ///   `ARGO_METEOR_WS` = `ws://192.168.x.x:3000/websocket` (zelfde WiFi als de Mac).
    /// - **Productie testen (Simulator of device, DEBUG):** `ARGO_METEOR_WS` = `wss://argonauta.nl/websocket` — zie `DEV_LAN.md`.
    private var serverURL: String {
        if let override = ProcessInfo.processInfo.environment["ARGO_METEOR_WS"], !override.isEmpty {
            return override
        }
        return "ws://127.0.0.1:3000/websocket"
    }
    #else
    private let serverURL = "wss://argonauta.nl/websocket"
    #endif

    private init() {}

    /// Zelfde host/poort als de WebSocket, maar `http(s)://` — voor bereikbaarheid **zonder** DDP `connect()`.
    /// De WebSocket-kit hervat bij connection refused soms geen continuation; HTTP faalt dan wel netjes binnen seconden.
    func reachabilityHTTPURL() -> URL? {
        guard let ws = URL(string: serverURL) else { return nil }
        var components = URLComponents()
        components.scheme = (ws.scheme?.lowercased() == "wss") ? "https" : "http"
        components.host = ws.host
        components.port = ws.port
        components.path = "/"
        return components.url
    }

    /// Lichte GET naar de Meteor-root; `false` bij connection refused / timeout. Gebruikt geen WebSocket.
    func pingServerHTTP() async -> Bool {
        guard let url = reachabilityHTTPURL() else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.httpMethod = "GET"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<600).contains(http.statusCode)
        } catch {
            return false
        }
    }

    func connect(token: String? = nil) async {
        if isConnected { return }
        await connectCoordinator.run { [self] in
            await self.performConnect(token: token)
        }
    }

    /// WebSocket klaar voor `call` / `subscribe` (o.a. magic link na parallelle `connect`).
    func ensureConnected() async {
        if isConnected { return }
        await connect()
        var waited: Double = 0
        let maxWait = 30.0
        while !isConnected && waited < maxWait {
            if connectionError != nil { break }
            try? await Task.sleep(for: .milliseconds(100))
            waited += 0.1
        }
    }

    private func performConnect(token: String?) async {
        isConnecting = true
        connectionError = nil

        guard let url = URL(string: serverURL) else {
            connectionError = "Ongeldige server URL"
            isConnecting = false
            return
        }

        let config = DDPClientConfiguration(
            url: url,
            reconnectStrategy: .exponentialBackoff(initial: 1, max: 30, maxRetries: .max)
        )
        let ddp = DDPClient(configuration: config)
        self.client = ddp

        observeConnectionState(ddp)

        do {
            // Harde timeout: bij connection refused / vastlopende WebSocket kan de kit soms de continuation niet hervatten.
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await ddp.connect() }
                group.addTask {
                    try await Task.sleep(for: .seconds(14))
                    throw MeteorConnectTimeout()
                }
                defer { group.cancelAll() }
                try await group.next()!
            }

            let resumeToken = token ?? KeychainService.getToken()
            if let resumeToken {
                let result = try await ddp.loginWithToken(resumeToken)
                userId = result.userId
                KeychainService.saveToken(result.token)
                KeychainService.saveUserId(result.userId)
            }

            isConnecting = false
        } catch is MeteorConnectTimeout {
            connectionError = "Timeout — server reageert niet"
            isConnecting = false
            stateTask?.cancel()
            client?.disconnect()
            client = nil
            isConnected = false
        } catch {
            connectionError = error.localizedDescription
            isConnecting = false
            stateTask?.cancel()
            client?.disconnect()
            client = nil
            isConnected = false
        }
    }

    func loginWithToken(_ token: String) async throws {
        await ensureConnected()
        guard let client, isConnected else { throw MeteorServiceError.notConnected }
        let result = try await client.loginWithToken(token)
        userId = result.userId
        KeychainService.saveToken(result.token)
        KeychainService.saveUserId(result.userId)
    }

    func logout() async {
        try? await client?.logout()
        userId = nil
        KeychainService.clearAll()
        client?.disconnect()
        client = nil
        isConnected = false
    }

    @discardableResult
    func call(_ method: String, params: [Any] = []) async throws -> Any? {
        await ensureConnected()
        guard let client, isConnected else { throw MeteorServiceError.notConnected }
        return try await client.call(method, params: params)
    }

    func subscribe(_ name: String, params: [Any] = []) async throws -> DDPSubscription {
        await ensureConnected()
        guard let client, isConnected else { throw MeteorServiceError.notConnected }
        return try await client.subscribe(name, params: params)
    }

    func collection(_ name: String) -> DDPCollection? {
        client?.collection(name)
    }

    func disconnect() {
        stateTask?.cancel()
        client?.disconnect()
        client = nil
        isConnected = false
    }

    /// Na offline → online: oude WebSocket weggooien en opnieuw verbinden (anders blijft DDP dood terwijl HTTP weer OK is).
    func forceReconnect() async {
        disconnect()
        await connectCoordinator.reset()
        await connect()
    }

    private func observeConnectionState(_ ddp: DDPClient) {
        stateTask?.cancel()
        stateTask = Task { [weak self] in
            for await state in ddp.connectionState {
                await MainActor.run {
                    guard let self else { return }
                    switch state {
                    case .connected:
                        self.isConnected = true
                        self.connectionError = nil
                        // Los van de hoofd-DDP-flow houden (geen sync op main actor-keten blokkeren)
                        Task(priority: .utility) {
                            await PushNotificationManager.syncTokenWithServer()
                        }
                    case .disconnected:
                        self.isConnected = false
                    case .reconnecting:
                        self.isConnected = false
                    case .connecting:
                        break
                    }
                }
            }
        }
    }
}

enum MeteorServiceError: LocalizedError {
    case notConnected

    nonisolated var errorDescription: String? {
        switch self {
        case .notConnected: return "Niet verbonden met de server"
        }
    }
}

private struct MeteorConnectTimeout: Error {}
