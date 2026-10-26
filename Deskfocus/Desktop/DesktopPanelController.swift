import AppKit
import SwiftUI

/// Shows the dashboard as a glass panel on the desktop, below normal windows, on every Space; drag it to move it.
@MainActor
final class DesktopPanelController {
    static let panelSize = NSSize(width: 360, height: 320)
    private static let frameAutosaveName = "DeskfocusDesktopPanel"
    private static let screenMargin: CGFloat = 24

    private var panel: DesktopPanel?

    func setVisible(_ isVisible: Bool, model: AppModel) {
        if isVisible {
            show(model: model)
        } else {
            hide()
        }
    }

    private func show(model: AppModel) {
        guard panel == nil else { return }

        let panel = DesktopPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
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
        hostingView.frame = NSRect(origin: .zero, size: Self.panelSize)
        panel.contentView = hostingView

        if !panel.setFrameUsingName(Self.frameAutosaveName) {
            panel.setFrameOrigin(Self.defaultOrigin())
        }
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        panel.orderFrontRegardless()
        self.panel = panel
        Log.app.info("Desktop panel shown")
    }

    private func hide() {
        guard let panel else { return }
        panel.orderOut(nil)
        self.panel = nil
        Log.app.info("Desktop panel hidden")
    }

    /// Top-left corner of the main screen, clear of the menu bar.
    private static func defaultOrigin() -> NSPoint {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return NSPoint(x: screenMargin, y: screenMargin) }
        return NSPoint(
            x: visibleFrame.minX + screenMargin,
            y: visibleFrame.maxY - panelSize.height - screenMargin
        )
    }
}

/// Borderless panel that can take clicks without activating the app or stealing focus from the window you work in.
private final class DesktopPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
