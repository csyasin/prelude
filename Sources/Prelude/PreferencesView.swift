import AppKit
import SwiftUI
import PreludeCore

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updater: AppUpdater
    @StateObject private var launchAtLogin = LaunchAtLogin()
    @StateObject private var customColorPicker = CustomColorPicker()
    @AppStorage(ThemeColor.preferenceKey) private var accentHex = ThemeColor.defaultHex
    @AppStorage(ThemeColor.sourcePreferenceKey) private var accentSource = ""
    @AppStorage(ThemeColor.customHexPreferenceKey) private var customAccentHex = ""
    @AppStorage(EdgeLightPreference.enabledKey) private var edgeLightEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var errorMessage: String?
    @State private var errorTitle = "无法设置快捷键"
    private var accent: Color { ThemeColor.color(accentHex) }
    private var colorSource: ThemeColor.Source {
        ThemeColor.Source(rawValue: accentSource) ?? ThemeColor.source(for: accentHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("交互效果")
                effectChoices
            }
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    rowIcon("keyboard")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("激活快捷键").font(.system(size: 13, weight: .medium))
                        Text("点击右侧，按下新的组合键")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ShortcutRecorder(leader: model.activationHotkey) { leader in
                        do { try model.setActivationHotkey(leader) }
                        catch { errorTitle = "无法设置快捷键"; errorMessage = error.localizedDescription }
                    }
                    .frame(width: 142, height: 32)
                    Button { do { try model.resetActivationHotkey() } catch { errorTitle = "无法设置快捷键"; errorMessage = error.localizedDescription } } label: {
                        Image(systemName: "arrow.counterclockwise").frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.usesCustomHotkey)
                    .help("恢复默认快捷键")
                    .accessibilityLabel("恢复默认快捷键")
                }
                .padding(18)
                Divider().padding(.leading, 64)
                HStack(spacing: 14) {
                    rowIcon("light.beacon.max")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("呼吸灯").font(.system(size: 13, weight: .medium))
                        Text("所有交互效果共用屏幕边缘光")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("显示呼吸灯", isOn: $edgeLightEnabled)
                        .labelsHidden().toggleStyle(.switch)
                        .tint(accent)
                        .accessibilityLabel("显示呼吸灯")
                }
                .padding(18)
                Divider().padding(.leading, 64)
                HStack(spacing: 14) {
                    rowIcon("power")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("开机自启").font(.system(size: 13, weight: .medium))
                        Text(launchAtLogin.description)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if launchAtLogin.requiresApproval {
                        Button("打开系统设置") { launchAtLogin.openSystemSettings() }
                            .controlSize(.small)
                    }
                    Toggle("开机自启", isOn: Binding(
                        get: { launchAtLogin.isOn },
                        set: { enabled in
                            do { try launchAtLogin.setEnabled(enabled) }
                            catch { errorTitle = "无法设置开机自启"; errorMessage = error.localizedDescription }
                        }
                    ))
                    .labelsHidden().toggleStyle(.switch)
                    .tint(accent)
                    .accessibilityLabel("开机自启")
                }
                .padding(18)
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("主题色")
                HStack(spacing: 12) {
                    ForEach(ThemeColor.presets, id: \.hex) { preset in
                        Button { applyThemeColor(preset.hex, source: .preset) } label: {
                            themeSwatch(preset.hex, selected: colorSource == .preset && accentHex == preset.hex)
                        }
                        .buttonStyle(.plain)
                        .help(preset.name).accessibilityLabel(preset.name)
                        .accessibilityAddTraits(colorSource == .preset && accentHex == preset.hex ? .isSelected : [])
                    }
                    Divider().frame(height: 24)
                    Button { applyThemeColor(ThemeColor.systemValue, source: .system) } label: {
                        HStack(spacing: 6) {
                            themeSwatch(ThemeColor.systemValue, selected: colorSource == .system)
                            Text("跟随系统").font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("使用系统主题色作为主色")
                    .accessibilityLabel("跟随系统")
                    .accessibilityAddTraits(colorSource == .system ? .isSelected : [])
                    Divider().frame(height: 24)
                    HStack(spacing: 6) {
                        Button {
                            if customAccentHex.isEmpty { editCustomColor() }
                            else { applyThemeColor(customAccentHex, source: .custom) }
                        } label: {
                            HStack(spacing: 6) {
                                if customAccentHex.isEmpty {
                                    Circle().fill(.quaternary)
                                        .frame(width: 29, height: 29)
                                        .overlay {
                                            Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(5)
                                } else {
                                    themeSwatch(customAccentHex, selected: colorSource == .custom)
                                }
                                Text("自定义").font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(customAccentHex.isEmpty ? "设置自定义主题色" : "使用上次的自定义主题色")
                        .accessibilityLabel("自定义")
                        .accessibilityAddTraits(colorSource == .custom ? .isSelected : [])
                        Button { editCustomColor() } label: {
                            Image(systemName: "pencil").font(.system(size: 13))
                                .foregroundStyle(.secondary).frame(width: 24, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("编辑自定义主题色")
                        .accessibilityLabel("编辑自定义主题色")
                    }
                    Spacer(minLength: 0)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("应用更新")
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        rowIcon("arrow.triangle.2.circlepath")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(updater.versionDescription).font(.system(size: 13, weight: .medium))
                            Text(updateStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("检查更新…") { updater.checkForUpdates() }
                            .disabled(!updater.canCheckForUpdates)
                    }
                    Divider().padding(.leading, 46)
                    HStack(spacing: 14) {
                        rowIcon("clock")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("自动检查更新").font(.system(size: 13, weight: .medium))
                            Text("每天在后台检查，安装更新前会征求你的同意")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("自动检查更新", isOn: Binding(
                            get: { updater.automaticallyChecksForUpdates },
                            set: { updater.setAutomaticallyChecksForUpdates($0) }
                        ))
                        .labelsHidden().toggleStyle(.switch).tint(accent)
                        .disabled(updater.unavailableReason != nil)
                        .accessibilityLabel("自动检查更新")
                    }
                }
                .padding(18)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .padding(30)
        .frame(width: 680)
        .background(.background)
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: model.interactionEffect)
        .onAppear {
            migrateThemeColorSelection()
            launchAtLogin.refresh()
        }
        .onDisappear { customColorPicker.close() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
        .alert(errorTitle, isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("好", role: .cancel) { errorMessage = nil } }
        message: { Text(errorMessage ?? "") }
    }

    private var updateStatus: String {
        if let reason = updater.unavailableReason { return reason }
        if let version = updater.availableVersion { return "发现新版本 \(version)" }
        if let date = updater.lastUpdateCheckDate {
            return "上次检查：\(date.formatted(date: .abbreviated, time: .shortened))"
        }
        return "尚未检查更新"
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer()
        }
    }
    private func rowIcon(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 18, weight: .regular))
            .foregroundStyle(.secondary).frame(width: 30)
    }

    private func themeSwatch(_ hex: String, selected: Bool) -> some View {
        Circle().fill(ThemeColor.color(hex))
            .frame(width: 29, height: 29)
            .overlay {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ThemeColor.keyInk(hex))
                }
            }
            .padding(5)
            .overlay(Circle().strokeBorder(selected ? ThemeColor.color(hex).opacity(0.8) : .clear, lineWidth: 1.5))
            .contentShape(Circle())
    }

    private func migrateThemeColorSelection() {
        let source = colorSource
        if customAccentHex.isEmpty && source == .custom { customAccentHex = accentHex }
        if ThemeColor.Source(rawValue: accentSource) == nil { accentSource = source.rawValue }
    }

    private func applyThemeColor(_ hex: String, source: ThemeColor.Source) {
        customColorPicker.close()
        accentSource = source.rawValue
        accentHex = hex
    }

    private func editCustomColor() {
        if customAccentHex.isEmpty {
            customAccentHex = ThemeColor.hex(accent) ?? ThemeColor.defaultHex
        }
        applyThemeColor(customAccentHex, source: .custom)
        customColorPicker.open(selection: Binding(
            get: { ThemeColor.color(customAccentHex) },
            set: { color in
                guard let hex = ThemeColor.hex(color) else { return }
                customAccentHex = hex
                accentSource = ThemeColor.Source.custom.rawValue
                accentHex = hex
            }
        ))
    }

    @ViewBuilder private var effectChoices: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 16) { choices }
        } else { choices }
    }
    private var choices: some View {
        HStack(spacing: 16) {
            ForEach(InteractionEffect.allCases) { effect in
                Button { model.setInteractionEffect(effect) } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        miniature(effect)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(effect.title).font(.system(size: 14, weight: .semibold))
                                Text(effect.description)
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: model.interactionEffect == effect ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.interactionEffect == effect ? accent : Color.secondary.opacity(0.4))
                                .font(.system(size: 18))
                        }
                    }
                    .padding(14)
                    .contentShape(RoundedRectangle(cornerRadius: 20))
                    .modifier(PreferenceGlass(selected: model.interactionEffect == effect, accent: accent))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(effect.title)
                .accessibilityAddTraits(model.interactionEffect == effect ? .isSelected : [])
            }
        }
    }

    private func miniature(_ effect: InteractionEffect) -> some View {
        ZStack(alignment: effect == .island ? .top : .bottom) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [Color(red: 0.13, green: 0.19, blue: 0.27), Color(red: 0.28, green: 0.33, blue: 0.39)], startPoint: .topLeading, endPoint: .bottomTrailing))
            if effect == .island {
                VStack(spacing: 6) {
                    Capsule().fill(.white.opacity(0.2)).frame(width: 26, height: 3)
                    ForEach(0..<2) { _ in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 8, height: 8)
                            Capsule().fill(.white.opacity(0.55)).frame(width: 45, height: 3)
                        }
                    }
                }
                .padding(10).background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 12, bottomTrailingRadius: 12))
            } else if effect == .subtitles {
                VStack(spacing: 4) {
                    ForEach(0..<3) { _ in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 8, height: 8)
                            Capsule().fill(.white.opacity(0.7)).frame(width: 24, height: 3)
                        }
                        .padding(6)
                        .background(Color(red: 0.13, green: 0.14, blue: 0.16), in: RoundedRectangle(cornerRadius: 5))
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
                .padding(.bottom, 4)
            }
        }
        .frame(height: 106)
        .accessibilityHidden(true)
    }
}

@MainActor
private final class CustomColorPicker: NSObject, ObservableObject {
    private var selection: SwiftUI.Binding<Color>?

    func open(selection: SwiftUI.Binding<Color>) {
        self.selection = selection
        let panel = NSColorPanel.shared
        let color = NSColor(selection.wrappedValue)
        panel.color = color.usingColorSpace(.sRGB) ?? color
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        selection?.wrappedValue = Color(nsColor: sender.color)
    }

    func close() {
        guard selection != nil else { return }
        selection = nil
        let panel = NSColorPanel.shared
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.close()
    }
}

private struct PreferenceGlass: ViewModifier {
    let selected: Bool
    let accent: Color
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.tint(selected ? accent.opacity(0.16) : .clear).interactive(), in: RoundedRectangle(cornerRadius: 20))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
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
