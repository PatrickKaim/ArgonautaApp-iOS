import Foundation

enum URLResolver {
    /// In DEBUG: zelfde host als `ARGO_METEOR_WS` (LAN-IP van de Mac), anders localhost — zodat relatieve media-URL's op een fysieke iPhone laden.
    #if DEBUG
    static var baseURL: String {
        let ws = ProcessInfo.processInfo.environment["ARGO_METEOR_WS"] ?? ""
        guard !ws.isEmpty, let u = URL(string: ws), let host = u.host else {
            return "http://127.0.0.1:3000"
        }
        let port = u.port.map { ":\($0)" } ?? ""
        let httpScheme: String
        switch u.scheme?.lowercased() {
        case "wss": httpScheme = "https"
        case "ws": httpScheme = "http"
        default: httpScheme = "http"
        }
        return "\(httpScheme)://\(host)\(port)"
    }
    #else
    static let baseURL = "https://argonauta.nl"
    #endif

    static func resolve(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return path }
        return "\(baseURL)\(path)"
    }

    static func resolveURL(_ path: String?) -> URL? {
        guard let resolved = resolve(path) else { return nil }
        return URL(string: resolved)
    }
}
