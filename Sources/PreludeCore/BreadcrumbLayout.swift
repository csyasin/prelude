import AppKit

public struct BreadcrumbLayout {
    public let labels: [String]
    public let omittedCount: Int
    public static let separatorWidth: CGFloat = 6
    public static let separatorSpacing: CGFloat = 8

    /// Prefer the complete path, then remove only as many leading ancestors as
    /// necessary. The current group is always retained, even if it alone is long.
    public static func fit(labels: [String], availableWidth: CGFloat) -> BreadcrumbLayout {
        guard !labels.isEmpty else { return BreadcrumbLayout(labels: [], omittedCount: 0) }
        for start in labels.indices {
            let suffix = Array(labels[start...])
            let displayed = (start > 0 ? ["…"] : []) + suffix
            let namesWidth = displayed.enumerated().reduce(CGFloat.zero) { width, item in
                let weight: NSFont.Weight = item.offset == displayed.count - 1 ? .semibold : .regular
                return width + ceil((item.element as NSString).size(withAttributes:
                    [.font: NSFont.systemFont(ofSize: 12, weight: weight)]).width)
            }
            let separatorsWidth = CGFloat(displayed.count - 1) * (separatorWidth + separatorSpacing * 2)
            if namesWidth + separatorsWidth + 2 <= availableWidth || start == labels.count - 1 {
                return BreadcrumbLayout(labels: suffix, omittedCount: start)
            }
        }
        return BreadcrumbLayout(labels: labels, omittedCount: 0)
    }
}
