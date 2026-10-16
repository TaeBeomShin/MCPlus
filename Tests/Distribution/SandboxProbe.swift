import Cocoa
import ApplicationServices
@main struct SandboxProbe {
    static func main() {
        _ = NSApplication.shared
        let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        var children: CFTypeRef?
        let error: AXError
        if let dock = dock { error = AXUIElementCopyAttributeValue(AXUIElementCreateApplication(dock.processIdentifier), kAXChildrenAttribute as CFString, &children) }
        else { error = .invalidUIElement }
        var ownWindows: CFTypeRef?
        let selfError = AXUIElementCopyAttributeValue(AXUIElementCreateApplication(getpid()), kAXWindowsAttribute as CFString, &ownWindows)
        let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: 1 << CGEventType.keyDown.rawValue, callback: { _,_,event,_ in Unmanaged.passUnretained(event) }, userInfo: nil)
        let tapAvailable = tap != nil
        if let tap = tap { CFMachPortInvalidate(tap) }
        let result: [String: Any] = [
            "bundleID": Bundle.main.bundleIdentifier ?? "", "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "accessibilityTrusted": AXIsProcessTrusted(), "dockPIDFound": dock != nil,
            "otherAppAXError": error.rawValue, "otherAppChildCount": (children as? [AXUIElement])?.count ?? 0,
            "selfAXError": selfError.rawValue, "eventTapCreated": tapAvailable,
            "privateAPIsUsed": false, "mutatedOtherApps": false
        ]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted,.sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
    }
}
