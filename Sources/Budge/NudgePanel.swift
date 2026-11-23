import AppKit
import BudgeCore
import SwiftUI

/// A transparent, always-on-top window in the top-right corner. It never brings Budge to the
/// front; clicking the log's text box lets you type into it without switching apps.
@MainActor
final class NudgePanel {
    private var panel: NSPanel?
    private var autoHide: Task<Void, Never>?

    var isShowing: Bool { panel != nil }

    /// Shows a break nudge. If you ignore it for 90 seconds, it hides and counts as a snooze.
    func show(avatar: Avatar, prompt: Prompt, caption: String,
              onDone: @escaping () -> Void, onSnooze: @escaping () -> Void) {
        let view = NudgeView(
            avatar: avatar, prompt: prompt, caption: caption,
            onDone: { [weak self] in self?.hide(); onDone() },
            onSnooze: { [weak self] in self?.hide(); onSnooze() })
        present(view, autoHideAfter: .seconds(90), onTimeout: onSnooze)
    }

    /// Shows any bubble. Without a timeout it stays until `hide()`.
    func present(_ content: some View, autoHideAfter timeout: Duration? = nil,
                 onTimeout: @escaping () -> Void = {}) {
        hide(animated: false)

        let host = NSHostingView(rootView: content)
        let size = host.fittingSize

        let panel = TypingPanel(contentRect: NSRect(origin: .zero, size: size),
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
        panel.becomesKeyOnlyIfNeeded = true // only takes typing once you click the text box

        // Show it on the screen you are looking at (where the mouse is).
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
        panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - size.width,
                                     y: screen.visibleFrame.maxY - size.height)) // top-right, under the menu bar
        panel.orderFrontRegardless() // the view slides itself in
        self.panel = panel

        guard let timeout else { return }
        autoHide = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled, let self, self.isShowing else { return }
            self.hide()
            onTimeout()
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

/// Borderless panels refuse keyboard input by default; the log's text box needs it.
private final class TypingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
