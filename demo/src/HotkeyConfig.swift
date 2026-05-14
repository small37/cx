import Carbon
import Foundation

struct HotkeyDefinition {
    let keyCode: UInt32
    let modifiers: UInt32
}

struct HotkeyConfig {
    let text: HotkeyDefinition
    let screenshot: HotkeyDefinition

    static let defaultConfig = HotkeyConfig(
        text: HotkeyDefinition(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey)),
        screenshot: HotkeyDefinition(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(optionKey))
    )

    static func load() -> HotkeyConfig {
        let dictionary = AppConfig.loadDictionary()
        guard
              let hotkeys = dictionary["hotkeys"] as? [String: String] else {
            return defaultConfig
        }

        return HotkeyConfig(
            text: parse(hotkeys["text"]) ?? defaultConfig.text,
            screenshot: parse(hotkeys["screenshot"]) ?? defaultConfig.screenshot
        )
    }

    private static func parse(_ value: String?) -> HotkeyDefinition? {
        guard let value else { return nil }
        let parts = value
            .lowercased()
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let key = parts.last, let keyCode = keyCode(for: key) else { return nil }

        var modifiers: UInt32 = 0
        for modifier in parts.dropLast() {
            switch modifier {
            case "option", "opt", "alt":
                modifiers |= UInt32(optionKey)
            case "command", "cmd", "meta":
                modifiers |= UInt32(cmdKey)
            case "control", "ctrl":
                modifiers |= UInt32(controlKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            default:
                return nil
            }
        }

        return HotkeyDefinition(keyCode: keyCode, modifiers: modifiers)
    }

    private static func keyCode(for key: String) -> UInt32? {
        switch key {
        case "a": return UInt32(kVK_ANSI_A)
        case "b": return UInt32(kVK_ANSI_B)
        case "c": return UInt32(kVK_ANSI_C)
        case "d": return UInt32(kVK_ANSI_D)
        case "e": return UInt32(kVK_ANSI_E)
        case "f": return UInt32(kVK_ANSI_F)
        case "g": return UInt32(kVK_ANSI_G)
        case "h": return UInt32(kVK_ANSI_H)
        case "i": return UInt32(kVK_ANSI_I)
        case "j": return UInt32(kVK_ANSI_J)
        case "k": return UInt32(kVK_ANSI_K)
        case "l": return UInt32(kVK_ANSI_L)
        case "m": return UInt32(kVK_ANSI_M)
        case "n": return UInt32(kVK_ANSI_N)
        case "o": return UInt32(kVK_ANSI_O)
        case "p": return UInt32(kVK_ANSI_P)
        case "q": return UInt32(kVK_ANSI_Q)
        case "r": return UInt32(kVK_ANSI_R)
        case "s": return UInt32(kVK_ANSI_S)
        case "t": return UInt32(kVK_ANSI_T)
        case "u": return UInt32(kVK_ANSI_U)
        case "v": return UInt32(kVK_ANSI_V)
        case "w": return UInt32(kVK_ANSI_W)
        case "x": return UInt32(kVK_ANSI_X)
        case "y": return UInt32(kVK_ANSI_Y)
        case "z": return UInt32(kVK_ANSI_Z)
        case "0": return UInt32(kVK_ANSI_0)
        case "1": return UInt32(kVK_ANSI_1)
        case "2": return UInt32(kVK_ANSI_2)
        case "3": return UInt32(kVK_ANSI_3)
        case "4": return UInt32(kVK_ANSI_4)
        case "5": return UInt32(kVK_ANSI_5)
        case "6": return UInt32(kVK_ANSI_6)
        case "7": return UInt32(kVK_ANSI_7)
        case "8": return UInt32(kVK_ANSI_8)
        case "9": return UInt32(kVK_ANSI_9)
        default: return nil
        }
    }
}
