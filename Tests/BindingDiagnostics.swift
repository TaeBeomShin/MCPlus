// Read-only, redacted binding diagnosis. Does not persist titles or app names.
import Cocoa
import ApplicationServices

@main struct BindingDiagnostics {
    static func main() {
        guard AXIsProcessTrusted() else { exit(2) }
        let snapshot=MissionReader().read()
        guard snapshot.active else { fputs("Open Mission Control first.\n",stderr);exit(3) }
        let infos=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
        var unmatched:[[String:Any]]=[]
        for thumbnail in snapshot.thumbnails where thumbnail.window==nil {
            let exact=infos.filter { info in
                guard let dict=info[kCGWindowBounds as String] as? NSDictionary,let frame=CGRect(dictionaryRepresentation:dict) else { return false }
                return frame==thumbnail.frame
            }
            var candidates:[[String:Any]]=[]
            for info in exact {
                guard let pid=info[kCGWindowOwnerPID as String] as? Int32 else { continue }
                let app=NSRunningApplication(processIdentifier:pid)
                let element=AX.app(pid)
                var value:CFTypeRef?
                let error=AXUIElementCopyAttributeValue(element,kAXWindowsAttribute as CFString,&value)
                let windows=value as? [AXUIElement] ?? []
                let id=(info[kCGWindowNumber as String] as? NSNumber)?.uint32Value
                let name=info[kCGWindowName as String] as? String ?? ""
                let exactWindow=windows.first { AX.windowID($0)==id }
                let windowTitle=exactWindow.map { AX.string($0,kAXTitleAttribute) } ?? ""
                let ownerName=app?.localizedName ?? ""
                var knownClosedFixture=false
                if app?.bundleIdentifier=="local.mcplus.test-fixture",
                   let data=try? Data(contentsOf:URL(fileURLWithPath:".build/MCPlusTestFixture-state.json")),
                   let state=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
                   let items=state["windows"] as? [[String:Any]] {
                    knownClosedFixture=items.contains { ($0["windowID"] as? Int).map(UInt32.init)==id && $0["closed"] as? Bool==true }
                }
                candidates.append(["knownClosedFixtureCandidate":knownClosedFixture,"proxyTitleEqualsAppName":thumbnail.identity.title==ownerName,"matchingAXWindowTitleEmpty":windowTitle.isEmpty,"appAXTitleEqualsWindowServerTitle":windowTitle==name,"proxyTitleContainsCGTitle":!name.isEmpty && thumbnail.identity.title.contains(name),"cgTitleContainsProxyTitle":!thumbnail.identity.title.isEmpty && name.contains(thumbnail.identity.title),"layer":info[kCGWindowLayer as String] as? Int ?? -999,"ownerPolicy":app?.activationPolicy.rawValue ?? -999,"ownerAppAvailable":app != nil,"appAXWindowsError":error.rawValue,"appAXWindowCount":windows.count,"idMatchesAppAXWindow":windows.contains { AX.windowID($0)==id },"proxyTitleEqualsWindowServerTitle":thumbnail.identity.title==name,"windowServerTitleAvailable":!name.isEmpty,"proxyTitleMatchesAppAXWindowCount":windows.filter { AX.string($0,kAXTitleAttribute)==thumbnail.identity.title }.count])
            }
            unmatched.append(["proxyTitleEmpty":thumbnail.identity.title.isEmpty,"proxyIDAvailable":thumbnail.identity.id != nil,"proxyOwnerKnown":thumbnail.identity.pid>0,"exactWindowServerCandidates":candidates])
        }
        let report:[String:Any]=["recordedAt":ISO8601DateFormatter().string(from:Date()),"os":ProcessInfo.processInfo.operatingSystemVersionString,"thumbnailCount":snapshot.thumbnails.count,"matchedCount":snapshot.thumbnails.filter { $0.window != nil }.count,"unmatched":unmatched,"scope":"Read-only binding relationships; no titles, app names, images, or user documents persisted. CGWindowInfo is read after the reader snapshot, so animation/state changes can affect comparisons."]
        let data=try! JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
        try! data.write(to:URL(fileURLWithPath:"reports/binding-diagnostics.json"),options:.atomic)
        print("Binding diagnostic: \(snapshot.thumbnails.count) thumbnails, \(unmatched.count) unmatched; redacted report written")
    }
}
