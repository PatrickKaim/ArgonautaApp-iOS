import SwiftUI

/// Overzichtspagina van de kalender-tab.
/// - Header "Aankomende events" + knop naar de volledige maandweergave.
/// - Toggle voor bardiensten + lijst met items voor de komende 30 dagen.
struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                barDutyToggle
                Divider()
                upcomingList
            }
            .background(ArgoTheme.groupedBackground)
            .navigationTitle("Kalender")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task { await viewModel.loadUpcomingWindow() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .meteorConnectionRestored)) { _ in
                Task { await viewModel.loadUpcomingWindow() }
            }
            .navigationDestination(for: CalendarRoute.self) { route in
                switch route {
                case .month:
                    CalendarMonthView(viewModel: viewModel)
                }
            }
            .navigationDestination(for: CalendarViewModel.EventDetailRoute.self) { route in
                CalendarEventDetailView(slugOrId: route.slugOrId, occurrence: route.occurrence)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Aankomende events")
                .font(.argoHeadline)
            Spacer()
            NavigationLink(value: CalendarRoute.month) {
                Label("Open kalender", systemImage: "calendar")
                    .font(.argoSubheadline)
            }
            .buttonStyle(.borderedProminent)
            .tint(ArgoTheme.interactiveAccent)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
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

    // MARK: - Upcoming list

    private var upcomingList: some View {
        let upcoming = viewModel.upcomingItemsNext30Days()

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Text("Komende 30 dagen")
                    .font(.argoSubheadline)
                    .foregroundStyle(.primary)
                    .padding(.top, 4)

                if upcoming.isEmpty {
                    Text("Geen activiteiten in de komende 30 dagen.")
                        .font(.argoBody).foregroundStyle(.secondary).padding(.top, 8)
                } else {
                    ForEach(upcoming) { item in
                        CalendarItemRow(item: item, viewModel: viewModel, showCalendarDay: true)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

/// Subroute binnen de kalender-tab. Eén case nu (`.month`) maar zo voorkomen we dat we de
/// `EventDetailRoute` overlappen voor `.navigationDestination`.
enum CalendarRoute: Hashable {
    case month
}
