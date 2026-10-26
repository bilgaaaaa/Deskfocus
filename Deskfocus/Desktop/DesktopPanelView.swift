import SwiftUI

/// Content of the glass desktop panel: the shared dashboard, refreshed every minute so ended events drop off.
struct DesktopPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.everyMinute) { context in
            DeskfocusDashboardView(snapshot: model.snapshot, date: context.date, layout: .expanded)
                .padding(18)
                .frame(width: DesktopPanelController.panelSize.width, height: DesktopPanelController.panelSize.height, alignment: .topLeading)
                .modifier(DesktopGlassBackground())
        }
    }
}
