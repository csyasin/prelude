import AppKit
import SwiftUI

/// Store sRGB components rather than archiving platform-specific color objects.
enum ThemeColor {
    static let preferenceKey = "appearance.accentHex"
    static let defaultHex = "9EE8C9"
    static let presets: [(name: String, hex: String)] = [
        ("薄荷", defaultHex), ("天蓝", "8ACBFF"), ("紫藤", "C4ACFF"),
        ("玫瑰", "FFACC8"), ("蜜桃", "FFBE98"), ("暖黄", "F4DC8A")
    ]

    static func color(_ hex: String) -> Color {
        let value = hex.count == 6 ? UInt32(hex, radix: 16) : nil
        let rgb = value ?? 0x9EE8C9
        return Color(.sRGB, red: Double((rgb >> 16) & 255) / 255,
                     green: Double((rgb >> 8) & 255) / 255,
                     blue: Double(rgb & 255) / 255, opacity: 1)
    }

    static func hex(_ color: Color) -> String? {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        let components = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
            .map { Int((min(1, max(0, $0)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", components[0], components[1], components[2])
    }

    static func keyInk(_ hex: String) -> Color {
        guard let rgb = NSColor(color(hex)).usingColorSpace(.sRGB) else { return .black }
        func linear(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(rgb.redComponent)
            + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
        let contrastWithBlack = (luminance + 0.05) / 0.05
        let contrastWithWhite = 1.05 / (luminance + 0.05)
        return contrastWithBlack >= contrastWithWhite ? .black : .white
    }
}
