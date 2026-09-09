import Foundation

public struct ConfigError: LocalizedError {
    public let message: String
    public var errorDescription: String? { message }
    public init(_ message: String) { self.message = message }
}

public struct Leader: Decodable, Equatable {
    public let key: String
    public let modifiers: [String]
    public init(key: String = "space", modifiers: [String] = ["control"]) {
        self.key = key; self.modifiers = modifiers
    }
    public var display: String {
        ["control", "option", "shift", "command"].filter(modifiers.contains)
            .map { ["control": "⌃", "option": "⌥", "shift": "⇧", "command": "⌘"][$0]! }.joined()
            + (key == "space" ? " Space" : key.uppercased())
    }
}

public struct Binding: Equatable, Sendable {
    public let sequence: [String]
    public let label: String
    public let action: String
}
public struct Configuration {
    public let hotkey: Leader
    public let tree: [KeyNode]
    public let bindings: [Binding]
    public let map: MindMap
    public let nodesByPath: [[String]: KeyNode]
    public static func parse(_ text: String) throws -> Configuration {
        let parsed = try PreludeRC.parse(text)
        let tree = parsed.tree
        let flat = tree.flatMap(\.flattened)
        return Configuration(hotkey: parsed.leader, tree: tree, bindings: flat.compactMap(\.binding), map: MindMap(tree: tree), nodesByPath: Dictionary(uniqueKeysWithValues: flat.map { ($0.path, $0) }))
    }
}
public struct KeyNode: Identifiable {
    public let path: [String]
    public let label: String
    public let binding: Binding?
    public let children: [KeyNode]
    public var id: String { path.joined(separator: "\u{1F}") }
    public var key: String { path.last! }
    public var flattened: [KeyNode] { [self] + children.flatMap(\.flattened) }
}
public struct Navigator {
    public private(set) var path: [String] = []
    public init() {}
    public mutating func reset() { path = [] }
    public mutating func back() { if !path.isEmpty { path.removeLast() } }
    public enum Result: Equatable { case branch, action(Binding), invalid }
    public mutating func press(_ key: String, config: Configuration) -> Result {
        let next = path + [key]
        guard let node = config.nodesByPath[next] else { return .invalid }
        path = next
        if let binding = node.binding { return .action(binding) }
        return .branch
    }
}

/// Stable geometry is computed on configuration load, never per keystroke.
public struct MindMap {
    public struct Item: Identifiable {
        public let node: KeyNode
        public let x: Double
        public let y: Double
        public var id: String { node.id }
    }
    public struct Edge: Identifiable, Sendable {
        public let parent: String?
        public let child: String
        public let path: [String]
        public let x1: Double
        public let y1: Double
        public let x2: Double
        public let y2: Double
        public var id: String { child }
    }
    public let items: [Item]
    public let edges: [Edge]
    public let branches: [BranchRouting]
    public let width: Double
    public let height: Double
    public let rootY: Double
    public static let nodeWidth: Double = 174
    public static let column: Double = 264
    public init(tree: [KeyNode]) {
        var items: [Item] = []
        var edges: [Edge] = []
        var cursor: Double = 32
        func center(_ children: [Item]) -> Double {
            guard !children.isEmpty else { return 32 }
            let mid = children.count / 2
            return children.count.isMultiple(of: 2) ? (children[mid - 1].y + children[mid].y) / 2 : children[mid].y
        }
        func visit(_ node: KeyNode) -> Item {
            let children = node.children.map(visit)
            let y: Double
            if !children.isEmpty { y = center(children) }
            else { y = cursor; cursor += 54 }
            let item = Item(node: node, x: Double(node.path.count) * Self.column, y: y)
            items.append(item)
            for child in children {
                edges.append(Edge(parent: node.id, child: child.id, path: child.node.path, x1: item.x + Self.nodeWidth, y1: y, x2: child.x, y2: child.y))
            }
            return item
        }
        var roots: [Item] = []
        for node in tree { roots.append(visit(node)); cursor += 22 }
        let rootY = center(roots)
        for root in roots {
            edges.append(Edge(parent: nil, child: root.id, path: root.node.path, x1: Self.nodeWidth, y1: rootY, x2: root.x, y2: root.y))
        }
        self.items = items; self.edges = edges; self.rootY = rootY
        // Keep branch order deterministic, independent of Dictionary iteration order.
        let groups = Dictionary(grouping: edges, by: { $0.parent ?? "" })
        self.branches = groups.keys.sorted().map { BranchRouting(edges: groups[$0]!) }
        self.width = (items.map(\.x).max() ?? 0) + Self.nodeWidth + 24
        self.height = max(180, cursor + 6)
    }
}
public enum KeyNames {
    public static let codes: [String: UInt32] = [
        "a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,
        "q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"1":18,"2":19,"3":20,"4":21,
        "6":22,"5":23,"=":24,"9":25,"7":26,"-":27,"8":28,"0":29,
        "]":30,"o":31,"u":32,"[":33,"i":34,"p":35,"return":36,"l":37,"j":38,
        "'":39,"k":40,";":41,"\\":42,",":43,"/":44,"n":45,"m":46,".":47,"tab":48,
        "space":49,"`":50,"backspace":51,"escape":53,
        "f1":122,"f2":120,"f3":99,"f4":118,"f5":96,"f6":97,"f7":98,"f8":100,
        "f9":101,"f10":109,"f11":103,"f12":111,"f13":105,"f14":107,"f15":113,
        "f16":106,"f17":64,"f18":79,"f19":80,"f20":90,
        "left":123,"right":124,"down":125,"up":126
    ]
}
