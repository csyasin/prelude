import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("usage: make_menu_template.swift <orbit|panels> <output.png>\n", stderr)
    exit(2)
}

let style = CommandLine.arguments[1]
let size = 36
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

NSColor.black.setFill()

if style == "orbit" {
    let beam = NSBezierPath()
    beam.move(to: NSPoint(x: 7, y: 26))
    beam.curve(to: NSPoint(x: 27, y: 11), controlPoint1: NSPoint(x: 6, y: 10), controlPoint2: NSPoint(x: 17, y: 5))
    beam.lineWidth = 5.4
    beam.lineCapStyle = .round
    beam.lineJoinStyle = .round
    beam.stroke()
    NSBezierPath(ovalIn: NSRect(x: 24, y: 8, width: 7, height: 7)).fill()
} else {
    func panel(_ points: [NSPoint]) {
        let path = NSBezierPath()
        path.move(to: points[0])
        for point in points.dropFirst() { path.line(to: point) }
        path.close()
        path.fill()
    }
    panel([
        NSPoint(x: 6, y: 7), NSPoint(x: 14, y: 7), NSPoint(x: 18, y: 10),
        NSPoint(x: 18, y: 12), NSPoint(x: 13, y: 16), NSPoint(x: 6, y: 13)
    ])
    panel([
        NSPoint(x: 21, y: 7), NSPoint(x: 29, y: 7), NSPoint(x: 29, y: 16),
        NSPoint(x: 25, y: 19), NSPoint(x: 23, y: 17), NSPoint(x: 23, y: 11),
        NSPoint(x: 20, y: 9)
    ])
    panel([
        NSPoint(x: 6, y: 18), NSPoint(x: 10, y: 20), NSPoint(x: 10, y: 24),
        NSPoint(x: 15, y: 24), NSPoint(x: 13, y: 29), NSPoint(x: 6, y: 29)
    ])
    panel([
        NSPoint(x: 22, y: 20), NSPoint(x: 29, y: 16), NSPoint(x: 29, y: 29),
        NSPoint(x: 22, y: 29), NSPoint(x: 19, y: 26), NSPoint(x: 19, y: 23)
    ])
}
NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: outputURL)
