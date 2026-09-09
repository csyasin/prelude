import SwiftUI
import PreludeCore

private let islandInk = Color.black

/// A shallow screen attachment on notched displays; a continuous floating
/// capsule on external displays. The corners morph with the shell, not its text.
private struct IslandSilhouette: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var attached: Bool

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        if !attached {
            return RoundedRectangle(cornerRadius: bottomRadius, style: .continuous).path(in: rect)
        }
        let shoulder = min(topRadius, rect.height / 2)
        let left = rect.minX + shoulder
        let right = rect.maxX - shoulder
        let radius = min(bottomRadius, (right - left) / 2, (rect.height - shoulder) / 2)
        let k: CGFloat = 0.55228475
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(to: CGPoint(x: right, y: rect.minY + shoulder),
                      control1: CGPoint(x: rect.maxX - shoulder * k, y: rect.minY),
                      control2: CGPoint(x: right, y: rect.minY + shoulder * (1 - k)))
        path.addLine(to: CGPoint(x: right, y: rect.maxY - radius))
        path.addCurve(to: CGPoint(x: right - radius, y: rect.maxY),
                      control1: CGPoint(x: right, y: rect.maxY - radius * (1 - k)),
                      control2: CGPoint(x: right - radius * (1 - k), y: rect.maxY))
        path.addLine(to: CGPoint(x: left + radius, y: rect.maxY))
        path.addCurve(to: CGPoint(x: left, y: rect.maxY - radius),
                      control1: CGPoint(x: left + radius * (1 - k), y: rect.maxY),
                      control2: CGPoint(x: left, y: rect.maxY - radius * (1 - k)))
        path.addLine(to: CGPoint(x: left, y: rect.minY + shoulder))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                      control1: CGPoint(x: left, y: rect.minY + shoulder * (1 - k)),
                      control2: CGPoint(x: rect.minX + shoulder * k, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct IslandShake: GeometryEffect {
    var amount: CGFloat = 5
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * 2 * shakes),
            y: 0
        ))
    }
}

struct IslandView: View {
    @ObservedObject var model: AppModel
    @AppStorage(ThemeColor.preferenceKey) private var accentHex = ThemeColor.defaultHex
    private var islandAccent: Color { ThemeColor.color(accentHex) }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var routeNamespace
    @State private var shake: CGFloat = 0
    @State private var expanded = false
    @State private var contentVisible = false
    @State private var layoutSize = CGSize(width: 340, height: 200)
    @State private var entranceTask: Task<Void, Never>?

    private var options: [KeyNode] {
        guard let config = model.config else { return [] }
        guard !model.path.isEmpty else { return config.tree }
        return config.nodesByPath[model.path]?.children ?? []
    }

    private var currentNode: KeyNode? {
        guard !model.path.isEmpty else { return nil }
        return model.config?.nodesByPath[model.path]
    }

    private var columns: [[KeyNode]] {
        guard options.count > 6 else { return [options] }
        let split = Int(ceil(Double(options.count) / 2.0))
        return [Array(options.prefix(split)), Array(options.dropFirst(split))]
    }

    private var rowCount: Int {
        columns.map(\.count).max() ?? 0
    }

    private var targetWidth: CGFloat {
        let raw: CGFloat
        if model.completing { raw = 270 }
        else if model.configError != nil { raw = 430 }
        else { raw = columns.count == 1 ? 340 : 560 }
        return max(model.islandMetrics.notchWidth, min(raw, model.islandMetrics.maximumWidth))
    }

    private var targetHeight: CGFloat {
        // Completion is one 32pt row; do not reserve the removed subtitle's space.
        if model.completing { return contentTopInset + 32 + 12 }
        let contentHeight: CGFloat
        if model.configError != nil { contentHeight = 122 }
        else { contentHeight = 57 + CGFloat(rowCount) * 37 + 13 }
        return contentTopInset + contentHeight + 8
    }

    private var contentTopInset: CGFloat {
        model.islandMetrics.hasNotch ? model.islandMetrics.notchDepth + 8 : 16
    }

    // End inside the hardware cutout, above its bottom corners. The safe-area
    // rectangle describes a bounding box, not the actual rounded camera shape.
    private var closedSize: CGSize {
        let metrics = model.islandMetrics
        return CGSize(width: metrics.hasNotch ? max(1, metrics.notchWidth - 24) : metrics.notchWidth,
                      height: metrics.hasNotch ? max(1, metrics.notchDepth - 12) : metrics.notchDepth)
    }

    private var silhouette: IslandSilhouette {
        IslandSilhouette(
            topRadius: expanded ? 14 : 0,
            bottomRadius: expanded ? 24 : (model.islandMetrics.hasNotch ? 8 : 6),
            attached: model.islandMetrics.hasNotch
        )
    }

    private var shellAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.9)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            island
                .modifier(IslandShake(animatableData: shake))

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Animate the parent's centering placement together with the shell's
        // size. A leaf-only animation moves to the destination left edge first,
        // then grows from there, briefly exposing the physical notch on the right.
        .animation(shellAnimation, value: layoutSize)
        .preferredColorScheme(.dark)
        .onChange(of: targetWidth) { _, _ in updateLayoutSize() }
        .onChange(of: targetHeight) { _, _ in updateLayoutSize() }
        .onDisappear { entranceTask?.cancel() }
        .onChange(of: model.presentationID) { _, _ in openIsland() }
        .onChange(of: model.active) { _, active in
            if !active { closeIsland() }
        }
        .onChange(of: model.invalidCount) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 0.22)) { shake += 1 }
        }
    }

    private var island: some View {
        // Keep the content at its destination size throughout the reveal. Only
        // the mask changes size, so labels never squeeze into the closed notch.
        silhouette
            .fill(islandInk)
            .shadow(color: .black.opacity(expanded ? 0.22 : 0), radius: 12, y: 5)
            .frame(width: expanded ? layoutSize.width : closedSize.width,
                   height: expanded ? layoutSize.height : closedSize.height)
            .overlay(alignment: .top) {
                Group {
                    if model.completing {
                        completionContent
                            .transition(.opacity)
                    } else if let error = model.configError {
                        errorContent(error)
                            .transition(.opacity)
                    } else {
                        navigationContent
                            .transition(.opacity)
                    }
                }
                .padding(.top, contentTopInset)
                .padding(.horizontal, model.islandMetrics.hasNotch ? 26 : 22)
                .padding(.bottom, model.completing ? 12 : 20)
                .frame(width: layoutSize.width, height: layoutSize.height, alignment: .top)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible || reduceMotion ? 0 : -4)
                .frame(width: expanded ? layoutSize.width : closedSize.width,
                       height: expanded ? layoutSize.height : closedSize.height, alignment: .top)
                .clipShape(silhouette)
            }
            .accessibilityElement(children: .contain)
    }

    private var navigationContent: some View {
        VStack(spacing: 7) {
            routeHeader
                .frame(height: 36)
            Rectangle()
                .fill(.white.opacity(0.075))
                .frame(height: 1)
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(columns.enumerated()), id: \.offset) { columnIndex, column in
                    if columnIndex > 0 {
                        Rectangle()
                            .fill(.white.opacity(0.065))
                            .frame(width: 1, height: CGFloat(rowCount) * 37 - 7)
                            .padding(.horizontal, 1)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(column.enumerated()), id: \.element.id) { rowIndex, node in
                            optionRow(node)
                                .frame(height: 37)
                                .transition(
                                    .asymmetric(
                                        insertion: .offset(y: -8).combined(with: .opacity),
                                        removal: .offset(y: 8).combined(with: .opacity)
                                    )
                                )
                                .animation(
                                    reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9)
                                        .delay(Double(rowIndex) * 0.018),
                                    value: model.path
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .id(model.path.joined(separator: "\u{1F}"))
        }
    }

    private var routeHeader: some View {
        HStack(spacing: 9) {
            if let currentNode {
                if model.path.count > 1 {
                    Text(model.path.dropLast().map { $0.uppercased() }.joined(separator: " / "))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.38))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.22))
                }
                routeIdentity(currentNode, compact: true)
                    .matchedGeometryEffect(id: "route-\(currentNode.id)", in: routeNamespace)
            } else {
                Circle()
                    .fill(islandAccent)
                    .frame(width: 6, height: 6)
                    .shadow(color: islandAccent.opacity(0.8), radius: 5)
                Text("PRELUDE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(islandAccent)
            }
            Spacer(minLength: 8)
            Text("\(options.count) KEYS")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.26))
        }
    }

    private func optionRow(_ node: KeyNode) -> some View {
        HStack(spacing: 10) {
            routeIdentity(node, compact: false)
                .matchedGeometryEffect(id: "route-\(node.id)", in: routeNamespace)
            Spacer(minLength: 4)
            Group {
                if node.binding == nil {
                    Image(systemName: "chevron.right")
                } else {
                    Image(systemName: "bolt.fill")
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(node.binding == nil ? Color.gray : islandAccent.opacity(0.42))
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.045)).frame(height: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("按 \(node.key)，\(node.label)")
    }

    private func routeIdentity(_ node: KeyNode, compact: Bool) -> some View {
        HStack(spacing: 9) {
            Text(node.key.uppercased())
                .font(.system(size: compact ? 13 : 14, weight: .bold, design: .monospaced))
                .foregroundStyle(ThemeColor.keyInk(accentHex))
                .frame(width: compact ? 23 : 25, height: compact ? 23 : 25)
                .background(RoundedRectangle(cornerRadius: 7).fill(islandAccent))
            Text(node.label)
                .font(.system(size: compact ? 12 : 12.5, weight: compact ? .semibold : .regular))
                .foregroundStyle(compact ? islandAccent : .white.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.tail)
            if !compact && node.binding == nil {
                Text("\(node.children.count)")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.gray)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(Capsule().fill(.white.opacity(0.09)))
                    .fixedSize()
            }
        }
    }

    private var completionContent: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(islandAccent.opacity(0.13)).frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(islandAccent)
            }
            Text(model.completionLabel ?? "已执行")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.completionLabel ?? "动作")，已执行")
    }

    private func errorContent(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(islandAccent)
            VStack(alignment: .leading, spacing: 5) {
                Text(model.config == nil ? "配置需要修正" : "新配置未生效")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(3)
                Text("⌘, 打开偏好设置")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(islandAccent.opacity(0.65))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func updateLayoutSize() {
        guard model.active else { return }
        layoutSize = CGSize(width: targetWidth, height: targetHeight)
    }

    private func openIsland() {
        entranceTask?.cancel()
        updateLayoutSize()
        guard !reduceMotion else {
            expanded = true
            contentVisible = true
            return
        }
        // A cancellable next-frame reveal also handles Escape or a fast action
        // arriving before the entrance begins. Reopening reverses the current
        // spring instead of snapping the shell back to its closed geometry.
        entranceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled, model.active else { return }
            withAnimation(shellAnimation) { expanded = true }
            withAnimation(.easeOut(duration: 0.12).delay(0.055)) {
                contentVisible = true
            }
        }
    }

    private func closeIsland() {
        entranceTask?.cancel()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.07)) {
            contentVisible = false
        }
        let presentationID = model.presentationID
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.28), completionCriteria: .removed) {
            expanded = false
        } completion: {
            model.overlays.finishHiding(presentationID: presentationID)
        }
    }
}
