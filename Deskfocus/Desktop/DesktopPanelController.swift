import AppKit
import SwiftUI

/// Shows the agenda as a glass panel on the desktop, below normal windows, on every Space; drag it to move it.
@MainActor
final class DesktopPanelController {
    private static let frameAutosaveName = "DeskfocusDesktopPanel"
    private static let screenMargin: CGFloat = 24

    private var panel: DesktopPanel?
    private var layout: PanelLayout = .day

    /// Panel size for each layout; the week layout is wide enough for seven columns.
    static func size(for layout: PanelLayout) -> NSSize {
        switch layout {
        case .day: return NSSize(width: 380, height: 500)
        case .week: return NSSize(width: 980, height: 500)
        }
    }

    func update(isVisible: Bool, layout: PanelLayout, model: AppModel) {
        guard isVisible else {
            hide()
            return
        }
        if panel == nil {
            show(layout: layout, model: model)
        } else if layout != self.layout {
            resize(to: layout)
        }
    }

    private func show(layout: PanelLayout, model: AppModel) {
        let size = Self.size(for: layout)
        let panel = DesktopPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Just above the desktop icons, so it sits under every app window like a widget.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        let hostingView = NSHostingView(rootView: DesktopPanelView().environment(model))
        // The window size follows the layout; SwiftUI content stretches to it instead of resizing the window.
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        // Only the position is restored; the size always follows the layout.
        if panel.setFrameUsingName(Self.frameAutosaveName) {
            let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
            panel.setFrame(Self.frame(size: size, topLeft: topLeft), display: false)
        } else {
            panel.setFrame(Self.frame(size: size, topLeft: Self.defaultTopLeft()), display: false)
        }
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        panel.orderFrontRegardless()

        self.panel = panel
        self.layout = layout
        Log.app.info("Desktop panel shown in \(layout.rawValue, privacy: .public) layout")
    }

    /// Changes size while keeping the top-left corner in place, then pulls the panel back on screen if needed.
    private func resize(to layout: PanelLayout) {
        guard let panel else { return }
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        var frame = Self.frame(size: Self.size(for: layout), topLeft: topLeft)
        if let visible = (panel.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        }
        panel.setFrame(frame, display: true, animate: true)
        self.layout = layout
        Log.app.info("Desktop panel resized for \(layout.rawValue, privacy: .public) layout")
    }

    private func hide() {
        guard let panel else { return }
        panel.orderOut(nil)
        self.panel = nil
        Log.app.info("Desktop panel hidden")
    }

    private static func frame(size: NSSize, topLeft: NSPoint) -> NSRect {
        NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
    }

    /// Top-left corner of the main screen, clear of the menu bar.
    private static func defaultTopLeft() -> NSPoint {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return NSPoint(x: screenMargin, y: 600) }
        return NSPoint(x: visibleFrame.minX + screenMargin, y: visibleFrame.maxY - screenMargin)
    }
}

/// Borderless panel that can take clicks without activating the app or stealing focus from the window you work in.
private final class DesktopPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
