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
                    // Same indigo as the app icon, so the widget matches the glass panel's tint.
                    LinearGradient(colors: [DeskfocusTheme.indigo.opacity(0.85), DeskfocusTheme.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                .environment(\.colorScheme, .dark)
        }
        .configurationDisplayName("Deskfocus")
        .description("Today's tasks and your focus timer in one place.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
