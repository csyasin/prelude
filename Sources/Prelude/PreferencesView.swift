import AppKit
import SwiftUI
import PreludeCore

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @AppStorage(ThemeColor.preferenceKey) private var accentHex = ThemeColor.defaultHex
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("激活快捷键")
                        .font(.system(size: 13, weight: .medium))
                    Text(model.usesCustomHotkey ? "自定义" : "默认")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ShortcutRecorder(leader: model.activationHotkey) { leader in
                    do { try model.setActivationHotkey(leader) }
                    catch { errorMessage = error.localizedDescription }
                }
                .frame(width: 190, height: 32)
            }

            HStack {
                Text("点按快捷键后，直接按下新的组合。普通按键须搭配修饰键。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("恢复默认") {
                    do { try model.resetActivationHotkey() }
                    catch { errorMessage = error.localizedDescription }
                }
                .disabled(!model.usesCustomHotkey)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("主题色")
                            .font(.system(size: 13, weight: .medium))
                        Text("用于按键、高亮路径和状态提示，自动保存。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ColorPicker("自定义", selection: Binding(
                        get: { ThemeColor.color(accentHex) },
                        set: { if let hex = ThemeColor.hex($0) { accentHex = hex } }
                    ), supportsOpacity: false)
                    .fixedSize()
                }
                HStack(spacing: 10) {
                    ForEach(ThemeColor.presets, id: \.hex) { preset in
                        Button { accentHex = preset.hex } label: {
                            Circle()
                                .fill(ThemeColor.color(preset.hex))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if accentHex == preset.hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(ThemeColor.keyInk(preset.hex))
                                    }
                                }
                                .padding(3)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(preset.name)
                        .accessibilityLabel(preset.name)
                        .accessibilityAddTraits(accentHex == preset.hex ? .isSelected : [])
                    }
                    Spacer()
                    Button("恢复默认") { accentHex = ThemeColor.defaultHex }
                        .disabled(accentHex == ThemeColor.defaultHex)
                        .accessibilityLabel("恢复默认主题色")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 500, height: 260)
        .alert("无法设置快捷键", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let leader: Leader
    let onChange: (Leader) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.onChange = onChange
        button.leader = leader
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.onChange = onChange
        button.leader = leader
    }
}

private final class ShortcutRecorderButton: NSButton {
    var onChange: ((Leader) -> Void)?
    var leader = Leader() { didSet { updateTitle() } }
    private var recording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        setAccessibilityLabel("激活快捷键")
        updateTitle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { true }

    @objc private func beginRecording() {
        recording = true
        title = "请按下快捷键…"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        capture(event)
        return true
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        updateTitle()
        return super.resignFirstResponder()
    }

    private func capture(_ event: NSEvent) {
        if event.keyCode == 53 {
            recording = false
            updateTitle()
            window?.makeFirstResponder(nil)
            return
        }
        guard let key = KeyNames.codes.first(where: { $0.value == UInt32(event.keyCode) })?.key else {
            NSSound.beep()
            return
        }
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        var modifiers: [String] = []
        if flags.contains(.control) { modifiers.append("control") }
        if flags.contains(.option) { modifiers.append("option") }
        if flags.contains(.shift) { modifiers.append("shift") }
        if flags.contains(.command) { modifiers.append("command") }
        let candidate = Leader(key: key, modifiers: modifiers)
        guard !modifiers.isEmpty || candidate.isFunctionKey else {
            NSSound.beep()
            title = "请加修饰键"
            return
        }
        recording = false
        updateTitle()
        window?.makeFirstResponder(nil)
        onChange?(candidate)
    }

    private func updateTitle() {
        if !recording { title = leader.display }
    }
}
