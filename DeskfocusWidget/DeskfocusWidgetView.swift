import SwiftUI
import WidgetKit

/// WidgetKit wrapper around the shared dashboard; the medium widget uses the compact layout.
struct DeskfocusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DeskfocusEntry

    var body: some View {
        DeskfocusDashboardView(
            snapshot: entry.snapshot,
            date: entry.date,
            layout: family == .systemLarge ? .expanded : .compact
        )
        .environment(\.deskfocusAccent, entry.snapshot.settings.accentColor)
    }
}
