import SwiftUI

/// Red stop button for a task with a paused or saved session; ends it and forgets the time left.
/// Shows nothing when the task has no session.
struct EndSessionButton: View {
    @Environment(AppModel.self) private var model
    let task: DeskTask
    var size: CGFloat = 28

    private var hasSession: Bool {
        model.snapshot.savedProgress[task.id] != nil || model.snapshot.focus?.taskId == task.id
    }

    var body: some View {
        if hasSession {
            Button { model.endFocus(on: task) } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(DeskfocusTheme.danger.opacity(0.9), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(DeskfocusPressStyle())
            .help("End Session")
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }
}
