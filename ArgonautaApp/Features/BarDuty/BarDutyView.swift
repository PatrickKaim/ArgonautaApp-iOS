import SwiftUI

struct BarDutyView: View {
    @State private var viewModel = BarDutyViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isLoading {
                    LoadingView(message: "Bardiensten laden...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if viewModel.groupName == nil {
                    noGroupView
                } else {
                    groupHeader
                    openSlotsSection
                    assignedSlotsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ArgoTheme.groupedBackground)
        .navigationTitle("Bardienst")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.loadData() }
        .task { await viewModel.loadData() }
        .alert("Fout", isPresented: showErrorBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var showErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    // MARK: - No Group

    private var noGroupView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundStyle(ArgoTheme.iconAccent)
            Text("Je bent niet ingedeeld in een bardienstgroep.")
                .font(ArgoTheme.font(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Group Header

    private var groupHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(ArgoTheme.interactiveAccent)
                Text("Mijn groep: \(viewModel.groupName ?? "")")
                    .font(ArgoTheme.font(size: 17, weight: .semibold))
            }
            Text("Groepsindeling wordt beheerd door het bestuur.")
                .font(ArgoTheme.font(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Open Slots

    private var openSlotsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open datums")
                .font(ArgoTheme.font(size: 16, weight: .semibold))

            if viewModel.openSlots.isEmpty {
                Text("Alle datums zijn bezet.")
                    .font(ArgoTheme.font(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.openSlots) { slot in
                        HStack {
                            Text(formatDate(slot.date))
                                .font(ArgoTheme.font(size: 15))

                            Spacer()

                            Button {
                                Task { await viewModel.signUp(slot: slot) }
                            } label: {
                                Text("Aanmelden")
                                    .font(ArgoTheme.font(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(ArgoTheme.blueNormal)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.vertical, 10)

                        if slot.id != viewModel.openSlots.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: ArgoTheme.cardShadow, radius: 6, y: 2)
    }

    // MARK: - Assigned Slots

    private var assignedSlotsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bezette datums")
                .font(ArgoTheme.font(size: 16, weight: .semibold))

            if viewModel.assignedSlots.isEmpty {
                Text("Geen datums met iemand ingepland.")
                    .font(ArgoTheme.font(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.assignedSlots) { slot in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatDate(slot.date))
                                        .font(ArgoTheme.font(size: 15, weight: .medium))

                                    HStack(spacing: 4) {
                                        Text(slot.assignedName ?? "Lid")
                                            .font(ArgoTheme.font(size: 14))
                                            .foregroundStyle(.secondary)

                                        if slot.isMySlot {
                                            Text("(jij)")
                                                .font(ArgoTheme.font(size: 14, weight: .medium))
                                                .foregroundStyle(ArgoTheme.interactiveAccent)
                                        }
                                    }

                                    if slot.reserveCount > 0 {
                                        Text("Reserves: \(slot.reserveCount)")
                                            .font(ArgoTheme.font(size: 12))
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                slotActions(slot)
                            }
                        }
                        .padding(.vertical, 10)

                        if slot.id != viewModel.assignedSlots.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: ArgoTheme.cardShadow, radius: 6, y: 2)
    }

    // MARK: - Slot Actions

    @ViewBuilder
    private func slotActions(_ slot: BarDutyViewModel.Slot) -> some View {
        if slot.isMySlot {
            Button {
                Task { await viewModel.signOff(slot: slot) }
            } label: {
                Text("Afmelden")
                    .font(ArgoTheme.font(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
        } else if slot.isMyReserve {
            Button {
                Task { await viewModel.removeReserve(slot: slot) }
            } label: {
                Text("Reserve annuleren")
                    .font(ArgoTheme.font(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
        } else {
            Button {
                Task { await viewModel.signUpAsReserve(slot: slot) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.plus")
                        .font(ArgoTheme.font(size: 12))
                    Text("Reserve")
                        .font(ArgoTheme.font(size: 13, weight: .medium))
                }
                .foregroundStyle(ArgoTheme.interactiveAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(ArgoTheme.interactiveAccent, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "EEE d MMM yyyy"
        return f.string(from: date)
    }
}
