#!/bin/zsh
# Build this source locally, then install into the current user's Applications.
set -euo pipefail
cd "${0:A:h:h}"
SOURCE_ROOT="$PWD"
INSTALL_ROOT="${MCPLUS_INSTALL_ROOT:-$HOME/Applications}"
DESTINATION="$INSTALL_ROOT/MCPlus.app"
BUILD_APP="$SOURCE_ROOT/.build/products/development/MCPlus.app"
INSTALL_LOG="$SOURCE_ROOT/.build/install.log"
STAGING=""
BACKUP=""
LOCK_OWNED=false
LOCK_DIR="$INSTALL_ROOT/.mcplus-install.lock"
LAUNCH_APP=true
if [[ "${1:-}" == --no-launch ]]; then
  LAUNCH_APP=false
elif (( $# > 0 )); then
  print -u2 "사용법: scripts/install.sh [--no-launch]"
  exit 2
fi
cleanup() {
  # Restore the previous app if a replacement failed after moving it aside.
  if [[ -n "$BACKUP" && -d "$BACKUP" && ! -e "$DESTINATION" ]]; then
    /bin/mv "$BACKUP" "$DESTINATION" || print -u2 "이전 앱 복원 필요: $BACKUP"
  fi
  if [[ -n "$STAGING" && -d "$STAGING" ]]; then /bin/rm -rf "$STAGING"; fi
  if [[ "$LOCK_OWNED" == true && -f "$LOCK_DIR/pid" && "$(<"$LOCK_DIR/pid")" == "$$" ]]; then
    /bin/rm "$LOCK_DIR/pid"
    /bin/rmdir "$LOCK_DIR" || true
  fi
}
trap cleanup EXIT
fail() { print -u2 "\n설치를 완료하지 못했습니다: $1"; exit 1; }

print "MCPlus 설치 도우미"
print "설치 위치: $DESTINATION"
print ""
OS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[[ "$OS_MAJOR" == <-> && "$OS_MAJOR" -ge 13 ]] || fail "macOS 13 이상이 필요합니다."
if ! xcrun --find swiftc >/dev/null 2>&1 || ! xcrun --show-sdk-path >/dev/null 2>&1; then
  print "Apple 개발 도구가 필요해 설치 창을 요청합니다."
  print "설치 창의 안내를 따라 완료한 뒤 Install.command를 다시 열어 주세요."
  xcode-select --install || true
  exit 1
fi
if pgrep -x MCPlus >/dev/null 2>&1; then
  fail "실행 중인 MCPlus를 메뉴 막대에서 종료한 뒤 다시 설치해 주세요. 앱을 강제 종료하지는 않습니다."
fi
[[ ! -L "$INSTALL_ROOT" && ! -L "$DESTINATION" ]] || fail "설치 위치가 심볼릭 링크입니다. 일반 폴더를 사용해 주세요."
mkdir -p "$INSTALL_ROOT" || fail "설치 폴더를 만들 수 없습니다: $INSTALL_ROOT"
[[ -d "$INSTALL_ROOT" && -w "$INSTALL_ROOT" ]] || fail "이 폴더에 쓸 수 없습니다: $INSTALL_ROOT"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  LOCK_PID="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
  if [[ "$LOCK_PID" == <-> ]] && ! kill -0 "$LOCK_PID" 2>/dev/null; then
    # Remove only our known stale marker and an empty lock directory.
    /bin/rm "$LOCK_DIR/pid" || fail "이전 설치의 잠금 파일을 정리하지 못했습니다."
    /bin/rmdir "$LOCK_DIR" || fail "설치 잠금 폴더에 예상하지 못한 파일이 있습니다."
    mkdir "$LOCK_DIR" 2>/dev/null || fail "다른 설치 도우미가 실행됐습니다."
  else
    fail "다른 설치 도우미가 실행 중입니다. 먼저 열린 설치 창이 끝난 뒤 다시 시도해 주세요."
  fi
fi
LOCK_OWNED=true
print "$$" > "$LOCK_DIR/pid"
if [[ -e "$DESTINATION" ]]; then
  [[ -d "$DESTINATION" ]] || fail "같은 이름의 파일이 있습니다: $DESTINATION"
  EXPECTED_ID="${MCPLUS_BUNDLE_ID:-local.mcplus.app}"
  EXISTING_ID="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
  [[ "$EXISTING_ID" == "$EXPECTED_ID" ]] || fail "같은 위치의 앱이 다른 Bundle ID를 사용합니다. 기존 앱은 변경하지 않았습니다."
fi

print "[1/3] 소스에서 앱 만들기 · 첫 실행에는 추가 파일을 내려받습니다…"
mkdir -p "$SOURCE_ROOT/.build"
if ! CHANNEL=development BUILD_ROOT="$SOURCE_ROOT/.build/products" CODE_SIGN_IDENTITY=- /bin/zsh scripts/build.sh >"$INSTALL_LOG" 2>&1; then
  tail -n 15 "$INSTALL_LOG" >&2
  fail "빌드 오류입니다. 전체 기록: $INSTALL_LOG"
fi
/usr/bin/codesign --verify --deep --strict "$BUILD_APP" || fail "빌드한 앱의 서명을 확인하지 못했습니다."

print "[2/3] 개인용 응용 프로그램 폴더에 설치하기…"
STAGING="$(mktemp -d "$INSTALL_ROOT/.mcplus-install.XXXXXX")"
/usr/bin/ditto "$BUILD_APP" "$STAGING/MCPlus.app" || fail "앱을 복사하지 못했습니다."
/usr/bin/codesign --verify --deep --strict "$STAGING/MCPlus.app" || fail "복사한 앱의 서명을 확인하지 못했습니다."
# Recheck before moving anything: another installer or app may have started.
if pgrep -x MCPlus >/dev/null 2>&1; then fail "MCPlus가 실행됐습니다. 종료한 뒤 다시 설치해 주세요."; fi
[[ ! -L "$DESTINATION" ]] || fail "설치 위치가 변경되어 중단했습니다."
if [[ -e "$DESTINATION" ]]; then
  CURRENT_ID="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
  BUILT_ID="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$BUILD_APP/Contents/Info.plist")"
  [[ "$CURRENT_ID" == "$BUILT_ID" ]] || fail "기존 앱이 변경되어 중단했습니다."
  BACKUP_DIR="$INSTALL_ROOT/MCPlus Backups/$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$BACKUP_DIR" || fail "이전 앱을 보관할 폴더를 만들지 못했습니다."
  BACKUP="$BACKUP_DIR/MCPlus.app"
  /bin/mv "$DESTINATION" "$BACKUP" || fail "이전 앱을 보관하지 못했습니다."
fi
/bin/mv "$STAGING/MCPlus.app" "$DESTINATION" || fail "앱을 설치 위치로 옮기지 못했습니다."

print "[3/3] 설치 완료"
print "앱 위치: $DESTINATION"
if [[ -n "$BACKUP" ]]; then print "이전 버전 보관: $BACKUP"; fi
print ""
print "앱 설정의 '권한 설정'을 눌러 손쉬운 사용 목록에서 MCPlus를 켜 주세요."
print "권한 변경 뒤에는 MCPlus를 종료하고 다시 실행해 주세요."
print "창을 닫아도 화면 상단 메뉴 막대에 남습니다."
if [[ "$LAUNCH_APP" == true ]]; then
  open "$DESTINATION" || print "자동으로 열지 못했습니다. Finder에서 위 경로의 MCPlus.app을 열어 주세요."
fi
