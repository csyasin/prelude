import SwiftUI
import PreludeCore

private let accent = Color(red: 0.62, green: 0.91, blue: 0.79)

private func connectionPath(_ segments: [BranchRouting.Segment]) -> Path {
    var path = Path()
    for segment in segments {
        if path.currentPoint != segment.start { path.move(to: segment.start) }
        switch segment {
        case .line(_, let end): path.addLine(to: end)
        case .quad(_, let control, let end): path.addQuadCurve(to: end, control: control)
        }
    }
    return path
}

struct TreeView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "pianokeys").foregroundStyle(accent)
                    Text("Prelude").font(.system(size: 29, weight: .medium, design: .serif)).tracking(-0.5)
                }
                Spacer()
                Text(model.config?.hotkey.display ?? "⌃ Space").font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            }
            HStack(spacing: 8) {
                Text("完整按键图").foregroundStyle(.white.opacity(0.5))
                Text("/  \(model.config?.bindings.count ?? 0) 个动作").foregroundStyle(.white.opacity(0.3))
                Spacer()
                Text(model.path.isEmpty ? "等待按键" : model.path.map { $0.uppercased() }.joined(separator: "  →  "))
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(accent)
            }.font(.system(size: 11)).padding(.top, 12).padding(.bottom, 18)
            Divider().overlay(.white.opacity(0.07))
            if let error = model.configError {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.config == nil ? "配置需要修正" : "新配置未生效 · 保留上次有效配置").fontWeight(.semibold)
                    Text(error).lineLimit(3)
                    Button("编辑配置") { model.openConfig() }.buttonStyle(.plain).foregroundStyle(accent)
                }.font(.system(size: 12)).foregroundStyle(.white.opacity(0.8)).padding(.vertical, 12)
            }
            if let map = model.config?.map {
                GeometryReader { geometry in
                    let scale = min(1, max(0.8, min(geometry.size.width / map.width, (geometry.size.height - 24) / map.height)))
                    ScrollViewReader { proxy in
                        ScrollView([.horizontal, .vertical]) {
                            ZStack(alignment: .topLeading) {
                                Canvas { context, _ in
                                    // Draw each shared segment once. Highlight is a second pass over
                                    // exactly the same geometry, never a separately rounded edge.
                                    let base = map.branches.flatMap(\.segments)
                                    context.stroke(connectionPath(base), with: .color(.white.opacity(0.20)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                                    let selected = map.branches.flatMap(\.routes).filter { !model.path.isEmpty && model.path.starts(with: $0.path) }.flatMap(\.segments)
                                    context.stroke(connectionPath(selected), with: .color(accent), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                }.frame(width: map.width, height: map.height).accessibilityHidden(true)
                                HStack(spacing: 9) {
                                    Circle().fill(accent).frame(width: 6, height: 6)
                                    Text("LEADER").font(.system(size: 12, weight: .semibold, design: .monospaced)).tracking(1)
                                }
                                .foregroundStyle(accent).frame(width: MindMap.nodeWidth, height: 38)
                                .background(RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.22)))
                                .position(x: MindMap.nodeWidth / 2, y: map.rootY)
                                ForEach(map.items) { item in
                                    node(item.node)
                                        .frame(width: MindMap.nodeWidth, height: 40)
                                        .position(x: item.x + MindMap.nodeWidth / 2, y: item.y)
                                        .id(item.id)
                                }
                            }
                            .frame(width: map.width, height: map.height)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: map.width * scale, height: map.height * scale, alignment: .topLeading)
                            .padding(.vertical, 12)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: model.path) { _, path in
                            guard !path.isEmpty, map.width * scale > geometry.size.width || map.height * scale > geometry.size.height - 24 else { return }
                            proxy.scrollTo(path.joined(separator: "\u{1F}"), anchor: .center)
                        }
                    }
                }
            } else { Spacer() }
            Divider().overlay(.white.opacity(0.07))
            HStack(spacing: 8) {
                Image(systemName: model.completing ? "checkmark" : "arrow.turn.down.right").foregroundStyle(accent)
                Text(model.message).lineLimit(1)
                Spacer()
                Text("⌫ 返回").foregroundStyle(.white.opacity(0.35))
                Text("esc 退出").foregroundStyle(.white.opacity(0.35)).padding(.leading, 8)
            }.font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).padding(.top, 16)
        }
        .padding(28)
        .background(Color(red: 0.046, green: 0.063, blue: 0.061))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.12), lineWidth: 1))
        .preferredColorScheme(.dark)
    }
    private func node(_ node: KeyNode) -> some View {
        let selected = !model.path.isEmpty && model.path.starts(with: node.path)
        let next = node.path.count == model.path.count + 1 && node.path.starts(with: model.path)
        let relevant = model.path.isEmpty || selected || node.path.starts(with: model.path)
        return HStack(spacing: 9) {
            Text(node.key.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(selected ? Color(red: 0.05, green: 0.15, blue: 0.12) : accent.opacity(next ? 1 : 0.7))
                .frame(width: 27, height: 27)
                .background(RoundedRectangle(cornerRadius: 6).fill(selected ? accent : .white.opacity(0.05)))
            Text(node.label).font(.system(size: 13, weight: node.children.isEmpty ? .regular : .semibold))
                .foregroundStyle(selected ? accent : .white.opacity(relevant ? 0.86 : 0.48))
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
            if next && node.binding != nil { Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(accent.opacity(0.6)) }
        }
        .padding(.horizontal, 9)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 9).fill(selected ? accent.opacity(0.075) : Color(red: 0.046, green: 0.063, blue: 0.061)))
        .overlay(alignment: .bottom) { Rectangle().fill(selected ? accent.opacity(0.5) : .white.opacity(relevant ? 0.16 : 0.07)).frame(height: 1).padding(.horizontal, 8) }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: selected)
        .help(node.label + (node.binding.map { "\n" + $0.action } ?? ""))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(node.path.joined(separator: "，"))，\(node.label)\(selected ? "，已激活" : "")")
    }
}
