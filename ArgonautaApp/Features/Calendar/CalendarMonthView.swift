import SwiftUI

/// Volledige maandkalender met items voor de geselecteerde dag eronder.
///
/// Wordt vanuit `CalendarView` (overzicht) gepusht. De parent geeft zijn `CalendarViewModel`
/// door zodat we niet opnieuw subscriben en de bestaande data direct hergebruiken.
struct CalendarMonthView: View {
    @Bindable var viewModel: CalendarViewModel

    @State private var selectedDate: Date = .init()
    @State private var displayedMonth: Date = .init()

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayHeader
            calendarGrid
            Divider()
            barDutyToggle
            Divider()
            dayDetailList
        }
        .background(ArgoTheme.groupedBackground)
        .navigationTitle("Kalender")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await viewModel.loadMonth(displayedMonth) }
        }
        .onChange(of: displayedMonth) { _, newMonth in
            Task { await viewModel.loadMonth(newMonth) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .meteorConnectionRestored)) { _ in
            Task { await viewModel.loadMonth(displayedMonth) }
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
            LazyVStack(alignment: .leading, spacing: 10) {
                Text(selectedDate.calendarDayString)
                    .font(.argoSubheadline)
                    .foregroundStyle(.primary)
                    .padding(.top, 4)

                if dayItems.isEmpty {
                    Text("Geen activiteiten op deze dag.")
                        .font(.argoBody).foregroundStyle(.secondary).padding(.top, 8)
                } else {
                    ForEach(dayItems) { item in
                        CalendarItemRow(item: item, viewModel: viewModel, showCalendarDay: false)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
