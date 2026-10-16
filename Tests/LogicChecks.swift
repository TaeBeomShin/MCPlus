import Foundation
import CoreGraphics

@main
struct LogicChecks {
    static func main() {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        let windows = [
            WindowIdentity(id: 11, pid: 101, title: "Untitled"),
            WindowIdentity(id: 12, pid: 101, title: "Untitled"),
            WindowIdentity(id: 13, pid: 102, title: "Report"),
            WindowIdentity(id: 14, pid: 103, title: "Report")
        ]
        expect(WindowMatching.index(for: .init(id: 12, pid: 0, title: ""), in: windows) == 1, "Exact ID must disambiguate same-title windows")
        expect(WindowMatching.index(for: .init(id: 12, pid: 102, title: "Untitled"), in: windows) == nil, "Conflicting PID must fail")
        expect(WindowMatching.index(for: .init(id: 99, pid: 101, title: "Untitled"), in: windows) == nil, "Unknown ID must never fall back to a title")
        expect(WindowMatching.index(for: .init(id: nil, pid: 0, title: "Report"), in: windows) == nil, "Ambiguous global title must fail")
        expect(WindowMatching.index(for: .init(id: nil, pid: 102, title: "Report"), in: windows) == nil, "PID plus unique title does not establish which real window a thumbnail represents")
        expect(WindowMatching.index(for: .init(id: nil, pid: 0, title: "Report"), in: [windows[2]]) == nil, "A stale thumbnail must not bind to the sole remaining same-title window without an ID")
        expect(WindowMatching.index(for: .init(id: nil, pid: 101, title: "Untitled"), in: windows) == nil, "Duplicate titles in one app must fail")
        expect(WindowMatching.index(for: .init(id: nil, pid: 0, title: ""), in: windows) == nil, "Missing identity must fail")
        expect(WindowMatching.index(for: .init(id: 11, pid: 101, title: "Untitled"), in: windows + [windows[0]]) == nil, "Duplicate IDs must fail")
        let frames = [CGRect(x: 100, y: 100, width: 200, height: 100), CGRect(x: 400, y: 100, width: 200, height: 100), CGRect(x: 100, y: 350, width: 200, height: 100), CGRect(x: -300, y: 100, width: 200, height: 100)]
        expect(WindowNavigation.next(from: 0, frames: frames, direction: .right) == 1, "Right should follow row")
        expect(WindowNavigation.next(from: 0, frames: frames, direction: .down) == 2, "AX down means positive Y")
        expect(WindowNavigation.next(from: 0, frames: frames, direction: .left) == 3, "Negative monitor coordinates must work")
        expect(WindowNavigation.next(from: 0, frames: frames, direction: .up) == nil, "No candidate should not wrap to unrelated window")
        expect(WindowNavigation.next(from: 0, frames: [], direction: .down) == nil, "Empty layout must be safe")
        expect(WindowNavigation.cocoaFrame(CGRect(x: -1400, y: -900, width: 800, height: 600), primaryScreenHeight: 1080) == CGRect(x: -1400, y: 1380, width: 800, height: 600), "Screen above/left must preserve global coordinates")
        expect(WindowNavigation.cocoaFrame(CGRect(x: 20, y: 100, width: 200, height: 150), primaryScreenHeight: 1080).minY == 830, "AX top-left to AppKit bottom-left conversion")
        let staggered=[CGRect(x:200,y:0,width:80,height:50),CGRect(x:100,y:20,width:80,height:50),CGRect(x:0,y:40,width:80,height:50)]
        expect(WindowNavigation.orderedIndices(staggered)==[1,0,2],"Staggered rows require a transitive, deterministic ordering")
        expect(WindowNavigation.orderedIndices([]).isEmpty,"Empty ordering")
        let duplicate=CGRect(x:62,y:508,width:109,height:81)
        let server=[WindowServerRecord(identity:windows[0],frame:duplicate,layer:0,onScreen:true),WindowServerRecord(identity:windows[1],frame:CGRect(x:492,y:524,width:109,height:81),layer:0,onScreen:true)]
        expect(WindowServerMatching.identity(for:duplicate,title:"Untitled",pid:0,in:server)==windows[0],"Exact transformed bounds disambiguate duplicate titles")
        expect(WindowServerMatching.identity(for:duplicate,title:"",pid:0,in:server)==windows[0],"An empty thumbnail title can resolve through exact WindowServer identity")
        expect(WindowServerMatching.identity(for:duplicate.offsetBy(dx:1,dy:0),title:"Untitled",pid:0,in:server)==nil,"Approximate bounds must never resolve")
        expect(WindowServerMatching.identity(for:duplicate,title:"Untitled",pid:102,in:server)==nil,"Conflicting owner PID must reject bounds match")
        expect(WindowServerMatching.identity(for:duplicate,title:"Another window",pid:0,in:server)==nil,"Conflicting available title must reject bounds match")
        expect(WindowServerMatching.identity(for:duplicate,title:"Another caption",pid:0,in:server,validatedWindows:windows)==windows[0],"A unique independently verified AX ID/PID binding can resolve differing captions")
        expect(WindowServerMatching.identity(for:duplicate,title:"Another caption",pid:0,in:server,validatedWindows:[.init(id:11,pid:102,title:"Untitled")])==nil,"Conflicting AX owner must not authorize differing captions")
        expect(WindowServerMatching.identity(for:duplicate,title:"Another caption",pid:0,in:server,validatedWindows:windows+[windows[0]])==nil,"Ambiguous independent AX binding must reject differing captions")
        expect(WindowServerMatching.identity(for:duplicate,title:"Untitled",pid:0,in:server+[server[0]])==nil,"Overlapping exact bounds must fail closed")
        expect(WindowServerMatching.identity(for:duplicate,title:"Untitled",pid:0,in:[WindowServerRecord(identity:windows[0],frame:duplicate,layer:0,onScreen:false)])==nil,"Offscreen window must not resolve")
        expect(WindowServerMatching.identity(for:duplicate,title:"Untitled",pid:0,in:[WindowServerRecord(identity:windows[0],frame:duplicate,layer:1,onScreen:true)])==nil,"Non-application window layer must not resolve")
        expect(WindowServerMatching.identity(for:duplicate,title:"Untitled",pid:0,in:[WindowServerRecord(identity:.init(id:11,pid:101,title:""),frame:duplicate,layer:0,onScreen:true)])?.id==11,"Redacted WindowServer title does not require screen recording")
        print("Passed \(checks) window identity, navigation, and coordinate checks.")
    }
}
