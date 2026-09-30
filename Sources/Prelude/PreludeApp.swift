import AppKit
import Carbon
import SwiftUI
import PreludeCore

@main
enum PreludeApp {
    @MainActor
    static func main() {
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
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var status: NSStatusItem!
    private var preferencesWindow: NSWindowController?
    private var pendingURLs: [URL] = []
    private var receivedURL = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        model.onShowPreferences = { [weak self] in self?.showPreferences() }
        configureMainMenu()
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
        // Ordinary launches keep the navigation panel; login and URL launches
        // keep their existing background behavior. Settings are opened on demand.
        let defaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? false
        let loginLaunch = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem))?.booleanValue ?? false
        if defaultLaunch && !loginLaunch && !receivedURL && !model.active { model.activate() }
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
    private func configureMainMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu(title: "Prelude")
        addItem(to: appMenu, title: "关于 Prelude", action: #selector(about))
        appMenu.addItem(.separator())
        addItem(to: appMenu, title: "偏好设置…", action: #selector(showPreferences), key: ",")
        appMenu.addItem(.separator())
        addItem(to: appMenu, title: "退出 Prelude", action: #selector(quit), key: "q")
        let appItem = NSMenuItem(title: "Prelude", action: nil, keyEquivalent: "")
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        for (title, action, key) in [
            ("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a")
        ] {
            editMenu.addItem(NSMenuItem(title: title, action: action, keyEquivalent: key))
        }
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        NSApp.mainMenu = menu
        NSApp.windowsMenu = windowMenu
    }
    private func applyIcons() {
        if let appURL = Bundle.main.url(forResource: "Prelude", withExtension: "icns"),
           let appIcon = NSImage(contentsOf: appURL) {
            NSApp.applicationIconImage = appIcon
        }
        if let menuURL = Bundle.main.url(forResource: "PreludeMenuTemplate", withExtension: "png"),
           let menuIcon = NSImage(contentsOf: menuURL) {
            menuIcon.size = NSSize(width: 20, height: 20)
            menuIcon.isTemplate = true
            status.button?.image = menuIcon
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.activate()
        return false
    }
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }
    @objc private func activate() { model.activate() }
    @objc func showPreferences() {
        model.dismiss()
        if preferencesWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView(model: model)))
            window.title = "Prelude Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isRestorable = false
            window.isReleasedWhenClosed = false
            window.center()
            preferencesWindow = NSWindowController(window: window)
        }
        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        alert.informativeText = "每个动作，始于一个按键。\n\n版本 \(version)（构建 \(build)） · 原生 macOS 按键导航\n\n激活：\(model.activationHotkey.display)\n退格返回上级，Esc 退出。\n编辑 preluderc 配置，保存后自动生效。"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
