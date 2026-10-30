import AppKit
import SwiftUI

/// Shows the agenda as a glass panel on the desktop, below normal windows, on every Space; drag it to move it.
/// Dragging is done here rather than with `isMovableByWindowBackground`, which SwiftUI content does not reliably support.
@MainActor
final class DesktopPanelController {
    /// Transparent room around the glass card for its SwiftUI shadow.
    static let shadowInset: CGFloat = 28

    private static let frameAutosaveName = "DeskfocusDesktopPanel"
    private static let screenMargin: CGFloat = 24
    /// How long the window waits before shrinking, so the card's spring can finish first.
    private static let shrinkDelay: TimeInterval = 0.55

    private var panel: DesktopPanel?
    private var layout: PanelLayout = .day
    private var pendingShrink: DispatchWorkItem?
    /// Pointer and window positions when the current drag began, in screen coordinates.
    private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    /// Size of the glass card for each layout; the week layout is wide enough for seven columns.
    static func cardSize(for layout: PanelLayout) -> NSSize {
        switch layout {
        case .day: return NSSize(width: 380, height: 460)
        case .week: return NSSize(width: 980, height: 500)
        }
    }

    private static func windowSize(for layout: PanelLayout) -> NSSize {
        let card = cardSize(for: layout)
        return NSSize(width: card.width + shadowInset * 2, height: card.height + shadowInset * 2)
    }

    func update(isVisible: Bool, layout: PanelLayout, model: AppModel) {
        guard isVisible else {
            hide()
            return
        }
        if panel == nil {
            show(layout: layout, model: model)
        } else if layout != self.layout {
            morph(to: layout)
        }
    }

    private func show(layout: PanelLayout, model: AppModel) {
        let size = Self.windowSize(for: layout)
        let panel = DesktopPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The card draws its own shadow, which follows the glass while it morphs.
        panel.hasShadow = false
        // Just above the desktop icons, so it sits under every app window like a widget.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        let hostingView = NSHostingView(rootView: DesktopPanelView().environment(model))
        // The window size is set here; SwiftUI animates the card inside it instead of resizing the window.
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        // Only the position is restored; the size always follows the layout.
        let topLeft = panel.setFrameUsingName(Self.frameAutosaveName)
            ? NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
            : Self.defaultTopLeft()
        panel.setFrame(Self.clamped(Self.frame(size: size, topLeft: topLeft), to: panel.screen ?? NSScreen.main), display: false)
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        panel.orderFrontRegardless()

        self.panel = panel
        self.layout = layout
        Log.app.info("Desktop panel shown in \(layout.rawValue, privacy: .public) layout")
    }

    /// Growing: the window grows at once and the card springs open inside it.
    /// Shrinking: the card springs closed first, then the window follows so nothing gets cut off mid-animation.
    private func morph(to layout: PanelLayout) {
        guard let panel else { return }
        pendingShrink?.cancel()
        pendingShrink = nil

        let newSize = Self.windowSize(for: layout)
        let grows = newSize.width > panel.frame.width || newSize.height > panel.frame.height
        self.layout = layout

        if grows {
            setWindowSize(newSize)
        } else {
            let shrink = DispatchWorkItem { [weak self] in
                guard let self, self.layout == layout else { return }
                self.setWindowSize(newSize)
            }
            pendingShrink = shrink
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.shrinkDelay, execute: shrink)
        }
        Log.app.info("Desktop panel morphing to \(layout.rawValue, privacy: .public) layout")
    }

    /// Resizes while keeping the top-left corner in place, then pulls the panel back on screen if needed.
    private func setWindowSize(_ size: NSSize) {
        guard let panel else { return }
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        panel.setFrame(Self.clamped(Self.frame(size: size, topLeft: topLeft), to: panel.screen ?? NSScreen.main), display: true)
    }

    /// Follows the pointer; the start is worked out from the first translation, so the panel never jumps.
    /// Screen coordinates are used because the view's own coordinates move along with the window.
    func drag(mouseLocation: NSPoint, translation: CGSize) {
        guard let panel else { return }
        if dragStart == nil {
            // SwiftUI's y grows downwards, the screen's upwards.
            let startMouse = NSPoint(x: mouseLocation.x - translation.width, y: mouseLocation.y + translation.height)
            dragStart = (mouse: startMouse, origin: panel.frame.origin)
            Log.app.debug("Desktop panel drag started")
        }
        guard let dragStart else { return }
        panel.setFrameOrigin(NSPoint(
            x: dragStart.origin.x + mouseLocation.x - dragStart.mouse.x,
            y: dragStart.origin.y + mouseLocation.y - dragStart.mouse.y
        ))
    }

    /// Keeps the panel on screen after a drag and saves where it was dropped.
    func endDrag() {
        guard let panel, dragStart != nil else { return }
        dragStart = nil
        panel.setFrame(Self.clamped(panel.frame, to: panel.screen ?? NSScreen.main), display: true)
        panel.saveFrame(usingName: Self.frameAutosaveName)
        Log.app.info("Desktop panel moved")
    }

    /// Moves the panel back to the top-left corner of the main screen.
    func resetPosition() {
        guard let panel else { return }
        dragStart = nil
        let frame = Self.frame(size: panel.frame.size, topLeft: Self.defaultTopLeft())
        panel.setFrame(Self.clamped(frame, to: NSScreen.main), display: true)
        panel.saveFrame(usingName: Self.frameAutosaveName)
        Log.app.info("Desktop panel position reset")
    }

    private func hide() {
        guard let panel else { return }
        pendingShrink?.cancel()
        pendingShrink = nil
        dragStart = nil
        panel.orderOut(nil)
        self.panel = nil
        Log.app.info("Desktop panel hidden")
    }

    /// Keeps the whole panel inside the screen's visible area, e.g. after a monitor was disconnected.
    private static func clamped(_ frame: NSRect, to screen: NSScreen?) -> NSRect {
        guard let visible = screen?.visibleFrame else { return frame }
        var clamped = frame
        clamped.origin.x = min(max(frame.minX, visible.minX - shadowInset), visible.maxX - frame.width + shadowInset)
        clamped.origin.y = min(max(frame.minY, visible.minY - shadowInset), visible.maxY - frame.height + shadowInset)
        return clamped
    }

    private static func frame(size: NSSize, topLeft: NSPoint) -> NSRect {
        NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
    }

    /// Places the card's corner a margin away from the top-left of the main screen, clear of the menu bar.
    private static func defaultTopLeft() -> NSPoint {
        let margin = screenMargin - shadowInset
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return NSPoint(x: margin, y: 600) }
        return NSPoint(x: visibleFrame.minX + margin, y: visibleFrame.maxY - margin)
    }
}

/// Borderless panel that can take clicks without activating the app or stealing focus from the window you work in.
private final class DesktopPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
