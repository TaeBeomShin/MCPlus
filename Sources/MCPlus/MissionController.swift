import Cocoa
import ApplicationServices
import Combine
import CryptoKit

enum RuntimeBuild {
    // Cache at process startup: reading the path afresh in every poll could
    // mistake a rebuilt file on disk for the executable this process launched.
    static let executableSHA256: String = {
        guard let url=Bundle.main.executableURL,let bytes=try? Data(contentsOf:url,options:.mappedIfSafe) else { return "" }
        return SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined()
    }()
}

final class MissionController: ObservableObject {
    let preferences: Preferences
    @Published var trusted = AXIsProcessTrusted()
    @Published var keyboardReady = false
    @Published var status = "Mission Control 대기 중"
    @Published var lastAction = ""
    private let worker = DispatchQueue(label: "local.mcplus.accessibility", qos: .userInitiated)
    private let reader: MissionSnapshotReading
    private var timer: DispatchSourceTimer?
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var snapshot = MissionSnapshot()
    private var snapshotDate = Date.distantPast
    private var selected: Int?
    private let input = InputRouter()
    private let executor: WindowActionApplying
    private var swallowedClick = false
    private var busy = false
    private let overlay: SelectionDisplaying
    private let connectsInputTap: Bool
    private var authorizationEpoch: UInt64 = 0
    private var preferenceChanges: AnyCancellable?
    private var running=false
    private let launchedExecutableSHA256=RuntimeBuild.executableSHA256

    init(preferences: Preferences, reader: MissionSnapshotReading = MissionReader(),
         executor: WindowActionApplying = WindowActionExecutor(),
         overlay: SelectionDisplaying = SelectionOverlay(), connectsInputTap: Bool = true) {
        self.preferences = preferences; self.reader=reader; self.executor=executor
        self.overlay=overlay; self.connectsInputTap=connectsInputTap
        preferenceChanges=preferences.objectWillChange.sink { [weak self] _ in self?.authorizationEpoch &+= 1 }
    }

    func start() {
        guard !running else { return }
        running=true
        let timer = DispatchSource.makeTimerSource(queue: worker)
        timer.schedule(deadline: .now(), repeating: .milliseconds(180), leeway: .milliseconds(30))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let trust = AXIsProcessTrusted()
            // Skip remote AX calls entirely when disabled or permission is missing.
            let (enabled, epoch) = DispatchQueue.main.sync { (self.running && self.preferences.enabled,self.authorizationEpoch) }
            let next = trust && enabled ? self.reader.read() : MissionSnapshot(diagnostics: trust ? "일시 정지됨" : "손쉬운 사용 권한 필요")
            DispatchQueue.main.async {
                guard self.running else { return }
                self.accept(next, trusted: trust, epoch:epoch)
            }
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        running=false
        authorizationEpoch &+= 1; snapshot.active=false; selected=nil
        input.reset(); swallowedClick=false
        timer?.cancel(); timer = nil
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source = tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; tapSource = nil; keyboardReady=false; overlay.hide()
    }

    private func installTap() {
        guard connectsInputTap, tap == nil, trusted else { return }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context = context else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<MissionController>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            return controller.handle(type, event) ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap = tap {
            tapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            keyboardReady = true
        } else { keyboardReady = false }
    }

    func accept(_ next: MissionSnapshot, trusted: Bool, epoch: UInt64? = nil) {
        // A poll that started before Escape, a click, stop, or a settings change
        // must not restore a context the user has just invalidated.
        if let epoch=epoch, epoch != authorizationEpoch { return }
        if snapshot.active && (!next.active || !trusted) { authorizationEpoch &+= 1 }
        if self.trusted != trusted { self.trusted = trusted }
        if trusted { installTap() }
        else if let tap = tap {
            CFMachPortInvalidate(tap); self.tap = nil
            if let source = tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
            tapSource = nil; keyboardReady = false
        }
        let previous = selected.flatMap { snapshot.thumbnails.indices.contains($0) ? snapshot.thumbnails[$0] : nil }
        snapshot = next; snapshotDate = next.capturedAt
        if status != next.diagnostics { status = next.diagnostics }
        let runtime: [String: Any] = ["pid": ProcessInfo.processInfo.processIdentifier, "version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "", "executable":Bundle.main.executablePath ?? "", "trusted": trusted, "keyboardReady": keyboardReady, "active": next.active, "windows": next.thumbnails.count, "matched": next.thumbnails.filter { $0.window != nil }.count, "status": status]
        var identifiedRuntime=runtime
        identifiedRuntime["executableSHA256"]=launchedExecutableSHA256
        preferences.recordRuntime(identifiedRuntime)
        if !next.active || !preferences.enabled || !trusted { selected = nil; overlay.hide(); return }
        if let previous = previous {
            // A Mission Control AX proxy may be reused for another window after
            // layout changes. Preserve a resolved real window ID before proxy identity.
            selected = next.thumbnails.firstIndex { sameWindow($0.identity, previous.identity) && $0.window != nil }
            if selected == nil && previous.window == nil {
                selected = next.thumbnails.firstIndex { CFEqual($0.proxy,previous.proxy) }
            }
        }
        if selected == nil {
            let mouse = CGEvent(source: nil)?.location ?? .zero
            selected = next.thumbnails.firstIndex { $0.frame.contains(mouse) } ?? (next.thumbnails.isEmpty ? nil : 0)
        }
        drawSelection()
    }

    private func sameWindow(_ a: WindowIdentity, _ b: WindowIdentity) -> Bool {
        if let id = a.id, let other = b.id { return id == other && a.pid == b.pid }
        return a == b
    }

    private func drawSelection() {
        guard preferences.enabled, trusted, snapshot.active, let selected = selected,
              snapshot.thumbnails.indices.contains(selected) else { overlay.hide(); return }
        let thumbnail = snapshot.thumbnails[selected]
        overlay.show(frame: thumbnail.frame, closeButton: preferences.closeButtons && thumbnail.window != nil,
                     selectable: preferences.navigation, title: thumbnail.identity.title)
    }

    // This callback reads cached state only. Cross-process calls always run on the worker queue.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .keyDown:
            let keyEvent=NSEvent(cgEvent:event)
            return handleInput(.keyDown(event.getIntegerValueField(.keyboardEventKeycode),event.flags,
                repeating:event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                characters:keyEvent?.characters,charactersIgnoringModifiers:keyEvent?.charactersIgnoringModifiers))
        case .keyUp: return handleInput(.keyUp(event.getIntegerValueField(.keyboardEventKeycode)))
        case .mouseMoved: return handleInput(.mouseMoved(event.location))
        case .leftMouseDown: return handleInput(.mouseDown(event.location))
        case .leftMouseUp: return handleInput(.mouseUp)
        default: return false
        }
    }

    func handleInput(_ event: MissionInputEvent) -> Bool {
        if case .keyUp(let key)=event { return input.release(key) }
        if case .mouseUp=event, swallowedClick { swallowedClick = false; return true }
        guard preferences.enabled, trusted, snapshot.active, Date().timeIntervalSince(snapshotDate) < 1 else { return false }
        if case .mouseMoved(let point)=event {
            if let hover = snapshot.thumbnails.firstIndex(where: { $0.frame.contains(point) }), hover != selected {
                selected = hover; drawSelection()
            }
            return false
        }
        if case .mouseDown(let point)=event {
            if preferences.closeButtons, overlay.closeRect?.contains(point) == true {
                swallowedClick = true; perform(.close); return true
            }
            // A normal Mission Control click may immediately exit it. Stop intercepting keys until the next read.
            authorizationEpoch &+= 1; snapshot.active = false; overlay.hide()
            return false
        }
        guard case .keyDown(let key,let flags,let repeating,let characters,let ignoringModifiers)=event else { return false }
        let context = InputContext(active: snapshot.active, fresh: Date().timeIntervalSince(snapshotDate) < 1,
            enabled: preferences.enabled, trusted: trusted, hasSelection: selected != nil,
            navigation: preferences.navigation, actions: preferences.activeActions)
        let decision = input.keyDown(key, flags: flags, characters: characters, charactersIgnoringModifiers: ignoringModifiers, repeatKey: repeating, context: context)
        switch decision {
        case .pass: return false
        case .swallow: return true
        case .escape: authorizationEpoch &+= 1; snapshot.active=false; overlay.hide(); return false
        case .noSelection: lastAction="선택할 수 있는 창이 없습니다."; return true
        case .action(let action): perform(action); return true
        case .cycle(let backwards):
            guard !snapshot.thumbnails.isEmpty else { return true }
            selected=((selected ?? 0)+(backwards ? snapshot.thumbnails.count-1 : 1)) % snapshot.thumbnails.count
            drawSelection(); return true
        case .direction(let direction):
            guard !snapshot.thumbnails.isEmpty else { return true }
            let current=selected ?? 0
            selected=WindowNavigation.next(from:current,frames:snapshot.thumbnails.map(\.frame),direction:direction) ?? current
            drawSelection(); return true
        }
    }

    private func perform(_ action: WindowAction) {
        guard !busy, let selected = selected, snapshot.thumbnails.indices.contains(selected) else { return }
        let target = snapshot.thumbnails[selected]
        let epoch=authorizationEpoch
        busy = true
        worker.async { [weak self] in
            guard let self = self else { return }
            let fresh = self.reader.read()
            // Revalidate Mission Control and the window identity before any mutating action.
            let matches = fresh.thumbnails.filter { self.sameWindow($0.identity, target.identity) }
            let exactProxy = matches.filter { CFEqual($0.proxy, target.proxy) }
            let current = matches.count == 1 ? matches.first : (exactProxy.count == 1 ? exactProxy.first : nil)
            let stillAuthorized=DispatchQueue.main.sync {
                self.authorizationEpoch==epoch && self.preferences.enabled && self.trusted && self.snapshot.active && Date().timeIntervalSince(fresh.capturedAt)<1
            }
            guard stillAuthorized, fresh.active, let current = current else {
                DispatchQueue.main.async { self.busy = false; self.lastAction = "창 또는 설정이 변경되어 작업을 취소했습니다." }; return
            }
            let result = self.executor.apply(action, target: current)
            DispatchQueue.main.async {
                self.busy = false
                self.lastAction = result.message
                if self.authorizationEpoch==epoch && result.succeeded && [.open, .hide, .hideOthers, .quit, .forceQuit].contains(action) { self.authorizationEpoch &+= 1; self.snapshot.active = false; self.overlay.hide() }
            }
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func saveDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MCPlus-diagnostics.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        worker.async {
            let text = "MCPlus \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")\n\(ProcessInfo.processInfo.operatingSystemVersionString)\n" + self.reader.dump()
            do { try text.write(to: url, atomically: true, encoding: .utf8) }
            catch { DispatchQueue.main.async { self.lastAction = "진단 저장 실패: \(error.localizedDescription)" } }
        }
    }
}
