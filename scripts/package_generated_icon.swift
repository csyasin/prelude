import AppKit

guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 4 else {
    fputs("usage: package_generated_icon.swift <source.png> <iconset-dir> [crop-ratio]\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = NSImage(contentsOf: sourceURL) else {
    fputs("cannot read source image\n", stderr)
    exit(1)
}

let sourceSize = min(source.size.width, source.size.height)
let cropRatio = CommandLine.arguments.count == 4 ? (Double(CommandLine.arguments[3]) ?? 0) : 0
let cropInset = sourceSize * cropRatio
let sourceRect = NSRect(
    x: (source.size.width - sourceSize) / 2 + cropInset,
    y: (source.size.height - sourceSize) / 2 + cropInset,
    width: sourceSize - cropInset * 2,
    height: sourceSize - cropInset * 2
)

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func render(size: Int) throws -> Data {
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
    ) else { throw NSError(domain: "PreludeIcon", code: 1) }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // Keep the icon tile opaque. Transparent corners make the preview panel
    // show through and produce a broken-looking four-corner silhouette.
    NSColor(calibratedRed: 0.015, green: 0.023, blue: 0.070, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let rect = NSRect(x: 1, y: 1, width: size - 2, height: size - 2)
    let radius = CGFloat(size) * 0.19
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    source.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: sourceRect, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "PreludeIcon", code: 2)
    }
    return data
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(points)x\(points)\(suffix).png"
        try render(size: pixels).write(to: iconsetURL.appendingPathComponent(name))
    }
}
