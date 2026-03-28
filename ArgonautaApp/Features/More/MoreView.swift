import SwiftUI

struct MoreView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("Activiteiten") {
                    NavigationLink { BarDutyView() } label: {
                        Label("Bardienst", systemImage: "wineglass.fill")
                    }

                    if appState.isOWHMember {
                        NavigationLink { OWHTrainingView() } label: {
                            Label("OWH Training", systemImage: "sportscourt.fill")
                        }
                    }
                }

                Section("Content") {
                    NavigationLink { MyBlogsView() } label: {
                        Label("Mijn artikelen", systemImage: "doc.text.fill")
                    }
                }

                if appState.canManageClubhouse {
                    Section("Clubhuis") {
                        NavigationLink { ShoppingListView() } label: {
                            Label("Boodschappenlijst", systemImage: "cart.fill")
                        }
                    }
                }

                if appState.canManageCMS {
                    Section("CMS") {
                        NavigationLink { NotificationsComposeView() } label: {
                            Label("Notificatie versturen", systemImage: "bell.badge.fill")
                        }
                    }
                }
            }
            .navigationTitle("Meer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
