import SwiftUI

/// Pusht `ShoppingListView` via `NavigationLink(value:)` (zelfde patroon als detail, geen dubbele stack-registratie).
private enum MoreClubhouseRoute: Hashable {
    case shoppingLists
}

struct MoreView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("Activiteiten") {
                    NavigationLink { BarDutyView() } label: {
                        Label("Bardienst", systemImage: "wineglass.fill")
                    }

                    if appState.owhMenuTraining {
                        NavigationLink { OWHTrainingView() } label: {
                            Label("OWH Training", systemImage: "sportscourt.fill")
                        }
                    }
                    if appState.owhMenuCompetition {
                        NavigationLink {
                            OWHPlaceholderDetailView(
                                title: "OWH Competitie",
                                message: "Hier komt straks informatie over competities en het programma."
                            )
                        } label: {
                            Label("OWH Competitie", systemImage: "trophy.fill")
                        }
                    }
                    if appState.owhMenuResults {
                        NavigationLink {
                            OWHPlaceholderDetailView(
                                title: "OWH Uitslagen",
                                message: "Hier komt straks een overzicht van gespeelde wedstrijden en uitslagen."
                            )
                        } label: {
                            Label("OWH Uitslagen", systemImage: "list.bullet.rectangle.fill")
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
                        NavigationLink(value: MoreClubhouseRoute.shoppingLists) {
                            Label("Boodschappenlijst", systemImage: "cart.fill")
                        }
                    }
                }

                if appState.canManageCMS {
                    Section("CMS") {
                        NavigationLink { NotificationsComposeView() } label: {
                            Label("Push-notificatie versturen", systemImage: "bell.badge.fill")
                        }
                        NavigationLink { DisplayAnnouncementsAdminView() } label: {
                            Label("Belangrijke mededeling", systemImage: "megaphone.fill")
                        }
                    }
                }
            }
            .navigationTitle("Meer")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await appState.refreshCapabilities() }
            .navigationDestination(for: MoreClubhouseRoute.self) { route in
                switch route {
                case .shoppingLists:
                    ShoppingListView()
                }
            }
            .navigationDestination(for: ShoppingListDetailRoute.self) { route in
                ShoppingListDetailView(listId: route.listId)
            }
        }
    }
}
