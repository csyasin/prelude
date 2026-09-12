import SwiftUI
import PreludeCore

/// Shared key identity, group count and action indicator for every presentation.
struct KeyOptionRow: View {
    let node: KeyNode
    let accentHex: String
    private var accent: Color { ThemeColor.color(accentHex) }

    var body: some View {
        HStack(spacing: 10) {
            routeIdentity(node)
            Spacer(minLength: 4)
            Group {
                if node.binding == nil {
                    Image(systemName: "chevron.right")
                } else {
                    Image(systemName: "bolt.fill")
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(node.binding == nil ? Color.gray : accent.opacity(0.42))
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.045)).frame(height: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("按 \(node.key)，\(node.label)")
    }

    private func routeIdentity(_ node: KeyNode) -> some View {
        HStack(spacing: 9) {
            Text(node.key.uppercased())
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(ThemeColor.keyInk(accentHex))
                .frame(width: 25, height: 25)
                .background(RoundedRectangle(cornerRadius: 7).fill(accent))
            Text(node.label)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.tail)
            if node.binding == nil {
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

}
