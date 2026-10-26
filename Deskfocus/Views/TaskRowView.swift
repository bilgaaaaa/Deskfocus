import SwiftUI

/// One task in the menu bar list: color dot, title, time or list, and start / done actions.
struct TaskRowView: View {
    let task: DeskTask
    let onStart: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: task.colorHex) ?? .accentColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .lineLimit(1)
                Text(DeskTaskFormatter.subtitle(for: task))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onComplete) {
                Image(systemName: "checkmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Mark as done")

            Button(action: onStart) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .help("Start focus on this task")
        }
        .padding(.vertical, 4)
    }
}
