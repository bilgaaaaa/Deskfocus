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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Deskfocus")
        .description("Today's tasks and your focus timer in one place.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
