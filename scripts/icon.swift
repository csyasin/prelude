import AppKit
let output = CommandLine.arguments[1]
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSColor(calibratedRed: 0.065, green: 0.095, blue: 0.09, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 216, yRadius: 216).fill()
let mint = NSColor(calibratedRed: 0.62, green: 0.91, blue: 0.79, alpha: 1)
let halo = NSBezierPath(roundedRect: NSRect(x: 74, y: 74, width: 876, height: 876), xRadius: 177, yRadius: 177)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow(); shadow.shadowColor = mint.withAlphaComponent(0.65); shadow.shadowBlurRadius = 36; shadow.set()
mint.withAlphaComponent(0.85).setStroke(); halo.lineWidth = 5; halo.stroke()
NSGraphicsContext.restoreGraphicsState()
// A P drawn as a continuous route, with three piano-key strokes.
let path = NSBezierPath()
path.move(to: NSPoint(x: 354, y: 266)); path.line(to: NSPoint(x: 354, y: 734))
path.line(to: NSPoint(x: 562, y: 734))
path.curve(to: NSPoint(x: 562, y: 460), controlPoint1: NSPoint(x: 749, y: 734), controlPoint2: NSPoint(x: 749, y: 460))
path.line(to: NSPoint(x: 463, y: 460))
path.lineWidth = 55; path.lineCapStyle = .round; path.lineJoinStyle = .round
mint.setStroke(); path.stroke()
for (x, h) in [(463.0, 101.0), (567.0, 58.0)] {
    let line = NSBezierPath(); line.move(to: NSPoint(x: x, y: 266)); line.line(to: NSPoint(x: x, y: 266 + h))
    line.lineWidth = 41; line.lineCapStyle = .round; mint.withAlphaComponent(0.45).setStroke(); line.stroke()
}
image.unlockFocus()
let directory = URL(fileURLWithPath: output)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
