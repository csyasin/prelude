import AppKit
import Combine
import Sparkle

@MainActor
// Sparkle's standard user driver invokes its delegate on the main thread.
final class AppUpdater: NSObject, ObservableObject, @preconcurrency SPUStandardUserDriverDelegate {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var lastUpdateCheckDate: Date?
    @Published private(set) var availableVersion: String?
    @Published private(set) var unavailableReason: String?
    let versionDescription: String
    let isEnabled: Bool
    var onShowUpdateUI: (() -> Void)?
    private var controller: SPUStandardUpdaterController?

    override init() {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        versionDescription = "版本 \(version)（构建 \(build)）"
        isEnabled = bundle.object(forInfoDictionaryKey: "PreludeUpdatesEnabled") as? Bool ?? false
        super.init()
        guard isEnabled else {
            unavailableReason = "开发构建不检查更新，请使用 GitHub 发布版"
            return
        }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self)
        self.controller = controller
        do {
            try controller.updater.start()
            controller.updater.publisher(for: \.canCheckForUpdates)
                .receive(on: RunLoop.main).assign(to: &$canCheckForUpdates)
            controller.updater.publisher(for: \.automaticallyChecksForUpdates)
                .receive(on: RunLoop.main).assign(to: &$automaticallyChecksForUpdates)
            controller.updater.publisher(for: \.lastUpdateCheckDate)
                .receive(on: RunLoop.main).assign(to: &$lastUpdateCheckDate)
        } catch {
            unavailableReason = "更新服务暂不可用：\(error.localizedDescription)"
            NSLog("Prelude updater: %@", error.localizedDescription)
        }
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard unavailableReason == nil else { return }
        controller?.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        onShowUpdateUI?()
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        availableVersion = update.displayVersionString
        if state.userInitiated { onShowUpdateUI?() }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        availableVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableVersion = nil
    }
}
