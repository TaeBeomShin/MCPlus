import Cocoa
#if canImport(Sparkle) && !APP_STORE
import Sparkle
#endif

final class UpdateController: ObservableObject {
    @Published private(set) var message = ""
    #if canImport(Sparkle) && !APP_STORE
    private var standard: SPUStandardUpdaterController?
    #endif
    var configured: Bool {
        #if APP_STORE
        return false
        #else
        guard let raw=Bundle.main.object(forInfoDictionaryKey:"SUFeedURL") as? String,
              let url=URL(string:raw), url.scheme=="https", url.host != nil,
              let key=Bundle.main.object(forInfoDictionaryKey:"SUPublicEDKey") as? String,
              Data(base64Encoded:key)?.count == 32 else { return false }
        return true
        #endif
    }
    init() {
        #if canImport(Sparkle) && !APP_STORE
        if configured {
            standard=SPUStandardUpdaterController(startingUpdater:false,updaterDelegate:nil,userDriverDelegate:nil)
            standard?.updater.sendsSystemProfile=false
            do { try standard?.updater.start() } catch { message="업데이트를 시작하지 못했습니다: \(error.localizedDescription)" }
        }
        #endif
    }
    func check() {
        #if APP_STORE
        message="이 버전의 업데이트는 App Store에서 제공됩니다."
        #elseif canImport(Sparkle)
        guard let standard=standard else { message="이 개발 빌드에는 업데이트 배포 주소가 아직 설정되지 않았습니다."; return }
        standard.checkForUpdates(nil)
        #else
        message="이 빌드에는 업데이트 프레임워크가 포함되지 않았습니다."
        #endif
    }
    var automaticChecks: Bool {
        get {
            #if canImport(Sparkle) && !APP_STORE
            return standard?.updater.automaticallyChecksForUpdates ?? false
            #else
            return false
            #endif
        }
        set {
            #if canImport(Sparkle) && !APP_STORE
            standard?.updater.automaticallyChecksForUpdates=newValue
            objectWillChange.send()
            #endif
        }
    }
}
