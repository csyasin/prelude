import AppKit
import Carbon
import PreludeCore

final class GlobalHotkey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?
    private var current: Leader?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalHotkey>.fromOpaque(data).takeUnretainedValue()
            owner.onPress?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(_ leader: Leader) throws {
        if current == leader { return }
        guard let code = KeyNames.codes[leader.key] else { throw ConfigError("无效的激活键。") }
        var modifiers: UInt32 = 0
        for modifier in leader.modifiers {
            modifiers |= ["command": UInt32(cmdKey), "option": UInt32(optionKey), "control": UInt32(controlKey), "shift": UInt32(shiftKey)][modifier] ?? 0
        }
        var replacement: EventHotKeyRef?
        let result = RegisterEventHotKey(code, modifiers, EventHotKeyID(signature: 0x50524C44, id: 1), GetApplicationEventTarget(), 0, &replacement)
        guard result == noErr else { throw ConfigError("激活快捷键 \(leader.display) 注册失败（\(result)），可能已被占用。请修改配置。") }
        if let reference { UnregisterEventHotKey(reference) }
        reference = replacement
        current = leader
    }
    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}
