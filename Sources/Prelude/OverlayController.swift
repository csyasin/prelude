import AppKit
import SwiftUI

final class KeyPanel: NSPanel {
    var onShowPreferences: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if event.type == .keyDown, event.keyCode == 43, modifiers == .command {
            onShowPreferences?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Keep AppKit's hosting surface transparent as well as the NSPanel.
private final class IslandHostingView: NSHostingView<IslandView> {
    override var isOpaque: Bool { false }
}

@MainActor
final class OverlayController {
    private unowned let model: AppModel
    private var panel: KeyPanel?
    init(model: AppModel) { self.model = model }

    /// Warm the hosting view and layer trees before the next leader event.
    func prepare() {
        if panel == nil {
            let panel = KeyPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "Prelude"
            panel.isOpaque = false; panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.animationBehavior = .none
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.ignoresMouseEvents = true
            let host = IslandHostingView(rootView: IslandView(model: model))
            host.sizingOptions = []
            host.safeAreaRegions = []
            panel.contentView = host
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
            panel.contentView?.layer?.isOpaque = false
            panel.onShowPreferences = { [weak model = self.model] in
                model?.dismiss()
                model?.onShowPreferences?()
            }
            self.panel = panel
        }
        position()
        panel?.contentView?.layoutSubtreeIfNeeded()
    }
    private func position() {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        let notchGap = max(0, right.minX - left.maxX)
        let hasNotch = screen.safeAreaInsets.top > 0 && !left.isEmpty && !right.isEmpty && notchGap > 40
        let notchWidth = hasNotch ? notchGap : 96
        let notchDepth = hasNotch ? screen.safeAreaInsets.top : 12
        let width = min(680, max(340, screen.frame.width - 24))
        let height = min(520, max(320, screen.frame.height * 0.56))
        let top = hasNotch ? screen.frame.maxY : screen.visibleFrame.maxY - 8
        model.islandMetrics = IslandScreenMetrics(
            notchWidth: notchWidth,
            notchDepth: notchDepth,
            maximumWidth: width - 32,
            hasNotch: hasNotch
        )
        panel?.setFrame(
            NSRect(x: (hasNotch ? (left.maxX + right.minX) / 2 : screen.frame.midX) - width / 2, y: top - height, width: width, height: height),
            display: false
        )
    }
    func show() {
        prepare()
        guard let panel else { return }
        // Opaque and key immediately: no entrance animation can swallow fast input.
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        model.beginPresentation()
    }
    func hide() {
        panel?.resignKey()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel?.orderOut(nil)
        }
    }

    /// Called only after the shell has finished retracting. A stale completion
    /// must never hide a newer presentation when the leader is pressed rapidly.
    func finishHiding(presentationID: Int) {
        guard !model.active, model.presentationID == presentationID else { return }
        panel?.orderOut(nil)
    }
}
