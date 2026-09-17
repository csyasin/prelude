import AppKit
import SwiftUI
import PreludeCore

@main
struct PreludeApp: App {
    init() {
        if let index = CommandLine.arguments.firstIndex(of: "--check-config"), CommandLine.arguments.count > index + 1 {
            do {
                let config = try Configuration.parse(String(contentsOfFile: CommandLine.arguments[index + 1], encoding: .utf8))
                print("Valid: \(config.bindings.count) shell actions, \(config.map.items.count) nodes")
                exit(0)
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                exit(1)
            }
        }
    }
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { PreferencesSceneView() }
    }
}

@MainActor
private final class PreludeState: ObservableObject {
    static let shared = PreludeState()
    @Published var model: AppModel?
}

private struct PreferencesSceneView: View {
    @ObservedObject private var state = PreludeState.shared

    var body: some View {
        Group {
            if let model = state.model {
                PreferencesView(model: model)
            } else {
                ProgressView()
                    .frame(width: 500, height: 220)
            }
        }
        .onAppear { state.model?.dismiss() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var status: NSStatusItem!
    private var pendingURLs: [URL] = []
    private var receivedURL = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        PreludeState.shared.model = model
        model.onShowPreferences = { [weak self] in self?.showPreferences() }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        applyIcons()
        let menu = NSMenu()
        addItem(to: menu, title: "打开 Prelude", action: #selector(activate))
        menu.addItem(.separator())
        addItem(to: menu, title: "偏好设置…", action: #selector(showPreferences), key: ",")
        addItem(to: menu, title: "重新载入配置", action: #selector(reload), key: "r")
        addItem(to: menu, title: "配置状态…", action: #selector(configStatus))
        menu.addItem(.separator())
        addItem(to: menu, title: "关于 Prelude", action: #selector(about))
        addItem(to: menu, title: "退出 Prelude", action: #selector(quit), key: "q")
        status.menu = menu
        model.start()
        let urls = pendingURLs
        pendingURLs.removeAll()
        urls.forEach(receiveURL)
        // A URL launch must not briefly display the navigation panel or take key
        // focus before its notification. Ordinary Finder launches keep their UI.
        let defaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? false
        if defaultLaunch && !receivedURL && !model.active { model.activate() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedURL = true
        guard model != nil else { pendingURLs.append(contentsOf: urls); return }
        urls.forEach(receiveURL)
    }

    private func receiveURL(_ url: URL) {
        do { model.showToast(try ToastRequest(url: url)) }
        catch { NSLog("Prelude toast: %@", error.localizedDescription) }
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }
    private func applyIcons() {
        if let appURL = Bundle.main.url(forResource: "Prelude", withExtension: "icns"),
           let appIcon = NSImage(contentsOf: appURL) {
            NSApp.applicationIconImage = appIcon
        }
        if let menuURL = Bundle.main.url(forResource: "PreludeMenuTemplate", withExtension: "png"),
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
    @objc func showPreferences() {
        model.dismiss()
        NSApp.activate(ignoringOtherApps: true)
        if let item = NSApp.mainMenu?.items.first?.submenu?.items.first(where: {
            $0.keyEquivalent == "," && $0.keyEquivalentModifierMask.contains(.command)
        }), let action = item.action {
            NSApp.sendAction(action, to: item.target, from: item)
        }
    }
    @objc private func reload() { model.dismiss(); model.reload(force: true) }
    @objc private func configStatus() {
        let errors = [model.configError, model.hotkeyError].compactMap { $0 }
        let text = errors.isEmpty
            ? "配置有效，共 \(model.config?.bindings.count ?? 0) 个动作。"
            : errors.joined(separator: "\n")
        model.showError("\(text)\n激活：\(model.activationHotkey.display)\(model.usesCustomHotkey ? "（自定义）" : "（默认）")\n\(model.configURL.path)")
    }
    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "Prelude"
        alert.informativeText = "每个动作，始于一个按键。\n\n版本 0.3.0 · 原生 macOS 按键导航\n\n激活：\(model.activationHotkey.display)\n退格返回上级，Esc 退出。\n编辑 preluderc 配置，保存后自动生效。"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
