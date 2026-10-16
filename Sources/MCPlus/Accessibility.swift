import Cocoa
import ApplicationServices
import Darwin

enum AX {
    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }
    static func string(_ element: AXUIElement, _ attribute: String) -> String { value(element, attribute) as? String ?? "" }
    static func elements(_ element: AXUIElement, _ attribute: String = kAXChildrenAttribute) -> [AXUIElement] {
        value(element, attribute) as? [AXUIElement] ?? []
    }
    static func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let result = value(parent, attribute), CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let p = value(element, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
              let s = value(element, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size),
              size.width > 1, size.height > 1, point.x.isFinite, point.y.isFinite else { return nil }
        return CGRect(origin: point, size: size)
    }
    typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    // Optional, read-only bridge. Without a window ID, destructive actions fail closed.
    private static let getWindow: GetWindow? = {
        #if APP_STORE
        return nil
        #else
        guard let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY),
              let address = dlsym(handle, "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(address, to: GetWindow.self)
        #endif
    }()
    static func windowID(_ element: AXUIElement) -> UInt32? {
        var id: CGWindowID = 0
        if let fn = getWindow, fn(element, &id) == .success, id != 0 { return id }
        if let number = value(element, "AXWindowNumber") as? NSNumber, number.uint32Value != 0 { return number.uint32Value }
        return nil
    }
    static func pid(_ element: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return pid
    }
    static func app(_ pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.12)
        return element
    }
}

struct MissionThumbnail {
    let identity: WindowIdentity
    let frame: CGRect
    let proxy: AXUIElement
    let window: AXUIElement?
    let application: NSRunningApplication?
    var key: String { "\(identity.pid):\(identity.id.map(String.init) ?? identity.title):\(CFHash(proxy))" }
}

struct MissionSnapshot {
    var active = false
    var thumbnails: [MissionThumbnail] = []
    var diagnostics = "Mission Control 대기 중"
    var capturedAt = Date()
}

protocol MissionSnapshotReading {
    func read() -> MissionSnapshot
    func dump() -> String
}

final class MissionReader: MissionSnapshotReading {
    private var systemApps: [(pid_t, AXUIElement)] = []
    private var refreshAt = Date.distantPast

    private func hosts() -> [(pid_t, AXUIElement)] {
        if Date() > refreshAt {
            systemApps = ["com.apple.dock", "com.apple.WindowManager"].flatMap {
                NSRunningApplication.runningApplications(withBundleIdentifier: $0)
            }.map { ($0.processIdentifier, AX.app($0.processIdentifier)) }
            refreshAt = Date().addingTimeInterval(3)
        }
        return systemApps
    }

    func groups() -> [AXUIElement] {
        hosts().flatMap { _, app -> [AXUIElement] in
            // The mc root normally sits directly below the application. A bounded extra level handles wrappers.
            let children = AX.elements(app)
            return (children + children.flatMap { AX.elements($0) }).filter { AX.string($0, kAXIdentifierAttribute) == "mc" }
        }
    }

    func read() -> MissionSnapshot {
        let started=Date()
        guard AXIsProcessTrusted() else { return MissionSnapshot(diagnostics: "손쉬운 사용 권한 필요") }
        let roots = groups().filter { !AX.elements($0).isEmpty }
        guard !roots.isEmpty else { return MissionSnapshot() }
        var proxies: [AXUIElement] = [], queue = roots.map { ($0, false) }, visited = Set<CFHashCode>(), count = 0
        while !queue.isEmpty && count < 600 {
            let (item, insideWindows) = queue.removeFirst()
            guard visited.insert(CFHash(item)).inserted else { continue }
            count += 1
            let identifier = AX.string(item, kAXIdentifierAttribute)
            // Desktop/fullscreen Space buttons must never be treated as application windows.
            if identifier.hasPrefix("mc.spaces") { continue }
            let role = AX.string(item, kAXRoleAttribute)
            let inWindowGroup = insideWindows || identifier == "mc.windows"
            if role == kAXWindowRole || (inWindowGroup && role == kAXButtonRole) {
                if AX.frame(item) != nil { proxies.append(item) }
            } else { queue.append(contentsOf: AX.elements(item).map { ($0, inWindowGroup) }) }
        }
        guard !proxies.isEmpty else {
            return MissionSnapshot(active: true, diagnostics: "Mission Control 감지 · 창 썸네일 없음 (\(count)개 요소)")
        }
        let serverWindows: [WindowServerRecord] = (CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements], kCGNullWindowID) as? [[String:Any]] ?? []).compactMap { info in
            guard let id=info[kCGWindowNumber as String] as? NSNumber,
                  let pid=info[kCGWindowOwnerPID as String] as? NSNumber,
                  let bounds=info[kCGWindowBounds as String] as? NSDictionary,
                  let frame=CGRect(dictionaryRepresentation:bounds) else { return nil }
            return WindowServerRecord(identity:WindowIdentity(id:id.uint32Value,pid:pid.int32Value,title:info[kCGWindowName as String] as? String ?? ""),frame:frame,layer:info[kCGWindowLayer as String] as? Int ?? -1,onScreen:info[kCGWindowIsOnscreen as String] as? Bool ?? false)
        }
        let proxyFrames=proxies.compactMap { AX.frame($0) }
        let representedOwners=Set(serverWindows.filter { $0.layer==0 && proxyFrames.contains($0.frame) }.map { $0.identity.pid })
        let apps = NSWorkspace.shared.runningApplications.filter {
            // Accessory/menu-bar apps can have real Mission Control windows.
            // Query them only when WindowServer identifies a represented window,
            // rather than polling every background agent on the system.
            ($0.activationPolicy == .regular || ($0.activationPolicy == .accessory && representedOwners.contains($0.processIdentifier))) && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        var windows: [(WindowIdentity, AXUIElement, NSRunningApplication)] = []
        for app in apps {
            for window in AX.elements(AX.app(app.processIdentifier), kAXWindowsAttribute) {
                let identity = WindowIdentity(id: AX.windowID(window), pid: app.processIdentifier, title: AX.string(window, kAXTitleAttribute))
                windows.append((identity, window, app))
            }
        }
        let identities = windows.map { $0.0 }
        let hostPids = Set(hosts().map { $0.0 })
        var thumbnails: [MissionThumbnail] = []
        for proxy in proxies {
            guard let frame = AX.frame(proxy) else { continue }
            let pid = AX.pid(proxy)
            // _AXUIElementGetWindow(proxy) returns Mission Control's shared container window,
            // not the represented application window. Only use an explicit per-thumbnail ID.
            let explicitID = (AX.value(proxy, "AXWindowNumber") as? NSNumber).flatMap { $0.uint32Value == 0 ? nil : $0.uint32Value }
            let proxyPID=hostPids.contains(pid) ? 0 : pid
            let title=AX.string(proxy,kAXTitleAttribute)
            let serverIdentity=WindowServerMatching.identity(for:frame,title:title,pid:proxyPID,in:serverWindows,validatedWindows:identities)
            let identity = explicitID.map { WindowIdentity(id:$0,pid:proxyPID,title:title) }
                ?? serverIdentity.map { WindowIdentity(id:$0.id,pid:$0.pid,title:title) }
                ?? WindowIdentity(id:nil,pid:proxyPID,title:title)
            let match = WindowMatching.index(for: identity, in: identities).map { windows[$0] }
            thumbnails.append(MissionThumbnail(identity: match?.0 ?? identity, frame: frame, proxy: proxy, window: match?.1, application: match?.2))
        }
        thumbnails=WindowNavigation.orderedIndices(thumbnails.map(\.frame)).map { thumbnails[$0] }
        let matched = thumbnails.filter { $0.window != nil }.count
        return MissionSnapshot(active: true, thumbnails: thumbnails, diagnostics: "Mission Control · 창 \(thumbnails.count)개 · 연결 \(matched)개", capturedAt:started)
    }

    func dump() -> String {
        guard AXIsProcessTrusted() else { return "Accessibility permission: denied\n" }
        var lines = ["Accessibility permission: granted"]
        for (pid, app) in hosts() {
            lines.append("HOST pid=\(pid)")
            var queue: [(AXUIElement, Int)] = [(app, 0)], count = 0
            while !queue.isEmpty && count < 180 {
                let (item, depth) = queue.removeFirst(); count += 1
                let role = AX.string(item, kAXRoleAttribute), identifier = AX.string(item, kAXIdentifierAttribute)
                lines.append("\(String(repeating: "  ", count: depth))\(role) id=\(identifier) title=\(AX.string(item, kAXTitleAttribute)) window=\(AX.windowID(item) ?? 0) frame=\(String(describing: AX.frame(item)))")
                if depth < 7 { queue.append(contentsOf: AX.elements(item).map { ($0, depth + 1) }) }
            }
        }
        return lines.joined(separator: "\n")
    }
}
