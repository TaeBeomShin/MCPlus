import Foundation
import Combine

final class Preferences: ObservableObject {
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "enabled") } }
    @Published var closeButtons: Bool { didSet { defaults.set(closeButtons, forKey: "closeButtons") } }
    @Published var shortcuts: Bool { didSet { defaults.set(shortcuts, forKey: "shortcuts") } }
    @Published var navigation: Bool { didSet { defaults.set(navigation, forKey: "navigation") } }
    @Published var hideMenuBar: Bool { didSet { defaults.set(hideMenuBar, forKey: "hideMenuBar") } }
    @Published private var disabledActions: Set<WindowAction> { didSet { defaults.set(disabledActions.map(\.rawValue).sorted(), forKey: "disabledActions") } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["enabled":true,"closeButtons":true,"shortcuts":true,"navigation":true,"hideMenuBar":false])
        enabled=defaults.bool(forKey:"enabled"); closeButtons=defaults.bool(forKey:"closeButtons")
        shortcuts=defaults.bool(forKey:"shortcuts"); navigation=defaults.bool(forKey:"navigation")
        hideMenuBar=defaults.bool(forKey:"hideMenuBar")
        disabledActions=Set((defaults.stringArray(forKey:"disabledActions") ?? []).compactMap(WindowAction.init(rawValue:)))
    }
    func isEnabled(_ action: WindowAction) -> Bool { !disabledActions.contains(action) }
    func setEnabled(_ action: WindowAction, _ enabled: Bool) {
        if enabled { disabledActions.remove(action) } else { disabledActions.insert(action) }
    }
    var activeActions: Set<WindowAction> { shortcuts ? Set(WindowAction.allCases).subtracting(disabledActions) : [] }
    func recordRuntime(_ state: [String:Any]) {
        let previous=defaults.dictionary(forKey:"runtimeState") ?? [:]
        if !NSDictionary(dictionary:state).isEqual(to:previous) { defaults.set(state,forKey:"runtimeState") }
    }
}
