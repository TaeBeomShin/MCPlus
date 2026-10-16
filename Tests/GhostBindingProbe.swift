// Read-only comparison. Never executes a window action, including in the legacy replay.
import Cocoa
import ApplicationServices

@main struct GhostBindingProbe {
    static func main() {
        guard AXIsProcessTrusted(),let app=NSRunningApplication.runningApplications(withBundleIdentifier:"local.mcplus.test-fixture").first,
              let data=try? Data(contentsOf:URL(fileURLWithPath:".build/MCPlusTestFixture-state.json")),
              let state=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let windows=state["windows"] as? [[String:Any]],windows.count==2 else { exit(2) }
        let openIDs=Set(windows.filter { $0["closed"] as? Bool==false }.compactMap { ($0["windowID"] as? Int).map(UInt32.init) })
        let closedIDs=Set(windows.filter { $0["closed"] as? Bool==true }.compactMap { ($0["windowID"] as? Int).map(UInt32.init) })
        guard openIDs.count==1,closedIDs.count==1,windows.allSatisfy({$0["title"] as? String=="MCPlus Test Duplicate"}) else { exit(3) }
        let snapshot=MissionReader().read()
        guard snapshot.active else { exit(4) }
        let bindings=snapshot.thumbnails.filter { $0.window != nil && $0.identity.pid==app.processIdentifier }
        let remaining=bindings.filter { $0.identity.id.map(openIDs.contains) ?? false }.count
        let closed=bindings.filter { $0.identity.id.map(closedIDs.contains) ?? false }.count
        let report:[String:Any]=["recordedAt":ISO8601DateFormatter().string(from:Date()),"actualOpenFixtureWindows":openIDs.count,"actualClosedFixtureWindows":closedIDs.count,"bindingsToOpenFixtureWindow":remaining,"bindingsToClosedFixtureWindow":closed,"fixtureCaptionCountInMissionControl":snapshot.thumbnails.filter { AX.string($0.proxy,kAXTitleAttribute)=="MCPlus Test Duplicate" }.count,"scope":"Read-only production reader or explicitly labeled controlled replay of the former title-fallback policy. No actions or OS input posted; no user app titles/names persisted."]
        let output=CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "reports/ghost-production-readonly.json"
        let bytes=try! JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
        try! bytes.write(to:URL(fileURLWithPath:output),options:.atomic)
        print("Read-only ghost probe: \(remaining) bindings to one open fixture window; \(closed) to its closed window")
    }
}
