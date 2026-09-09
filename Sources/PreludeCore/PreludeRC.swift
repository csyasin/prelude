import Foundation

/// Line-oriented, contextual DSL. Shell text is opaque after the action separator.
enum PreludeRC {
    private final class Draft {
        let key: String
        let name: String
        let line: Int
        let script: String?
        var children: [Draft] = []
        init(key: String, name: String, line: Int, script: String? = nil) {
            self.key = key; self.name = name; self.line = line; self.script = script
        }
    }
    static func parse(_ text: String) throws -> (tree: [KeyNode], leader: Leader) {
        let root = Draft(key: "", name: "root", line: 1)
        var context: [Draft] = []
        var leader = Leader()
        var hasLeader = false
        func failure(_ line: Int, _ message: String) -> ConfigError { ConfigError("第 \(line) 行：\(message)") }
        func trim(_ text: String) -> String { text.trimmingCharacters(in: .whitespaces) }
        func keyAndRest(_ source: String, line: Int) throws -> (String, String) {
            guard let first = source.first else { throw failure(line, "缺少按键。") }
            let key = String(first)
            guard key == key.lowercased(), key.unicodeScalars.allSatisfy({ (33...126).contains(Int($0.value)) }), key != "@", key != "#" else {
                throw failure(line, "按键须为一个小写字母、数字或 ASCII 符号；@ 和 # 为保留符号。")
            }
            let remainder = String(source.dropFirst())
            guard remainder.isEmpty || remainder.first?.isWhitespace == true else { throw failure(line, "按键后需要空格。") }
            return (key, String(remainder.drop(while: { $0 == " " || $0 == "\t" })))
        }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        for (index, raw) in normalized.components(separatedBy: "\n").enumerated() {
            let line = index + 1
            let source = index == 0 && raw.hasPrefix("\u{FEFF}") ? String(raw.dropFirst()) : raw
            let content = source.drop(while: { $0 == " " || $0 == "\t" })
            if content.isEmpty || content.hasPrefix("#") { continue }
            if content.hasPrefix("!leader ") {
                guard !hasLeader else { throw failure(line, "!leader 只能定义一次。") }
                let parts = trim(String(content.dropFirst(8))).split(separator: "+", omittingEmptySubsequences: false).map { trim(String($0)).lowercased() }
                guard let key = parts.last, KeyNames.codes[key] != nil else { throw failure(line, "无效的激活键。") }
                let modifiers = Array(parts.dropLast())
                guard Set(modifiers).count == modifiers.count, modifiers.allSatisfy({ ["control", "option", "shift", "command"].contains($0) }), !modifiers.isEmpty || (1...20).contains(where: { key == "f\($0)" }) else {
                    throw failure(line, "激活键示例：!leader control+space 或 !leader f12。")
                }
                leader = Leader(key: key, modifiers: modifiers); hasLeader = true
                continue
            }
            if content.hasPrefix("@") {
                let depth = content.prefix(while: { $0 == "@" }).count
                let rest = trim(String(content.dropFirst(depth)))
                if depth == 1 && rest.isEmpty { context = []; continue }
                guard depth <= context.count + 1 else { throw failure(line, "分组层级不能跳级；缺少第 \(depth - 1) 层上下文。") }
                let (key, suffix) = try keyAndRest(rest, line: line)
                let parent = depth == 1 ? root : context[depth - 2]
                let name: String?
                if suffix.isEmpty { name = nil }
                else {
                    guard suffix.hasPrefix("- ") else { throw failure(line, "分组格式：@ 按键 - 名称；切回已有分组可写 @ 按键。") }
                    let value = trim(String(suffix.dropFirst(2)))
                    guard !value.isEmpty else { throw failure(line, "分组名称不能为空。") }
                    name = value
                }
                let group: Draft
                if let existing = parent.children.first(where: { $0.key == key }) {
                    guard existing.script == nil else { throw failure(line, "按键 \(key) 已被动作占用。") }
                    guard name == nil || name == existing.name else { throw failure(line, "同级分组按键 \(key) 已定义为“\(existing.name)”。") }
                    group = existing
                } else {
                    guard let name else { throw failure(line, "分组 \(key) 尚未声明，请先写名称。") }
                    group = Draft(key: key, name: name, line: line)
                    parent.children.append(group)
                }
                context = Array(context.prefix(depth - 1)) + [group]
                continue
            }
            let (key, suffix) = try keyAndRest(String(content), line: line)
            guard suffix.hasPrefix("- "), let separator = suffix.dropFirst(2).firstIndex(of: ":") else { throw failure(line, "动作格式：按键 - 名称 : shell 脚本。") }
            let name = trim(String(suffix[suffix.index(suffix.startIndex, offsetBy: 2)..<separator]))
            // Remove only one optional formatting space. Preserve all shell quotes, #, URLs,
            // colons, backslashes and trailing spaces. Never tokenize or execute on load.
            var script = String(suffix[suffix.index(after: separator)...])
            if script.first == " " { script.removeFirst() }
            guard !name.isEmpty, !trim(script).isEmpty else { throw failure(line, "动作名称和脚本不能为空。") }
            let parent = context.last ?? root
            guard !parent.children.contains(where: { $0.key == key }) else { throw failure(line, "当前分组的按键 \(key) 重复。") }
            parent.children.append(Draft(key: key, name: name, line: line, script: script))
        }
        func freeze(_ node: Draft, prefix: [String]) throws -> KeyNode {
            let path = prefix + [node.key]
            if let script = node.script { return KeyNode(path: path, label: node.name, binding: Binding(sequence: path, label: node.name, action: script), children: []) }
            guard !node.children.isEmpty else { throw failure(node.line, "分组“\(node.name)”没有动作。") }
            return KeyNode(path: path, label: node.name, binding: nil, children: try node.children.map { try freeze($0, prefix: path) })
        }
        guard !root.children.isEmpty else { throw failure(1, "至少需要一个动作。") }
        return (try root.children.map { try freeze($0, prefix: []) }, leader)
    }
}
