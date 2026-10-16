import Cocoa
import ServiceManagement

final class LoginItemController: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var message = ""
    init() { refresh() }
    func refresh() {
        let status=SMAppService.mainApp.status
        enabled=status == .enabled || status == .requiresApproval
        requiresApproval=status == .requiresApproval
    }
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            message=""
        } catch { message=error.localizedDescription }
        refresh()
        if requiresApproval { message="시스템 설정의 로그인 항목에서 승인을 완료해 주세요." }
    }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
