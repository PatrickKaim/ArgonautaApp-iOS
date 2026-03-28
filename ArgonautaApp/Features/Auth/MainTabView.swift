import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var notificationsVM = NotificationsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if appState.serverReachable == false {
                ServerOfflineBannerView()
            }

            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                CalendarView()
                    .tabItem { Label("Kalender", systemImage: "calendar") }
                    .tag(1)

                WalletView()
                    .tabItem { Label("Wallet", systemImage: "wallet.pass.fill") }
                    .tag(2)

                MoreView()
                    .tabItem { Label("Meer", systemImage: "ellipsis.circle.fill") }
                    .tag(3)
            }
        }
        .tint(ArgoTheme.interactiveAccent)
        .environment(notificationsVM)
        .task {
            await notificationsVM.start()
            PushNotificationManager.requestAuthorizationAndRegister()
            await PushNotificationManager.syncTokenWithServer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .meteorConnectionRestored)) { _ in
            Task {
                notificationsVM.stop()
                await notificationsVM.start()
            }
        }
        .onDisappear {
            notificationsVM.stop()
        }
    }
}

/// Waarschuwing boven de tabbar als DDP/`auth.connectionOk` faalt (periodiek opnieuw geprobeerd).
private struct ServerOfflineBannerView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.body)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Geen verbinding met de server")
                    .font(.argoCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("We proberen automatisch opnieuw (ongeveer elke minuut).")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.88))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemRed).opacity(0.92))
    }
}
