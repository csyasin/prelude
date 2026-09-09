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

@MainActor
final class OverlayController {
    private unowned let model: AppModel
    private var panel: KeyPanel?
    private var edges: [NSWindow] = []
    private var displays: [NSRect] = []
    private var generation = 0
    init(model: AppModel) { self.model = model }

    /// Warm the hosting view and layer trees before the next leader event.
    func prepare() {
        if panel == nil {
            let panel = KeyPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "Prelude"
            panel.isOpaque = false; panel.backgroundColor = .clear
            panel.hasShadow = true; panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: TreeView(model: model))
            panel.onShowPreferences = { [weak model = self.model] in
                model?.dismiss()
                model?.onShowPreferences?()
            }
            self.panel = panel
        }
        if displays != NSScreen.screens.map(\.frame) {
            edges.forEach { $0.orderOut(nil) }
            edges = NSScreen.screens.map { display in
                let edge = NSWindow(contentRect: display.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                edge.isOpaque = false; edge.backgroundColor = .clear; edge.hasShadow = false
                edge.ignoresMouseEvents = true
                edge.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
                edge.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
                edge.contentView = EdgeGlowView(frame: NSRect(origin: .zero, size: display.frame.size))
                return edge
            }
            displays = NSScreen.screens.map(\.frame)
        }
        position()
        panel?.contentView?.layoutSubtreeIfNeeded()
    }
    private func position() {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let width = min(1200, max(320, area.width - 72))
        let height = min(820, max(320, area.height - 80))
        panel?.setFrame(NSRect(x: area.midX - width / 2, y: area.midY - height / 2, width: width, height: height), display: false)
    }
    func show() {
        generation += 1
        prepare()
        guard let panel else { return }
        // Opaque and key immediately: no entrance animation can swallow fast input.
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        for edge in edges {
            edge.alphaValue = 1
            (edge.contentView as? EdgeGlowView)?.start()
            edge.orderFrontRegardless()
        }
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.92; fade.toValue = 1; fade.duration = 0.08
            panel.contentView?.layer?.add(fade, forKey: "appear")
        }
    }
    func hide() {
        generation += 1
        let ticket = generation
        // Release keyboard focus now; edge fade continues independently.
        panel?.orderOut(nil)
        let closing = edges
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.10
            closing.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == ticket else { return }
                closing.forEach { $0.orderOut(nil); ($0.contentView as? EdgeGlowView)?.stop() }
            }
        }
    }
}

/// The render server animates small stroked layers; SwiftUI never redraws a screen-sized blur.
final class EdgeGlowView: NSView {
    private let glow = CALayer()
    private var segments: [CAShapeLayer] = []
    private var perimeter: CGFloat = 1
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(glow)
        let tint = NSColor(calibratedRed: 0.62, green: 0.91, blue: 0.79, alpha: 1)
        for index in 0..<6 {
            let stroke = CAShapeLayer()
            stroke.fillColor = nil; stroke.strokeColor = tint.cgColor
            stroke.lineWidth = index == 0 ? 2 : 3
            stroke.lineCap = .round
            stroke.opacity = index == 0 ? 0.16 : Float(6 - index) * 0.16
            if index == 1 {
                stroke.shadowColor = tint.cgColor; stroke.shadowRadius = 7
                stroke.shadowOpacity = 0.8; stroke.shadowOffset = .zero
            }
            glow.addSublayer(stroke); segments.append(stroke)
        }
        rebuild()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() { super.layout(); rebuild() }
    private func rebuild() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        glow.frame = bounds
        let rect = bounds.insetBy(dx: 3, dy: 3)
        let radius: CGFloat = 18
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        perimeter = max(1, 2 * (rect.width + rect.height) - 8 * radius + 2 * .pi * radius)
        for (index, stroke) in segments.enumerated() {
            stroke.frame = bounds; stroke.path = path
            if index > 0 { stroke.lineDashPattern = [140, NSNumber(value: Double(max(1, perimeter - 140)))] }
        }
        CATransaction.commit()
    }
    func start() {
        stop()
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        for (index, stroke) in segments.enumerated() where index > 0 {
            let phase = CABasicAnimation(keyPath: "lineDashPhase")
            let offset = CGFloat(index - 1) * 115
            phase.fromValue = offset; phase.toValue = offset - perimeter
            phase.duration = 5.5; phase.repeatCount = .infinity
            phase.timingFunction = CAMediaTimingFunction(name: .linear)
            stroke.add(phase, forKey: "marquee")
        }
        let breath = CABasicAnimation(keyPath: "opacity")
        breath.fromValue = 0.55; breath.toValue = 1; breath.duration = 1.8
        breath.autoreverses = true; breath.repeatCount = .infinity
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glow.add(breath, forKey: "breath")
    }
    func stop() {
        glow.removeAllAnimations()
        segments.forEach { $0.removeAllAnimations() }
    }
}
