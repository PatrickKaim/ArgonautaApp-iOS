import SwiftUI

/// Gedeelde rij-renderer voor `CalendarView` (overzicht) en `CalendarMonthView` (per dag).
/// `showCalendarDay` toont de datum onder de titel — in de maand-detailweergave is dat overbodig
/// omdat de geselecteerde dag al uit de header blijkt.
struct CalendarItemRow: View {
    let item: CalendarViewModel.CalendarItem
    let viewModel: CalendarViewModel
    let showCalendarDay: Bool

    var body: some View {
        switch item.kind {
        case .event:
            if let route = viewModel.eventDetailRoute(for: item) {
                NavigationLink(value: route) {
                    eventRowContent(showChevron: true)
                }
                .buttonStyle(.plain)
            } else {
                eventRowContent(showChevron: false)
            }
        case .barDuty:
            barDutyRow
        case .owhTraining:
            owhRow
        }
    }

    private func eventRowContent(showChevron: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(ArgoTheme.blueNormal).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.argoSubheadline)
                if let start = item.start {
                    if showCalendarDay {
                        Text(start.calendarDayString).font(.argoCaption).foregroundStyle(.secondary)
                    }
                    Text(start.timeString).font(.argoCaption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.argoCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }

    private var barDutyRow: some View {
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

                if showCalendarDay, let start = item.start {
                    Text(start.calendarDayString).font(.argoCaption).foregroundStyle(.secondary)
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

    private var owhRow: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2).fill(.purple).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "sportscourt.fill")
                        .font(ArgoTheme.font(size: 12))
                        .foregroundStyle(.purple)
                    Text(item.title).font(.argoSubheadline)
                }
                if showCalendarDay, let start = item.start {
                    Text(start.calendarDayString).font(.argoCaption).foregroundStyle(.secondary)
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
