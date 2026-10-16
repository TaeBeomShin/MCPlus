import Foundation
import CoreGraphics

@main struct InputChecks {
    static func main() {
        var checks=0
        func expect(_ value: @autoclosure () -> Bool,_ message:String) { precondition(value(),message); checks+=1 }
        let cases: [(Int64,CGEventFlags,WindowAction)] = [
            (13,.maskCommand,.close),(13,[.maskCommand,.maskAlternate],.closeAll),
            (46,.maskCommand,.minimize),(36,[],.open),(12,.maskCommand,.quit),
            (12,[.maskCommand,.maskControl],.forceQuit),(4,.maskCommand,.hide),(4,[.maskCommand,.maskAlternate],.hideOthers)
        ]
        func characters(_ key:Int64) -> String? { [13:"w",46:"m",12:"q",4:"h"][key] }
        for iteration in 0..<100 {
            let router=InputRouter()
            var context=InputContext(active:true,fresh:true,enabled:true,trusted:true,hasSelection:true,navigation:true)
            for (key,flags,action) in cases {
                expect(router.keyDown(key,flags:flags,characters:characters(key),repeatKey:false,context:context) == .action(action),"Action route \(iteration) \(action)")
                expect(router.keyDown(key,flags:flags,characters:characters(key),repeatKey:true,context:context) == .swallow,"Repeating a destructive key must not repeat the operation")
                expect(router.release(key),"The matching key-up must be suppressed")
                expect(!router.release(key),"A second key-up must pass")
                context.actions.remove(action)
                expect(router.keyDown(key,flags:flags,characters:characters(key),repeatKey:false,context:context) == .pass,"Individual disabled action must pass")
                expect(!router.release(key),"Disabled key-up must not be claimed")
                context.actions.insert(action)
            }
            expect(router.keyDown(48,flags:[],characters:characters(48),repeatKey:false,context:context) == .cycle(backwards:false),"Tab")
            expect(router.keyDown(48,flags:.maskShift,characters:characters(48),repeatKey:false,context:context) == .cycle(backwards:true),"Shift Tab")
            expect(router.keyDown(123,flags:.maskControl,characters:characters(123),repeatKey:false,context:context) == .pass,"Do not steal system Space navigation")
            expect(router.keyDown(13,flags:[.maskCommand,.maskAlphaShift,.maskSecondaryFn],characters:characters(13),repeatKey:false,context:context) == .action(.close),"Caps lock/Fn do not break command shortcuts")
            context.active=false
            expect(router.keyDown(12,flags:.maskCommand,characters:characters(12),repeatKey:false,context:context) == .pass,"Outside Mission Control Cmd Q passes")
            expect(router.release(13),"Release remains suppressed after Mission Control exits")
            context.active=true; context.hasSelection=false
            expect(router.keyDown(13,flags:.maskCommand,characters:characters(13),repeatKey:false,context:context) == .noSelection,"An unresolved selection cannot leak a close to another app")
            context.hasSelection=true; context.fresh=false
            expect(router.keyDown(13,flags:.maskCommand,characters:characters(13),repeatKey:false,context:context) == .pass,"Stale context cannot trigger an action")
            context.fresh=true; context.trusted=false
            expect(router.keyDown(13,flags:.maskCommand,characters:characters(13),repeatKey:false,context:context) == .pass,"No permission")
            context.trusted=true; context.enabled=false
            expect(router.keyDown(13,flags:.maskCommand,characters:characters(13),repeatKey:false,context:context) == .pass,"Paused")
        }
        // Deliberately mismatch character and physical position: on non-QWERTY
        // layouts these are different keys. Releases must still use physical IDs.
        let layoutContext=InputContext(active:true,fresh:true,enabled:true,trusted:true,hasSelection:true,navigation:true)
        let layoutRouter=InputRouter()
        for (key,character,flags,action) in [
            (7,"q",CGEventFlags.maskCommand,WindowAction.quit),
            (7,"Q",CGEventFlags([.maskCommand,.maskShift]),.quit),
            (12,"w",CGEventFlags.maskCommand,.close),
            (12,"W",CGEventFlags([.maskCommand,.maskShift]),.close),
            (2,"m",CGEventFlags.maskCommand,.minimize),
            (5,"h",CGEventFlags.maskCommand,.hide),
            (12,"w",CGEventFlags([.maskCommand,.maskAlternate]),.closeAll),
            (7,"Q",CGEventFlags([.maskCommand,.maskControl,.maskShift]),.forceQuit)
        ] {
            expect(layoutRouter.keyDown(Int64(key),flags:flags,characters:character,repeatKey:false,context:layoutContext) == .action(action),"Character, not QWERTY position, selects \(action)")
            expect(layoutRouter.keyDown(Int64(key),flags:flags,characters:character,repeatKey:true,context:layoutContext) == .swallow,"Character-based action does not autorepeat")
            expect(layoutRouter.release(Int64(key)),"Character mapping suppresses original physical key release")
            expect(!layoutRouter.release(Int64(key)),"Release suppression is cleared")
        }
        for (actual,unmodified,flags,expected) in [
            ("q","w",CGEventFlags.maskCommand,WindowAction.quit),
            ("∑","w",CGEventFlags([.maskCommand,.maskAlternate]),.closeAll),
            ("\u{11}","q",CGEventFlags([.maskCommand,.maskControl]),.forceQuit),
            ("˙","h",CGEventFlags([.maskCommand,.maskAlternate]),.hideOthers)
        ] {
            expect(layoutRouter.keyDown(7,flags:flags,characters:actual,charactersIgnoringModifiers:unmodified,repeatKey:false,context:layoutContext) == .action(expected),"Actual characters take priority, then modifier-independent fallback")
            expect(layoutRouter.release(7),"Two-stage parser still pairs the physical key-up")
        }
        for character:String? in [nil,"","a","ㅂ","qw","q\u{301}"] {
            expect(layoutRouter.keyDown(12,flags:.maskCommand,characters:character,repeatKey:false,context:layoutContext) == .pass,"Unknown characters must never trigger physical Q termination")
            expect(!layoutRouter.release(12),"Unclaimed character's key-up passes")
        }
        let suite="local.mcplus.tests.\(UUID().uuidString)"
        let defaults=UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let p=Preferences(defaults:defaults)
        p.setEnabled(.forceQuit,false); p.hideMenuBar=true
        let restored=Preferences(defaults:defaults)
        expect(!restored.isEnabled(.forceQuit) && restored.isEnabled(.close),"Per-action preference persistence")
        expect(restored.hideMenuBar,"Menu visibility persistence")
        restored.shortcuts=false
        expect(restored.activeActions.isEmpty,"Master switch disables all actions without losing per-action preferences")
        print("Passed \(checks) input and preference checks (100 repetitions per action).")
    }
}
