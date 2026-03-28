import SwiftUI

/// CMS: notificaties naar alle leden — zelfde drie typen als de website.
struct NotificationsComposeView: View {
    @State private var viewModel = NotificationsComposeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(
                    "Iedereen met een inlogaccount ziet de melding bij het bel-icoon. "
                        + "Leden met push aan ontvangen ook een melding op hun telefoon."
                )
                .font(ArgoTheme.font(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                typePicker

                VStack(alignment: .leading, spacing: 8) {
                    Text("Titel")
                        .font(ArgoTheme.font(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Titel", text: $viewModel.titleText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.sentences)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bericht")
                        .font(ArgoTheme.font(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $viewModel.bodyText)
                        .font(ArgoTheme.font(size: 16))
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(ArgoTheme.adaptiveSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ArgoTheme.adaptiveBorder, lineWidth: 1)
                        )
                }

                if viewModel.kind == .calendarEvent {
                    calendarFields
                }

                if viewModel.kind == .openingHours {
                    openingHoursFields
                }

                Button {
                    Task { await viewModel.send() }
                } label: {
                    HStack {
                        if viewModel.isSending {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.isSending ? "Versturen…" : "Notificatie versturen")
                            .font(ArgoTheme.font(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.isSending ? ArgoTheme.blueNormal.opacity(0.7) : ArgoTheme.blueNormal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ArgoTheme.groupedBackground)
        .navigationTitle("Notificatie")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Fout", isPresented: errorBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Gelukt", isPresented: successBinding) {
            Button("OK") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Soort")
                .font(ArgoTheme.font(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker("Soort", selection: $viewModel.kind) {
                ForEach(NotificationComposeKind.allCases) { k in
                    Text(k.title).tag(k)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var calendarFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            DatePicker(
                "Start",
                selection: $viewModel.eventStart,
                displayedComponents: [.date, .hourAndMinute]
            )
            .environment(\.locale, Locale(identifier: "nl_NL"))

            Toggle("Eindtijd opgeven", isOn: $viewModel.hasEventEnd)
            if viewModel.hasEventEnd {
                DatePicker(
                    "Einde",
                    selection: $viewModel.eventEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .environment(\.locale, Locale(identifier: "nl_NL"))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Zichtbaarheid")
                    .font(ArgoTheme.font(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("Zichtbaarheid", selection: $viewModel.eventVisibility) {
                    ForEach(NotificationEventVisibility.allCases) { v in
                        Text(v.title).tag(v)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Extra toelichting (optioneel)")
                    .font(ArgoTheme.font(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Omschrijving voor de kalender", text: $viewModel.eventDescriptionText, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var openingHoursFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Locatie")
                    .font(ArgoTheme.font(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("Locatie", selection: $viewModel.ohLocation) {
                    ForEach(NotificationOhLocation.allCases) { loc in
                        Text(loc.title).tag(loc)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Datum (vrije tekst)")
                    .font(ArgoTheme.font(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("bijv. zaterdag 5 april", text: $viewModel.ohDateText)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tijden")
                    .font(ArgoTheme.font(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("bijv. 12:00 – 18:00", text: $viewModel.ohHoursText)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Reden")
                    .font(ArgoTheme.font(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Waarom wijken de tijden af?", text: $viewModel.ohReasonText)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Deze notificatie verloopt automatisch na twee dagen (zelfde als website).")
                .font(ArgoTheme.font(size: 12))
                .foregroundStyle(.orange)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var successBinding: Binding<Bool> {
        Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )
    }
}
