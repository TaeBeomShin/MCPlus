import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var controller: MissionController
    @ObservedObject var preferences: Preferences
    @ObservedObject var login: LoginItemController
    @ObservedObject var updates: UpdateController
    @State private var showAdvanced=false
    private let accent = Color(red: 0.65, green: 0.51, blue: 1)

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "rectangle.3.group.fill").font(.system(size: 27)).foregroundColor(accent)
                    .frame(width: 52, height: 52).background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 4) {
                    Text("MCPlus").font(.system(size: 25, weight: .bold, design: .rounded))
                    Text("Mission Control에서, 한 번에.").font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Toggle("활성화", isOn: $preferences.enabled).toggleStyle(.switch).tint(accent).fixedSize()
            }

            preview

            HStack(spacing: 10) {
                Image(systemName: controller.trusted ? "checkmark.shield.fill" : "hand.raised.fill")
                    .foregroundColor(controller.trusted ? .green : .orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(controller.trusted ? "손쉬운 사용 연결됨" : "먼저 손쉬운 사용 권한을 켜 주세요").font(.system(size: 12, weight: .semibold))
                    Text(controller.trusted ? (controller.keyboardReady ? controller.status : "키보드 연결 대기 · 앱을 다시 실행하거나 입력 모니터링을 확인해 주세요.") : "시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용 → MCPlus")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
                Button(controller.trusted ? "설정 열기" : "권한 설정") { controller.requestAccessibility() }
                    .controlSize(.small)
            }
            .padding(13).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 0) {
                option("xmark.circle", "창 위에 닫기 버튼 표시", detail: "마우스를 올리거나 선택한 썸네일에 표시", value: $preferences.closeButtons)
                Divider().padding(.leading, 42)
                option("command", "창 제어 단축키", detail: "선택한 창에 닫기, 최소화, 앱 종료 적용", value: $preferences.shortcuts)
                Divider().padding(.leading, 42)
                option("arrow.up.left.and.arrow.down.right", "키보드로 창 탐색", detail: "방향키 · Tab · Shift Tab", value: $preferences.navigation)
            }.padding(.horizontal, 14).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))

            DisclosureGroup("단축키 및 시작 설정", isExpanded:$showAdvanced) {
                VStack(spacing:10) {
                    Group {
                    ForEach(WindowAction.allCases) { action in
                        Toggle(isOn:Binding(get:{ preferences.isEnabled(action) },set:{ preferences.setEnabled(action,$0) })) {
                            HStack { Text(action.title); Spacer(); Text(action.shortcut).foregroundColor(.secondary) }
                        }.toggleStyle(.checkbox)
                    }
                    Text("⌘Q는 앱에 정상 종료를 요청합니다. 추가 기능인 ⌃⌘Q는 강제 종료하며, 저장하지 않은 내용이 사라질 수 있습니다.")
                        .font(.caption2).foregroundColor(.orange).fixedSize(horizontal:false,vertical:true)
                    }
                    Divider()
                    Group {
                    Toggle("로그인 시 시작",isOn:Binding(get:{login.enabled},set:{login.setEnabled($0)})).toggleStyle(.checkbox)
                    if !login.message.isEmpty { Text(login.message).font(.caption2).foregroundColor(.orange) }
                    if login.requiresApproval { Button("로그인 항목 설정 열기") { login.openSettings() } }
                    Toggle("메뉴 막대 아이콘 숨기기",isOn:$preferences.hideMenuBar).toggleStyle(.checkbox)
                    if preferences.hideMenuBar {
                        Text("MCPlus 앱을 다시 열면 이 설정 화면을 열 수 있습니다.").font(.caption2).foregroundColor(.secondary)
                        Button("메뉴 막대 아이콘 다시 표시") { preferences.hideMenuBar=false }
                    }
                    }
                    Divider()
                    Group {
                    HStack {
                        Button("업데이트 확인…") { updates.check() }
                        Toggle("자동 확인",isOn:Binding(get:{updates.automaticChecks},set:{updates.automaticChecks=$0})).disabled(!updates.configured)
                    }
                    if !updates.message.isEmpty { Text(updates.message).font(.caption2).foregroundColor(.secondary) }
                    }
                }.font(.system(size:11)).padding(.top,10)
            }.font(.system(size:11)).foregroundColor(.secondary)
            HStack { Text("MCPlus \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "")").foregroundColor(.secondary); Spacer(); Button("진단 저장…") { controller.saveDiagnostics() }.buttonStyle(.link) }.font(.system(size:10))
            if !controller.lastAction.isEmpty {
                Text(controller.lastAction).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2)
            }
        }
        .padding(26).frame(width: 610)
        }.frame(width:610,height:690)
        .background(Color(red: 0.075, green: 0.08, blue: 0.105))
        .preferredColorScheme(.dark)
    }

    private func option(_ icon: String, _ title: String, detail: String, value: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(accent).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 10)).foregroundColor(.secondary)
            }
            Spacer()
            Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).tint(accent).controlSize(.small)
        }.padding(.vertical, 12)
    }

    private var preview: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                mockWindow("메모", symbol: "note.text", color: .yellow, selected: false)
                mockWindow("Safari", symbol: "safari", color: accent, selected: true)
                mockWindow("Finder", symbol: "folder", color: .blue, selected: false)
            }
            HStack(spacing: 18) {
                key("⌘ W", "닫기"); key("⌘ M", "최소화"); key("↵", "열기"); key("⌘ Q", "정상 종료")
            }
            Text("Mission Control을 열고 창을 선택하세요").font(.system(size: 10)).foregroundColor(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [accent.opacity(0.1), Color.white.opacity(0.015)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("사용 예시. Mission Control에서 창을 선택하고 단축키로 제어합니다.")
    }

    private func mockWindow(_ title: String, symbol: String, color: Color, selected: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in Circle().fill(Color.white.opacity(0.17)).frame(width: 4, height: 4) }
                Spacer()
            }.padding(8).background(Color.white.opacity(0.035))
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundColor(color).font(.system(size: 20))
                Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.8))
            }.frame(height: 54).frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.13, green: 0.14, blue: 0.18), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? accent : .white.opacity(0.1), lineWidth: selected ? 2 : 1))
        .overlay(alignment: .topLeading) {
            if selected {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).frame(width: 18, height: 18)
                    .background(Color(red: 0.2, green: 0.2, blue: 0.25), in: Circle()).overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1)).offset(x: -7, y: -7)
            }
        }
    }

    private func key(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(key).font(.system(size: 10, weight: .medium, design: .monospaced)).padding(.horizontal, 6).padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
        }
    }
}
