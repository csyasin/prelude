import AppKit
import SwiftUI
import PreludeCore

struct IslandScreenMetrics: Equatable {
    var notchWidth: CGFloat
    var notchDepth: CGFloat
    var maximumWidth: CGFloat
    var hasNotch: Bool = false

    static let fallback = IslandScreenMetrics(notchWidth: 96, notchDepth: 12, maximumWidth: 560)
}

@MainActor
final class AppModel: ObservableObject {
    @Published var config: Configuration?
    @Published var path: [String] = []
    @Published var message = "输入按键，沿路径前往"
    @Published var configError: String?
    @Published var hotkeyError: String?
    @Published var active = false
    @Published var completing = false
    @Published var completionLabel: String?
    @Published var invalidCount = 0
    @Published var islandMetrics = IslandScreenMetrics.fallback
    @Published private(set) var presentationID = 0
    @Published private(set) var activationHotkey = Leader()
    @Published private(set) var usesCustomHotkey = false
    let configURL: URL
    let hotkey = GlobalHotkey()
    let runner = ActionRunner()
    var overlays: OverlayController!
    private var navigator = Navigator()
    private var reloadTimer: Timer?
    private var lastContent: Data?
    private let loadQueue = DispatchQueue(label: "dev.yasin.prelude.config", qos: .utility)
    private var reading = false
    private var monitor: Any?
    private var externalClickMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var deferredReload = false
    private let preview: Bool
    var onShowPreferences: (() -> Void)?

    init() {
        preview = CommandLine.arguments.contains("--preview")
        if let index = CommandLine.arguments.firstIndex(of: "--config"), CommandLine.arguments.count > index + 1 {
            configURL = URL(fileURLWithPath: CommandLine.arguments[index + 1])
        } else {
            configURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/prelude/preluderc")
        }
        overlays = OverlayController(model: self)
        hotkey.onPress = { [weak self] in
            MainActor.assumeIsolated { self?.toggle() }
        }
        runner.onError = { [weak self] error in self?.showError(error) }
    }
    func start() {
        configureHotkey()
        do {
            if !FileManager.default.fileExists(atPath: configURL.path) {
                try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                guard let bundled = (Bundle.main.url(forResource: "preluderc", withExtension: nil) ?? Bundle.module.url(forResource: "preluderc", withExtension: nil)) else { throw ConfigError("缺少默认配置资源。") }
                // Copy rather than overwrite, including if another instance created the file meanwhile.
                try FileManager.default.copyItem(at: bundled, to: configURL)
            }
        } catch { configError = error.localizedDescription }
        reload(force: true, synchronous: true)
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.active else { return event }
            if event.type != .keyDown { return event }
            self.handle(event)
            return nil
        }
        externalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
        if preview { activate() }
    }
    private func configureHotkey() {
        let preferred = HotkeyPreference.load()
        let selected = preferred ?? Leader()
        activationHotkey = selected
        usesCustomHotkey = preferred != nil
        guard !preview else { return }
        do {
            try hotkey.register(selected)
            hotkeyError = nil
        } catch {
            guard preferred != nil else {
                hotkeyError = error.localizedDescription
                return
            }
            do {
                let fallback = Leader()
                try hotkey.register(fallback)
                HotkeyPreference.clear()
                activationHotkey = fallback
                usesCustomHotkey = false
                hotkeyError = "自定义快捷键不可用，已恢复默认值：\(error.localizedDescription)"
            } catch {
                hotkeyError = error.localizedDescription
            }
        }
    }
    func reload(force: Bool = false, synchronous: Bool = false) {
        guard !reading else { return }
        if active { deferredReload = true; return }
        reading = true
        let url = configURL
        let previous = force || deferredReload ? nil : lastContent
        deferredReload = false
        let load = { () -> (Data?, Result<Configuration, Error>?) in
            do {
                let data = try Data(contentsOf: url)
                if data == previous { return (data, nil) }
                guard let text = String(data: data, encoding: .utf8) else { throw ConfigError("配置必须使用 UTF-8 编码。") }
                return (data, Result { try Configuration.parse(text) })
            } catch { return (nil, .failure(error)) }
        }
        if synchronous {
            let (data, result) = load()
            accept(data: data, result: result)
        } else {
            loadQueue.async { [weak self] in
                let (data, result) = load()
                DispatchQueue.main.async { self?.accept(data: data, result: result) }
            }
        }
    }
    private func accept(data: Data?, result: Result<Configuration, Error>?) {
        reading = false
        guard !active else { deferredReload = true; return }
        lastContent = data
        guard let result else { return }
        do {
            let candidate = try result.get()
            config = candidate
            configError = nil
            overlays.prepare()
        } catch {
            configError = error.localizedDescription
        }
    }
    func toggle() { active ? dismiss() : activate() }
    func beginPresentation() { presentationID += 1 }
    func activate() {
        navigator.reset(); path = []; completing = false; completionLabel = nil
        message = "输入按键，沿路径前往"
        active = true
        overlays.show()
    }
    func dismiss() {
        guard active else { return }
        active = false
        overlays.hide()
        if completing {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(180))
                guard let self, !self.active else { return }
                self.completing = false
                self.completionLabel = nil
            }
        }
    }
    private func handle(_ event: NSEvent) {
        let shortcutModifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if event.keyCode == 43, shortcutModifiers == .command {
            dismiss()
            onShowPreferences?()
            return
        }
        if event.keyCode == 53 { dismiss(); return }
        guard !completing else { return }
        if event.keyCode == 51 || event.keyCode == 117 {
            if navigator.path.isEmpty {
                dismiss()
                return
            }
            navigator.back()
            path = navigator.path; message = "输入按键，沿路径前往"
            return
        }
        guard !event.isARepeat else { return }
        // Accept rapid sequences even before the leader modifiers have been released.
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        let allowed = activationHotkey.modifiers.reduce(NSEvent.ModifierFlags()) {
            $0.union(["command": NSEvent.ModifierFlags.command, "control": .control, "option": .option, "shift": .shift][$1] ?? [])
        }
        guard modifiers.subtracting(allowed).isEmpty else { return }
        // charactersIgnoringModifiers avoids depending on an input method composition session.
        guard let key = event.charactersIgnoringModifiers?.lowercased(), key.count == 1 else { return }
        press(key)
    }
    func press(_ key: String) {
        guard let config, active, !completing else { return }
        let result = navigator.press(key, config: config)
        do {
            path = navigator.path
            switch result {
            case .invalid: invalidCount += 1; message = "此路径没有 “\(key)” · 退格返回上一级"
            case .branch: message = "继续输入下一级按键"
            case .action(let binding):
                completing = true
                completionLabel = binding.label
                message = "\(preview ? "预览" : "执行") · \(binding.label)"
            }
        }
        if case .action(let binding) = result {
            if !preview { runner.run(binding) }
            let completedPresentation = presentationID
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.active, self.completing,
                      self.presentationID == completedPresentation else { return }
                self.dismiss()
            }
        }
    }
    func openConfig() {
        dismiss()
        NSWorkspace.shared.open([configURL], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"), configuration: NSWorkspace.OpenConfiguration())
    }
    func setActivationHotkey(_ leader: Leader) throws {
        guard KeyNames.codes[leader.key] != nil,
              Set(leader.modifiers).count == leader.modifiers.count,
              leader.modifiers.allSatisfy({ ["control", "option", "shift", "command"].contains($0) }),
              !leader.modifiers.isEmpty || leader.isFunctionKey else {
            throw ConfigError("普通按键至少需要一个修饰键；F1–F20 可以单独使用。")
        }
        guard !(leader.key == "," && leader.modifiers == ["command"]) else {
            throw ConfigError("⌘, 已保留用于打开偏好设置，请选择其他激活快捷键。")
        }
        if !preview { try hotkey.register(leader) }
        HotkeyPreference.save(leader)
        activationHotkey = leader
        usesCustomHotkey = true
        hotkeyError = nil
    }
    func resetActivationHotkey() throws {
        let fallback = Leader()
        if !preview { try hotkey.register(fallback) }
        HotkeyPreference.clear()
        activationHotkey = fallback
        usesCustomHotkey = false
        hotkeyError = nil
    }
    func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "Prelude"
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    func stop() {
        reloadTimer?.invalidate()
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let externalClickMonitor { NSEvent.removeMonitor(externalClickMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        overlays.hide()
    }
}
