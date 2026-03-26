import SwiftUI

struct OWHTrainingView: View {
    @State private var viewModel = OWHTrainingViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    LoadingView(message: "Trainingen laden...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if viewModel.trainings.isEmpty {
                    EmptyStateView(icon: "sportscourt.fill", title: "Geen trainingen")
                        .padding(.top, 40)
                } else {
                    ForEach(viewModel.trainings) { training in
                        trainingCard(training)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ArgoTheme.groupedBackground)
        .navigationTitle("OWH Training")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.loadData() }
        .task { await viewModel.loadData() }
    }

    // MARK: - Training Card

    @ViewBuilder
    private func trainingCard(_ training: OWHTrainingViewModel.Training) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: datum + tijd
            VStack(alignment: .leading, spacing: 2) {
                Text(training.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().locale(Locale(identifier: "nl_NL"))))
                    .font(ArgoTheme.font(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("\(training.startTime) – \(training.endTime)")
                    .font(ArgoTheme.font(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            Divider()
                .padding(.bottom, 12)

            // Poll + Signup side-by-side on iPad, stacked on iPhone
            VStack(spacing: 16) {
                // Poll: voorkeuren progress bars
                if let att = viewModel.attendees[training.id], att.totalAttendees > 0 {
                    pollSection(training: training, attendees: att)
                }

                // Signup form
                signupSection(training: training)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: ArgoTheme.cardShadow, radius: 6, y: 2)
    }

    // MARK: - Poll Section (Progress Bars)

    @ViewBuilder
    private func pollSection(training: OWHTrainingViewModel.Training, attendees: OWHTrainingViewModel.TrainingAttendees) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VOORKEUREN")
                .font(ArgoTheme.font(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)

            ForEach(OWHTrainingViewModel.pollTypeIds, id: \.self) { typeId in
                let users = attendees.byType[typeId] ?? []
                let count = users.count
                let fraction = attendees.totalAttendees > 0
                    ? Double(count) / Double(attendees.totalAttendees)
                    : 0

                VStack(spacing: 4) {
                    HStack {
                        Text(OWHTrainingViewModel.typeLabels[typeId] ?? typeId)
                            .font(ArgoTheme.font(size: 14, weight: .medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        if !users.isEmpty {
                            avatarStack(users: users)
                        }

                        Text("\(count)")
                            .font(ArgoTheme.font(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(minWidth: 20, alignment: .trailing)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(ArgoTheme.blueNormal)
                                .frame(width: max(0, geo.size.width * fraction), height: 6)
                                .animation(.easeInOut(duration: 0.3), value: fraction)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Avatar Stack

    @ViewBuilder
    private func avatarStack(users: [OWHTrainingViewModel.AttendeeInfo]) -> some View {
        HStack(spacing: -6) {
            ForEach(users.prefix(4)) { user in
                Circle()
                    .fill(ArgoTheme.blueLight)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(ArgoTheme.font(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .overlay(
                        Circle().stroke(Color(.systemBackground), lineWidth: 1.5)
                    )
            }
            if users.count > 4 {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 22, height: 22)
                    .overlay {
                        Text("+\(users.count - 4)")
                            .font(ArgoTheme.font(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .overlay(
                        Circle().stroke(Color(.systemBackground), lineWidth: 1.5)
                    )
            }
        }
    }

    // MARK: - Signup Section (Toggles)

    @ViewBuilder
    private func signupSection(training: OWHTrainingViewModel.Training) -> some View {
        let isOn = training.isSignedUp
        let isDisabled = viewModel.loadingTraining.contains(training.id)

        VStack(alignment: .leading, spacing: 12) {
            Text("JOUW AANMELDING")
                .font(ArgoTheme.font(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)

            // Toggle: Ik kom trainen
            HStack {
                Text("Ik kom trainen")
                    .font(ArgoTheme.font(size: 15, weight: .medium))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        Task { await viewModel.setAttending(trainingId: training.id, on: newValue) }
                    }
                ))
                .labelsHidden()
                .tint(ArgoTheme.interactiveAccent)
                .disabled(isDisabled)
            }

            if isOn {
                Divider()

                // Type training toggles
                Text("Type training (optioneel)")
                    .font(ArgoTheme.font(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(OWHTrainingViewModel.trainingTypes, id: \.self) { typeId in
                        let selected = viewModel.selectedTypes[training.id]?.contains(typeId) ?? false

                        HStack {
                            Text(OWHTrainingViewModel.typeLabels[typeId] ?? typeId)
                                .font(ArgoTheme.font(size: 15))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { selected },
                                set: { _ in
                                    Task { await viewModel.toggleType(trainingId: training.id, typeId: typeId) }
                                }
                            ))
                            .labelsHidden()
                            .tint(ArgoTheme.interactiveAccent)
                            .disabled(isDisabled)
                        }
                    }
                }

                Text("Zet aan voor je voorkeur(en). Geen keuze = geen voorkeur.")
                    .font(ArgoTheme.font(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
