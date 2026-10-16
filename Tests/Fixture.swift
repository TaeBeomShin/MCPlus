// A disposable integration-test app. It never reads or changes the user's documents.
import Cocoa

final class FixtureDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var windows: [NSWindow] = []
    var closed = Set<Int>()
    var timer: Timer?
    var lastCommand=""
    var protectedContent = false
    var pendingAlert: NSAlert?
    var alertKind = ""
    var cancelledPrompts = 0
    var prefix="MCPlus Test"
    var commandURL: URL { stateURL.deletingLastPathComponent().appendingPathComponent(stateURL.deletingPathExtension().lastPathComponent+"-command.json") }
    let stateURL: URL
    override init() {
        let path = Bundle.main.object(forInfoDictionaryKey: "MCPlusTestStatePath") as? String ?? "/tmp/mcplus-fixture-state.json"
        stateURL = URL(fileURLWithPath: path)
        super.init()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let main = NSMenu(), entry = NSMenuItem(), menu = NSMenu()
        let quit = NSMenuItem(title: "Quit test fixture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit); entry.submenu = menu; main.addItem(entry); NSApp.mainMenu = main
        prefix=Bundle.main.object(forInfoDictionaryKey:"MCPlusTestPrefix") as? String ?? "MCPlus Test"
        reset()
        NSApp.activate(ignoringOtherApps:true)
        timer=Timer.scheduledTimer(withTimeInterval:0.05,repeats:true) { [weak self] _ in self?.consumeCommand(); self?.writeState() }
    }
    func reset(mode: String = "unique") {
        precondition(pendingAlert == nil, "Resolve the fixture confirmation before resetting")
        protectedContent = mode == "protected"
        cancelledPrompts = 0
        if mode=="accessory" { NSApp.setActivationPolicy(.accessory) }
        for window in windows { window.close() }
        windows.removeAll(); closed.removeAll()
        for (offset, letter) in ["A", "B"].enumerated() {
            let window = NSWindow(contentRect: NSRect(x: 100 + offset * 410, y: 220, width: 360, height: 240), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = mode=="empty" ? "" : (mode=="duplicate" ? "\(prefix) Duplicate" : "\(prefix) \(letter)")
            window.isReleasedWhenClosed = false; window.delegate = self
            let text = NSTextField(labelWithString: "MCPlus Test \(letter)\n\nDisposable test window\nNo documents or unsaved content")
            text.frame = NSRect(x: 24, y: 70, width: 312, height: 100)
            text.alignment = .center; text.font = .systemFont(ofSize: 16)
            if protectedContent { text.stringValue = "MCPlus Test \(letter)\n\nSimulated unsaved content\nNo user documents" }
            window.contentView?.addSubview(text)
            windows.append(window); window.makeKeyAndOrderFront(nil)
        }
        writeState()
    }
    func consumeCommand() {
        guard let data=try? Data(contentsOf:commandURL), let command=try? JSONSerialization.jsonObject(with:data) as? [String:String],
              let sequence=command["sequence"],sequence != lastCommand,command["operation"]=="reset" else { return }
        lastCommand=sequence
        reset(mode:command["mode"] ?? "unique")
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard protectedContent else { return true }
        showConfirmation(kind: "close", window: sender)
        return false
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard protectedContent else { return .terminateNow }
        guard pendingAlert == nil, let window = windows.first(where: { !closed.contains($0.windowNumber) }) else { return .terminateCancel }
        showConfirmation(kind: "quit", window: window)
        return .terminateLater
    }
    func showConfirmation(kind: String, window: NSWindow) {
        guard pendingAlert == nil else { return }
        let alert = NSAlert()
        alert.messageText = "Discard disposable test changes?"
        alert.informativeText = "Fixture-only simulated unsaved content. No user documents are involved."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Discard")
        pendingAlert = alert; alertKind = kind
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self else { return }
            self.pendingAlert = nil; self.alertKind = ""
            let discard = response == .alertSecondButtonReturn
            if !discard { self.cancelledPrompts += 1 }
            if kind == "quit" { NSApp.reply(toApplicationShouldTerminate: discard) }
            else if discard { window.close() }
            self.writeState()
        }
        writeState()
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow { closed.insert(window.windowNumber) }
        writeState()
    }
    func writeState() {
        let state: [[String: Any]] = windows.map { ["title": $0.title, "windowID": $0.windowNumber, "visible": $0.isVisible, "minimized": $0.isMiniaturized, "closed": closed.contains($0.windowNumber)] }
        let payload: [String:Any] = ["lastCommand":lastCommand,"protectedContent":protectedContent,"alertKind":alertKind,"cancelledPrompts":cancelledPrompts,"hidden":NSApp.isHidden,"activationPolicy":NSApp.activationPolicy().rawValue,"windows":state]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: stateURL, options: .atomic) }
    }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); writeState() }
}
@main struct FixtureMain {
    static func main() {
        let app = NSApplication.shared, delegate = FixtureDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
