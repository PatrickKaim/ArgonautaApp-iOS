import SwiftUI

/// Route naar één boodschappenlijst. `navigationDestination` staat alleen op `MoreView` (één registratie per stack).
struct ShoppingListDetailRoute: Hashable {
    let listId: String
}

/// Clubhuis boodschappen: reactieve lijsten via `clubhouse.shoppingLists` (zie Argonauta_2026).
///
/// **Geen eigen `NavigationStack`:** `MoreView` levert al een stack. Een tweede stack hier
/// zorgde ervoor dat “terug” vanuit het detail soms de hele `ShoppingListView` wegpoptte
/// (terug naar Meer) in plaats van alleen het detail.
struct ShoppingListView: View {
    @State private var viewModel = ShoppingListsViewModel()
    @State private var showCreateList = false
    @State private var newListTitle = ""

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.lists.isEmpty {
                ProgressView("Laden…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = viewModel.errorMessage, viewModel.lists.isEmpty {
                ContentUnavailableView {
                    Label("Geen verbinding", systemImage: "wifi.slash")
                } description: {
                    Text(err)
                }
            } else if viewModel.lists.isEmpty {
                ContentUnavailableView {
                    Label("Geen open lijsten", systemImage: "cart")
                } description: {
                    Text("Tik op + voor een ad-hoc lijst. Leverancierslijsten verschijnen automatisch vanuit clubhuisbeheer (voorraad).")
                }
            } else {
                List {
                    ForEach(viewModel.lists) { list in
                        NavigationLink(value: ShoppingListDetailRoute(listId: list.id)) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(list.title)
                                        .font(.headline)
                                    HStack {
                                        Text(list.kindLabel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(list.lineCount) regels")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 8)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Boodschappen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newListTitle = ""
                    showCreateList = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Nieuwe lijst")
            }
        }
        .task {
            await viewModel.start()
        }
        .refreshable {
            await viewModel.start()
        }
        .sheet(isPresented: $showCreateList) {
            NavigationStack {
                Form {
                    TextField("Naam van de lijst", text: $newListTitle)
                        .textInputAutocapitalization(.sentences)
                    Text("Ad-hoc lijsten hebben geen koppeling met voorraad; handig voor eenmalige inkopen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Nieuwe lijst")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuleer") { showCreateList = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Maak aan") {
                            Task {
                                await viewModel.createList(title: newListTitle)
                                showCreateList = false
                            }
                        }
                        .disabled(newListTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}
