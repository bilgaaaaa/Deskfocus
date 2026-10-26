import SwiftUI

/// Big weekday + date header with any trailing control (progress ring, day arrows).
struct DayHeaderView<Trailing: View>: View {
    let date: Date
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DeskTaskFormatter.weekday(date).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(DeskfocusTheme.amber)
                Text(DeskTaskFormatter.dayMonth(date))
                    .font(.system(size: 26, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

/// Small "2/6" ring showing how much of today is done.
struct DayProgressRing: View {
    let done: Int
    let total: Int

    var body: some View {
        FocusRingView(progress: total > 0 ? Double(done) / Double(total) : 0, lineWidth: 4.5) {
            Text("\(done)/\(total)")
                .font(.system(size: 10.5, weight: .bold))
                .monospacedDigit()
        }
        .frame(width: 42, height: 42)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) done")
    }
}

/// A day's list: optional "Up next" card for the first item, then the rest as rows.
struct DayAgendaView<RowAction: View, UpNextAction: View>: View {
    let tasks: [DeskTask]
    let now: Date
    let maxRows: Int
    let showsUpNext: Bool
    @ViewBuilder var rowAction: (DeskTask) -> RowAction
    @ViewBuilder var upNextAction: (DeskTask) -> UpNextAction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if tasks.isEmpty {
                emptyState
            } else {
                if showsUpNext, let next = tasks.first {
                    upNextCard(for: next)
                }
                let rows = Array(tasks.dropFirst(showsUpNext ? 1 : 0))
                VStack(spacing: 0) {
                    ForEach(rows.prefix(maxRows)) { task in
                        Divider().overlay(DeskfocusTheme.hairline)
                        DeskTaskRow(task: task, now: now) {
                            rowAction(task)
                        }
                    }
                }
                if rows.count > maxRows {
                    Text("+\(rows.count - maxRows) more")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func upNextCard(for task: DeskTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DeskTaskFormatter.upNextLabel(for: task, now: now).uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .lineLimit(2)
                    Text(DeskTaskFormatter.subtitle(for: task, now: now))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                upNextAction(task)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.14)))
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(DeskfocusTheme.amber)
            Text("All clear")
                .font(.system(size: 14, weight: .semibold))
            Text("Nothing planned for this day.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}
