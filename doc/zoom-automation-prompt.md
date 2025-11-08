# Zoom 자동 진입 개선 작업 프롬프트

## 🎯 작업 목표

sat-lec-rec Flutter Windows Desktop 앱에서 Zoom 회의 자동 진입을 완전 자동화합니다.
현재는 Zoom 링크만 열지만, 이름 입력, 참가 버튼 클릭, 대기실 통과, 호스트 대기 등 중간 단계를 모두 자동화해야 합니다.

## 📊 현재 상태

### 2025-11-08 진행 상황
- ✅ Phase 1 (네이티브 기반 구축): `windows/runner/zoom_automation.{h,cpp}` 추가, UIAutomation + FFI 연결 완료
- ✅ Phase 2 (기본 자동화): `ZoomLauncherService.autoJoinZoomMeeting()`에서 이름 입력·참가 버튼 클릭까지 자동화
- ✅ Phase 3 (대기실·호스트 감시): `waitForWaitingRoomClear()`와 `waitForHostToStart()`가 구현되어 스케줄 실행 전에 재시도 정책을 적용
- ✅ Phase 4-A (알림 시스템): TrayService + WinToast로 자동 참가·대기실·호스트·녹화 상태를 Windows 토스트로 안내
- ✅ Phase 4-B (앱 내 상태 배너): 메인 화면 상단에 Zoom 자동화 상태 배너 추가 (실패 시 재시도 버튼 포함)
- ✅ Phase 4-C (오디오/비디오 자동화): 네이티브 레이어 함수 추가 완료
  - `ZoomAutomation_JoinWithAudio()`: 컴퓨터 오디오로 참가 버튼 자동 클릭
  - `ZoomAutomation_SetVideoEnabled(enable)`: 비디오 켜기/끄기
  - `ZoomAutomation_SetMuted(mute)`: 마이크 음소거/해제
  - FFI 바인딩 및 Dart 서비스 연동 완료
- ✅ Phase 5 (테스트 화면): `ZoomTestScreen` 구현
  - 단계별 테스트 버튼 (Zoom 실행, 참가, 오디오, 비디오, 음소거, 종료)
  - 실시간 결과 표시 및 자동화 상태 모니터링
  - PMI 사용법 안내 및 도움말 다이얼로그
- ✅ Phase 6 (Zoom API 통합): Server-to-Server OAuth 기반 자동 테스트 회의 생성/삭제
  - `ZoomApiConfig` 모델: Account ID, Client ID, Client Secret 저장
  - `ZoomApiService`: OAuth 토큰 관리, 회의 생성/삭제, 사용자 정보 조회
  - `AppSettings` 확장: Zoom API 설정 필드 추가
  - 설정 UI: Zoom API 설정 카드 및 도움말
  - 테스트 화면: 자동 회의 생성/삭제 버튼
  - 문서: ZOOM-TEST-GUIDE.md에 Zoom API 섹션 추가
- ✅ WinToast CLSID를 프로젝트 전용 GUID로 교체 (`B7C3D4E5-1A2B-4C5D-8E9F-0A1B2C3D4E5F`)
- ⚠️ 남은 작업: 스케줄 카드별 상세 상태 배너, 오류 가이드 모달, flutter analyze 경고 정리

## ✨ 최근 작업 요약 (2025-11-08)

### Phase 4-C: 오디오/비디오 자동화
1. **네이티브 함수 구현** (`windows/runner/zoom_automation.{h,cpp}`)
   - `ZoomAutomation_JoinWithAudio()`: "Join with Computer Audio" 버튼 자동 클릭
   - `ZoomAutomation_SetVideoEnabled(BOOL enable)`: 비디오 활성화/비활성화
   - `ZoomAutomation_SetMuted(BOOL mute)`: 마이크 음소거/해제
   - UI Automation API를 사용하여 Zoom 창 컨트롤 자동 조작

2. **FFI 바인딩** (`lib/ffi/zoom_automation_bindings.dart`)
   - `NativeBoolParamBool` / `DartBoolParamBool` 타입 정의
   - 네이티브 BOOL(1/0) ↔ Dart bool 변환

3. **ZoomLauncherService 확장**
   - `joinWithAudio()`, `setVideoEnabled()`, `setMuted()` 메서드 추가
   - 토스트 알림 및 DartDoc 주석 완비

### Phase 5: 테스트 화면
4. **ZoomTestScreen 구현** (`lib/ui/screens/zoom_test_screen.dart`)
   - 단계별 테스트 버튼 (Zoom 실행, 참가, 오디오, 비디오, 음소거, 종료)
   - 실시간 결과 표시 및 자동화 상태 모니터링
   - PMI 사용법 안내 및 도움말 다이얼로그

5. **문서: ZOOM-TEST-GUIDE.md**
   - PMI 사용 가이드
   - 단계별 테스트 시나리오 (빠른 확인, 전체 플로우, 에러 처리)
   - 문제 해결 섹션

### Phase 6: Zoom API 통합 ⭐ NEW!
6. **ZoomApiConfig 모델** (`lib/models/zoom_api_config.dart`)
   - Account ID, Client ID, Client Secret 저장
   - JSON 직렬화/역직렬화 지원

7. **ZoomApiService** (`lib/services/zoom_api_service.dart`)
   - **Server-to-Server OAuth 인증**: Basic Auth + Base64
   - **Access Token 캐싱**: 만료 1분 전까지 재사용
   - `createTestMeeting()`: Instant Meeting 생성 (type: 1, 대기실 비활성화)
   - `deleteMeeting()`: 테스트 회의 삭제
   - `getUserInfo()`: API 인증 확인

8. **AppSettings 확장**
   - Zoom API 설정 필드 추가 (zoomApiAccountId, zoomApiClientId, zoomApiClientSecret)
   - `toZoomApiConfig()` 헬퍼 메서드

9. **설정 UI** (`lib/ui/screens/settings_screen.dart`)
   - Zoom API 설정 카드 추가
   - Client Secret 보안 입력 (obscureText)
   - Server-to-Server OAuth 앱 생성 도움말 다이얼로그

10. **테스트 화면 통합**
    - "🤖 자동 테스트 회의" 섹션 추가
    - 테스트 회의 생성/삭제 버튼
    - API 미설정 시 안내 메시지
    - 생성된 회의 링크 자동 입력

11. **문서 업데이트**
    - ZOOM-TEST-GUIDE.md에 "🤖 NEW! 가장 안전한 방법: Zoom API 자동 회의 생성" 섹션 추가
    - Server-to-Server OAuth 앱 생성 단계별 가이드
    - API 오류 문제 해결 가이드

12. **기술 스택 추가**
    - `http: ^1.2.0`: HTTP 클라이언트
    - `dart_jsonwebtoken: ^2.14.0`: JWT 라이브러리 (향후 확장 대비)

**핵심 장점**:
- 실제 예약 강의를 건드리지 않고 안전하게 테스트
- 버튼 한 번으로 회의 생성/삭제
- PMI보다 깔끔하고 무제한 생성 가능

## ⚠️ 남은 과제
- 대기실/호스트 대기 단계에 대한 사용자 맞춤 가이드(예: 도움말 모달, 단계별 설명)
- 스케줄 카드별 상태 표시 (각 예약에 대해 개별 배너 또는 타임라인 적용)
- 오디오/비디오 자동화 실제 적용 (자동 참가 플로우에 통합)
- flutter analyze 경고(Use BuildContext synchronously, withOpacity 등) 해소
- 실제 Zoom 회의 환경에서 오디오/비디오 자동화 테스트

## 🛠️ 기술 스택/환경
- Flutter 3.35.6 + Dart 3.9.2 (Windows Desktop)
- C++17 + Windows UI Automation API (Win32)
- WinToast 플러그인 (DesktopNotificationManagerCompat 기반)
- 트레이 관리: `system_tray`, `window_manager`

## ✅ 성공 기준
- Zoom 자동 참가 전 과정(실행→이름 입력→대기실/호스트 대기→녹화 시작)에 대해 토스트/배너가 일관된 상태를 표시
- 실패 시 사용자 재시도 또는 수동 개입을 유도하는 UI 제공
- WinToast C4819 경고 없이 Windows 빌드/실행 가능

---

# 다음 작업을 위한 프롬프트

```
프로젝트 경로: w:\home\usereyebottle\projects\sat-lec-rec

현재 상태 요약:
1. Zoom 자동화 네이티브 레이어(zoom_automation.{h,cpp})와 Dart FFI 바인딩(lib/ffi/zoom_automation_bindings.dart) 구현 완료.
2. ZoomLauncherService가 자동 실행 → 이름 입력 → 대기실 → 호스트 대기를 처리하며, ValueNotifier로 상태를 방송하고 WinToast + UI 배너로 알림을 전송.
3. ScheduleService는 녹화 시작 시 토스트/상태 업데이트를 수행하며, 실패 시 markAutomationFailure로 UI/토스트가 빨간 경고를 띄움.
4. 메인 화면 상단에 자동화 상태 배너가 추가되어 현재 단계/메시지/재시도 버튼을 제공.
5. win_toast 플러그인의 Windows 소스는 UTF-8 ASCII로 패치되어 C4819 경고를 피함(WSL 및 Windows 캐시에 모두 적용 완료).

남은 작업(우선순위 순):
- Zoom 자동화: 오디오/비디오 설정 자동화 및 UI 힌트(Phase 4-C)
- 스케줄 카드별 상태/로그 UI 추가 (예약 히스토리, 문제 가이드)
- flutter analyze 경고 정리(BuildContext async gap, withOpacity, 미사용 import 등)
- WinToast CLSID/아이콘을 실제 앱 GUID/아이콘으로 교체하여 배포 대비

빌드/테스트 참고:
- WSL→Windows 동기화: ./scripts/sync_wsl_to_windows.sh
- Windows 실행: PowerShell → cd C:\ws-workspace\sat-lec-rec → flutter run -d windows
- WinToast 소스 경로:
  - WSL: /home/usereyebottle/.pub-cache/hosted/pub.dev/win_toast-0.4.0/windows
  - Windows: C:\Users\user\AppData\Local\Pub\Cache\hosted\pub.dev\win_toast-0.4.0\windows
```
