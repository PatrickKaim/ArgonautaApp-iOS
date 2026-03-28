import SwiftUI
import SwiftData

private let magicLinkHostSubstring = "argonauta.nl"
private let magicLinkPathPrefix = "/auth/magic-link/"

@main
struct ArgonautaAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState.shared
    @State private var meteor = MeteorService.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedEvent.self,
            CachedWalletData.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(meteor)
                .modelContainer(sharedModelContainer)
                .task {
                    await appState.initialize()
                }
                .onOpenURL { url in
                    handleUniversalLink(url)
                }
                // Universal Links worden vaak via browsing activity afgeleverd, niet via onOpenURL.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    if let url = userActivity.webpageURL {
                        handleUniversalLink(url)
                    }
                }
        }
    }

    private func handleUniversalLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host,
              host.contains(magicLinkHostSubstring),
              components.path.hasPrefix(magicLinkPathPrefix) else { return }

        let token = components.path
            .replacingOccurrences(of: magicLinkPathPrefix, with: "")
            .removingPercentEncoding ?? ""

        guard !token.isEmpty else { return }

        Task {
            await appState.consumeMagicLinkFromUniversalLink(token)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch appState.authStatus {
            case .unknown:
                LaunchScreenView()
            case .loggedOut:
                LoginView()
            case .loggedIn:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.authStatus)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await appState.refreshServerReachability() }
            }
        }
    }
}

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            ArgoTheme.blueNormal.ignoresSafeArea()
            VStack(spacing: 20) {
                ArgoLogo(size: 120)
                ProgressView().tint(.white)
            }
        }
    }
}
