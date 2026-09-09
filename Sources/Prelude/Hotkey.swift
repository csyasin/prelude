import AppKit
import Carbon
import PreludeCore

struct Leader: Equatable {
    let key: String
    let modifiers: [String]

    init(key: String = "space", modifiers: [String] = ["control"]) {
        self.key = key
        self.modifiers = modifiers
    }

    var display: String {
        ["control", "option", "shift", "command"].filter(modifiers.contains)
            .map { ["control": "⌃", "option": "⌥", "shift": "⇧", "command": "⌘"][$0]! }.joined()
            + (key == "space" ? " Space" : key.uppercased())
    }

    var isFunctionKey: Bool { (1...20).contains { key == "f\($0)" } }
}

enum KeyNames {
    static let codes: [String: UInt32] = [
        "a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,
        "q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"1":18,"2":19,"3":20,"4":21,
        "6":22,"5":23,"=":24,"9":25,"7":26,"-":27,"8":28,"0":29,
        "]":30,"o":31,"u":32,"[":33,"i":34,"p":35,"return":36,"l":37,"j":38,
        "'":39,"k":40,";":41,"\\":42,",":43,"/":44,"n":45,"m":46,".":47,"tab":48,
        "space":49,"`":50,"backspace":51,"escape":53,
        "f1":122,"f2":120,"f3":99,"f4":118,"f5":96,"f6":97,"f7":98,"f8":100,
        "f9":101,"f10":109,"f11":103,"f12":111,"f13":105,"f14":107,"f15":113,
        "f16":106,"f17":64,"f18":79,"f19":80,"f20":90,
        "left":123,"right":124,"down":125,"up":126
    ]
}

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

enum HotkeyPreference {
    private static let keyName = "Prelude.activationHotkey.key"
    private static let modifiersName = "Prelude.activationHotkey.modifiers"

    static func load() -> Leader? {
        let defaults = UserDefaults.standard
        guard let key = defaults.string(forKey: keyName),
              KeyNames.codes[key] != nil,
              let modifiers = defaults.stringArray(forKey: modifiersName),
              Set(modifiers).count == modifiers.count,
              modifiers.allSatisfy({ ["control", "option", "shift", "command"].contains($0) }),
              !modifiers.isEmpty || Leader(key: key, modifiers: modifiers).isFunctionKey else { return nil }
        return Leader(key: key, modifiers: modifiers)
    }

    static func save(_ leader: Leader) {
        UserDefaults.standard.set(leader.key, forKey: keyName)
        UserDefaults.standard.set(leader.modifiers, forKey: modifiersName)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: keyName)
        UserDefaults.standard.removeObject(forKey: modifiersName)
    }
}
