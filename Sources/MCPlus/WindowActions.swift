import Cocoa
import ApplicationServices

struct ActionOutcome: Equatable {
    enum State: String { case requested, completed, failed, unsupported }
    let state: State
    let message: String
    var succeeded: Bool { state == .requested || state == .completed }
}

protocol WindowActionApplying {
    func apply(_ action: WindowAction, target: MissionThumbnail) -> ActionOutcome
}

final class WindowActionExecutor: WindowActionApplying {
    private let applications: () -> [NSRunningApplication]
    private let beep: () -> Void
    init(applications: @escaping () -> [NSRunningApplication] = { NSWorkspace.shared.runningApplications },
         beep: @escaping () -> Void = { DispatchQueue.main.async { NSSound.beep() } }) {
        self.applications=applications; self.beep=beep
    }
    func apply(_ action: WindowAction, target: MissionThumbnail) -> ActionOutcome {
        if action == .open {
            let result=AXUIElementPerformAction(target.proxy,kAXPressAction as CFString)
            return outcome(result, "창 열기 요청을 보냈습니다.")
        }
        // Original 1.27 refuses normal Finder termination with a beep. Check
        // before any AX lookup or termination call, even for an unresolved window.
        if action == .quit, target.application?.bundleIdentifier == "com.apple.finder" {
            beep()
            return ActionOutcome(state:.unsupported,message:"Finder에는 정상 종료를 요청하지 않습니다.")
        }
        guard let window=target.window, let app=target.application, !app.isTerminated else {
            return ActionOutcome(state:.unsupported,message:"이 창을 정확히 식별할 수 없어 작업하지 않았습니다.")
        }
        // Revalidate the app/window binding. A released window or reused PID must never reach another app.
        guard AX.pid(window)==app.processIdentifier else {
            return ActionOutcome(state:.failed,message:"창 또는 앱이 변경되어 작업을 취소했습니다.")
        }
        if let live=NSRunningApplication(processIdentifier:app.processIdentifier),
           let capturedLaunch=app.launchDate,let currentLaunch=live.launchDate,capturedLaunch != currentLaunch {
            return ActionOutcome(state:.failed,message:"앱이 다시 시작되어 작업을 취소했습니다.")
        }
        if let id=target.identity.id, let current=AX.windowID(window), id != current {
            return ActionOutcome(state:.failed,message:"창 ID가 변경되어 작업을 취소했습니다.")
        }
        switch action {
        case .close:
            guard let button=AX.element(window,kAXCloseButtonAttribute) else { return ActionOutcome(state:.unsupported,message:"이 창은 닫기를 지원하지 않습니다.") }
            return outcome(AXUIElementPerformAction(button,kAXPressAction as CFString),"창에 닫기 요청을 보냈습니다.")
        case .closeAll:
            let windows=AX.elements(AX.app(app.processIdentifier),kAXWindowsAttribute)
            var sent=0, failed=0
            for item in windows where AX.pid(item)==app.processIdentifier {
                guard let button=AX.element(item,kAXCloseButtonAttribute) else { continue }
                if AXUIElementPerformAction(button,kAXPressAction as CFString) == .success { sent+=1 } else { failed+=1 }
            }
            return ActionOutcome(state:failed>0 ? .failed : (sent>0 ? .requested : .unsupported),message:"창 \(sent)개에 닫기 요청\(failed>0 ? " · 실패 \(failed)개" : "")")
        case .minimize:
            return outcome(AXUIElementSetAttributeValue(window,kAXMinimizedAttribute as CFString,kCFBooleanTrue),"창에 최소화 요청을 보냈습니다.")
        case .quit:
            let sent=app.terminate()
            return ActionOutcome(state:sent ? .requested : .failed,message:sent ? "앱에 정상 종료를 요청했습니다. 저장 확인은 해당 앱에서 처리합니다." : "앱의 정상 종료 요청을 확인하지 못했습니다.")
        case .forceQuit:
            let sent=app.forceTerminate()
            return ActionOutcome(state:sent ? .requested : .failed,message:sent ? "앱에 강제 종료를 요청했습니다." : "앱의 강제 종료 요청을 확인하지 못했습니다.")
        case .hide:
            return outcome(AXUIElementSetAttributeValue(AX.app(app.processIdentifier),kAXHiddenAttribute as CFString,kCFBooleanTrue),"앱 숨기기를 요청했습니다.")
        case .hideOthers:
            var failed=0
            for other in applications() where other.activationPolicy == .regular && other.processIdentifier != app.processIdentifier && other.processIdentifier != getpid() {
                if AXUIElementSetAttributeValue(AX.app(other.processIdentifier),kAXHiddenAttribute as CFString,kCFBooleanTrue) != .success { failed+=1 }
            }
            return ActionOutcome(state:failed==0 ? .requested : .failed,message:failed==0 ? "다른 앱 숨기기를 요청했습니다." : "다른 앱 \(failed)개를 숨기지 못했습니다.")
        case .open: return ActionOutcome(state:.unsupported,message:"")
        }
    }
    private func outcome(_ error: AXError, _ message: String) -> ActionOutcome {
        ActionOutcome(state:error == .success ? .requested : .failed,message:error == .success ? message : "작업 실패 (AX \(error.rawValue))")
    }
}
