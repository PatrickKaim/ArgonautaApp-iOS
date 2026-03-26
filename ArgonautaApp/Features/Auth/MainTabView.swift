import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var notificationsVM = NotificationsViewModel()

    var body: some View {
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
        .tint(ArgoTheme.interactiveAccent)
        .environment(notificationsVM)
        .task {
            await notificationsVM.start()
            PushNotificationManager.requestAuthorizationAndRegister()
            await PushNotificationManager.syncTokenWithServer()
        }
        .onDisappear {
            notificationsVM.stop()
        }
    }
}
