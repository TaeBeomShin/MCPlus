import Cocoa
import ApplicationServices

final class FixtureOnlyExecutor: WindowActionApplying {
    let app:NSRunningApplication
    let ids:Set<UInt32>
    private let lock=NSLock()
    private var recorded:[(WindowAction,UInt32)]=[]
    var calls:[(WindowAction,UInt32)] { lock.lock();defer { lock.unlock() };return recorded }
    init(app:NSRunningApplication,ids:Set<UInt32>) { self.app=app;self.ids=ids }
    func apply(_ action:WindowAction,target:MissionThumbnail) -> ActionOutcome {
        guard [.minimize,.close].contains(action),app.bundleIdentifier=="local.mcplus.test-fixture",
              target.application?.processIdentifier==app.processIdentifier,target.identity.pid==app.processIdentifier,
              let id=target.identity.id,ids.contains(id) else {
            return ActionOutcome(state:.failed,message:"Fixture gate rejected an unexpected target or action")
        }
        let result=WindowActionExecutor().apply(action,target:target)
        if result.succeeded { lock.lock();recorded.append((action,id));lock.unlock() }
        return result
    }
}
final class IntegrationOverlay: SelectionDisplaying {
    var closeRect:CGRect?
    func show(frame:CGRect,closeButton:Bool,selectable:Bool,title:String) {
        closeRect=closeButton ? CGRect(x:frame.minX-10,y:frame.minY-10,width:28,height:28) : nil
    }
    func hide() { closeRect=nil }
}

@main struct NativeIntegration {
    static let bundle="local.mcplus.test-fixture"
    static let stateURL=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".build/MCPlusTestFixture-state.json")
    static let commandURL=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".build/MCPlusTestFixture-state-command.json")
    static func state() -> [String:Any] {
        guard let data=try? Data(contentsOf:stateURL),let state=try? JSONSerialization.jsonObject(with:data) as? [String:Any] else { return [:] }
        return state
    }
    static func windows(_ state:[String:Any]) -> [[String:Any]] { state["windows"] as? [[String:Any]] ?? [] }
    static func wait(_ description:String,timeout:TimeInterval = 5,_ condition:()->Bool) {
        let end=Date().addingTimeInterval(timeout)
        while Date()<end { if condition() { return }; _ = RunLoop.current.run(mode:.default,before:Date().addingTimeInterval(0.02)) }
        fatalError("Timeout: \(description)")
    }
    static func reset(_ app:NSRunningApplication,mode:String = "unique") {
        _=AXUIElementSetAttributeValue(AX.app(app.processIdentifier),kAXHiddenAttribute as CFString,kCFBooleanFalse)
        let sequence=UUID().uuidString
        let data=try! JSONSerialization.data(withJSONObject:["sequence":sequence,"operation":"reset","mode":mode])
        try! data.write(to:commandURL,options:.atomic)
        wait("fixture reset") {
            let s=state(),w=windows(s)
            return s["lastCommand"] as? String == sequence && s["hidden"] as? Bool==false && w.count==2 && w.allSatisfy { $0["closed"] as? Bool == false && $0["minimized"] as? Bool == false }
        }
    }
    static func target(_ title:String,_ app:NSRunningApplication) -> MissionThumbnail {
        precondition(app.bundleIdentifier==bundle,"Tests must never target user apps")
        var selected: AXUIElement?
        wait("AX publishes the new exact fixture window") {
            let expected=windows(state()).first { $0["title"] as? String==title }?["windowID"] as? Int
            let matches=AX.elements(AX.app(app.processIdentifier),kAXWindowsAttribute).filter {
                AX.string($0,kAXTitleAttribute)==title && AX.pid($0)==app.processIdentifier && AX.windowID($0).map(Int.init)==expected
            }
            selected=matches.count==1 ? matches[0] : nil
            return selected != nil
        }
        let window=selected!
        return MissionThumbnail(identity:WindowIdentity(id:AX.windowID(window),pid:app.processIdentifier,title:title),frame:AX.frame(window) ?? .zero,proxy:window,window:window,application:app)
    }
    static func main() {
        _=NSApplication.shared
        guard AXIsProcessTrusted(),let app=NSRunningApplication.runningApplications(withBundleIdentifier:bundle).first else { fatalError("Launch the test fixture first; this test runner needs Accessibility access") }
        let args=CommandLine.arguments
        let mode=args.count>1 ? args[1] : "repeat"
        let executor=WindowActionExecutor()
        if mode == "saveCancellationUI" {
            reset(app,mode:"protected")
            precondition(state()["protectedContent"] as? Bool == true)
            var outcomes:[[String:String]]=[]
            for (index,action) in [WindowAction.close,.quit].enumerated() {
                let result=executor.apply(action,target:target("MCPlus Test A",app))
                precondition(result.state == .requested,"A request is not proof the app closed")
                let kind=action == .close ? "close" : "quit"
                wait("real AppKit confirmation sheet for \(kind)") { state()["alertKind"] as? String == kind }
                precondition(!app.isTerminated && windows(state()).allSatisfy { $0["closed"] as? Bool == false })
                print("WAITING: Cancel \(kind) confirmation in the disposable fixture")
                fflush(stdout)
                wait("fixture cancels \(kind) confirmation",timeout:60) {
                    let s=state()
                    return s["alertKind"] as? String == "" && s["cancelledPrompts"] as? Int == index+1
                }
                precondition(!app.isTerminated && windows(state()).count==2 && windows(state()).allSatisfy { $0["closed"] as? Bool == false })
                outcomes.append(["action":action.rawValue,"executorOutcome":result.state.rawValue,"result":"cancel respected; both fixture windows and process remain"])
            }
            reset(app)
            let report:[String:Any]=["os":ProcessInfo.processInfo.operatingSystemVersionString,"results":outcomes,"scope":"Production WindowActionExecutor sends real AX close / NSRunningApplication terminate to disposable fixture. Real NSAlert sheets cancelled by CUA button clicks. No physical input, user documents, Mission Control or save-to-disk flow exercised."]
            let data=try! JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
            try! data.write(to:URL(fileURLWithPath:"reports/save-cancellation-integration.json"),options:.atomic)
            print("PASS: real close and normal-quit requests respect fixture confirmation cancellation; requests do not imply completed closure")
            return
        }
        if mode == "controller" {
            let before=windows(state())
            precondition(before.count==2 && before.allSatisfy { $0["closed"] as? Bool==false && $0["minimized"] as? Bool==false },"Launch a fresh fixture before opening Mission Control")
            let aID=UInt32(before.first { $0["title"] as? String=="MCPlus Test A" }!["windowID"] as! Int)
            let bID=UInt32(before.first { $0["title"] as? String=="MCPlus Test B" }!["windowID"] as! Int)
            let reader=MissionReader(),initial=reader.read()
            precondition(initial.active,"Open Mission Control after launching the fixture")
            let a=initial.thumbnails.first { $0.identity.id==aID && $0.identity.pid==app.processIdentifier }!
            let gate=FixtureOnlyExecutor(app:app,ids:[aID,bID]),overlay=IntegrationOverlay()
            let domain="local.mcplus.native-controller.\(UUID().uuidString)"
            let isolated=UserDefaults(suiteName:domain)!
            defer { isolated.removePersistentDomain(forName:domain) }
            let controller=MissionController(preferences:Preferences(defaults:isolated),reader:reader,executor:gate,overlay:overlay,connectsInputTap:false)
            defer { controller.stop() }
            controller.accept(initial,trusted:true)
            _=controller.handleInput(.mouseMoved(CGPoint(x:a.frame.midX,y:a.frame.midY)))
            precondition(controller.handleInput(.keyDown(46,.maskCommand,repeating:false,characters:"m")),"Minimize command must be consumed")
            precondition(controller.handleInput(.keyUp(46)),"Minimize key release must be consumed")
            wait("controller minimizes only A") {
                let w=windows(state())
                return w.count==2 && w[0]["minimized"] as? Bool==true && w[1]["minimized"] as? Bool==false && w[1]["closed"] as? Bool==false && !controller.lastAction.isEmpty
            }
            var fresh=reader.read()
            wait("B remains selectable in Mission Control") {
                if fresh.active && fresh.thumbnails.contains(where:{ $0.identity.id==bID && $0.identity.pid==app.processIdentifier }) { return true }
                fresh=reader.read();return false
            }
            let b=fresh.thumbnails.first { $0.identity.id==bID && $0.identity.pid==app.processIdentifier }!
            controller.accept(fresh,trusted:true)
            _=controller.handleInput(.mouseMoved(CGPoint(x:b.frame.midX,y:b.frame.midY)))
            let point=CGPoint(x:overlay.closeRect!.midX,y:overlay.closeRect!.midY)
            precondition(controller.handleInput(.mouseDown(point)),"Close-button mouse down must be consumed")
            precondition(controller.handleInput(.mouseUp),"Close-button mouse up must be consumed")
            wait("controller closes only B") {
                let w=windows(state());return w.count==2 && w[1]["closed"] as? Bool==true && w[0]["closed"] as? Bool==false && w[0]["minimized"] as? Bool==true && gate.calls.count==2
            }
            let calls=gate.calls
            precondition(calls[0].0 == .minimize && calls[0].1==aID && calls[1].0 == .close && calls[1].1==bID,"Exact expected fixture actions only")
            let report:[String:Any]=["os":ProcessInfo.processInfo.operatingSystemVersionString,"minimizedA":aID,"closedB":bID,"otherFixtureWindowUntouched":true,"calls":calls.count,"scope":"MissionController value-input handling, selection, worker revalidation, real MissionReader and real AX executor; fixture-only mutation gate; no OS event posting, physical input, event-tap callback, or rendered overlay exercised"]
            let data=try! JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
            try! data.write(to:URL(fileURLWithPath:"reports/native-controller-integration.json"),options:.atomic)
            print("PASS: controller-to-native-window minimize and close; event tap and physical input excluded")
            return
        }
        if mode == "hideOthers" {
            let otherBundle="local.mcplus.other-fixture"
            let otherURL=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".build/MCPlusOtherFixture-state.json")
            guard let other=NSRunningApplication.runningApplications(withBundleIdentifier:otherBundle).first else { fatalError("Launch the second disposable fixture first") }
            func otherHidden() -> Bool? {
                guard let data=try? Data(contentsOf:otherURL),let value=try? JSONSerialization.jsonObject(with:data) as? [String:Any] else { return nil }
                return value["hidden"] as? Bool
            }
            _=AXUIElementSetAttributeValue(AX.app(other.processIdentifier),kAXHiddenAttribute as CFString,kCFBooleanFalse)
            defer { _=AXUIElementSetAttributeValue(AX.app(other.processIdentifier),kAXHiddenAttribute as CFString,kCFBooleanFalse) }
            reset(app)
            wait("other fixture visible before hideOthers") { otherHidden()==false }
            // Production executor; inject only the two disposable fixture apps.
            // Never enumerate or hide the user's actual applications during QA.
            let isolated=WindowActionExecutor(applications:{ [app,other] })
            let result=isolated.apply(.hideOthers,target:target("MCPlus Test A",app))
            precondition(result.succeeded,result.message)
            wait("other fixture hidden while selected fixture stays visible") { otherHidden()==true && state()["hidden"] as? Bool==false }
            _=AXUIElementSetAttributeValue(AX.app(other.processIdentifier),kAXHiddenAttribute as CFString,kCFBooleanFalse)
            wait("other fixture restored") { otherHidden()==false }
            print("PASS: hideOthers hid only the other disposable fixture and preserved the selected fixture; restored afterward")
            return
        }
        if mode == "missionDuplicate" || mode == "missionEmpty" || mode == "missionAccessory" || mode == "missionDuplicateGhost" {
            let expectedTitles=mode == "missionAccessory" ? ["MCPlus Test A","MCPlus Test B"] : Array(repeating:mode == "missionEmpty" ? "" : "MCPlus Test Duplicate",count:2)
            if mode == "missionAccessory" { precondition(app.activationPolicy == .accessory,"Fixture must actually use accessory activation policy") }
            let before=windows(state())
            precondition(before.count==2 && before.compactMap { $0["title"] as? String }.sorted()==expectedTitles.sorted() && before.allSatisfy { $0["closed"] as? Bool==false },"Reset the fixture to expected titles and open Mission Control first")
            let snapshot=MissionReader().read()
            let thumbnails=snapshot.thumbnails.filter { $0.application?.processIdentifier==app.processIdentifier }
            let expected=Set(before.compactMap { ($0["windowID"] as? Int).map(UInt32.init) })
            precondition(snapshot.active && thumbnails.count==2 && thumbnails.map { $0.identity.title }.sorted()==expectedTitles.sorted() && Set(thumbnails.compactMap { $0.identity.id })==expected,"Both thumbnails must resolve to the distinct fixture IDs")
            precondition(thumbnails.allSatisfy { $0.application?.processIdentifier==app.processIdentifier && $0.window != nil },"Every resolved window must belong to the disposable fixture")
            let selected=thumbnails[0],id=selected.identity.id!
            let result=executor.apply(.close,target:selected)
            precondition(result.succeeded,result.message)
            wait("only the resolved duplicate-title fixture window closes") {
                let w=windows(state())
                return w.count==2 && w.allSatisfy { item in
                    item["closed"] as? Bool == ((item["windowID"] as? Int)==Int(id))
                }
            }
            var report:[String:Any]=["os":ProcessInfo.processInfo.operatingSystemVersionString,"mode":mode,"fixtureThumbnailsMatched":2,"distinctFixtureIDs":expected.sorted(),"closedID":id,"otherWindowUntouched":true,"scope":"Production MissionReader plus WindowActionExecutor while Mission Control is active; physical input/event tap not exercised"]
            var ghostPassed=true
            if mode=="missionDuplicateGhost" {
                let remaining=expected.subtracting([id]).first!
                wait("closed fixture window leaves app AXWindows") {
                    let liveIDs=Set(AX.elements(AX.app(app.processIdentifier),kAXWindowsAttribute).compactMap { AX.windowID($0) })
                    return liveIDs.contains(remaining) && !liveIDs.contains(id)
                }
                let after=MissionReader().read()
                let bindings=after.thumbnails.filter { $0.window != nil && $0.identity.pid==app.processIdentifier }
                let remainingBindings=bindings.filter { $0.identity.id==remaining }.count
                let closedBindings=bindings.filter { $0.identity.id==id }.count
                ghostPassed=remainingBindings==1 && closedBindings==0
                report["postCloseRemainingWindowBindingCount"]=remainingBindings
                report["postCloseClosedWindowBindingCount"]=closedBindings
                report["postCloseGhostBindingCheckPassed"]=ghostPassed
                report["postCloseFixtureCaptionCount"]=after.thumbnails.filter { AX.string($0.proxy,kAXTitleAttribute)=="MCPlus Test Duplicate" }.count
            }
            let data=try! JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
            try! data.write(to:URL(fileURLWithPath:"reports/\(mode)-integration.json"),options:.atomic)
            if !ghostPassed { print("FAIL: a stale duplicate-title thumbnail rebound to the remaining fixture window; no second mutation was performed");exit(1) }
            print("PASS: \(mode) Mission Control identity and close integration")
            return
        }
        if mode=="quit" || mode=="forceQuit" {
            reset(app)
            let result=executor.apply(mode=="quit" ? .quit : .forceQuit,target:target("MCPlus Test A",app))
            precondition(result.succeeded,result.message)
            wait("fixture process terminated") { app.isTerminated }
            print("PASS: \(mode) terminated only the disposable fixture process")
            return
        }
        let iterations=args.count>2 ? Int(args[2]) ?? 100 : 100
        let start=Date()
        for iteration in 1...iterations {
            reset(app)
            let a=target("MCPlus Test A",app),b=target("MCPlus Test B",app)
            precondition(a.identity.id != b.identity.id,"Distinct test windows must have distinct IDs")
            let minimized=executor.apply(.minimize,target:a)
            precondition(minimized.succeeded,minimized.message)
            wait("A minimized while B untouched") {
                let w=windows(state());return w.count==2 && w[0]["minimized"] as? Bool==true && w[1]["minimized"] as? Bool==false && w[1]["closed"] as? Bool==false
            }
            let closed=executor.apply(.close,target:b)
            precondition(closed.succeeded,closed.message)
            wait("B closed while A remains minimized") {
                let w=windows(state());return w.count==2 && w[1]["closed"] as? Bool==true && w[0]["closed"] as? Bool==false && w[0]["minimized"] as? Bool==true
            }
            reset(app)
            let all=executor.apply(.closeAll,target:target("MCPlus Test A",app))
            if !all.succeeded {
                let live=NSRunningApplication(processIdentifier:app.processIdentifier)
                print("Fixture failure:",all.message,"expectedPID",app.processIdentifier,"bundleURLMatches",live?.bundleURL==app.bundleURL,"original",app.bundleURL?.path ?? "nil","live",live?.bundleURL?.path ?? "nil","originalDate",String(describing:app.launchDate),"liveDate",String(describing:live?.launchDate))
                fflush(stdout)
            }
            precondition(all.succeeded,all.message)
            wait("both fixture windows closed") { let w=windows(state());return w.count==2 && w.allSatisfy { $0["closed"] as? Bool==true } }
            if iteration % 10==0 { print("Passed native action iteration \(iteration)/\(iterations)"); fflush(stdout) }
        }
        reset(app)
        let hidden=executor.apply(.hide,target:target("MCPlus Test A",app))
        precondition(hidden.succeeded,hidden.message)
        wait("fixture hidden") { state()["hidden"] as? Bool==true }
        _=AXUIElementSetAttributeValue(AX.app(app.processIdentifier),kAXHiddenAttribute as CFString,kCFBooleanFalse)
        wait("fixture restored") { state()["hidden"] as? Bool==false }
        let report:[String:Any] = ["os":ProcessInfo.processInfo.operatingSystemVersionString,"iterations":iterations,"minimizePassed":iterations,"closePassed":iterations,"closeAllPassed":iterations,"hidePassed":true,"wrongFixtureWindowOperations":0,"seconds":Date().timeIntervalSince(start),"scope":"Production WindowActionExecutor called directly; only disposable fixture bundle; event-tap and physical input path not exercised"]
        let data=try! JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
        try! data.write(to:URL(fileURLWithPath:"reports/native-actions.json"),options:.atomic)
        print("PASS: native action integration checks; report: reports/native-actions.json")
    }
}
