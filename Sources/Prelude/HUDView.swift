import AppKit
import SwiftUI
import PreludeCore

/// A transparent screen overlay: light stays at the edges, navigation stays still.
struct HUDView: View {
    @ObservedObject var model: AppModel
    @AppStorage(ThemeColor.preferenceKey) private var accentHex = ThemeColor.defaultHex
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var closeTask: Task<Void, Never>?
    private var accent: Color { ThemeColor.color(accentHex) }
    private var options: [KeyNode] {
        guard let config = model.config else { return [] }
        return model.path.isEmpty ? config.tree : config.nodesByPath[model.path]?.children ?? []
    }
    private var preferredCellWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
        let labelWidth = options.map { ($0.label as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return min(360, max(260, ceil(labelWidth) + 120))
    }
    private func contentWidth(available: CGFloat) -> CGFloat {
        if model.completing {
            let font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
            let textWidth = ((model.toast?.message ?? "") as NSString).size(withAttributes: [.font: font]).width
            return min(available, min(420, max(260, ceil(textWidth) + 59)))
        }
        if model.configError != nil { return min(460, available) }
        return min(available, preferredCellWidth)
    }

    private func routeHeader(width: CGFloat) -> some View {
        let labels = model.path.indices.map {
            model.config?.nodesByPath[Array(model.path.prefix($0 + 1))]?.label ?? model.path[$0]
        }
        let fitted = BreadcrumbLayout.fit(labels: labels, availableWidth: max(0, width - 24))
        return HStack(spacing: 0) {
            if labels.isEmpty {
                Text("PRELUDE").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2).foregroundStyle(.white.opacity(0.55))
            }
            if fitted.omittedCount > 0 {
                Text("…").font(.system(size: 12)).foregroundStyle(.white.opacity(0.42))
            }
            ForEach(Array(fitted.labels.enumerated()), id: \.offset) { index, label in
                if index > 0 || fitted.omittedCount > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.gray)
                        .frame(width: BreadcrumbLayout.separatorWidth)
                        .padding(.horizontal, BreadcrumbLayout.separatorSpacing)
                }
                let current = index == fitted.labels.count - 1
                Text(label)
                    .font(.system(size: 12, weight: current ? .semibold : .regular))
                    .foregroundStyle(.white.opacity(current ? 0.65 : 0.38))
                    .lineLimit(1).truncationMode(.head)
                    .layoutPriority(current ? 1 : 0)
            }
        }
        .frame(height: 16)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color(red: 0.12, green: 0.13, blue: 0.15), in: Capsule())
        .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(labels.isEmpty ? "Prelude" : labels.joined(separator: "，"))
    }

    var body: some View {
        GeometryReader { geometry in
            let edgeMargin = (max(24, min(48, geometry.size.width * 0.025)) + 16) / 2
            ZStack {
                commandContent(width: contentWidth(available: geometry.size.width - 100), height: geometry.size.height)
                    .padding(.bottom, edgeMargin)
                    .padding(.trailing, edgeMargin)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .opacity(visible ? 1 : 0)
            // Animate the bottom-anchored placement as the route height changes.
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: model.path)
        }
        .onAppear { if model.active { open() } }
        .onChange(of: model.presentationID) { _, _ in open() }
        .onChange(of: model.active) { _, active in if !active { close() } }
        .onDisappear { closeTask?.cancel() }
    }

    private func commandContent(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            if model.completing {
                HStack(spacing: 10) {
                    if let type = model.toast?.type {
                        Image(systemName: type == .success ? "checkmark" : type == .error ? "xmark" : type == .warning ? "exclamationmark" : "info")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 25, height: 25)
                    }
                    Text(model.toast?.message ?? "")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(width: width, alignment: .leading)
                .background(Color(red: 0.12, green: 0.13, blue: 0.15), in: RoundedRectangle(cornerRadius: 12))
                .transition(.opacity)
            } else if let error = model.configError {
                VStack(alignment: .leading, spacing: 8) {
                Text("配置需要修正").font(.system(size: 20, weight: .medium))
                Text(error).font(.system(size: 14)).lineLimit(5)
                Text("⌘, 打开偏好设置").font(.system(size: 12)).foregroundStyle(accent)
                }
                .padding(16)
                .background(Color(red: 0.12, green: 0.13, blue: 0.15), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .trailing, spacing: 12) {
                        routeHeader(width: width)
                        optionGrid(width: width, height: height)
                    }
                    .id(model.path)
                    .transition(reduceMotion ? .identity : .opacity)
                }
                if model.message.hasPrefix("此路径") {
                    Text(model.message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(10)
                        .background(Color(red: 0.12, green: 0.13, blue: 0.15), in: Capsule())
                }
            }
        }
        .foregroundStyle(.white)
        .frame(width: width, alignment: .trailing)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: model.path)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: model.completing)
    }

    private func optionGrid(width: CGFloat, height: CGFloat) -> some View {
        let rows = max(1, options.count)
        let rowHeight = min(42, max(24, (height - 220 - CGFloat(rows - 1) * 6) / CGFloat(rows)))
        return VStack(spacing: 6) {
            ForEach(options) { node in
                KeyOptionRow(node: node, accentHex: accentHex)
                .padding(.horizontal, 12)
                .frame(height: rowHeight)
                .background(RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [Color(red: 0.15, green: 0.16, blue: 0.18), Color(red: 0.125, green: 0.135, blue: 0.155)], startPoint: .top, endPoint: .bottom)))
                .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("按 \(node.key)，\(node.label)")
            }
        }
    }

    private func open() {
        closeTask?.cancel()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { visible = true }
    }

    private func close() {
        closeTask?.cancel()
        let id = model.presentationID
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { visible = false }
        closeTask = Task { @MainActor in
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(240)) }
            guard !Task.isCancelled else { return }
            model.overlays.finishHiding(presentationID: id)
        }
    }
}

