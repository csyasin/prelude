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

    private var routeLabels: [String] {
        model.path.indices.map { index in
            model.config?.nodesByPath[Array(model.path.prefix(index + 1))]?.label ?? model.path[index]
        }
    }

    private var columns: [[KeyNode]] {
        guard options.count > 6 else { return [options] }
        let split = Int(ceil(Double(options.count) / 2.0))
        return [Array(options.prefix(split)), Array(options.dropFirst(split))]
    }

    private var rowCount: Int {
        columns.map(\.count).max() ?? 0
    }

    private var toastLayout: ToastLayout {
        ToastLayout.measure(message: model.toast?.message ?? "", hasIcon: model.toast?.type != nil,
                            minimumWidth: max(270, model.islandMetrics.notchWidth),
                            maximumWidth: model.islandMetrics.maximumToastWidth,
                            horizontalPadding: horizontalContentPadding)
    }

    private var targetWidth: CGFloat {
        if model.completing { return toastLayout.width }
        let raw: CGFloat
        if model.configError != nil { raw = 430 }
        else { raw = columns.count == 1 ? 340 : 560 }
        return max(model.islandMetrics.notchWidth, min(raw, model.islandMetrics.maximumWidth))
    }

    private var targetHeight: CGFloat {
        if model.completing { return contentTopInset + toastLayout.contentHeight + visibleSidePadding }
        if model.configError != nil { return contentTopInset + 122 + 8 }
        // Keep the same header space at root and within a route.
        let headerHeight: CGFloat = 39
        return contentTopInset + headerHeight + CGFloat(rowCount) * 37 + navigationBottomPadding
    }

    private var horizontalContentPadding: CGFloat {
        let base: CGFloat = model.islandMetrics.hasNotch ? 26 : 22
        return model.completing || model.configError == nil ? base + 8 : base
    }

    private var visibleSidePadding: CGFloat {
        horizontalContentPadding - (model.islandMetrics.hasNotch ? 14 : 0)
    }

    private var navigationBottomPadding: CGFloat {
        // The attached shell is inset 14pt from its frame on each side. A 25pt
        // key is centered in a 37pt row, already leaving 6pt below the last key.
        // Match the visible key-to-edge gap, rather than just the frame padding.
        return max(0, visibleSidePadding - 6)
    }

    private var bottomContentPadding: CGFloat {
        if model.completing { return visibleSidePadding }
        return model.configError == nil ? navigationBottomPadding : 20
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
        .animation(shellAnimation, value: model.path)
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
                .padding(.horizontal, horizontalContentPadding)
                .padding(.bottom, bottomContentPadding)
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
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Group {
                    VStack(spacing: 0) {
                        routeHeader
                            .frame(height: 24)
                            .padding(.bottom, 7)
                        Rectangle()
                            .fill(.white.opacity(0.065))
                            .frame(height: 1)
                            .padding(.bottom, 7)
                    }
                    // Lay out glyphs at their final width. Only the surrounding
                    // opacity transition animates; head truncation cannot sweep
                    // across the text as an inherited frame animation expands.
                    .frame(width: max(0, targetWidth - horizontalContentPadding * 2), alignment: .leading)
                    .transaction { $0.animation = nil }
                    .id(model.path)
                    .transition(.opacity.animation(reduceMotion ? nil : .easeInOut(duration: 0.16)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 39, alignment: .top)
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

                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .id(model.path.joined(separator: "\u{1F}"))
            .transition(.opacity)

        }
    }

    private struct RouteCrumb: Identifiable {
        let id: String
        let label: String
        let isCurrent: Bool
    }

    private var routeHeader: some View {
        let labels = routeLabels
        let fitted = BreadcrumbLayout.fit(labels: labels,
            availableWidth: max(0, targetWidth - horizontalContentPadding * 2))
        let crumbs = fitted.labels.enumerated().map { index, label in
            let depth = fitted.omittedCount + index + 1
            return RouteCrumb(id: model.path.prefix(depth).joined(separator: "\u{1F}"),
                              label: label, isCurrent: depth == model.path.count)
        }
        return HStack(spacing: 0) {
            if labels.isEmpty {
                Text("PRELUDE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
            }
            if fitted.omittedCount > 0 {
                Text("…")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.42))
            }
            ForEach(crumbs) { crumb in
                if fitted.omittedCount > 0 || crumb.id != crumbs.first?.id {
                    routeSeparator
                }
                Text(crumb.label)
                    .font(.system(size: 12, weight: crumb.isCurrent ? .semibold : .regular))
                    .foregroundStyle(.white.opacity(crumb.isCurrent ? 0.65 : 0.38))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .layoutPriority(crumb.isCurrent ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(labels.isEmpty ? "Prelude" : labels.joined(separator: "，"))
    }

    private var routeSeparator: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.gray)
            .frame(width: BreadcrumbLayout.separatorWidth)
            .padding(.horizontal, BreadcrumbLayout.separatorSpacing)
    }

    private func optionRow(_ node: KeyNode) -> some View {
        KeyOptionRow(node: node, accentHex: accentHex)
    }

    private var toastIcon: (symbol: String, color: Color, label: String)? {
        switch model.toast?.type {
        case .success: return ("checkmark", .green, "成功")
        case .error: return ("xmark", .red, "失败")
        case .warning: return ("exclamationmark", .orange, "警告")
        case .info: return ("info", .blue, "信息")
        case nil: return nil
        }
    }

    private var completionContent: some View {
        HStack(spacing: 11) {
            if let icon = toastIcon {
                ZStack {
                    Circle().fill(icon.color.opacity(0.13)).frame(width: 32, height: 32)
                    Image(systemName: icon.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(icon.color)
                }
            }
            Text(model.toast?.message ?? "")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: toastLayout.textWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([toastIcon?.label, model.toast?.message].compactMap { $0 }.joined(separator: "，"))
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
