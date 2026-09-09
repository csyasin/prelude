import AppKit
import SwiftUI
import PreludeCore

@main
struct PreludeApp: App {
    init() {
        if let index = CommandLine.arguments.firstIndex(of: "--check-config"), CommandLine.arguments.count > index + 1 {
            do {
                let config = try Configuration.parse(String(contentsOfFile: CommandLine.arguments[index + 1], encoding: .utf8))
                print("Valid: \(config.bindings.count) shell actions, \(config.map.items.count) nodes, leader \(config.hotkey.display)")
                exit(0)
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                exit(1)
            }
        }
    }
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

enum PreludeIconStyle: String, CaseIterable, Identifiable {
    case orbit
    case panels

    var id: Self { self }
    var title: String {
        switch self {
        case .orbit: return "轨道光束"
        case .panels: return "切面光束"
        }
    }
    var subtitle: String {
        switch self {
        case .orbit: return "深色轨道与暖色核心"
        case .panels: return "四块几何切面与斜向光束"
        }
    }
    var appIconResource: String {
        switch self {
        case .orbit: return "PreludeOrbit"
        case .panels: return "PreludePanels"
        }
    }
    var menuIconResource: String {
        switch self {
        case .orbit: return "PreludeMenuOrbit"
        case .panels: return "PreludeMenuPanels"
        }
    }
    static var stored: Self {
        guard let raw = UserDefaults.standard.string(forKey: "Prelude.iconStyle"),
              let style = Self(rawValue: raw) else { return .orbit }
        return style
    }
}

@MainActor
final class IconPreferences: ObservableObject {
    @Published var style: PreludeIconStyle {
        didSet {
            UserDefaults.standard.set(style.rawValue, forKey: "Prelude.iconStyle")
            onChange?(style)
        }
    }
    var onChange: ((PreludeIconStyle) -> Void)?

    init() { style = .stored }
}

struct IconPreferencesView: View {
    @ObservedObject var preferences: IconPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("偏好设置")
                .font(.system(size: 22, weight: .semibold))
            Text("选择 Prelude 的 App 图标与菜单栏图标样式。切换会立即生效。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            ForEach(PreludeIconStyle.allCases, content: optionRow)

            Spacer(minLength: 0)
            Text("当前选择会保存，并在下次启动时继续使用。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(width: 430, height: 315)
    }

    private func optionRow(for style: PreludeIconStyle) -> some View {
        let selected = preferences.style == style
        return Button {
            preferences.style = style
        } label: {
            HStack(spacing: 12) {
                preview(for: style)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.title)
                        .font(.system(size: 14, weight: .medium))
                    Text(style.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.045))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func preview(for style: PreludeIconStyle) -> some View {
        if let url = Bundle.main.url(forResource: style.appIconResource, withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.secondary.opacity(0.2))
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var status: NSStatusItem!
    private var iconPreferences: IconPreferences!
    private var preferencesWindow: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        iconPreferences = IconPreferences()
        iconPreferences.onChange = { [weak self] style in self?.applyIconStyle(style) }
        applyIconStyle(iconPreferences.style)
        let menu = NSMenu()
        for (title, action, key) in [
            ("激活 Prelude", #selector(activate), ""),
            ("偏好设置…", #selector(showPreferences), ""),
            ("编辑配置…", #selector(editConfig), ","),
            ("重新载入配置", #selector(reload), "r"),
            ("配置状态…", #selector(configStatus), ""),
            ("关于 Prelude", #selector(about), ""),
            ("退出 Prelude", #selector(quit), "q")
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self; menu.addItem(item)
        }
        status.menu = menu
        model.start()
        if !model.active { model.activate() }
    }
    private func applyIconStyle(_ style: PreludeIconStyle) {
        if let appURL = Bundle.main.url(forResource: style.appIconResource, withExtension: "icns"),
           let appIcon = NSImage(contentsOf: appURL) {
            NSApp.applicationIconImage = appIcon
        }
        if let menuURL = Bundle.main.url(forResource: style.menuIconResource, withExtension: "png"),
           let menuIcon = NSImage(contentsOf: menuURL) {
            menuIcon.size = NSSize(width: 18, height: 18)
            menuIcon.isTemplate = true
            status.button?.image = menuIcon
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.activate()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }
    @objc private func activate() { model.activate() }
    @objc private func showPreferences() {
        if preferencesWindow == nil {
            let view = IconPreferencesView(preferences: iconPreferences)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Prelude 偏好设置"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            preferencesWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.center()
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }
    @objc private func editConfig() { model.openConfig() }
    @objc private func reload() { model.dismiss(); model.reload(force: true) }
    @objc private func configStatus() {
        model.showError(model.configError ?? "配置有效，共 \(model.config?.bindings.count ?? 0) 个动作。\n激活：\(model.config?.hotkey.display ?? "")\n\(model.configURL.path)")
    }
    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "Prelude"
        alert.informativeText = "每个动作，始于一个按键。\n\n版本 0.3.0 · 原生 macOS 按键导航\n\n激活：\(model.config?.hotkey.display ?? "⌃ Space")\n退格返回上级，Esc 退出。\n编辑 preluderc 配置，保存后自动生效。"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
