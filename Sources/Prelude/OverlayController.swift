import AppKit
import SwiftUI

final class KeyPanel: NSPanel {
    var onShowPreferences: (() -> Void)?
    var acceptsNavigationFocus = true
    override var canBecomeKey: Bool { acceptsNavigationFocus }
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
private final class IslandHostingView: NSHostingView<InteractionView> {
    override var isOpaque: Bool { false }
}

@MainActor
final class OverlayController {
    private unowned let model: AppModel
    private var panel: KeyPanel?
    private var lightPanel: NSPanel?
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
            let host = IslandHostingView(rootView: InteractionView(model: model))
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
        if lightPanel == nil {
            let light = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            light.isOpaque = false
            light.backgroundColor = .clear
            light.hasShadow = false
            light.animationBehavior = .none
            light.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            light.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            light.hidesOnDeactivate = false
            light.isReleasedWhenClosed = false
            light.ignoresMouseEvents = true
            let host = LightHostingView(rootView: GlobalEdgeLightView(model: model))
            host.sizingOptions = []
            host.safeAreaRegions = []
            light.contentView = host
            self.lightPanel = light
        }
        position()
        panel?.contentView?.layoutSubtreeIfNeeded()
        if model.interactionEffect == .subtitles {
            panel?.contentView?.displayIfNeeded()
        }
    }
    private func position() {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        lightPanel?.setFrame(screen.frame, display: false)
        if model.interactionEffect == .subtitles {
            panel?.setFrame(screen.frame, display: false)
            return
        }
        if model.interactionEffect == .invisible {
            // Keep a transparent key window solely to consume navigation input.
            panel?.setFrame(NSRect(x: screen.frame.minX, y: screen.frame.minY, width: 1, height: 1), display: false)
            return
        }
        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        let notchGap = max(0, right.minX - left.maxX)
        let hasNotch = screen.safeAreaInsets.top > 0 && !left.isEmpty && !right.isEmpty && notchGap > 40
        let notchWidth = hasNotch ? notchGap : 96
        let notchDepth = hasNotch ? screen.safeAreaInsets.top : 12
        let navigationWidth = min(680, max(340, screen.frame.width - 24))
        let maximumToastWidth = screen.frame.width * 0.5
        // The hosting window stays fixed throughout presentation; leave room for
        // any toast up to half this display, including its shadow margins.
        let width = max(navigationWidth, maximumToastWidth + 32)
        let height = min(520, max(320, screen.frame.height * 0.56))
        let top = hasNotch ? screen.frame.maxY : screen.visibleFrame.maxY - 8
        model.islandMetrics = IslandScreenMetrics(
            notchWidth: notchWidth,
            notchDepth: notchDepth,
            maximumWidth: navigationWidth - 32,
            hasNotch: hasNotch,
            maximumToastWidth: maximumToastWidth
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
        panel.acceptsNavigationFocus = true
        lightPanel?.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        model.beginPresentation()
    }
    func showNotification() {
        // Preserve the screen and anchor when morphing an existing presentation.
        if panel?.isVisible != true { prepare() }
        guard let panel else { return }
        releaseKeyboardFocus()
        panel.alphaValue = 1
        lightPanel?.orderFrontRegardless()
        panel.orderFrontRegardless()
        model.beginPresentation()
    }

    /// Keep the completion visible without retaining the nonactivating panel's
    /// keyboard focus. Do not activate an app here: the action may open another.
    func releaseKeyboardFocus() {
        panel?.resignKey()
        panel?.acceptsNavigationFocus = false
    }

    func resetPresentation() {
        releaseKeyboardFocus()
        lightPanel?.orderOut(nil)
        panel?.orderOut(nil)
    }

    func hide() {
        releaseKeyboardFocus()
        if model.interactionEffect == .invisible || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            lightPanel?.orderOut(nil)
            panel?.orderOut(nil)
        }
    }

    /// Called only after the shell has finished retracting. A stale completion
    /// must never hide a newer presentation when the leader is pressed rapidly.
    func finishHiding(presentationID: Int) {
        guard !model.active, model.presentationID == presentationID else { return }
        lightPanel?.orderOut(nil)
        panel?.orderOut(nil)
        model.presentPendingToast()
    }
}

struct InteractionView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        switch model.interactionEffect {
        case .invisible: Color.clear.accessibilityHidden(true)
        case .island: IslandView(model: model)
        case .subtitles:
            HUDView(model: model)
                // A fresh activation must not crossfade from the last route.
                // Keep this identity stable during navigation and completion.
                .id(model.navigationSessionID)
        }
    }
}

private final class LightHostingView: NSHostingView<GlobalEdgeLightView> {
    override var isOpaque: Bool { false }
}

private struct GlobalEdgeLightView: View {
    @ObservedObject var model: AppModel
    @AppStorage(ThemeColor.preferenceKey) private var accentHex = ThemeColor.defaultHex
    @AppStorage(EdgeLightPreference.enabledKey) private var enabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false
    @State private var visible = false
    @State private var stopTask: Task<Void, Never>?

    var body: some View {
        FlowingEdgeLight(active: running, reduceMotion: reduceMotion, accent: accentHex)
            .opacity(visible ? 1 : 0)
            .accessibilityHidden(true)
            .onAppear { synchronize() }
            .onChange(of: model.presentationID) { _, _ in synchronize() }
            .onChange(of: model.active) { _, _ in synchronize() }
            .onChange(of: enabled) { _, _ in synchronize() }
            .onChange(of: model.completing) { _, _ in synchronize() }
            .onDisappear { stopTask?.cancel() }
    }

    private var shouldShowLight: Bool { model.active && !model.completing && enabled }

    private func synchronize() {
        stopTask?.cancel()
        if shouldShowLight {
            running = true
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { visible = true }
        } else {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { visible = false }
            stopTask = Task { @MainActor in
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(210)) }
                guard !Task.isCancelled, !shouldShowLight else { return }
                running = false
            }
        }
    }
}
