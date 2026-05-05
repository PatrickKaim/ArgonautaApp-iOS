import SwiftUI

struct DisplayAnnouncementsAdminView: View {
    @State private var viewModel = DisplayAnnouncementsAdminViewModel()
    @State private var pendingDeleteId: String?
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(
                    "Teksten verschijnen op het narrowcasting-scherm in het clubhuis en op de startpagina bij actieve mededelingen."
                )
                .font(ArgoTheme.font(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nieuwe mededeling")
                        .font(ArgoTheme.font(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Tekst", text: $viewModel.newText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.sentences)
                        .onSubmit { Task { await viewModel.add() } }

                    Button {
                        Task { await viewModel.add() }
                    } label: {
                        HStack {
                            if viewModel.isBusy { ProgressView().tint(.white) }
                            Text("Toevoegen")
                                .font(ArgoTheme.font(size: 16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ArgoTheme.blueNormal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(viewModel.isBusy || viewModel.newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Lijst")
                        .font(ArgoTheme.font(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    if viewModel.rows.isEmpty {
                        Text("Nog geen mededelingen.")
                            .font(ArgoTheme.font(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    } else {
                        ForEach(viewModel.rows) { row in
                            announcementRow(row)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ArgoTheme.groupedBackground)
        .navigationTitle("Belangrijke mededelingen")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
        .onChange(of: viewModel.errorMessage) { _, new in
            showError = new != nil
        }
        .alert("Fout", isPresented: $showError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog(
            "Deze mededeling verwijderen?",
            isPresented: Binding(
                get: { pendingDeleteId != nil },
                set: { if !$0 { pendingDeleteId = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Verwijderen", role: .destructive) {
                if let id = pendingDeleteId {
                    Task { await viewModel.remove(id: id) }
                }
                pendingDeleteId = nil
            }
            Button("Annuleren", role: .cancel) {
                pendingDeleteId = nil
            }
        } message: {
            Text("Dit haalt de regel van het narrowcasting-scherm.")
        }
    }

    @ViewBuilder
    private func announcementRow(_ row: DisplayAnnouncementsAdminViewModel.Row) -> some View {
        let isEditing = viewModel.editingId == row.id

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "megaphone.fill")
                    .font(.argoCaption)
                    .foregroundStyle(.secondary)

                if isEditing {
                    TextField("Tekst", text: $viewModel.editingText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...6)
                } else {
                    Text(row.text)
                        .font(ArgoTheme.font(size: 15))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 0)

                if isEditing {
                    Button("Opslaan") {
                        Task { await viewModel.saveEdit() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ArgoTheme.interactiveAccent)
                    .controlSize(.small)
                    Button("Annuleer") {
                        viewModel.cancelEdit()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button {
                        viewModel.beginEdit(row)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .tint(ArgoTheme.interactiveAccent)
                    .accessibilityLabel("Bewerken")

                    Button {
                        pendingDeleteId = row.id
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .tint(.red)
                    .accessibilityLabel("Verwijderen")
                }
            }

            if !row.active {
                Text("Inactief")
                    .font(ArgoTheme.font(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(ArgoTheme.adaptiveSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ArgoTheme.adaptiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
