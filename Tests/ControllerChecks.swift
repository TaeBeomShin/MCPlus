// In-process controller integration. No event posting, real event tap, app
// launches, remote AX calls, window mutation, or standard UserDefaults writes.
import Cocoa
import ApplicationServices

final class ControlledReader: MissionSnapshotReading {
    var next: MissionSnapshot
    var hold=false
    let entered=DispatchSemaphore(value:0), release=DispatchSemaphore(value:0)
    init(_ snapshot:MissionSnapshot) { next=snapshot }
    func read() -> MissionSnapshot {
        entered.signal()
        if hold { precondition(release.wait(timeout:.now()+4) == .success,"Test failed to release controlled reader") }
        return next
    }
    func dump() -> String { "Controlled reader: no remote AX access" }
}
final class RecordingExecutor: WindowActionApplying {
    private let lock=NSLock()
    private var values:[(WindowAction,UInt32?)]=[]
    var calls:[(WindowAction,UInt32?)] { lock.lock(); defer { lock.unlock() }; return values }
    func apply(_ action:WindowAction,target:MissionThumbnail) -> ActionOutcome {
        lock.lock(); values.append((action,target.identity.id)); lock.unlock()
        return ActionOutcome(state:.requested,message:"Recorded without mutating any app")
    }
}
final class RecordingOverlay: SelectionDisplaying {
    var closeRect:CGRect?
    var title:String?
    func show(frame:CGRect,closeButton:Bool,selectable:Bool,title:String) {
        self.title=title
        closeRect=closeButton ? CGRect(x:frame.minX-10,y:frame.minY-10,width:28,height:28) : nil
    }
    func hide() { title=nil; closeRect=nil }
}
@main struct ControllerChecks {
    static func main() {
        var checks=0
        func expect(_ value:@autoclosure ()->Bool,_ message:String) { precondition(value(),message); checks+=1 }
        func wait(_ description:String,_ condition:()->Bool) {
            let deadline=Date().addingTimeInterval(4)
            while Date()<deadline {
                if condition() { return }
                _=RunLoop.current.run(mode:.default,before:Date().addingTimeInterval(0.005))
            }
            fatalError("Timeout: \(description)")
        }
        let domain="local.mcplus.controller-checks.\(UUID().uuidString)"
        let isolated=UserDefaults(suiteName:domain)!
        defer { isolated.removePersistentDomain(forName:domain) }
        func snapshot() -> MissionSnapshot {
            let thumbnails=(0..<2).map { i -> MissionThumbnail in
                let proxy=AXUIElementCreateApplication(getpid()+Int32(i))
                return MissionThumbnail(identity:.init(id:UInt32(i+1),pid:123,title:i==0 ? "A" : "B"),frame:CGRect(x:i==0 ? -400 : 100,y:100,width:200,height:120),proxy:proxy,window:proxy,application:nil)
            }
            return MissionSnapshot(active:true,thumbnails:thumbnails,diagnostics:"Controlled snapshot")
        }
        func setup() -> (MissionController,Preferences,ControlledReader,RecordingExecutor,RecordingOverlay) {
            isolated.removePersistentDomain(forName:domain)
            let preferences=Preferences(defaults:isolated), reader=ControlledReader(snapshot()), executor=RecordingExecutor(),overlay=RecordingOverlay()
            let controller=MissionController(preferences:preferences,reader:reader,executor:executor,overlay:overlay,connectsInputTap:false)
            controller.accept(reader.next,trusted:true)
            _=controller.handleInput(.mouseMoved(CGPoint(x:-300,y:150)))
            return (controller,preferences,reader,executor,overlay)
        }
        do {
            // Finder identity lookup is read-only. The target has no AX window,
            // so even a regressed guard cannot reach a real termination call.
            let finder=NSRunningApplication.runningApplications(withBundleIdentifier:"com.apple.finder").first!
            var beeps=0
            let executor=WindowActionExecutor(beep:{ beeps+=1 })
            let proxy=AXUIElementCreateApplication(getpid())
            let target=MissionThumbnail(identity:.init(id:nil,pid:finder.processIdentifier,title:""),frame:.zero,proxy:proxy,window:nil,application:finder)
            let result=executor.apply(.quit,target:target)
            expect(result.state == .unsupported && !result.succeeded,"Finder normal quit is rejected")
            expect(beeps==1,"Finder rejection emits exactly one feedback request before AX validation")
            expect(!finder.isTerminated,"Read-only Finder rejection leaves it running")
        }
        do {
            let (c,_,r,e,o)=setup()
            expect(o.title=="A","Mouse selects A on negative monitor coordinates")
            expect(c.handleInput(.keyDown(48,[],repeating:false)),"Tab consumed")
            expect(o.title=="B","Tab selection reaches overlay")
            var reordered=r.next;reordered.thumbnails.reverse()
            c.accept(reordered,trusted:true)
            expect(o.title=="B","Snapshot reordering preserves the selected window")
            expect(c.handleInput(.keyDown(13,.maskCommand,repeating:false,characters:"w")),"Cmd W consumed")
            expect(c.handleInput(.keyDown(13,.maskCommand,repeating:true,characters:"w")),"Autorepeat consumed")
            expect(c.handleInput(.keyUp(13)),"Corresponding key up consumed")
            wait("controller dispatches close") { !c.lastAction.isEmpty }
            expect(e.calls.count==1 && e.calls[0].0 == .close && e.calls[0].1==2,"Only selected B receives one close")
            c.stop()
            expect(!c.handleInput(.keyDown(13,.maskCommand,repeating:false,characters:"w")),"Stopped controller passes normal keys")
        }
        do {
            let (c,_,_,e,_)=setup()
            expect(c.handleInput(.keyDown(7,.maskCommand,repeating:false,characters:"q")),"Non-QWERTY Q reaches controller")
            expect(c.handleInput(.keyUp(7)),"Controller releases the original physical key")
            wait("controller dispatches character-based quit") { !c.lastAction.isEmpty }
            expect(e.calls.count==1 && e.calls[0].0 == .quit && e.calls[0].1==1,"Character-based Q sends normal quit only to selected A")
            c.stop()
        }
        do {
            let (c,p,_,e,o)=setup()
            p.setEnabled(.close,false)
            expect(!c.handleInput(.keyDown(13,.maskCommand,repeating:false,characters:"w")),"Disabled shortcut passes through")
            let point=CGPoint(x:o.closeRect!.midX,y:o.closeRect!.midY)
            expect(c.handleInput(.mouseDown(point)),"Independent close button consumes mouse down")
            expect(c.handleInput(.mouseUp),"Matching mouse up consumed")
            wait("controller dispatches close-button action") { !c.lastAction.isEmpty }
            expect(e.calls.count==1 && e.calls[0].1==1,"Close button acts on selected A despite shortcut being disabled")
            c.stop()
        }
        do {
            let (c,_,r,e,o)=setup()
            let a=r.next.thumbnails[0],b=r.next.thumbnails[1]
            r.next.thumbnails=[
                MissionThumbnail(identity:b.identity,frame:a.frame,proxy:a.proxy,window:b.window,application:nil),
                MissionThumbnail(identity:a.identity,frame:b.frame,proxy:b.proxy,window:a.window,application:nil)
            ]
            c.accept(r.next,trusted:true)
            expect(o.title=="A","A reused AX proxy cannot move selection to another resolved window")
            _=c.handleInput(.keyDown(13,.maskCommand,repeating:false,characters:"w"))
            wait("reused-proxy selection dispatches") { !c.lastAction.isEmpty }
            expect(e.calls.count==1 && e.calls[0].1==1,"The original window ID receives the action after proxy reuse")
            c.stop()
        }
        do {
            let (c,p,_,e,o)=setup()
            let point=CGPoint(x:o.closeRect!.midX,y:o.closeRect!.midY)
            p.closeButtons=false
            expect(!c.handleInput(.mouseDown(point)),"A disabled close button cannot act through an old overlay rectangle")
            expect(e.calls.isEmpty,"Disabled close button never reaches executor")
            c.stop()
        }
        do {
            let (c,p,r,e,o)=setup();r.hold=true
            let point=CGPoint(x:o.closeRect!.midX,y:o.closeRect!.midY)
            expect(c.handleInput(.mouseDown(point)),"Queued close-button click consumed")
            wait("mouse action begins validation") { r.entered.wait(timeout:.now()) == .success }
            p.enabled=false
            expect(c.handleInput(.mouseUp),"Mouse release stays consumed after pause")
            r.release.signal()
            wait("paused mouse action cancelled") { !c.lastAction.isEmpty }
            expect(e.calls.isEmpty,"Pausing cancels an in-flight close-button action")
            c.stop()
        }
        do {
            let (c,_,_,e,_)=setup()
            c.accept(MissionSnapshot(active:true,thumbnails:[]),trusted:true)
            expect(c.handleInput(.keyDown(13,.maskCommand,repeating:false,characters:"w")),"Empty Mission Control consumes close without forwarding to an underlying app")
            expect(!c.lastAction.isEmpty && e.calls.isEmpty,"Empty selection explains why no action ran")
            c.stop()
        }
        for cancellation in ["pause","escape","normalClick","stop","preference","permission"] {
            let (c,p,r,e,o)=setup();r.hold=true
            expect(c.handleInput(.keyDown(13,.maskCommand,repeating:false,characters:"w")),"Queued close consumed: \(cancellation)")
            wait("reader starts") { r.entered.wait(timeout:.now()) == .success }
            switch cancellation {
            case "pause": p.enabled=false
            case "escape": expect(!c.handleInput(.keyDown(53,[],repeating:false)),"Escape reaches Mission Control")
            case "normalClick": expect(!c.handleInput(.mouseDown(CGPoint(x:800,y:800))),"Normal click passes through")
            case "stop": c.stop()
            case "preference": p.navigation=false
            case "permission": c.accept(r.next,trusted:false)
            default: break
            }
            r.release.signal()
            wait("queued action cancelled") { !c.lastAction.isEmpty }
            expect(e.calls.isEmpty,"Cancellation prevents executor call: \(cancellation)")
            if cancellation != "stop" { expect(c.handleInput(.keyUp(13)),"Already consumed key release stays consumed: \(cancellation)") }
            if cancellation == "escape" || cancellation == "normalClick" || cancellation == "stop" {
                c.accept(r.next,trusted:true,epoch:0)
                expect(o.title==nil,"A pre-exit poll cannot restore overlay: \(cancellation)")
            }
            c.stop()
        }
        for scenario in ["missingWindow","inactive","stale"] {
            let (c,_,r,e,_)=setup()
            if scenario=="missingWindow" { r.next.thumbnails.removeFirst() }
            if scenario=="inactive" { r.next.active=false }
            if scenario=="stale" { r.next.capturedAt=Date().addingTimeInterval(-2) }
            _=c.handleInput(.keyDown(13,.maskCommand,repeating:false,characters:"w"))
            wait("fresh validation rejects \(scenario)") { !c.lastAction.isEmpty }
            expect(e.calls.isEmpty,"No operation after fresh validation failure: \(scenario)")
            c.stop()
        }
        do {
            let (c,_,r,e,_)=setup();r.hold=true
            _=c.handleInput(.keyDown(13,.maskCommand,repeating:false,characters:"w"))
            wait("first action pending") { r.entered.wait(timeout:.now()) == .success }
            _=c.handleInput(.keyDown(46,.maskCommand,repeating:false,characters:"m"))
            r.release.signal()
            wait("first action finishes") { !c.lastAction.isEmpty }
            expect(e.calls.count==1 && e.calls[0].0 == .close,"Busy controller does not enqueue a second destructive action")
            c.stop()
        }
        print("Passed \(checks) controller routing, selection, revalidation, and cancellation checks. No event tap or physical input exercised.")
    }
}
