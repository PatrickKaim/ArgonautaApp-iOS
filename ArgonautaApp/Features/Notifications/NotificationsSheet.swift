import SwiftUI

struct NotificationsSheet: View {
    @Bindable var model: NotificationsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.items.isEmpty {
                    ContentUnavailableView(
                        "Geen meldingen",
                        systemImage: "bell.slash",
                        description: Text("Je hebt geen actieve mededelingen.")
                    )
                } else {
                    List {
                        ForEach(model.items) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(item.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let d = item.createdAt {
                                    Text(d.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await model.dismiss(id: item.id) }
                                } label: {
                                    Label("Verwijder", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Meldingen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                }
                if model.unreadCount > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Alles gelezen") {
                            Task { await model.dismissAll() }
                        }
                    }
                }
            }
        }
    }
}
