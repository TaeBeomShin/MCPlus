// Read-only identity investigation, restricted to disposable fixture windows.
import Cocoa
import ApplicationServices

@main struct WindowIdentityProbe {
    static func main() {
        guard AXIsProcessTrusted(),let fixture=NSRunningApplication.runningApplications(withBundleIdentifier:"local.mcplus.test-fixture").first else { fatalError("Trusted runner and disposable fixture required") }
        let reader=MissionReader(), snapshot=reader.read()
        let proxies=snapshot.thumbnails.filter { $0.identity.title.hasPrefix("MCPlus Test") }
        var records:[[String:Any]]=[]
        for item in proxies {
            var names:CFArray?
            AXUIElementCopyAttributeNames(item.proxy,&names)
            var attrs:[String:String]=[:]
            for name in names as? [String] ?? [] {
                if let value=AX.value(item.proxy,name) { attrs[name]=String(describing:value) }
            }
            records.append(["title":item.identity.title,"frame":NSStringFromRect(item.frame),"matched":item.window != nil,"attributes":attrs])
        }
        let cg=(CGWindowListCopyWindowInfo([.optionAll,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []).filter { ($0[kCGWindowOwnerPID as String] as? Int)==Int(fixture.processIdentifier) }
        let actual=AX.elements(AX.app(fixture.processIdentifier),kAXWindowsAttribute).map { ["id":AX.windowID($0).map(String.init) ?? "nil","title":AX.string($0,kAXTitleAttribute),"frame":AX.frame($0).map(NSStringFromRect) ?? "nil"] }
        let report:[String:Any]=["missionControlActive":snapshot.active,"thumbnails":records,"actualWindows":actual,"windowServer":cg,"scope":"Read-only; fixture-owned window metadata only; no input synthesis"]
        let data=try! JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
        try! data.write(to:URL(fileURLWithPath:"reports/window-identity-probe.json"),options:.atomic)
        print("Wrote reports/window-identity-probe.json; Mission Control active: \(snapshot.active); fixture thumbnails: \(proxies.count)")
    }
}
