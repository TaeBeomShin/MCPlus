import Foundation
import CoreGraphics

// Values received from the event tap. Tests can exercise the controller without
// constructing or posting synthetic operating-system events.
enum MissionInputEvent {
    case keyDown(Int64, CGEventFlags, repeating: Bool, characters: String? = nil, charactersIgnoringModifiers: String? = nil)
    case keyUp(Int64)
    case mouseMoved(CGPoint)
    case mouseDown(CGPoint)
    case mouseUp
}

enum WindowAction: String, CaseIterable, Codable, Identifiable {
    case close, closeAll, minimize, open, quit, forceQuit, hide, hideOthers
    var id: String { rawValue }
    var title: String {
        switch self {
        case .close: return "창 닫기"
        case .closeAll: return "앱의 모든 창 닫기"
        case .minimize: return "창 최소화"
        case .open: return "창 열기"
        case .quit: return "앱 정상 종료"
        case .forceQuit: return "앱 강제 종료"
        case .hide: return "앱 숨기기"
        case .hideOthers: return "다른 앱 숨기기"
        }
    }
    var shortcut: String {
        switch self {
        case .close: return "⌘W"
        case .closeAll: return "⌥⌘W"
        case .minimize: return "⌘M"
        case .open: return "↵"
        case .quit: return "⌘Q"
        case .forceQuit: return "⌃⌘Q"
        case .hide: return "⌘H"
        case .hideOthers: return "⌥⌘H"
        }
    }
}

struct InputContext {
    var active = false
    var fresh = false
    var enabled = true
    var trusted = false
    var hasSelection = false
    var navigation = true
    var actions = Set(WindowAction.allCases)
}

enum InputDecision: Equatable {
    case pass, swallow, escape, cycle(backwards: Bool), direction(Direction), action(WindowAction), noSelection
}

final class InputRouter {
    private var suppressed = Set<Int64>()
    func release(_ key: Int64) -> Bool { suppressed.remove(key) != nil }
    func reset() { suppressed.removeAll() }

    func keyDown(_ key: Int64, flags rawFlags: CGEventFlags, characters: String?, charactersIgnoringModifiers: String? = nil, repeatKey: Bool, context: InputContext) -> InputDecision {
        guard context.enabled, context.trusted, context.active, context.fresh else { return .pass }
        let flags = rawFlags.intersection([.maskCommand,.maskShift,.maskAlternate,.maskControl])
        if key == 53 { return .escape }
        let action: WindowAction?
        // Letter shortcuts follow the keyboard's characters, not QWERTY physical
        // positions. Missing/unknown characters must not fall back to a destructive
        // action by keycode. Keep physical keycodes solely for navigation/Return.
        let commandFlags = flags.subtracting(.maskShift)
        func letterAction(_ value:String?) -> WindowAction? {
            switch (value?.lowercased(), commandFlags.rawValue) {
            case ("w", CGEventFlags.maskCommand.rawValue): return .close
            case ("w", CGEventFlags([.maskCommand,.maskAlternate]).rawValue): return .closeAll
            case ("m", CGEventFlags.maskCommand.rawValue): return .minimize
            case ("q", CGEventFlags.maskCommand.rawValue): return .quit
            case ("q", CGEventFlags([.maskCommand,.maskControl]).rawValue): return .forceQuit
            case ("h", CGEventFlags.maskCommand.rawValue): return .hide
            case ("h", CGEventFlags([.maskCommand,.maskAlternate]).rawValue): return .hideOthers
            default: return nil
            }
        }
        // Preserve Command-dependent layouts (e.g. Dvorak–QWERTY ⌘) by trying
        // actual characters first, then modifier-independent characters for
        // Option/Control combinations, matching the original parser's order.
        action = letterAction(characters) ?? letterAction(charactersIgnoringModifiers)
            ?? ((key == 36 || key == 76) && flags.isEmpty ? .open : nil)
        if let action = action, context.actions.contains(action) {
            suppressed.insert(key)
            guard !repeatKey else { return .swallow }
            return context.hasSelection ? .action(action) : .noSelection
        }
        if context.navigation && (flags.isEmpty || (flags == .maskShift && key == 48)) {
            let decision: InputDecision
            switch key {
            case 48: decision = .cycle(backwards: flags.contains(.maskShift))
            case 123: decision = .direction(.left)
            case 124: decision = .direction(.right)
            case 125: decision = .direction(.down)
            case 126: decision = .direction(.up)
            default: return .pass
            }
            suppressed.insert(key)
            return context.hasSelection ? decision : .noSelection
        }
        return .pass
    }
}
