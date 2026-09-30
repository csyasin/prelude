import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status

    // A pending registration stays on so it can also be cancelled here.
    var isOn: Bool { status == .enabled || status == .requiresApproval }
    var requiresApproval: Bool { status == .requiresApproval }

    var description: String {
        switch status {
        case .enabled: "登录 Mac 后自动在菜单栏运行"
        case .requiresApproval: "需要在系统设置的登录项中允许 Prelude"
        case .notRegistered, .notFound: "登录 Mac 后自动启动 Prelude"
        @unknown default: "请在系统设置中检查登录项状态"
        }
    }

    func refresh() { status = SMAppService.mainApp.status }

    func setEnabled(_ enabled: Bool) throws {
        refresh()
        defer { refresh() }
        guard enabled != isOn else { return }
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            throw LaunchAtLoginError.appBundleRequired
        }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

private enum LaunchAtLoginError: LocalizedError {
    case appBundleRequired

    var errorDescription: String? {
        "请打开构建后的 Prelude.app，再设置开机自启。"
    }
}
