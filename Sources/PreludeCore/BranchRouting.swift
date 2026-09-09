import CoreGraphics
import Foundation

/// A single shared bus per parent, with rounded OUTER corners only.
/// Interior children join the same straight bus; no per-child S curves or tiny doglegs.
public struct BranchRouting {
    public enum Segment: Equatable, Sendable {
        case line(CGPoint, CGPoint)
        case quad(CGPoint, CGPoint, CGPoint)
        public var start: CGPoint { switch self { case .line(let a, _), .quad(let a, _, _): return a } }
        public var end: CGPoint { switch self { case .line(_, let b), .quad(_, _, let b): return b } }
    }
    public struct Route {
        public let path: [String]
        public let segments: [Segment]
    }
    public let segments: [Segment]
    public let routes: [Route]
    public let radius: Double
    public let busX: Double

    public init(edges: [MindMap.Edge]) {
        let children = edges.sorted { $0.y2 < $1.y2 }
        guard let first = children.first, let last = children.last else {
            segments = []; routes = []; radius = 0; busX = 0; return
        }
        let x = (first.x1 + first.x2) / 2
        busX = x
        let source = CGPoint(x: first.x1, y: first.y1)
        let join = CGPoint(x: x, y: first.y1)
        if children.count == 1 {
            // Layout centers a single child exactly on its parent.
            let line = Segment.line(source, CGPoint(x: first.x2, y: first.y2))
            segments = [line]; routes = [Route(path: first.path, segments: [line])]; radius = 0
            return
        }
        let minGap = zip(children, children.dropFirst()).map { $1.y2 - $0.y2 }.min() ?? 0
        let r = max(0, min(24, (first.x2 - first.x1) / 3, minGap / 2, (last.y2 - first.y2) / 2))
        radius = r
        let top = first.y2, bottom = last.y2
        let stem = Segment.line(source, join)
        let topArc = Segment.quad(CGPoint(x: x, y: top + r), CGPoint(x: x, y: top), CGPoint(x: x + r, y: top))
        let bottomArc = Segment.quad(CGPoint(x: x, y: bottom - r), CGPoint(x: x, y: bottom), CGPoint(x: x + r, y: bottom))
        let topExit = Segment.line(topArc.end, CGPoint(x: first.x2, y: top))
        let bottomExit = Segment.line(bottomArc.end, CGPoint(x: last.x2, y: bottom))
        var base: [Segment] = [stem, .line(topArc.start, bottomArc.start), topArc, topExit, bottomArc, bottomExit]
        for child in children.dropFirst().dropLast() {
            base.append(.line(CGPoint(x: x, y: child.y2), CGPoint(x: child.x2, y: child.y2)))
        }
        segments = base.filter { $0.start != $0.end }
        routes = children.enumerated().map { index, child in
            let tail: [Segment]
            if index == 0 { tail = [.line(join, topArc.start), topArc, topExit] }
            else if index == children.count - 1 { tail = [.line(join, bottomArc.start), bottomArc, bottomExit] }
            else { tail = [.line(join, CGPoint(x: x, y: child.y2)), .line(CGPoint(x: x, y: child.y2), CGPoint(x: child.x2, y: child.y2))] }
            return Route(path: child.path, segments: ([stem] + tail).filter { $0.start != $0.end })
        }
    }
}
