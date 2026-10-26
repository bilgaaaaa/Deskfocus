import SwiftUI
import WidgetKit

@main
struct DeskfocusWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeskfocusWidget()
    }
}

/// One desktop widget for both jobs: today's list with start buttons, turning into the live timer while focusing.
struct DeskfocusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DeskfocusConstants.widgetKind, provider: DeskfocusTimelineProvider()) { entry in
            DeskfocusWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    // Same color the user picked for the glass widget on the desktop.
                    entry.snapshot.settings.glassTint.gradient
                }
                .environment(\.colorScheme, .dark)
        }
        .configurationDisplayName("Deskfocus")
        .description("Today's tasks and your focus timer in one place.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
