import SwiftUI

/// Round checkbox that ticks first, then checks the task off so its row can slide away; hovering previews the tick.
struct CompleteTaskButton: View {
    @Environment(AppModel.self) private var model
    let task: DeskTask
    var size: CGFloat = 20
    @State private var isChecked = false
    @State private var isHovered = false

    var body: some View {
        Button {
            complete()
        } label: {
            CheckGlyph(size: size, isChecked: isChecked, isPreviewing: isHovered)
        }
        .buttonStyle(DeskfocusPressStyle())
        .onHover { hovering in
            withAnimation(DeskfocusMotion.hover) { isHovered = hovering }
        }
        .help("Mark as done")
        .accessibilityLabel("Mark as done")
    }

    /// The tick shows for a moment so the click feels confirmed, then the row animates out.
    private func complete() {
        guard !isChecked else { return }
        withAnimation(DeskfocusMotion.press) { isChecked = true }
        Task { @MainActor in
            try? await Task.sleep(for: DeskfocusMotion.completionDelay)
            withAnimation(DeskfocusMotion.list) { model.complete(task) }
        }
    }
}
