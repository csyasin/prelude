import AppKit
import PreludeCore

@MainActor
final class ActionRunner {
    var onError: ((String) -> Void)?
    private var processes: [UUID: Process] = [:]
    func run(_ binding: Binding) {
        let process = Process()
        let id = UUID()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // No login/interactive startup files, and no animation completion delay.
        process.arguments = ["-f", "-c", binding.action]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] finished in
            Task { @MainActor in
                self?.processes.removeValue(forKey: id)
                if finished.terminationStatus != 0 { self?.onError?("“\(binding.label)” 执行失败，退出码 \(finished.terminationStatus)。请在终端检查脚本或将输出重定向到日志。") }
            }
        }
        do { try process.run(); processes[id] = process }
        catch { onError?(error.localizedDescription) }
    }
}
