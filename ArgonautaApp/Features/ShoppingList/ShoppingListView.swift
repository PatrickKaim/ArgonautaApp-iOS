import SwiftUI

struct ShoppingListView: View {
    @State private var viewModel = ShoppingListViewModel()
    @State private var newItemName = ""
    @State private var showAddItem = false

    var body: some View {
        List {
            Section {
                ForEach(viewModel.activeItems) { item in
                    Button { Task { await viewModel.complete(itemId: item.id) } } label: {
                        Label(item.name, systemImage: "circle").foregroundStyle(.primary)
                    }
                }
            } header: {
                HStack {
                    Text("Te kopen")
                    Spacer()
                    Button { showAddItem = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }

            if !viewModel.completedItems.isEmpty {
                Section("Afgevinkt") {
                    ForEach(viewModel.completedItems) { item in
                        Label(item.name, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .strikethrough()
                    }
                }
            }
        }
        .navigationTitle("Boodschappenlijst")
        .refreshable { await viewModel.loadData() }
        .task { await viewModel.loadData() }
        .alert("Item toevoegen", isPresented: $showAddItem) {
            TextField("Productnaam", text: $newItemName)
            Button("Toevoegen") {
                Task { await viewModel.addItem(name: newItemName) }
                newItemName = ""
            }
            Button("Annuleren", role: .cancel) { newItemName = "" }
        }
    }
}
