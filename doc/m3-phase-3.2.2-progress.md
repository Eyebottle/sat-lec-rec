# Phase 3.2.2 구현 완료 보고서
**T-10 헬스체크 기능 통합**

## 개요

**Phase**: Milestone 3 - Phase 3.2.2
**목표**: 예약 녹화 10분 전 시스템 상태 자동 확인
**완료일**: 2025-10-24
**빌드 시간**: 24.7초
**빌드 결과**: ✅ SUCCESS

## 구현 범위

### ✅ 완료된 기능

1. **HealthCheckResult 모델** (`lib/models/health_check_result.dart`)
   - 네트워크, Zoom 링크, 오디오 장치, 디스크 공간 체크 결과 저장
   - `isHealthy` getter로 전체 상태 판단
   - 사람이 읽을 수 있는 `summary` 제공
   - 디스크 공간을 GB 단위로 표시

2. **HealthCheckService** (`lib/services/health_check_service.dart`)
   - `performHealthCheck()`: 4가지 항목 동시 체크
   - 네트워크 확인: `InternetAddress.lookup('google.com')` (5초 타임아웃)
   - Zoom 링크 확인: HTTP HEAD 요청 (10초 타임아웃)
   - 오디오 장치 확인: 임시 구현 (향후 네이티브 레이어 연동)
   - 디스크 공간 확인: PowerShell `Get-PSDrive` 명령어 (최소 5GB)
   - 상세 로깅 기능

3. **ScheduleService 통합**
   - T-10분 헬스체크 타이머 관리
   - `_scheduleHealthCheck()`: 다음 실행 10분 전에 타이머 등록
   - `_performScheduledHealthCheck()`: 헬스체크 실행 및 결과 로깅
   - `_unregisterCronJob()`: 타이머 정리 로직 추가
   - `dispose()`: 모든 헬스체크 타이머 취소

## 상세 구현

### 1. HealthCheckResult 모델

```dart
class HealthCheckResult {
  final bool networkOk;
  final bool? zoomLinkOk;  // 선택적 (Zoom 미사용 가능)
  final bool audioDeviceOk;
  final bool diskSpaceOk;
  final int? availableDiskSpaceBytes;
  final List<String> errors;
  final List<String> warnings;
  final DateTime checkedAt;

  bool get isHealthy =>
      networkOk &&
      diskSpaceOk &&
      audioDeviceOk &&
      (zoomLinkOk ?? true);

  String get summary {
    if (isHealthy) return '✅ 모든 시스템 정상';
    final issues = <String>[];
    if (!networkOk) issues.add('네트워크 연결 실패');
    if (zoomLinkOk == false) issues.add('Zoom 링크 접속 불가');
    if (!audioDeviceOk) issues.add('오디오 장치 없음');
    if (!diskSpaceOk) issues.add('디스크 공간 부족');
    return '❌ 문제 발견: ${issues.join(', ')}';
  }
}
```

### 2. HealthCheckService 주요 메서드

#### performHealthCheck()
```dart
Future<HealthCheckResult> performHealthCheck({String? zoomLink}) async {
  final errors = <String>[];

  // 1. 네트워크 체크
  final networkOk = await _checkNetwork();
  if (!networkOk) errors.add('네트워크 연결 실패');

  // 2. Zoom 링크 체크 (선택적)
  bool? zoomLinkOk;
  if (zoomLink != null && zoomLink.isNotEmpty) {
    zoomLinkOk = await _checkZoomLink(zoomLink);
    if (zoomLinkOk == false) errors.add('Zoom 링크 접속 불가');
  }

  // 3. 오디오 장치 체크
  final audioDeviceOk = await _checkAudioDevice();
  if (!audioDeviceOk) errors.add('오디오 장치를 찾을 수 없음');

  // 4. 디스크 공간 체크
  final diskSpaceBytes = await _getAvailableDiskSpace();
  final diskSpaceOk = diskSpaceBytes != null &&
                      diskSpaceBytes >= minRequiredDiskSpace;
  if (!diskSpaceOk) errors.add('디스크 공간 부족');

  return HealthCheckResult(...);
}
```

#### 네트워크 체크
```dart
Future<bool> _checkNetwork() async {
  try {
    final result = await InternetAddress.lookup('google.com')
        .timeout(const Duration(seconds: 5));
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (e) {
    return false;
  }
}
```

#### Zoom 링크 체크
```dart
Future<bool> _checkZoomLink(String zoomLink) async {
  try {
    final uri = Uri.tryParse(zoomLink);
    if (uri == null || !uri.hasScheme) return false;

    final client = HttpClient();
    try {
      final request = await client.headUrl(uri)
          .timeout(const Duration(seconds: 10));
      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 400;
    } finally {
      client.close();
    }
  } catch (e) {
    return false;
  }
}
```

#### 디스크 공간 체크
```dart
Future<int?> _getAvailableDiskSpace() async {
  try {
    final documentsDir = await getApplicationDocumentsDirectory();
    final drive = documentsDir.path.substring(0, 1);  // C:\ -> C

    final result = await Process.run(
      'powershell.exe',
      ['-Command', '(Get-PSDrive $drive).Free'],
    );

    if (result.exitCode == 0) {
      return int.tryParse(result.stdout.toString().trim());
    }
    return null;
  } catch (e) {
    return null;
  }
}
```

### 3. ScheduleService 통합

#### _scheduleHealthCheck()
```dart
void _scheduleHealthCheck(RecordingSchedule schedule) {
  try {
    // 기존 타이머 제거
    _healthCheckTimers[schedule.id]?.cancel();

    final nextExecution = schedule.getNextExecutionTime();
    final now = DateTime.now();
    final timeUntilExecution = nextExecution.difference(now);

    // T-10분 시각 계산
    final healthCheckTime = timeUntilExecution - const Duration(minutes: 10);

    if (healthCheckTime.isNegative || healthCheckTime.inMinutes < 1) {
      _logger.w('⚠️ 헬스체크 시간 부족: ${schedule.name}');
      return;
    }

    // T-10분 타이머 생성
    final timer = Timer(healthCheckTime, () async {
      await _performScheduledHealthCheck(schedule);
    });

    _healthCheckTimers[schedule.id] = timer;
    _logger.i('🏥 헬스체크 예약: ${schedule.name} - ${healthCheckTime.inMinutes}분 후 실행');
  } catch (e, stackTrace) {
    _logger.e('❌ 헬스체크 예약 실패', error: e, stackTrace: stackTrace);
  }
}
```

#### _performScheduledHealthCheck()
```dart
Future<void> _performScheduledHealthCheck(RecordingSchedule schedule) async {
  _logger.i('🏥 T-10 헬스체크 실행: ${schedule.name}');

  try {
    final result = await _healthCheckService.performHealthCheck(
      zoomLink: schedule.zoomLink,
    );

    _healthCheckService.logHealthCheckSummary(result);

    if (!result.isHealthy) {
      _logger.w('⚠️ 헬스체크 실패 - 녹화 시작 전 문제 해결 필요');
      _logger.w('  문제: ${result.errors.join(', ')}');
      // TODO: Phase 3.2.3에서 시스템 트레이 알림 추가
    } else {
      _logger.i('✅ 헬스체크 통과 - 녹화 준비 완료');
    }
  } catch (e, stackTrace) {
    _logger.e('❌ 헬스체크 수행 실패', error: e, stackTrace: stackTrace);
  }
}
```

#### 타이머 정리
```dart
// _unregisterCronJob()에 추가
final timer = _healthCheckTimers.remove(scheduleId);
if (timer != null) {
  timer.cancel();
  _logger.d('🔕 헬스체크 타이머 취소: $scheduleId');
}

// dispose()에 추가
for (final timer in _healthCheckTimers.values) {
  timer.cancel();
}
_healthCheckTimers.clear();
```

## 동작 흐름

```
1. 사용자가 스케줄 생성 (예: 토요일 14:00)
   ↓
2. ScheduleService._registerCronJob()
   - Cron 작업 등록 (14:00 실행)
   - _scheduleHealthCheck() 호출
   ↓
3. _scheduleHealthCheck()
   - 다음 실행 시각 계산 (예: 2025-10-26 14:00)
   - T-10분 시각 계산 (13:50)
   - Timer 생성 및 _healthCheckTimers에 저장
   ↓
4. [T-10분] Timer 콜백 실행
   - _performScheduledHealthCheck() 호출
   ↓
5. _performScheduledHealthCheck()
   - HealthCheckService.performHealthCheck() 호출
   - 네트워크, Zoom 링크, 오디오, 디스크 공간 체크
   ↓
6. 결과 로깅
   - isHealthy = true: "✅ 헬스체크 통과 - 녹화 준비 완료"
   - isHealthy = false: "⚠️ 헬스체크 실패 - [문제 목록]"
   ↓
7. [T0] Cron 작업 실행
   - 녹화 시작
```

## 헬스체크 항목별 상세

| 항목 | 체크 방법 | 성공 조건 | 실패 시 메시지 |
|------|----------|----------|---------------|
| **네트워크** | `InternetAddress.lookup('google.com')` | DNS 조회 성공 | "네트워크 연결 실패" |
| **Zoom 링크** | HTTP HEAD 요청 | 200-399 응답 코드 | "Zoom 링크 접속 불가: [URL]" |
| **오디오 장치** | (임시) 항상 true | - | "오디오 장치를 찾을 수 없음" |
| **디스크 공간** | PowerShell Get-PSDrive | ≥ 5GB | "디스크 공간 부족 ([사용가능]GB, 필요: 5GB)" |

## 로그 출력 예시

### 성공 케이스
```
🏥 헬스체크 예약: 토요일 강의 - 500분 후 실행
...
🏥 T-10 헬스체크 실행: 토요일 강의
🏥 헬스체크 시작...
  네트워크 확인 중... (8.8.8.8:53)
  ✅ 네트워크 연결 정상
  Zoom 링크 확인 중: https://zoom.us/j/123456789
  ✅ Zoom 링크 접속 가능 (200)
  오디오 장치 확인 중...
  ✅ 오디오 장치 사용 가능 (네이티브 초기화됨)
  디스크 공간 확인 중...
  ✅ 디스크 공간: 127.3 GB 사용 가능
✅ 헬스체크 통과: ✅ 모든 시스템 정상
📊 헬스체크 요약:
  - 네트워크: ✅
  - Zoom 링크: ✅
  - 오디오 장치: ✅
  - 디스크 공간: ✅ (127.3 GB)
✅ 헬스체크 통과 - 녹화 준비 완료
```

### 실패 케이스
```
🏥 T-10 헬스체크 실행: 토요일 강의
🏥 헬스체크 시작...
  네트워크 확인 중... (8.8.8.8:53)
  ⚠️ 네트워크 연결 실패
  디스크 공간 확인 중...
  ⚠️ 디스크 공간 확인 실패: ...
❌ 헬스체크 실패: ❌ 문제 발견: 네트워크 연결 실패, 디스크 공간 부족
📊 헬스체크 요약:
  - 네트워크: ❌
  - 오디오 장치: ✅
  - 디스크 공간: ❌ (N/A)
🔴 에러:
  - 네트워크 연결 실패
  - 디스크 공간 부족 (사용 가능: 2.1GB, 필요: 5GB)
⚠️ 헬스체크 실패 - 녹화 시작 전 문제 해결 필요
  문제: 네트워크 연결 실패, 디스크 공간 부족
```

## 빌드 결과

```
Windows Build (C:\ws-workspace\sat-lec-rec)
====================================
Command: flutter build windows
Duration: 24.7초
Output: build\windows\x64\runner\Release\sat_lec_rec.exe
Status: ✅ SUCCESS
```

## 테스트 시나리오

### 1. 정상 케이스
- [ ] 스케줄 생성 시 헬스체크 타이머 등록 확인
- [ ] T-10분에 헬스체크 자동 실행 확인
- [ ] 모든 항목 통과 시 "✅ 헬스체크 통과" 로그 확인

### 2. 네트워크 실패 케이스
- [ ] 인터넷 연결 끊고 헬스체크 실행
- [ ] "네트워크 연결 실패" 에러 메시지 확인

### 3. Zoom 링크 실패 케이스
- [ ] 잘못된 Zoom 링크로 스케줄 생성
- [ ] "Zoom 링크 접속 불가" 에러 메시지 확인

### 4. 디스크 공간 부족 케이스
- [ ] (수동 테스트 어려움 - 임시 디렉토리 사용)
- [ ] "디스크 공간 부족" 에러 메시지 확인

### 5. 타이머 정리 케이스
- [ ] 스케줄 삭제 시 타이머 취소 확인
- [ ] 앱 종료 시 모든 타이머 정리 확인

## 파일 변경 사항

### 신규 파일
- `lib/models/health_check_result.dart` (111줄)
- `lib/services/health_check_service.dart` (245줄)

### 수정 파일
- `lib/services/schedule_service.dart`
  - `_healthCheckTimers` 맵 추가
  - `_healthCheckService` 인스턴스 추가
  - `_scheduleHealthCheck()` 메서드 추가 (27줄)
  - `_performScheduledHealthCheck()` 메서드 추가 (24줄)
  - `_unregisterCronJob()` 타이머 정리 로직 추가 (6줄)
  - `dispose()` 타이머 정리 로직 추가 (5줄)

## 향후 개선 사항 (TODO)

### Phase 3.2.3에서 구현 예정
1. **시스템 트레이 알림**
   - 헬스체크 실패 시 사용자에게 알림
   - 문제 해결 가이드 표시
   - 녹화 시작 5분 전 재확인 옵션

2. **오디오 장치 체크 완성**
   - 네이티브 레이어에 WASAPI 장치 열거 함수 추가
   - 실제 오디오 장치 사용 가능 여부 확인

3. **헬스체크 결과 UI**
   - ScheduleScreen에 마지막 헬스체크 결과 표시
   - 문제가 있는 항목에 대한 해결 방법 안내

4. **스마트 재시도**
   - 헬스체크 실패 시 T-5분에 재확인
   - 네트워크 일시적 끊김 대응

## 기술 결정 사항

### 1. Timer vs Cron for T-10 Health Check
**선택**: Dart Timer
**이유**:
- Cron은 분 단위 스케줄링만 지원 (T-10분은 매번 다른 시각)
- Timer는 일회성 실행에 적합
- 메모리 효율적 (스케줄당 Timer 1개)

### 2. HTTP HEAD vs GET for Zoom Link Check
**선택**: HTTP HEAD
**이유**:
- HEAD 요청은 헤더만 가져와 네트워크 부하 최소화
- Zoom 페이지는 수 MB이므로 GET은 비효율적
- 접속 가능 여부만 확인하면 되므로 충분

### 3. PowerShell vs Win32 API for Disk Space
**선택**: PowerShell Get-PSDrive
**이유**:
- Win32 API는 FFI 바인딩 추가 필요
- PowerShell은 Dart Process.run()으로 간단히 호출
- 성능 차이 무시 가능 (10분에 1회 실행)

### 4. 최소 디스크 공간 5GB
**이유**:
- 120분 녹화 시 예상 크기: ~2.5GB (1080p 30fps)
- 버퍼: 2배 (5GB)
- 임시 파일 및 시스템 여유 공간 고려

## 알려진 제약사항

1. **오디오 장치 체크 미완성**
   - 현재: 항상 true 반환
   - 향후: 네이티브 레이어 WASAPI 통합 필요

2. **Zoom 링크 체크 한계**
   - HTTP HEAD 요청만으로는 실제 회의 ID 유효성 미확인
   - Zoom API 인증 없이는 회의 활성화 여부 확인 불가

3. **사용자 알림 미구현**
   - 현재: 로그만 출력
   - 향후: 시스템 트레이 알림 (Phase 3.2.3)

## 성능 영향

- **메모리**: 스케줄당 Timer 1개 (~100 bytes)
- **CPU**: T-10분에만 실행 (평상시 0%)
- **네트워크**: 헬스체크당 ~2KB (DNS lookup + HTTP HEAD)
- **디스크**: 없음 (로그 제외)

## 다음 단계

### Phase 3.2.3: Windows 통합 (예정)
1. Windows Task Scheduler 등록
2. 절전 모드 방지 (녹화 중)
3. 시스템 시작 시 자동 실행
4. 헬스체크 실패 시 시스템 트레이 알림

### Phase 3.3: 안정성 강화 (사용자 강조 단계)
1. 네트워크 단절 대응
2. 디스크 공간 모니터링
3. **Fragmented MP4** (크래시 복구 핵심)
4. 오디오/비디오 장치 변경 처리

---

**작성자**: Claude Code
**검토**: -
**승인**: -
**버전**: 1.0.0
**문서 갱신일**: 2025-10-24
