# MCPlus

Mission Control에서 창을 선택하고, 닫거나 최소화할 수 있는 macOS 메뉴 막대 앱입니다.

## 설치 · 앱을 내려받아 드래그하기

**[MCPlus 0.2.0 DMG 다운로드](https://github.com/TaeBeomShin/MCPlus/releases/download/v0.2.0-preview.1/MCPlus-0.2.0.dmg)** · [릴리스 안내](https://github.com/TaeBeomShin/MCPlus/releases/tag/v0.2.0-preview.1)

1. 다운로드한 **`MCPlus-0.2.0.dmg`**를 더블클릭합니다.
2. 안의 **MCPlus 앱을 Applications 폴더로 드래그**합니다. 기존 MCPlus가 실행 중이면 메뉴 막대에서 먼저 종료하세요.
3. Finder의 **응용 프로그램**에서 MCPlus를 실행합니다. 인터넷에서 내려받은 앱을 열 것인지 묻는 일반 확인 창이 나오면 앱 이름을 확인하고 엽니다.
4. 앱의 **권한 설정** 안내에 따라 **시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용 → MCPlus 켜기**를 진행한 뒤 앱을 종료하고 다시 실행합니다.

**터미널, 소스 빌드, Xcode 설치가 필요하지 않습니다.** 설치가 끝나면 Finder에서 MCPlus 디스크를 추출해도 됩니다. DMG 속 앱 대신 응용 프로그램 폴더에 복사한 앱을 실행하세요.

macOS 13 이상이 필요하며 Intel·Apple Silicon용 통합 빌드입니다. 배포 앱은 Developer ID로 서명하고 Apple 공증을 거쳤습니다. 손쉬운 사용 권한은 사용자가 직접 허용해야 합니다.

**개발 미리보기입니다.** 실제 동작 관측은 한 대의 macOS 26.5.2 Mac에 한정되며, 지원 OS·하드웨어·키보드 배열 전체 검증은 남아 있습니다. App Store 배포판은 아니며 자동 업데이트는 아직 제공하지 않습니다.

### 손쉬운 사용 목록에 MCPlus가 없다면

시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 **+**를 누릅니다. 파일 선택 창에서 `⌘⇧G`를 누르고 아래 경로를 입력한 뒤 MCPlus를 추가하고 켜 주세요.

```text
/Applications/MCPlus.app
```

이전에 소스 설치 도우미로 `~/Applications`에 설치했거나 다른 폴더에서 사용했다면, 이번에 `/Applications`에 복사한 앱에 권한을 부여했는지 확인하세요. 이전 앱의 로그인 시 시작 설정도 확인해 중복 실행을 피하세요. 창 제어를 위해 다른 앱의 창을 읽고 조작하는 권한을 사용하며, 화면 녹화 권한은 요청하지 않습니다.

### 처음 사용해 보기

저장할 내용이 없는 테스트 창 두 개를 준비하고 **Mission Control**을 엽니다. 기본 단축키는 `Control + ↑`입니다. 썸네일 위에 마우스를 올리거나 `Tab`으로 선택한 뒤, `⌘M`으로 최소화하거나 왼쪽 위 **×**로 닫아 보세요.

설정 창을 닫아도 앱은 **화면 상단 메뉴 막대**에 남습니다. 메뉴 막대 아이콘에서 설정, 일시 정지, 종료를 할 수 있습니다. Dock에 아이콘이 표시되지 않는 것은 정상입니다.

<details>
<summary>개발자용: 소스에서 직접 빌드해 설치하기</summary>

[소스 ZIP](https://github.com/TaeBeomShin/MCPlus/releases/download/v0.2.0-source.2/MCPlus-0.2.0-source.zip)을 내려받아 압축을 풉니다. 기존 `Install.command`는 다운로드한 명령 파일이라는 이유로 macOS에서 차단될 수 있어 일반 사용자에게는 위 DMG 설치를 권장합니다. 아래는 직접 빌드하는 방법입니다.

### 개발 도구 설치

`⌘ Space`를 누르고 **터미널**을 검색해 실행합니다. 아래 명령을 붙여넣고 Return을 누르세요.

```sh
xcode-select --install
```

설치 창이 나오면 안내에 따라 설치가 끝날 때까지 기다립니다. **이미 설치되어 있다는 메시지가 나오면 다음 단계로 넘어가면 됩니다.** Xcode 전체를 설치한 경우에는 Xcode를 한 번 열어 필요한 초기 설정을 완료해 주세요.

### 소스에서 빌드

다운로드 폴더에 압축을 풀었다면 터미널에서 다음 명령을 **한 줄씩** 실행합니다.

```sh
cd ~/Downloads/MCPlus-0.2.0
./scripts/build.sh
```

다른 위치에 풀었거나 폴더 이름이 다르다면, 터미널에 `cd`와 공백 하나를 입력한 뒤 **Finder의 압축을 푼 폴더를 터미널로 끌어다 놓고** Return을 누릅니다. 그다음 `./scripts/build.sh`를 실행하세요.

첫 빌드에서는 업데이트용 라이브러리인 Sparkle을 공식 배포처에서 내려받고 체크섬을 확인합니다. 빌드가 끝나면 터미널 마지막에 `Built:`와 `MCPlus.app` 경로가 표시됩니다.

### 앱을 직접 이동

빌드가 끝난 터미널에서 다음 명령을 실행합니다.

```sh
mkdir -p ~/Applications
open .build/products/development
open ~/Applications
```

Finder에 나타난 **MCPlus.app을 함께 열린 개인용 Applications 폴더로 옮긴 뒤, 옮긴 앱을 더블클릭해서 실행**합니다. 압축을 푼 소스 폴더 자체를 응용 프로그램 폴더로 옮기는 것은 아닙니다.

앱을 옮기는 이유는 다음 단계에서 실제 사용할 설치 경로의 앱에 권한을 부여하기 위해서입니다. 이후 다른 위치로 옮기거나 다시 빌드하면 권한을 다시 확인해야 할 수 있습니다.


설치 후에는 위의 손쉬운 사용 권한 설정을 진행하세요.

</details>

## 단축키

아래 창 제어·탐색 단축키는 **Mission Control이 감지된 동안** 처리됩니다.

| 조작 | 동작 |
|---|---|
| 선택한 썸네일 왼쪽 위 × | 창 닫기 요청 |
| 방향키 | 해당 방향의 창 선택 |
| Tab / Shift Tab | 다음 / 이전 창 선택 |
| ⌘W | 선택한 창 닫기 요청 |
| ⌥⌘W | 선택한 앱의 모든 창에 닫기 요청 |
| ⌘M | 선택한 창 최소화 |
| Return | 선택한 썸네일 열기 |
| ⌘Q | 선택한 앱에 정상 종료 요청; Finder는 제외 |
| ⌃⌘Q | 추가 기능: 선택한 앱 강제 종료 |
| ⌘H | 선택한 앱 숨기기 |
| ⌥⌘H | 선택한 앱을 제외한 다른 일반 앱 숨기기 |

**⌃⌘Q는 강제 종료이므로 저장하지 않은 내용이 사라질 수 있습니다.** 일반 닫기·정상 종료의 저장 확인과 취소는 대상 앱이 처리합니다. 문자 단축키는 QWERTY의 고정 키 위치 대신 이벤트의 문자와 보조키를 제외한 문자를 사용합니다. 실제 키보드 배열 전환에 대한 전체 검증은 남아 있습니다.

설정의 **단축키 및 시작 설정**을 펼치면 기능별 단축키, 로그인 시 시작, 메뉴 막대 아이콘 표시 여부를 변경할 수 있습니다. 현재 소스에는 자동 업데이트 서버가 설정돼 있지 않습니다.

## 설치 중 막혔나요?

| 증상 | 확인할 내용 |
|---|---|
| `Install.command`가 macOS에서 차단됨 | 위의 DMG를 받아 앱을 응용 프로그램 폴더로 드래그하세요. 소스 설치 도우미는 필요하지 않습니다. |
| DMG 앱에 “Apple이 확인할 수 없음” 또는 “손상됨” 경고가 나옴 | 실행을 멈추고 공식 릴리스의 DMG를 다시 받으세요. 계속되면 파일 이름과 경고 내용을 Issues에 남겨 주세요. |
| 개발 도구 설치 뒤 앱이 바로 설치되지 않음 | Apple 도구 설치가 끝난 뒤 `Install.command`를 한 번 더 열어 주세요. |
| 이미 설치 도우미가 실행 중이라고 나옴 | 먼저 실행한 설치가 끝날 때까지 기다리세요. 여러 설치 창을 동시에 열 필요는 없습니다. |
| MCPlus를 종료하라고 나옴 | 메뉴 막대에서 실행 중인 MCPlus를 종료한 뒤 설치 도우미를 다시 열어 주세요. |
| `cd: no such file or directory` | 폴더의 위치나 이름이 예시와 다릅니다. 수동 설치 안내처럼 `cd` 뒤에 Finder의 폴더를 끌어 넣으세요. |
| `./scripts/build.sh: no such file or directory` | 현재 위치가 소스 폴더인지 확인하세요. Finder에서 해당 폴더를 열었을 때 `scripts`가 보여야 합니다. |
| `permission denied`로 빌드 스크립트가 실행되지 않음 | 소스 폴더에서 `chmod +x scripts/*.sh`를 실행한 뒤 `./scripts/build.sh`를 다시 실행하세요. |
| `xcrun` 또는 `swiftc`를 찾을 수 없음 | 2단계의 개발 도구 설치를 완료하세요. Xcode를 설치했다면 한 번 실행해 초기 설정도 완료해 주세요. |
| Sparkle 다운로드 또는 체크섬 오류 | 빌드를 중단하고 인터넷 연결과 전체 오류 메시지를 확인하세요. 체크섬 검사를 제거하거나 건너뛰지 마세요. |
| 앱은 열리는데 창 제어가 안 됨 | 설치 4단계에서 실제 설치한 앱의 손쉬운 사용 권한을 확인하고 앱을 다시 실행하세요. 설정의 활성화 스위치도 켜져 있어야 합니다. |
| 다시 빌드하거나 앱을 옮긴 뒤 권한이 안 됨 | 손쉬운 사용 목록의 이전 MCPlus 항목을 제거한 뒤 현재 응용 프로그램 폴더의 앱을 다시 추가하고 재실행하세요. |
| 특정 창에 ×가 표시되지 않음 | 실제 창을 명확히 식별하지 못한 경우 조작하지 않습니다. macOS 변경, 창 종류, 애니메이션 중 배치도 영향을 줄 수 있습니다. |
| 설정 창을 닫은 뒤 앱이 안 보임 | 상단 메뉴 막대를 확인하세요. 메뉴 막대 아이콘도 숨겼다면 응용 프로그램 폴더에서 MCPlus를 다시 열어 설정으로 돌아갈 수 있습니다. |

해결되지 않으면 [Issues](https://github.com/TaeBeomShin/MCPlus/issues)에 **macOS 버전, Intel/Apple Silicon 여부, 실패한 단계, 오류 메시지**를 남겨 주세요. 진단 파일에는 열린 창 제목이 포함될 수 있으므로 공유 전에 내용을 확인하세요.

## 업데이트와 제거

[Releases](https://github.com/TaeBeomShin/MCPlus/releases)에서 새 DMG를 받습니다. 실행 중인 MCPlus를 종료하고 새 앱을 응용 프로그램 폴더로 드래그해 교체한 뒤 실행하세요. 자동 업데이트는 아직 설정되지 않았습니다.

제거할 때는 설정에서 **로그인 시 시작**을 끄고 MCPlus를 종료한 뒤, **응용 프로그램 폴더(`/Applications`)의 MCPlus.app을 휴지통으로 옮깁니다.** 시스템 설정의 손쉬운 사용 목록에서도 MCPlus를 제거할 수 있습니다.

기존 소스 설치 도우미를 사용했다면 `~/Applications/MCPlus.app`과 `~/Applications/MCPlus Backups/`에 이전 앱이 남아 있을 수 있습니다. 필요한 버전인지 확인한 뒤 별도로 정리하세요.

## 개발자용 안내

Swift, AppKit, SwiftUI로 구현했습니다. Swift 5.8 이상과 macOS SDK가 필요합니다. 빌드 스크립트는 기본적으로 현재 Mac의 아키텍처로 앱을 만들고 로컬 ad-hoc 서명을 적용합니다. 직접 배포용 서명·공증은 별도 작업입니다.

검사 실행:

```sh
./scripts/test.sh
```

arm64·x86_64 universal 빌드:

```sh
ARCHS='arm64 x86_64' ./scripts/build.sh
```

Xcode를 사용하려면 먼저 `./scripts/fetch-sparkle.sh`를 실행한 뒤 `MCPlus.xcodeproj`를 엽니다. 공유 scheme은 `MCPlus`입니다. 서명 설정은 `Config/Local.example.xcconfig`를 `Config/Local.xcconfig`로 복사한 뒤 본인 Team과 Bundle ID를 지정합니다. 이 로컬 파일은 git에서 제외됩니다. 셸 빌드의 Bundle ID는 `MCPLUS_BUNDLE_ID` 환경 변수로 지정합니다. 인증서·개인 키·계정 비밀번호는 저장소에 넣지 마세요.

`Package.swift`도 포함하지만 앱 번들 빌드의 검증된 진입점은 `scripts/build.sh`입니다. Sparkle 2.10.0은 고정 SHA-256으로 검증하며, 해당 프레임워크는 저장소에 포함하지 않습니다.

- [검사 및 전용 테스트 앱](docs/TESTING.md)
- [구현 구조](docs/ARCHITECTURE.md)
- [검증 상태와 남은 항목](docs/STATUS.md)
- [Mac App Store 기술 제약](docs/app-store-feasibility.md)

현재는 개발용 미리보기입니다. 물리 키보드·마우스 전체 경로, 다중 화면·Spaces·전체 화면, 로그인 시작과 실제 업데이트, 지원 OS·하드웨어 전체 검증이 완료되지 않았습니다. 비공개 시스템 동작과 선택적인 `_AXUIElementGetWindow` bridge에 의존하며, macOS 업데이트에 따라 조정이 필요할 수 있습니다. **앱스토어 제출·승인을 받은 배포판이 아닙니다.**

창 메타데이터는 로컬에서 읽으며, 진단 파일은 사용자가 저장을 선택할 때 생성합니다. 자동 전송하지 않습니다. 직접 배포용 Sparkle 업데이트는 배포자가 HTTPS 피드와 서명 공개 키를 설정하기 전까지 미설정 상태입니다.

## 라이선스와 참고 자료

소스는 [MIT 라이선스](LICENSE)로 공개합니다. 외부 구성 요소와 참고 자료의 고지는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에 있으며 Sparkle 라이선스도 보존합니다.

[Mission Control Plus](https://www.fadel.io/missioncontrolplus)의 공개 기능과 [REA](https://github.com/morluto/rea)를 통한 정적 조사를 참고해 독립적으로 구현했습니다. Mission Control 접근성 트리 조사에는 Hammerspoon의 spaces 모듈도 참고했습니다. 원본 상용 앱의 바이너리·이미지·라이선스 코드와 분석용 disassembly는 포함하지 않습니다. 원본 제품이나 참고 프로젝트와 제휴한 프로젝트는 아닙니다.
