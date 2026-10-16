import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let preferences = Preferences()
    lazy var controller = MissionController(preferences: preferences)
    private var item: NSStatusItem!
    private var settings: NSWindow?
    private var subscriptions=Set<AnyCancellable>()
    private let login=LoginItemController()
    private let updates=UpdateController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let duplicates = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.mcplus.app")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let existing = duplicates.first { existing.activate(options: [.activateIgnoringOtherApps]); NSApp.terminate(nil); return }
        NSApp.setActivationPolicy(.accessory)
        let mainMenu = NSMenu()
        let appEntry = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "설정…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self; appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "MCPlus 종료", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self; appMenu.addItem(quitItem)
        appEntry.submenu = appMenu; mainMenu.addItem(appEntry); NSApp.mainMenu = mainMenu
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "MCPlus")
        item.button?.toolTip = "MCPlus · Mission Control 창 관리"
        let menu = NSMenu(); menu.delegate = self; item.menu = menu
        preferences.$hideMenuBar.receive(on:DispatchQueue.main).sink { [weak self] hidden in self?.item.isVisible = !hidden }.store(in:&subscriptions)
        controller.start()
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hasLaunched") || !controller.trusted {
            defaults.set(true, forKey: "hasLaunched"); showSettings()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "MCPlus", action: nil, keyEquivalent: ""); title.isEnabled = false; menu.addItem(title)
        let status = NSMenuItem(title: controller.status, action: nil, keyEquivalent: ""); status.isEnabled = false; menu.addItem(status)
        menu.addItem(.separator())
        add(menu, preferences.enabled ? "일시 정지" : "다시 시작", #selector(toggleEnabled), "")
        add(menu, "설정…", #selector(showSettings), ",")
        if !controller.trusted { add(menu, "손쉬운 사용 권한 설정…", #selector(requestPermission), "") }
        menu.addItem(.separator())
        for action in WindowAction.allCases {
            let text="\(action.shortcut)  \(action.title)"
            let entry = NSMenuItem(title: text, action: nil, keyEquivalent: ""); entry.isEnabled = false; menu.addItem(entry)
        }
        menu.addItem(.separator())
        add(menu,"업데이트 확인…",#selector(checkUpdates),"")
        add(menu,"메뉴 막대 아이콘 숨기기",#selector(hideMenuItem),"")
        add(menu,"MCPlus 정보",#selector(about),"")
        menu.addItem(.separator()); add(menu, "MCPlus 종료", #selector(quit), "q")
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
    }
    @objc func showSettings() {
        if settings == nil {
            let view = SettingsView(controller: controller, preferences: preferences, login: login, updates: updates)
            let host = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: host)
            window.title = "MCPlus"; window.styleMask = [.titled, .closable, .miniaturizable]
            window.titlebarAppearsTransparent = true; window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(calibratedRed: 0.075, green: 0.08, blue: 0.105, alpha: 1)
            window.center(); settings = window
        }
        login.refresh()
        settings?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func checkUpdates() { showSettings(); updates.check() }
    @objc func hideMenuItem() { showSettings(); preferences.hideMenuBar=true }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"MCPlus",.applicationVersion:Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? ""]) }
    @objc func toggleEnabled() { preferences.enabled.toggle() }
    @objc func requestPermission() { controller.requestAccessibility() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationWillTerminate(_ notification: Notification) { controller.stop() }
}

@main
struct MCPlusMain {
    static func main() {
        if CommandLine.arguments.contains("--status") {
            var state = UserDefaults.standard.dictionary(forKey: "runtimeState") ?? [:]
            let reportedPID=(state["pid"] as? NSNumber)?.int32Value ?? 0
            let live=reportedPID>0 ? NSRunningApplication(processIdentifier:reportedPID) : nil
            let currentVersion=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? ""
            let sameProcess=live != nil && live?.isTerminated==false && live?.bundleIdentifier==Bundle.main.bundleIdentifier
            let currentHash=RuntimeBuild.executableSHA256
            state["runtimeIsCurrentBuild"]=sameProcess && live?.executableURL?.standardizedFileURL == Bundle.main.executableURL?.standardizedFileURL && state["version"] as? String == currentVersion && !currentHash.isEmpty && state["executableSHA256"] as? String == currentHash
            state["runtimeProcessAlive"]=sameProcess
            state["queriedExecutableSHA256"]=currentHash
            state["queriedVersion"]=currentVersion
            if let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
            return
        }
        if CommandLine.arguments.contains("--diagnose") {
            print("MCPlus \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · \(ProcessInfo.processInfo.operatingSystemVersionString)")
            print(MissionReader().dump()); return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
