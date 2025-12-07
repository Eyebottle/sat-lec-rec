# Zoom 암호 입력창 반복 문제 진단 보고서

**작성일**: 2025-01-17
**최종 업데이트**: 2025-12-07 (코드 수정 완료, 테스트 대기)
**상태**: ✅ **코드 수정 완료** - Windows 테스트 필요
**우선순위**: ⭐⭐⭐ 긴급

---

## 🎯 핵심 요약 (TL;DR)

### 문제
- 암호 포함 Zoom 링크를 앱에서 자동 실행하면 **암호 입력창 반복 출현**
- 사용자 직접 클릭은 암호 입력 없이 정상 작동 ✅

### 원인
- **회귀 버그**: 과거(커밋 `31620dd`)에 이미 해결했던 문제가 재발
- `zoommtg://` 프로토콜에 `pwd` 파라미터를 포함하면:
  1. CMD가 `&`를 명령 구분자로 해석하여 파싱 오류
  2. Zoom 클라이언트가 쿼리 파라미터를 무시함

### 해결책
- **zoommtg:// 프로토콜 사용 중단**
- 항상 HTTP URL을 브라우저로 실행 (사용자 직접 클릭과 동일)
- 코드 수정: `lib/services/zoom_launcher_service.dart` 169-198줄 제거

### 다음 단계
1. **옵션 A (추천)**: AI가 자동 수정 → 바로 아래 "9단계" 참조
2. **옵션 B**: 수동 수정 → 상세 가이드 아래 참조
3. **옵션 C**: 로그 수집 후 테스트 → 확실한 확인 원하는 경우

---

## 📋 상세 문제 요약

### 증상
- **사용자가 직접 클릭**: 암호가 포함된 Zoom 링크를 클릭하면 암호 입력 없이 바로 회의 참가됨 ✅
- **앱에서 자동 실행**: 동일한 링크를 앱에서 실행하면 암호 입력창이 **반복해서** 나타남 ❌

### 영향
- Zoom 자동 참가 기능이 작동하지 않음
- 사용자가 수동으로 암호를 입력해야 함 (자동화 실패)
- 녹화 스케줄이 정상 작동하지 않을 수 있음

---

## 🔍 1단계: 현재 코드 분석

### Zoom 링크 실행 로직 (`lib/services/zoom_launcher_service.dart:169-248`)

현재 코드는 **2단계 폴백 방식**을 사용:

```dart
// 1단계: zoommtg:// 프로토콜로 직접 실행 시도
if (uri.scheme.startsWith('http')) {
  zoomMtgUri = Uri(
    scheme: 'zoommtg',
    host: uri.host,
    pathSegments: uri.pathSegments,
    queryParameters: uri.queryParameters,  // ⚠️ pwd 포함
  );
}

await Process.start('cmd', ['/c', 'start', '', zoomMtgLink]);

// 2단계: 실패 시 rundll32로 브라우저 실행
await Process.start('rundll32', ['url.dll,FileProtocolHandler', zoomLink]);
```

### 핵심 차이점

| 방식 | URL 형식 | 암호 처리 | 브라우저 경유 |
|------|----------|-----------|--------------|
| **사용자 직접 클릭** | `https://zoom.us/j/123?pwd=abc` | ✅ 자동 처리 | ✅ 예 |
| **앱: zoommtg://** | `zoommtg://zoom.us/j/123?pwd=abc` | ❌ 실패 | ❌ 아니오 |
| **앱: rundll32 폴백** | `https://zoom.us/j/123?pwd=abc` | ✅ 자동 처리 | ✅ 예 |

---

## 🎯 2단계: 문제 원인 가설

### 가설 A: zoommtg:// 프로토콜이 pwd 파라미터를 무시함 ⭐ (가능성 높음)

**증거**:
- Git 커밋 히스토리: `31620dd - fix: zoommtg:// URL에서 pwd 파라미터 제거`
- 이전에도 같은 문제로 pwd를 제거했던 기록이 있음
- 하지만 현재 코드는 다시 pwd를 포함하고 있음 (177줄)

**테스트 방법**:
```powershell
# Windows 명령 프롬프트에서 직접 실행
start zoommtg://zoom.us/j/1234567890?pwd=abc123
→ 암호 입력창이 나타나는지 확인

start https://zoom.us/j/1234567890?pwd=abc123
→ 암호 입력 없이 참가되는지 확인
```

### 가설 B: zoommtg:// 실행이 성공했지만 실제로는 암호가 전달 안 됨

**증거**:
- 코드 193줄: `directZoomLaunchSucceeded = true`
- 성공 판정을 너무 일찍 함 (프로세스 시작만으로 판단)
- 실제로는 브라우저 폴백으로 가야 하는데 건너뜀

**테스트 방법**:
```dart
// 로그를 확인하여 어느 경로로 실행되었는지 파악
// "🎯 zoommtg 프로토콜로 직접 실행" vs "🌐 브라우저를 통해 실행"
```

### 가설 C: 브라우저 다이얼로그 클릭 실패로 Zoom 앱이 제대로 실행 안 됨

**증거**:
- 코드 231-232줄: "브라우저 다이얼로그를 찾지 못함" 경고만 로그
- 실패해도 계속 진행함 (치명적 오류로 처리 안 함)

---

## 📊 3단계: 로그 분석 필요

### 확인해야 할 로그 항목

```
[ ] "🎯 zoommtg 프로토콜로 직접 실행 시도" 로그가 나타나는가?
[ ] "✅ Zoom 앱 직접 실행 완료" 로그가 나타나는가?
[ ] "🌐 브라우저를 통해 Zoom 링크 실행" 로그가 나타나는가?
[ ] "✅ 브라우저 다이얼로그 클릭 성공" 로그가 나타나는가?
[ ] "🔑 회의 암호 입력 시도 중" 로그가 나타나는가?
```

### 로그 파일 위치 (예상)

- Windows 빌드: `C:\ws-workspace\sat-lec-rec\logs\sat_lec_rec_YYYYMMDD.log`
- 또는 콘솔 출력: Flutter 실행 시 터미널

---

## 💡 4단계: 해결 방안 제안

> **⚠️ 업데이트 (과거 커밋 분석 후)**:
> 과거에 이미 pwd 제거 방식을 사용했으나, 현재 코드가 되돌려져 회귀 버그 발생.
> **최선의 방안**: zoommtg:// 완전히 제거하고 항상 브라우저 사용 (방안 1A)

---

### 방안 1A: zoommtg:// 완전히 제거, 항상 브라우저 사용 ⭐⭐⭐ (최우선 추천)

**장점**:
- 사용자 직접 클릭과 동일한 방식으로 실행
- 암호가 확실하게 전달됨
- 브라우저가 Zoom 앱을 자동으로 실행해줌

**단점**:
- 브라우저 다이얼로그가 나타날 수 있음 (하지만 자동 클릭 로직 있음)

**구현 방법**:

1. `lib/services/zoom_launcher_service.dart`의 **169-198줄 제거** (zoommtg:// 시도 부분)
2. 200번 줄부터 시작하도록 수정

**수정 전 (169-250줄):**
```dart
// 3. zoommtg:// 프로토콜 우선 실행
Uri? zoomMtgUri;
if (uri.scheme.startsWith('http')) {
  zoomMtgUri = Uri(
    scheme: 'zoommtg',
    host: uri.host,
    pathSegments: uri.pathSegments,
    queryParameters: uri.queryParameters,  // ⚠️ 문제의 원인!
  );
}

bool directZoomLaunchSucceeded = false;
if (zoomMtgUri != null) {
  // ... zoommtg:// 실행 시도
  directZoomLaunchSucceeded = true;
}

if (!directZoomLaunchSucceeded) {  // 실패 시에만 브라우저 사용
  // HTTP(S) 링크를 브라우저로 열기
  // ...
}
```

**수정 후 (간소화):**
```dart
// 3. HTTP(S) 링크를 브라우저로 직접 열기 (암호 자동 전달 보장)
// zoommtg:// 프로토콜은 pwd 파라미터를 제대로 처리하지 못하므로 사용 안 함
_logger.i('🌐 브라우저를 통해 Zoom 링크 실행 (암호 자동 전달)');
_logger.i('📞 회의 URL: $zoomLink');

try {
  // HTTP(S) URL을 브라우저로 열기
  final process = await Process.start(
    'rundll32',
    ['url.dll,FileProtocolHandler', zoomLink],
    runInShell: false,
  );

  _logger.i('✅ Zoom 링크 실행 완료: pid=${process.pid}');
  _logger.i('💡 브라우저가 Zoom 앱을 자동으로 실행하며 암호를 전달합니다');

  // 브라우저 다이얼로그 자동 클릭 시도 (최대 5초)
  _logger.i('🖱️ 브라우저 다이얼로그 자동 클릭 시도 중...');
  bool dialogClicked = false;
  for (int i = 0; i < 10; i++) {
    await Future.delayed(const Duration(milliseconds: 500));
    if (ZoomAutomationBindings.initializeUIAutomation() != 0) {
      if (automationBool(ZoomAutomationBindings.clickBrowserDialog())) {
        _logger.i('✅ 브라우저 다이얼로그 클릭 성공 (${i + 1}회 시도)');
        dialogClicked = true;
        break;
      }
    }
  }
  if (!dialogClicked) {
    _logger.d('ℹ️ 브라우저 다이얼로그를 찾지 못함 (수동 클릭 필요할 수 있음)');
  }
} catch (e) {
  // rundll32 실패 시 폴백: CMD start 사용
  _logger.w('⚠️ rundll32 실패, CMD 폴백 시도: $e');
  try {
    final process = await Process.start(
      'cmd',
      ['/c', 'start', '', zoomLink],
      runInShell: false,
    );
    _logger.i('✅ Zoom 링크 실행 완료 (CMD 폴백): pid=${process.pid}');
  } catch (e2) {
    _logger.e('❌ Zoom 링크 실행 실패: $e2');
    rethrow;
  }
}
```

**변경 요약**:
- ❌ 삭제: zoommtg:// 프로토콜 변환 로직 (169-198줄)
- ✅ 유지: rundll32 브라우저 실행 로직 (200-248줄)
- 📝 추가: 주석으로 이유 명시

### 방안 2: zoommtg:// URL에서 pwd 제거하고 UI Automation으로 입력

**장점**:
- 브라우저 경유 없이 Zoom 앱 직접 실행
- 암호는 별도로 UI Automation으로 입력

**단점**:
- UI Automation이 불안정할 수 있음
- 추가 대기 시간 필요

**구현**:
```dart
if (uri.scheme.startsWith('http')) {
  zoomMtgUri = Uri(
    scheme: 'zoommtg',
    host: uri.host,
    pathSegments: uri.pathSegments,
    // queryParameters 제거 (pwd 포함 안 함)
  );
}
```

### 방안 3: 조건부 로직 추가 (pwd 파라미터 유무에 따라 분기)

**장점**:
- 암호가 있는 경우와 없는 경우 모두 처리
- 유연성 증가

**단점**:
- 코드 복잡도 증가
- 디버깅 어려움

---

## 🧪 5단계: 테스트 계획

### 테스트 케이스

#### TC-1: 암호 포함 링크 (현재 문제 상황)
```
입력: https://zoom.us/j/1234567890?pwd=abc123def456
예상: 암호 입력 없이 자동 참가
```

#### TC-2: 암호 없는 링크
```
입력: https://zoom.us/j/1234567890
예상: 암호 입력창 나타남 → UI Automation으로 입력
```

#### TC-3: PMI 링크
```
입력: https://zoom.us/j/1234567890
예상: 대기실 또는 바로 참가
```

### 테스트 환경

- Windows 11 (사용자 환경)
- Zoom 클라이언트 최신 버전
- 실제 Zoom 계정 (테스트용 회의 생성)

---

## 📝 6단계: 실행 로그 수집 (작업 대기)

### 로그 수집 명령어

```powershell
# Windows에서 실행
cd C:\ws-workspace\sat-lec-rec
flutter run -d windows > zoom_test_log.txt 2>&1
```

### 수집할 정보

1. **Zoom 링크 실행 경로**
   - zoommtg:// 실행 여부
   - 브라우저 폴백 실행 여부

2. **브라우저 다이얼로그**
   - 다이얼로그 감지 여부
   - 자동 클릭 성공/실패

3. **암호 입력 시도**
   - UI Automation 초기화 성공/실패
   - 암호 필드 감지 여부
   - 암호 입력 성공/실패

4. **최종 결과**
   - 회의 참가 성공/실패
   - 대기실 도달 여부
   - 호스트 시작 대기 여부

---

## 🎯 7단계: 다음 행동 계획

### 즉시 실행 (우선순위 1)

- [x] 진단 문서 생성
- [ ] 현재 Zoom 링크로 수동 테스트 (브라우저에서 직접 클릭)
- [ ] 앱에서 동일 링크 실행 후 로그 수집
- [ ] 로그를 분석하여 실행 경로 확인

### 단기 실행 (우선순위 2)

- [ ] 방안 1 구현: zoommtg:// 제거, 항상 브라우저 사용
- [ ] 테스트 실행 (TC-1, TC-2, TC-3)
- [ ] 결과 기록 및 문서 업데이트

### 중기 실행 (우선순위 3)

- [ ] 안정성 개선: 재시도 로직 강화
- [ ] 오류 처리: 사용자에게 명확한 가이드 제공
- [ ] 문서화: ZOOM-TEST-GUIDE.md 업데이트

---

## 🔗 참고 자료

### 관련 파일
- `lib/services/zoom_launcher_service.dart` (803줄)
- `windows/runner/zoom_automation.cpp` (711줄)
- `ZOOM-TEST-GUIDE.md`

### 관련 커밋
```bash
31620dd - fix: zoommtg:// URL에서 pwd 파라미터 제거
57873d2 - fix: Zoom.exe 직접 실행으로 암호 자동 전달 문제 해결
b1bc02a - fix: HTTP URL을 브라우저로 열어 Zoom 암호 자동 전달 보장
c88ab2a - fix: URL pwd 토큰을 포함하여 암호 없이 회의 참가 가능하도록 수정
```

### Zoom 프로토콜 문서
- [Zoom URL Schemes](https://marketplace.zoom.us/docs/guides/zoom-url-schemes/)
- [Zoom Web Client](https://support.zoom.us/hc/en-us/articles/214629443-Zoom-web-client)

---

## 🎯 8단계: 결정적 증거 발견!

### 과거 커밋 분석 결과

**커밋 `31620dd` (과거)에서 이미 동일한 문제를 경험하고 해결했음:**

```dart
// 주의: pwd 파라미터는 포함하지 않음
// (cmd에서 &를 명령 구분자로 해석하는 문제)
// 대신 UI Automation으로 암호를 입력합니다

zoomProtocolUrl = 'zoommtg://zoom.us/join?confno=$confNo';  // pwd 제외
```

**하지만 현재 코드는 다시 pwd를 포함:**

```dart
// lib/services/zoom_launcher_service.dart:177
queryParameters: uri.queryParameters,  // ⚠️ pwd 포함 (회귀 버그!)
```

### 문제의 근본 원인 확정 ✅

**zoommtg:// 프로토콜에 pwd 파라미터를 포함하면 두 가지 문제 발생:**

1. **CMD 파싱 오류**: `&`를 명령 구분자로 해석
   ```
   예: zoommtg://zoom.us/j/123?pwd=abc&zak=def
   → CMD가 &를 명령어 연결로 해석하여 파싱 실패
   ```

2. **Zoom 클라이언트가 pwd를 무시**: 프로토콜 핸들러가 쿼리 파라미터 처리 안 함

### 왜 이 문제가 재발했는가?

**커밋 히스토리 추적:**

```
31620dd (과거) → pwd 제거 결정 ✅
↓
여러 커밋 (중간)
↓
현재 코드 → pwd 다시 포함 ❌ (누가 왜 되돌렸는지 불명)
```

**가능한 시나리오:**
1. 다른 기능 추가 시 의도치 않게 코드가 되돌려짐
2. "암호 자동 전달"을 구현하려다 잘못된 접근
3. Git merge 충돌 해결 시 잘못된 버전 선택

---

## 📌 현재 상태 업데이트

**2025-01-17 최초 작성**
- 문제 정의 완료
- 코드 분석 완료
- 가설 수립 완료
- 다음: 로그 수집 및 테스트 실행 대기

**2025-01-17 오후 - 과거 커밋 분석 완료** ⭐
- ✅ 결정적 증거 발견: 과거에 동일 문제 해결했었음
- ✅ 근본 원인 확정: zoommtg:// + pwd = 파싱 오류
- ✅ 회귀 버그 확인: 현재 코드가 과거 수정을 되돌림
- ✅ 해결 방안 문서화: 방안 1A (zoommtg:// 제거)
- 다음: 코드 수정 적용 및 테스트

**2025-01-17 저녁 - 수정 완료 및 커밋** 🎉
- ✅ zoom_launcher_service.dart 수정 완료
- ✅ zoommtg:// 로직 제거 (30줄 삭제)
- ✅ 회귀 방지 주석 추가 (14줄)
- ✅ Git 커밋 완료 (커밋 5e98ef3)
- ✅ 진단 문서 작성 완료
- ~~**상태: 해결 완료**~~ ❌ 여전히 문제 발생
- 다음: Windows에서 테스트 실행 권장

**2025-01-18 새벽 - 테스트 실패 및 추가 분석** ⚠️
- ❌ 테스트 결과: 암호 입력창 여전히 나타남
- ❌ 30초 동안 참가 버튼을 찾지 못함
- 🔍 **새로운 근본 원인 발견**: 브라우저가 pwd 파라미터를 전달했지만 Zoom이 무시함
- 🔍 **코드 분석 결과**: password 파라미터가 null이면 암호 입력을 시도하지 않음
- 💡 **실제 문제**: URL에 pwd가 있어도 함수에 password로 전달되지 않음
- 💡 **해결책**: URL에서 pwd 추출 → UI Automation으로 암호 입력

---

## 🚨 10단계: 실제 문제의 근본 원인 (2025-01-18 분석)

### 테스트 로그 분석

사용자가 테스트한 URL:
```
https://us05web.zoom.us/j/8064406126?pwd=0XQLpDgrVgzjEmFa8XJlUD5mXffNxc.1
```

**테스트 결과 로그:**
```
💡 🌐 브라우저를 통해 Zoom 링크 실행 (암호 자동 전달)
💡 📞 회의 URL: https://us05web.zoom.us/j/8064406126?pwd=0XQLpDgrVgzjEmFa8XJlUD5mXffNxc.1
💡 ✅ Zoom 링크 실행 완료: pid=41804
🐛 ℹ️ 브라우저 다이얼로그를 찾지 못함
🐛 ℹ️ 별도 암호가 제공되지 않음 (URL에 포함된 암호가 브라우저를 통해 자동 전달됨)
🐛 ⏳ 참가 버튼을 찾지 못함. 재시도 중... (1/30)
...
! ! Zoom 자동 진입 타임아웃 (30초 경과)
```

**사용자 보고:**
> "회의 암호를 입력하라고 하네"

### 실제로 일어난 일

1. ✅ HTTP URL을 브라우저로 실행 (zoommtg:// 사용 안 함)
2. ✅ 브라우저가 Zoom 앱을 실행
3. ❌ **Zoom이 pwd 파라미터를 무시함** (이유 불명)
4. ❌ 암호 입력 다이얼로그가 나타남
5. ❌ 코드가 암호 입력을 시도하지 않음 (password=null이므로)
6. ❌ 참가 버튼 대신 암호 입력 다이얼로그만 존재
7. ❌ 30초 동안 참가 버튼을 찾지 못하고 타임아웃

### 왜 암호 입력을 시도하지 않았는가?

**코드 분석 (zoom_launcher_service.dart:468-496줄):**

```dart
// 암호 입력 시도 (암호가 제공된 경우만)
if (password != null && password.isNotEmpty) {  // ⚠️ 문제!
  _logger.i('🔑 회의 암호 입력 시도 중...');
  // ... 암호 입력 로직
} else {
  _logger.d('ℹ️ 별도 암호가 제공되지 않음 (URL에 포함된 암호가 브라우저를 통해 자동 전달됨)');
  // ⚠️ 실제로는 자동 전달되지 않았는데 입력도 안 함!
}
```

**함수 호출:**
```dart
autoJoinZoomMeeting(
  zoomLink: 'https://zoom.us/j/123?pwd=abc',  // URL에 pwd 있음
  userName: '녹화 시스템',
  password: null,  // ⚠️ 별도로 제공 안 함
);
```

**결과:**
- URL에는 `pwd=0XQLpDgrVgzjEmFa8XJlUD5mXffNxc.1`이 있음
- 하지만 `password` 파라미터는 `null`
- 따라서 암호 입력을 시도하지 않음
- Zoom은 브라우저를 통해서도 pwd를 처리하지 못함 (보안 정책 또는 형식 문제)

### 해결 방안

**Option 1: URL에서 pwd 파라미터 자동 추출** ⭐⭐⭐ (최우선 추천)

```dart
Future<bool> autoJoinZoomMeeting({
  required String zoomLink,
  required String userName,
  String? password,  // null이면 URL에서 추출
  // ...
}) async {
  // 1. password가 제공되지 않았으면 URL에서 pwd 추출
  String? effectivePassword = password;
  if (effectivePassword == null || effectivePassword.isEmpty) {
    final uri = Uri.tryParse(zoomLink);
    if (uri != null && uri.queryParameters.containsKey('pwd')) {
      effectivePassword = uri.queryParameters['pwd'];
      _logger.i('🔑 URL에서 암호 추출: ${effectivePassword?.substring(0, 5)}...');
    }
  }

  // 2. Zoom 실행 (브라우저 사용)
  await launchZoomMeeting(...);

  // 3. 암호 입력 시도 (추출된 암호 포함)
  if (effectivePassword != null && effectivePassword.isNotEmpty) {
    _logger.i('🔑 회의 암호 입력 시도 중...');
    // UI Automation으로 암호 입력
    for (int i = 1; i <= passwordAttempts; i++) {
      final passwordPointer = effectivePassword.toNativeUtf16();
      try {
        final passwordResult = ZoomAutomationBindings.enterPassword(passwordPointer);
        if (automationBool(passwordResult)) {
          _logger.i('✅ 암호 입력 성공 ($i회 시도)');
          // 암호 확인 버튼도 클릭 필요!
          break;
        }
      } finally {
        malloc.free(passwordPointer);
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  // 4. 이름 입력 및 참가 버튼 클릭
  // ...
}
```

**장점:**
- URL만 있으면 자동으로 암호 처리
- 기존 호출 코드 수정 불필요
- 브라우저 방식과 UI Automation 방식 모두 지원

**Option 2: 항상 암호 입력 시도 (필드가 있으면 입력)**

```dart
// URL에서 pwd 추출
final pwd = Uri.tryParse(zoomLink)?.queryParameters['pwd'];

// 암호 필드를 찾아서 입력 시도
if (pwd != null) {
  // 암호 입력 다이얼로그가 나타날 때까지 대기
  for (int i = 1; i <= 20; i++) {
    final passwordPointer = pwd.toNativeUtf16();
    try {
      if (automationBool(ZoomAutomationBindings.enterPassword(passwordPointer))) {
        _logger.i('✅ 암호 입력 성공');
        // 확인 버튼 클릭
        await Future.delayed(const Duration(milliseconds: 300));
        ZoomAutomationBindings.clickPasswordConfirmButton();
        break;
      }
    } finally {
      malloc.free(passwordPointer);
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
```

**장점:**
- 더 적극적으로 암호 입력 시도
- 암호 다이얼로그 감지 및 처리

### 추가 조사 필요 사항

1. **왜 브라우저가 pwd를 전달하지 못했는가?**
   - Zoom 최신 버전에서 보안 정책 변경?
   - `pwd` 파라미터 형식이 변경됨?
   - 특정 도메인(`us05web.zoom.us`)에서만 문제?

2. **암호 확인 버튼 클릭이 필요한가?**
   - C++ 코드에 `ZoomAutomation_EnterPassword()` 있음
   - 하지만 확인 버튼 클릭 함수도 호출해야 할 수 있음

3. **암호 입력 후 대기 시간**
   - 암호 입력 후 참가 버튼이 나타나기까지 시간 필요?

---

## 🚀 9단계: 즉시 적용 가능한 수정 방법

### 옵션 A: 자동 수정 (추천)

**나(AI 어시스턴트)가 바로 코드를 수정해드릴 수 있습니다:**

1. `lib/services/zoom_launcher_service.dart` 파일 수정
2. zoommtg:// 로직 제거 (169-198줄)
3. 주석 추가로 향후 재발 방지
4. Git 커밋 메시지 제안

**승인하시면 바로 진행하겠습니다!** ✅

---

### 옵션 B: 수동 수정 (직접 확인하고 싶은 경우)

**단계별 가이드:**

1. **파일 열기**
   ```bash
   # WSL에서
   code /home/usereyebottle/projects/sat-lec-rec/lib/services/zoom_launcher_service.dart
   ```

2. **169-198줄 찾기** (Ctrl+G → 169 입력)
   ```dart
   // 3. zoommtg:// 프로토콜 우선 실행 ...
   Uri? zoomMtgUri;
   // ... (이 부분 전체 삭제)
   ```

3. **200-248줄을 169줄로 이동**
   - 169줄부터 바로 `if (!directZoomLaunchSucceeded)` 대신
   - 브라우저 실행 코드가 바로 시작되도록 수정

4. **주석 추가**
   ```dart
   // 3. HTTP(S) 링크를 브라우저로 직접 열기 (암호 자동 전달 보장)
   // ⚠️ 주의: zoommtg:// 프로토콜은 pwd 파라미터를 제대로 처리하지 못하므로 사용하지 않음
   //         (과거 커밋 31620dd에서 동일 문제 해결 - 회귀 버그 방지)
   ```

5. **저장 및 동기화**
   ```bash
   # WSL에서
   cd /home/usereyebottle/projects/sat-lec-rec
   ./scripts/sync_wsl_to_windows.sh
   ```

6. **테스트**
   ```powershell
   # Windows PowerShell에서
   cd C:\ws-workspace\sat-lec-rec
   flutter run -d windows
   ```

---

### 옵션 C: 먼저 테스트만 해보기

**현재 코드로 로그 수집 후 확실히 확인:**

```powershell
# Windows PowerShell
cd C:\ws-workspace\sat-lec-rec
flutter run -d windows 2>&1 | Tee-Object -FilePath zoom_debug.log

# 앱 실행 후:
# 1. Zoom 테스트 화면 열기
# 2. 암호 포함 링크로 테스트
# 3. 로그 확인: "🎯 zoommtg 프로토콜로 직접 실행" 검색
```

---

## 💬 논의 노트

### 핵심 질문

1. **왜 사용자 직접 클릭은 되는데 앱 실행은 안 되는가?**
   → 답: 사용자는 브라우저를 통해 실행, 앱은 zoommtg://를 먼저 시도

2. **zoommtg:// 프로토콜은 왜 pwd를 무시하는가?**
   → 답: Zoom 클라이언트의 보안 정책 때문일 가능성 (검증 필요)

3. **브라우저 폴백이 항상 작동하는가?**
   → 답: 로그 확인 필요 (zoommtg:// 성공 시 폴백 건너뜀)

### 결론 (현재)

**문제의 근본 원인**: zoommtg:// 프로토콜 사용 시 pwd 파라미터가 무시되어 암호 입력창이 나타남

**해결 방향**: zoommtg:// 시도를 제거하고 항상 브라우저(rundll32)를 통해 HTTP URL 실행

---

## 🔧 2025-12-07 코드 수정 완료

### 수정 내용

**파일**: `lib/services/zoom_launcher_service.dart` (462-494줄)

**변경 사항**:
1. URL에서 `pwd` 파라미터 자동 추출
2. Zoom 실행 후 암호 입력창 감지 (최대 10회, 5초)
3. 암호 입력창 발견 시 UI Automation으로 자동 입력

**커밋**: `17aee4f` - fix: URL에서 pwd 추출하여 암호 입력창 자동 처리

### 수정된 코드

```dart
// URL에서 pwd 파라미터 추출 (브라우저가 전달 실패할 경우 대비)
final uri = Uri.tryParse(zoomLink);
final extractedPassword = uri?.queryParameters['pwd'];
if (extractedPassword != null && extractedPassword.isNotEmpty) {
  _logger.i('🔑 URL에서 암호 추출됨: ${extractedPassword.substring(0, 5)}...');
}

// 암호 입력 시도 (암호 입력창이 나타날 경우를 대비)
if (extractedPassword != null && extractedPassword.isNotEmpty) {
  _logger.i('🔑 암호 입력창 감지 및 자동 입력 시도 중...');
  for (int pwdAttempt = 1; pwdAttempt <= 10; pwdAttempt++) {
    await Future.delayed(const Duration(milliseconds: 500));
    final passwordPointer = extractedPassword.toNativeUtf16();
    try {
      final passwordResult = ZoomAutomationBindings.enterPassword(passwordPointer);
      if (automationBool(passwordResult)) {
        _logger.i('✅ 암호 입력 성공 ($pwdAttempt회 시도)');
        await Future.delayed(const Duration(seconds: 2));
        break;
      }
    } finally {
      malloc.free(passwordPointer);
    }
  }
}
```

### 테스트 방법

1. Windows에서 앱 실행: `flutter run -d windows`
2. **Zoom 자동화 테스트** 화면 이동
3. pwd 포함 링크 입력 (예: `https://zoom.us/j/123?pwd=abc`)
4. **"이름 입력 + 참가 버튼 클릭"** 버튼 클릭

### 예상 로그

```
🔑 URL에서 암호 추출됨: 0XQLp...
🔑 암호 입력창 감지 및 자동 입력 시도 중...
✅ 암호 입력 성공 (N회 시도)
```

---

**다음 업데이트**: Windows 테스트 결과 후
