import AppKit

/// Measure the same font used by the toast before animating its shell. Text wraps
/// at the width limit, so neither long sentences nor unbroken strings truncate.
public struct ToastLayout {
    public let width: CGFloat
    public let textWidth: CGFloat
    public let contentHeight: CGFloat

    public static func measure(message: String, hasIcon: Bool, minimumWidth: CGFloat,
                               maximumWidth: CGFloat, horizontalPadding: CGFloat) -> ToastLayout {
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: paragraph]
        let text = NSAttributedString(string: message, attributes: attributes)
        let iconWidth: CGFloat = hasIcon ? 43 : 0 // 32pt icon + 11pt spacing
        let insets = horizontalPadding * 2 + iconWidth
        let naturalTextWidth = ceil(text.size().width) + 2
        let width = min(maximumWidth, max(minimumWidth, naturalTextWidth + insets))
        let textWidth = max(1, min(naturalTextWidth, width - insets))
        let bounds = text.boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                                       options: [.usesLineFragmentOrigin, .usesFontLeading])
        return ToastLayout(width: width, textWidth: textWidth,
                           contentHeight: max(32, ceil(bounds.height) + 4))
    }
}
