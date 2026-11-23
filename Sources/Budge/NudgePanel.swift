import AppKit
import BudgeCore
import SwiftUI

/// A transparent, always-on-top window in the top-right corner that never steals focus.
@MainActor
final class NudgePanel {
    private var panel: NSPanel?
    private var autoHide: Task<Void, Never>?

    var isShowing: Bool { panel != nil }

    /// Shows the nudge. If you ignore it for `timeout`, it hides and counts as a snooze.
    func show(avatar: Avatar, prompt: Prompt, caption: String, timeout: Duration = .seconds(90),
              onDone: @escaping () -> Void, onSnooze: @escaping () -> Void) {
        hide(animated: false)

        let view = NudgeView(
            avatar: avatar, prompt: prompt, caption: caption,
            onDone: { [weak self] in self?.hide(); onDone() },
            onSnooze: { [weak self] in self?.hide(); onSnooze() })
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = host
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        // Show it on the screen you are looking at (where the mouse is).
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
        panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - size.width,
                                     y: screen.visibleFrame.maxY - size.height)) // top-right, under the menu bar
        panel.orderFrontRegardless() // the view slides itself in
        self.panel = panel

        autoHide = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled, let self, self.isShowing else { return }
            self.hide()
            onSnooze()
        }
    }

    func hide(animated: Bool = true) {
        autoHide?.cancel()
        autoHide = nil
        guard let panel else { return }
        self.panel = nil
        guard animated else { panel.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            panel.orderOut(nil)
        }
    }
}
