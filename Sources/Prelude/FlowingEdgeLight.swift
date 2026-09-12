import AppKit
import SwiftUI
import QuartzCore

enum EdgeLightPreference {
    static let enabledKey = "appearance.edgeLightEnabled"
}

/// Core Animation moves soft radial lights without redrawing the SwiftUI tree.
struct FlowingEdgeLight: NSViewRepresentable {
    var active: Bool
    var reduceMotion: Bool
    var accent: String

    func makeNSView(context: Context) -> EdgeLightSurface { EdgeLightSurface() }
    func updateNSView(_ view: EdgeLightSurface, context: Context) {
        view.configure(active: active, reduceMotion: reduceMotion, accent: accent)
    }
}

final class EdgeLightSurface: NSView {
    override var isOpaque: Bool { false }
    private var active = false
    private var reduced = false
    private var accent = ""
    private var renderedSize = CGSize.zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(active: Bool, reduceMotion: Bool, accent: String) {
        guard self.active != active || reduced != reduceMotion || self.accent != accent || accent == ThemeColor.systemValue else { return }
        self.active = active
        reduced = reduceMotion
        self.accent = accent
        rebuild()
    }
    override func layout() {
        super.layout()
        if renderedSize != bounds.size { rebuild() }
    }

    private func rebuild() {
        guard let layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        renderedSize = bounds.size
        guard active, bounds.width > 0, bounds.height > 0 else { return }
        let colors = [NSColor(ThemeColor.color(accent)),
                      NSColor(srgbRed: 0.24, green: 0.62, blue: 1, alpha: 1),
                      NSColor(srgbRed: 0.73, green: 0.39, blue: 0.96, alpha: 1)]
        let now = CACurrentMediaTime()
        for edge in 0..<4 {
            let horizontal = edge < 2
            let length = horizontal ? bounds.width : bounds.height
            let lightCount = Int.random(in: 3...5)
            for _ in 0..<lightCount {
                let span = max(300, length * CGFloat.random(in: 0.35...0.85))
                let depth = CGFloat.random(in: 140...240)
                let glow = CAGradientLayer()
                glow.type = .radial
                glow.startPoint = CGPoint(x: 0.5, y: 0.5)
                glow.endPoint = CGPoint(x: 1, y: 1)
                let base = colors.randomElement()!.usingColorSpace(.deviceRGB)!
                let color = NSColor(hue: base.hueComponent,
                                    saturation: min(1, base.saturationComponent * 1.25 + 0.12),
                                    brightness: base.brightnessComponent * CGFloat.random(in: 0.85...0.96), alpha: 1)
                glow.colors = [color.withAlphaComponent(0.96).cgColor,
                               color.withAlphaComponent(0.48).cgColor,
                               color.withAlphaComponent(0.12).cgColor,
                               color.withAlphaComponent(0).cgColor]
                glow.locations = [0, 0.28, 0.62, 1]
                glow.bounds = CGRect(x: 0, y: 0, width: horizontal ? span : depth,
                                     height: horizontal ? depth : span)
                let inset = CGFloat.random(in: 12...36)
                let fixed: CGFloat = edge == 0 || edge == 2 ? -inset : (horizontal ? bounds.height : bounds.width) + inset
                let along = CGFloat.random(in: 0...length)
                glow.position = horizontal ? CGPoint(x: along, y: fixed) : CGPoint(x: fixed, y: along)
                glow.opacity = Float.random(in: 0.7...0.95)
                layer.addSublayer(glow)
                guard !reduced else { continue }

                // Each light crosses the edge at its own phase. It fades before
                // wrapping, so neither the color nor position jumps at the seam.
                let travel = CABasicAnimation(keyPath: horizontal ? "position.x" : "position.y")
                travel.fromValue = -span * 0.45
                travel.toValue = length + span * 0.45
                if Bool.random() {
                    swap(&travel.fromValue, &travel.toValue)
                }
                let envelope = CAKeyframeAnimation(keyPath: "opacity")
                envelope.values = [0, Double.random(in: 0.72...1), Double.random(in: 0.55...0.95), 0]
                envelope.keyTimes = [0, 0.2, 0.8, 1]
                envelope.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 3)
                let flow = CAAnimationGroup()
                flow.duration = Double.random(in: 11...23)
                travel.duration = flow.duration
                envelope.duration = flow.duration
                flow.animations = [travel, envelope]
                flow.repeatCount = .infinity
                flow.beginTime = now - flow.duration * Double.random(in: 0...1)
                glow.add(flow, forKey: "flow")

                let breath = CABasicAnimation(keyPath: horizontal ? "transform.scale.y" : "transform.scale.x")
                breath.fromValue = Double.random(in: 0.6...0.85)
                breath.toValue = Double.random(in: 1.15...1.6)
                breath.duration = Double.random(in: 2...4.8)
                breath.autoreverses = true
                breath.repeatCount = .infinity
                breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                breath.beginTime = now - Double.random(in: 0...8)
                glow.add(breath, forKey: "breath")
            }
        }
    }
}
