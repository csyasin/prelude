import CoreGraphics
import XCTest
@testable import PreludeCore

final class BranchRoutingTests: XCTestCase {
    private func leaf(_ path: [String]) -> KeyNode {
        KeyNode(path: path, label: path.last!, binding: Binding(sequence: path, label: path.last!, action: "true"), children: [])
    }
    private func assertGeometry(_ map: MindMap, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(map.branches.flatMap(\.routes).count, map.items.count, file: file, line: line)
        let lookup = Dictionary(uniqueKeysWithValues: map.items.map { ($0.node.path, $0) })
        for branch in map.branches {
            // No duplicate segment or reversed duplicate: shared trunks are emitted once.
            for (i, a) in branch.segments.enumerated() {
                XCTAssertNotEqual(a.start, a.end, file: file, line: line)
                for b in branch.segments.dropFirst(i + 1) {
                    XCTAssertNotEqual(a, b, file: file, line: line)
                    if case .line = a, case .line = b {
                        XCTAssertFalse(a.start == b.end && a.end == b.start, file: file, line: line)
                    }
                }
            }
            for route in branch.routes {
                let item = lookup[route.path]!
                XCTAssertEqual(route.segments.last?.end, CGPoint(x: item.x, y: item.y), file: file, line: line)
                for (a, b) in zip(route.segments, route.segments.dropFirst()) {
                    XCTAssertEqual(a.end, b.start, file: file, line: line)
                }
                for segment in route.segments {
                    let covered = branch.segments.contains { base in
                        if segment == base { return true }
                        guard case .line(let a, let b) = segment, case .line(let c, let d) = base else { return false }
                        if a.x == b.x && c.x == d.x && a.x == c.x {
                            return min(a.y,b.y) >= min(c.y,d.y) && max(a.y,b.y) <= max(c.y,d.y)
                        }
                        if a.y == b.y && c.y == d.y && a.y == c.y {
                            return min(a.x,b.x) >= min(c.x,d.x) && max(a.x,b.x) <= max(c.x,d.x)
                        }
                        return false
                    }
                    XCTAssertTrue(covered, "Highlight must be a subset of shared routing", file: file, line: line)
                    for point in [segment.start, segment.end] {
                        XCTAssertTrue(point.x.isFinite && point.y.isFinite, file: file, line: line)
                        XCTAssertGreaterThanOrEqual(point.y, 0, file: file, line: line)
                        XCTAssertLessThanOrEqual(point.y, map.height, file: file, line: line)
                    }
                }
            }
        }
        // Sibling subtrees cannot overlap at any depth.
        let columns = Dictionary(grouping: map.items, by: { $0.node.path.count })
        for items in columns.values {
            let sorted = items.sorted { $0.y < $1.y }
            for (a,b) in zip(sorted, sorted.dropFirst()) {
                XCTAssertGreaterThanOrEqual(b.y - a.y, 40, file: file, line: line)
            }
        }
    }
    func testSingleChildAndDeepChainAreStraight() {
        var node = leaf((0..<30).map { String($0) })
        for depth in (1..<30).reversed() { node = KeyNode(path: Array(node.path.prefix(depth)), label: "group", binding: nil, children: [node]) }
        let map = MindMap(tree: [node])
        assertGeometry(map)
        XCTAssertTrue(map.branches.allSatisfy { $0.radius == 0 && $0.segments.count == 1 })
    }
    func testScreenshotFourChildrenHasOneTrunkAndTwoOuterCorners() {
        let children = ["s","t","f","n"].map { leaf(["a", $0]) }
        let map = MindMap(tree: [KeyNode(path: ["a"], label: "应用", binding: nil, children: children)])
        assertGeometry(map)
        let branch = map.branches.first { $0.routes.count == 4 }!
        XCTAssertEqual(branch.radius, 24)
        XCTAssertEqual(branch.segments.filter { if case .quad = $0 { return true }; return false }.count, 2)
    }
    func testNearAlignedChildCannotProduceTinyDogleg() {
        let edges = [0.0, 107.0, 200.0].enumerated().map { i,y in
            MindMap.Edge(parent: nil, child: String(i), path: [String(i)], x1: 174, y1: 100, x2: 264, y2: y)
        }
        let branch = BranchRouting(edges: edges)
        let middle = branch.routes[1]
        XCTAssertTrue(middle.segments.allSatisfy { if case .line = $0 { return true }; return false })
        XCTAssertEqual(branch.radius, 24)
    }
    func testOddBranchParentAlignsExactlyWithMiddleChild() {
        let big = KeyNode(path: ["a"], label: "big", binding: nil, children: (0..<8).map { leaf(["a", String($0)]) })
        let map = MindMap(tree: [big, leaf(["b"]), leaf(["c"])])
        XCTAssertEqual(map.rootY, map.items.first { $0.node.path == ["b"] }!.y)
        assertGeometry(map)
    }
    func testManySiblingsAndUnbalancedTrees() {
        var seed: UInt64 = 847
        func next(_ upper: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 32) % UInt64(upper))
        }
        for _ in 0..<100 {
            var remaining = 350
            func generate(_ path: [String], depth: Int) -> KeyNode {
                remaining -= 1
                if depth == 0 || remaining <= 0 || next(3) == 0 { return leaf(path) }
                let children = (0..<(next(8) + 1)).map { generate(path + [String($0)], depth: depth - 1) }
                return KeyNode(path: path, label: "group", binding: nil, children: children)
            }
            let roots = (0..<(next(8) + 1)).map { generate([String($0)], depth: 5) }
            assertGeometry(MindMap(tree: roots))
        }
    }
}
