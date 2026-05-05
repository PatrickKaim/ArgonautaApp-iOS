import SwiftUI

private struct LineEditToken: Identifiable, Hashable {
    let id: String
}

struct ShoppingListDetailView: View {
    let listId: String
    @State private var viewModel: ShoppingListDetailViewModel
    @State private var showAddProduct = false
    @State private var selectedProductId: String?
    @State private var addQty = 1
    @State private var adhocLabel = ""
    @State private var adhocQty = 1
    @State private var editingLineToken: LineEditToken?

    init(listId: String) {
        self.listId = listId
        _viewModel = State(wrappedValue: ShoppingListDetailViewModel(listId: listId))
    }

    var body: some View {
        List {
            if let err = viewModel.errorMessage {
                Section {
                    Text(err).foregroundStyle(.red)
                }
            }

            Section {
                ForEach(viewModel.lines) { line in
                    lineRow(line)
                }
            } header: {
                Text("Regels")
            }

            Section {
                Button {
                    showAddProduct = true
                    selectedProductId = viewModel.productOptions.first?.id
                    addQty = 1
                } label: {
                    Label("Product uit catalogus", systemImage: "plus.circle.fill")
                }
                .disabled(viewModel.productOptions.isEmpty)

                if viewModel.isSupplierStockList && viewModel.productOptions.isEmpty {
                    Text("Geen extra producten voor deze leverancier op de lijst.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Toevoegen")
            }

            if viewModel.allowsAdhocLines {
                Section {
                    TextField("Omschrijving (nog niet in Producten)", text: $adhocLabel)
                    Stepper("Aantal: \(adhocQty)", value: $adhocQty, in: 1...999)
                    Button("Vrije regel toevoegen") {
                        Task {
                            await viewModel.addAdhoc(label: adhocLabel, orderPackages: adhocQty)
                            adhocLabel = ""
                            adhocQty = 1
                        }
                    }
                    .disabled(adhocLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("Zonder catalogusproduct")
                } footer: {
                    Text("Na de aanschaf kun je het product alsnog in clubhuisbeheer → Producten vastleggen.")
                }
            }
        }
        .navigationTitle(viewModel.listTitle.isEmpty ? "Lijst" : viewModel.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.start()
        }
        .refreshable {
            await viewModel.start()
        }
        .sheet(item: $editingLineToken) { token in
            ShoppingLineEditSheet(lineId: token.id, viewModel: viewModel)
        }
        .sheet(isPresented: $showAddProduct) {
            NavigationStack {
                Form {
                    Picker("Product", selection: $selectedProductId) {
                        ForEach(viewModel.productOptions) { p in
                            Text("\(p.name) (\(p.unit))").tag(Optional(p.id))
                        }
                    }
                    Stepper("Aantal: \(addQty)", value: $addQty, in: 1...999)
                }
                .navigationTitle("Product toevoegen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuleer") { showAddProduct = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Voeg toe") {
                            guard let pid = selectedProductId else { return }
                            Task {
                                await viewModel.addManualProduct(productId: pid, orderPackages: addQty)
                                showAddProduct = false
                            }
                        }
                        .disabled(selectedProductId == nil)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func lineRow(_ line: ShoppingListDetailViewModel.Line) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                Task { await viewModel.setPicked(itemId: line.id, picked: !line.picked) }
            } label: {
                Image(systemName: line.picked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(line.picked ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(line.picked ? "Gepakt" : "Niet gepakt")

            VStack(alignment: .leading, spacing: 4) {
                Text(line.displayName + line.unitSuffix)
                    .font(.body.weight(line.picked ? .regular : .medium))
                    .foregroundStyle(line.picked ? .secondary : .primary)
                    .strikethrough(line.picked, color: .secondary)
                    .multilineTextAlignment(.leading)

                Text("Voorgesteld: \(line.suggestedPackages) · Te bestellen: \(line.orderPackages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                editingLineToken = LineEditToken(id: line.id)
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bewerken: bestellen, volgende keer, verwijderen")
        }
        .padding(.vertical, 4)
        .opacity(line.picked ? 0.55 : 1)
    }
}

// MARK: - Bewerken (sheet)

private struct ShoppingLineEditSheet: View {
    let lineId: String
    var viewModel: ShoppingListDetailViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    private var line: ShoppingListDetailViewModel.Line? {
        viewModel.lines.first { $0.id == lineId }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let line {
                    Section {
                        Stepper(
                            "Te bestellen: \(line.orderPackages)",
                            value: Binding(
                                get: { line.orderPackages },
                                set: { newVal in
                                    Task { await viewModel.updateOrderQty(itemId: line.id, qty: newVal) }
                                }
                            ),
                            in: 0...9999
                        )
                        Toggle(
                            "Volgende keer",
                            isOn: Binding(
                                get: { line.deferred },
                                set: { v in
                                    Task { await viewModel.setDeferred(itemId: line.id, deferred: v) }
                                }
                            )
                        )
                    } footer: {
                        Text("Wijzigingen worden direct opgeslagen.")
                            .font(.footnote)
                    }

                    Section {
                        Button("Verwijder regel", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                } else {
                    Section {
                        Text("Regel niet meer beschikbaar.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Regel bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gereed") {
                        dismiss()
                    }
                }
            }
            .alert("Regel verwijderen?", isPresented: $confirmDelete) {
                Button("Verwijderen", role: .destructive) {
                    Task {
                        await viewModel.removeLine(itemId: lineId)
                        dismiss()
                    }
                }
                Button("Annuleer", role: .cancel) {}
            } message: {
                Text("Deze regel wordt van de lijst gehaald.")
            }
        }
    }
}
