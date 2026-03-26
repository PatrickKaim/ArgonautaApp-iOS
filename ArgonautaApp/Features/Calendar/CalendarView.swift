import SwiftUI

struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                weekdayHeader
                calendarGrid
                Divider()
                barDutyToggle
                dayDetailList
            }
            .background(ArgoTheme.groupedBackground)
            .navigationTitle("Kalender")
            .navigationBarTitleDisplayMode(.inline)
            // TabView houdt child views levend: .task draait maar één keer; onAppear bij elk tabblad-bezoek
            .onAppear { Task { await viewModel.loadMonth(displayedMonth) } }
            .onChange(of: displayedMonth) { _, newMonth in
                Task { await viewModel.loadMonth(newMonth) }
            }
        }
    }

    // MARK: - Month navigation

    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left").font(ArgoTheme.font(size: 20))
            }
            Spacer()
            Text(displayedMonth, format: .dateTime.month(.wide).year()).font(.argoHeadline)
            Spacer()
            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right").font(ArgoTheme.font(size: 20))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .tint(ArgoTheme.interactiveAccent)
    }

    // MARK: - Weekday header

    private var weekdayHeader: some View {
        HStack {
            ForEach(["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"], id: \.self) { day in
                Text(day).font(.argoCaption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Calendar grid

    private var calendarGrid: some View {
        let days = viewModel.daysInMonth(displayedMonth)
        let cal = Calendar.current

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { date in
                let isCurrentMonth = cal.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
                let kinds = viewModel.itemKinds(on: date)

                Button { selectedDate = date } label: {
                    VStack(spacing: 2) {
                        Text("\(cal.component(.day, from: date))")
                            .font(.argoBody)
                            .foregroundStyle(isSelected ? Color.white : isCurrentMonth ? Color.primary : Color.secondary)

                        HStack(spacing: 2) {
                            if kinds.contains(.event) {
                                Circle().fill(ArgoTheme.blueNormal).frame(width: 5, height: 5)
                            }
                            if kinds.contains(.barDuty) {
                                Circle().fill(.orange).frame(width: 5, height: 5)
                            }
                            if kinds.contains(.owhTraining) {
                                Circle().fill(.purple).frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isSelected ? ArgoTheme.blueNormal : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Toggle

    private var barDutyToggle: some View {
        HStack {
            Toggle(isOn: $viewModel.showBarDuties) {
                Label("Toon bardiensten", systemImage: "wineglass.fill")
                    .font(.argoCaption)
            }
            .toggleStyle(.switch)
            .tint(ArgoTheme.interactiveAccent)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Day detail list

    private var dayDetailList: some View {
        let dayItems = viewModel.items(on: selectedDate)

        return ScrollView {
            LazyVStack(spacing: 8) {
                if dayItems.isEmpty {
                    Text("Geen activiteiten op deze dag")
                        .font(.argoBody).foregroundStyle(.secondary).padding(.top, 20)
                } else {
                    ForEach(dayItems) { item in
                        itemRow(item)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Item rows

    @ViewBuilder
    private func itemRow(_ item: CalendarViewModel.CalendarItem) -> some View {
        switch item.kind {
        case .event:
            eventRow(item)
        case .barDuty:
            barDutyRow(item)
        case .owhTraining:
            owhRow(item)
        }
    }

    private func eventRow(_ item: CalendarViewModel.CalendarItem) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 2).fill(ArgoTheme.blueNormal).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.argoSubheadline)
                if let start = item.start {
                    Text(start.timeString).font(.argoCaption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }

    private func barDutyRow(_ item: CalendarViewModel.CalendarItem) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(item.isMySlot ? Color.green : .orange)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "wineglass.fill")
                        .font(ArgoTheme.font(size: 12))
                        .foregroundStyle(.orange)
                    Text(item.title).font(.argoSubheadline)
                }

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.argoCaption).foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    if item.assignedUserId == nil {
                        Button("Aanmelden") { Task { await viewModel.signUp(slotId: item.id) } }
                            .buttonStyle(.borderedProminent).tint(ArgoTheme.interactiveAccent).controlSize(.small)
                    }
                    if item.isMySlot {
                        Button("Afmelden") { Task { await viewModel.signOff(slotId: item.id) } }
                            .buttonStyle(.bordered).tint(.red).controlSize(.small)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(item.isMySlot ? Color.green.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func owhRow(_ item: CalendarViewModel.CalendarItem) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 2).fill(.purple).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "sportscourt.fill")
                        .font(ArgoTheme.font(size: 12))
                        .foregroundStyle(.purple)
                    Text(item.title).font(.argoSubheadline)
                }
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.argoCaption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}
