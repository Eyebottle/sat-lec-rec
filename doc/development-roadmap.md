# SAT-LEC-REC 개발 로드맵

본 문서는 sat-lec-rec 프로젝트의 단계별 개발 순서 가이드입니다.

**전제 조건**: [M0: 환경 설정](./m0-environment-setup.md) 완료

**전체 예상 기간**: 8~12주

---

## 개발 Phase 개요

| Phase | 목표 | 기간 | 의존성 레벨 | 마일스톤 |
|-------|------|------|------------|---------|
| Phase 1 | 기초 인프라 구축 | 1-2주 | L0 (Foundation) | M1 시작 |
| Phase 2 | 녹화 코어 구현 | 2-3주 | L1 (Core) | M1 완료 |
| Phase 3 | 예약 시스템 | 1-2주 | L1 (Core) | M2 시작 |
| Phase 4 | 자동화 & 안정성 | 2-3주 | L2 (Enhancement) | M2-M3 |
| Phase 5 | UX & 배포 | 1-2주 | L3 (Polish) | M4 |

---

## Phase 1: 기초 인프라 구축 (1-2주)

**목표**: Dart ↔ C++ FFI 통신 및 FFmpeg 파이프라인 기초 구축

**의존성**: M0 환경 설정 완료

### 작업 항목

#### 1.1 FFI 기초 구조 (2일)

**체크리스트**:
- [ ] **[L0]** windows/runner에 C++ 플러그인 스캐폴딩 구성
- [ ] **[L0]** Dart ↔ C++ 간단한 함수 호출 성공 (`NativeHello()`)
- [ ] **[L0]** FFI 에러 처리 및 로깅 구조 설계

**산출물**:
- `windows/runner/native_recorder_plugin.h`
- `windows/runner/native_recorder_plugin.cpp`
- `lib/ffi/native_bindings.dart`

**검증 포인트**:
```bash
flutter run -d windows
# 로그에 "Hello from C++ Native Plugin!" 출력
```

**참고**:
- [M0: FFI 기초 검증](./m0-environment-setup.md#5-ffi-기초-검증-30분)

---

#### 1.2 FFmpeg 런타임 통합 (3일)

**체크리스트**:
- [ ] **[L0]** FFmpeg 실행 파일 경로 설정 (`third_party/ffmpeg/`)
- [ ] **[L0]** Dart에서 FFmpeg 프로세스 실행 헬퍼 작성
- [ ] **[L0]** FFmpeg 테스트 인코딩 (testsrc → mp4)

**산출물**:
- `lib/services/ffmpeg_service.dart`
- `lib/utils/process_helper.dart`

**구현 예시**:
```dart
// lib/services/ffmpeg_service.dart
class FFmpegService {
  static Future<bool> testEncode() async {
    final cmd = [
      'third_party/ffmpeg/ffmpeg.exe',
      '-f', 'lavfi',
      '-i', 'testsrc=size=1280x720:rate=24:duration=5',
      '-f', 'lavfi',
      '-i', 'anullsrc=r=48000:cl=stereo',
      '-c:v', 'h264_nvenc',
      '-c:a', 'aac',
      'test_output.mp4',
    ];

    final result = await Process.run(cmd[0], cmd.sublist(1));
    return result.exitCode == 0;
  }
}
```

**검증 포인트**:
```dart
// 10초 테스트 버튼 클릭 시
await FFmpegService.testEncode();
// test_output.mp4 파일 생성 확인
```

---

#### 1.3 Named Pipe 기초 (4일)

**체크리스트**:
- [ ] **[L0]** C++에서 Named Pipe 생성 (`\\.\pipe\video`, `\\.\pipe\audio`)
- [ ] **[L0]** 더미 프레임 데이터를 Pipe에 쓰기
- [ ] **[L0]** FFmpeg가 Pipe에서 읽어 인코딩하는 흐름 구축

**산출물**:
- `windows/runner/named_pipe_writer.h`
- `windows/runner/named_pipe_writer.cpp`

**구현 참고**:
```cpp
// windows/runner/named_pipe_writer.cpp
HANDLE CreateVideoPipe() {
    return CreateNamedPipeA(
        "\\\\.\\pipe\\video",
        PIPE_ACCESS_OUTBOUND,
        PIPE_TYPE_BYTE | PIPE_WAIT,
        1, 1024 * 1024, 0, 0, NULL
    );
}

void WriteTestFrames(HANDLE pipe) {
    // 720p BGRA 더미 프레임 (1280*720*4 = 3686400 bytes)
    std::vector<uint8_t> frame(3686400, 128);  // 회색 화면

    for (int i = 0; i < 120; i++) {  // 5초 (24fps)
        DWORD written;
        WriteFile(pipe, frame.data(), frame.size(), &written, NULL);
        Sleep(1000 / 24);  // 24fps
    }
}
```

**검증 포인트**:
```bash
# FFmpeg가 Named Pipe에서 읽어 5초 영상 생성
# 회색 화면 5초 영상 재생 확인
```

---

### Phase 1 완료 기준

- ✅ Dart → C++ 함수 호출 성공
- ✅ FFmpeg 테스트 인코딩 성공 (testsrc)
- ✅ Named Pipe를 통한 더미 프레임 인코딩 성공
- ✅ 로그 시스템 구축 (JSON 구조화 로그)

**다음 단계**: Phase 2 (화면/오디오 실제 캡처)

---

## Phase 2: 녹화 코어 구현 (2-3주)

**목표**: 실제 화면 + 오디오 캡처 및 10초 녹화 테스트 성공

**의존성**: Phase 1 완료

### 작업 항목

#### 2.1 Windows Graphics Capture (5일)

**체크리스트**:
- [ ] **[L1]** Windows.Graphics.Capture API 초기화
- [ ] **[L1]** 전체 모니터 캡처 구현 (1프레임 테스트)
- [ ] **[L1]** Zoom 창 핸들 타깃 캡처 (FR-7)
- [ ] **[L2]** 창 캡처 실패 시 전체 모니터 폴백 (FR-7)

**산출물**:
- `windows/runner/screen_capture.h`
- `windows/runner/screen_capture.cpp`

**구현 참고**:
- https://github.com/robmikh/Win32CaptureSample
- https://github.com/ffiirree/ffmpeg-tutorials

**검증 포인트**:
```cpp
// 1프레임 캡처 → BMP 저장 → 육안 확인
CaptureFrame(primaryMonitor) → frame.bmp
```

---

#### 2.2 WASAPI Loopback (5일)

**체크리스트**:
- [ ] **[L1]** WASAPI 기본 재생 장치 열기
- [ ] **[L1]** Loopback 모드로 오디오 스트림 캡처
- [ ] **[L1]** 1초 오디오 캡처 → WAV 저장 테스트
- [ ] **[L2]** 마이크 믹스 옵션 토글 (FR-8)

**산출물**:
- `windows/runner/audio_capture.h`
- `windows/runner/audio_capture.cpp`

**구현 참고**:
```cpp
// 기본 재생 장치에서 Loopback 캡처
IMMDevice* device = enumerator->GetDefaultAudioEndpoint(eRender, eConsole);
IAudioClient* audioClient = device->Activate(...);

audioClient->Initialize(
    AUDCLNT_SHAREMODE_SHARED,
    AUDCLNT_STREAMFLAGS_LOOPBACK,
    10000000,  // 1초 버퍼
    0, waveFormat, NULL
);
```

**검증 포인트**:
```bash
# YouTube 재생 중 1초 캡처
# → test_audio.wav 재생하여 소리 확인
```

---

#### 2.3 캡처 → FFmpeg 파이프라인 연결 (5일)

**체크리스트**:
- [ ] **[L1]** 화면 프레임을 Named Pipe로 전송하는 스레드
- [ ] **[L1]** 오디오 샘플을 Named Pipe로 전송하는 스레드
- [ ] **[L1]** FFmpeg가 두 Pipe에서 동시에 읽어 muxing
- [ ] **[L1]** 10초 화면+오디오 녹화 성공

**산출물**:
- `windows/runner/recorder_engine.h`
- `windows/runner/recorder_engine.cpp`

**구현 흐름**:
```
[화면 캡처 스레드]
   ↓ BGRA 프레임
[Named Pipe: \\.\pipe\video]
   ↓
[FFmpeg -f rawvideo -i \\.\pipe\video]

[오디오 캡처 스레드]
   ↓ PCM 샘플
[Named Pipe: \\.\pipe\audio]
   ↓
[FFmpeg -f s16le -i \\.\pipe\audio]
   ↓
[output.mp4 (H.264 + AAC)]
```

**검증 포인트**:
```dart
// 10초 테스트 버튼 클릭
await RecorderService.startRecording(duration: 10);
// → 10초 후 output.mp4 생성
// → VLC로 재생: 화면 + 소리 모두 확인
```

---

#### 2.4 UI: 10초 테스트 버튼 연동 (2일)

**체크리스트**:
- [ ] **[L1]** 10초 테스트 버튼 클릭 시 RecorderService 호출
- [ ] **[L1]** 녹화 중 상태 표시 (진행바 또는 타이머)
- [ ] **[L1]** 완료 후 파일 위치 알림 및 "폴더 열기" 버튼

**산출물**:
- `lib/services/recorder_service.dart`
- `lib/ui/widgets/test_recording_button.dart`

**검증 포인트**:
```
1. 10초 테스트 버튼 클릭
2. "녹화 중... 7초 남음" 표시
3. 완료 후 "녹화 완료! output.mp4 저장됨" 알림
4. "폴더 열기" 버튼 → 탐색기에서 파일 확인
```

---

### Phase 2 완료 기준

- ✅ 화면 캡처 성공 (720p, 24fps)
- ✅ 오디오 캡처 성공 (48kHz, 스테레오)
- ✅ 10초 녹화 → mp4 파일 생성 및 재생 확인
- ✅ UI에서 10초 테스트 버튼 작동
- ✅ **마일스톤 M1 완료**: 녹화 코어

**다음 단계**: Phase 3 (예약 시스템)

---

## Phase 3: 예약 시스템 (1-2주)

**목표**: 수동 예약 → Zoom 입장 → 녹화 시작 흐름 구축

**의존성**: Phase 2 완료

### 작업 항목

#### 3.1 예약 데이터 구조 (2일)

**체크리스트**:
- [ ] **[L1]** 예약 데이터 모델 설계 (JSON)
- [ ] **[L1]** SharedPreferences로 단일 예약 저장/로드
- [ ] **[L1]** 예약 카드 UI 입력 검증

**산출물**:
- `lib/models/recording_schedule.dart`
- `lib/services/schedule_service.dart`

**데이터 구조**:
```dart
class RecordingSchedule {
  final String zoomLink;        // Zoom 링크
  final DateTime startTime;     // 시작 시간
  final int durationMinutes;    // 녹화 시간 (분)
  final String title;           // 강의명 (선택)
  final String presenter;       // 연자 (선택)

  Map<String, dynamic> toJson();
  factory RecordingSchedule.fromJson(Map<String, dynamic> json);
}
```

**검증 포인트**:
```
1. 예약 카드에 링크/시간/분 입력
2. "예약 저장" 버튼 클릭
3. 앱 재시작 → 저장된 예약 로드 확인
```

---

#### 3.2 Zoom 런처 (3일)

**체크리스트**:
- [ ] **[L1]** zoommtg:// 링크 실행 (Process.start)
- [ ] **[L1]** Zoom 프로세스 핸들 확보 및 상태 모니터링
- [ ] **[L2]** 재시도 로직 구현 (FR-5-1: 호스트 미시작)

**산출물**:
- `lib/services/zoom_launcher.dart`

**구현 예시**:
```dart
class ZoomLauncher {
  static Future<bool> launch(String zoomLink) async {
    // zoommtg:// 링크 실행
    await Process.start('cmd', ['/c', 'start', zoomLink]);

    // Zoom 프로세스 확인 (5초 대기)
    await Future.delayed(Duration(seconds: 5));

    final processes = await Process.run('tasklist', ['/FI', 'IMAGENAME eq Zoom.exe']);
    return processes.stdout.toString().contains('Zoom.exe');
  }
}
```

**검증 포인트**:
```
1. 테스트 Zoom 링크 입력
2. "예약 저장" 후 "지금 시작" 버튼 클릭
3. Zoom 클라이언트 자동 실행 확인
4. 회의 입장 확인
```

---

#### 3.3 수동 예약 → 녹화 플로우 (3일)

**체크리스트**:
- [ ] **[L1]** "지금 시작" 버튼 구현
- [ ] **[L1]** Zoom 입장 → 5초 대기 → 녹화 시작
- [ ] **[L1]** 녹화 시간 만료 시 자동 중지

**산출물**:
- `lib/services/recording_controller.dart`

**플로우**:
```
1. 사용자: 예약 저장
2. 사용자: "지금 시작" 버튼 클릭
3. 앱: Zoom 링크 실행
4. 앱: 5초 대기 (Zoom 창 로딩)
5. 앱: 녹화 시작
6. 앱: N분 후 자동 중지
7. 앱: 파일 저장 완료 알림
```

**검증 포인트**:
```
1. 10분 예약 생성
2. "지금 시작" 클릭
3. Zoom 입장 확인
4. 10분 녹화 완료
5. mp4 파일 생성 및 재생 확인
```

---

### Phase 3 완료 기준

- ✅ 예약 저장/로드 성공
- ✅ Zoom 자동 입장 성공
- ✅ 수동 트리거로 녹화 시작 → 시간 만료 → 자동 중지 성공
- ✅ 파일명 규칙 적용 (`YYYYMMDD_HHMM_zoom.mp4`)
- ✅ **마일스톤 M2 시작**: 예약 시스템 구축

**다음 단계**: Phase 4 (자동화 & 안정성)

---

## Phase 4: 자동화 & 안정성 (2-3주)

**목표**: 정시 자동 시작, 헬스체크, 세그먼트 저장, 크래시 복구

**의존성**: Phase 3 완료

### 작업 항목

#### 4.1 헬스체크 (T-10분) (4일)

**체크리스트**:
- [ ] **[L2]** 네트워크 연결성 확인 (ping zoom.us)
- [ ] **[L2]** 디스크 용량 확인 (5GB 임계치)
- [ ] **[L2]** 오디오 장치 확인 (WASAPI 기본 장치)
- [ ] **[L2]** 인코더 확인 (NVENC/QSV/AMF 감지)
- [ ] **[L2]** Zoom 클라이언트 설치 확인

**산출물**:
- `lib/services/health_check_service.dart`

**구현 예시**:
```dart
class HealthCheckService {
  static Future<HealthCheckResult> runChecks() async {
    final results = <String, bool>{};

    // 1. 네트워크
    results['network'] = await _pingZoom();

    // 2. 디스크
    results['disk'] = await _checkDiskSpace();

    // 3. 오디오
    results['audio'] = await NativeRecorder.checkAudioDevice();

    // 4. 인코더
    results['encoder'] = await _detectHardwareEncoder();

    // 5. Zoom
    results['zoom'] = await _checkZoomInstalled();

    return HealthCheckResult(results);
  }
}
```

**검증 포인트**:
```
1. 헬스체크 실행
2. 각 항목 PASS/FAIL 표시
3. FAIL 항목 있으면 녹화 시작 차단
```

---

#### 4.2 워밍업 (T-2분) (3일)

**체크리스트**:
- [ ] **[L2]** FFmpeg 테스트 인코딩 (5초)
- [ ] **[L2]** Graphics Capture 초기화 (1프레임 캡처)
- [ ] **[L2]** WASAPI 초기화 (1초 오디오 캡처)
- [ ] **[L2]** 성능 스냅샷 (CPU/메모리 베이스라인)

**산출물**:
- `lib/services/warmup_service.dart`

**검증 포인트**:
```
1. 워밍업 실행
2. 로그에 "FFmpeg 초기화 완료" 등 메시지
3. T0 시점 500ms 내 녹화 시작 확인
```

---

#### 4.3 정시 자동 시작 (스케줄러) (5일)

**체크리스트**:
- [ ] **[L2]** 예약 시간 모니터링 (1초 간격 체크)
- [ ] **[L2]** T-10분: 헬스체크 실행
- [ ] **[L2]** T-2분: 워밍업 실행
- [ ] **[L2]** T0±3초: Zoom 입장 + 녹화 시작
- [ ] **[L2]** 정시성 메트릭 기록 (actual_start_time)

**산출물**:
- `lib/services/auto_scheduler.dart`

**구현 예시**:
```dart
class AutoScheduler {
  Timer? _timer;

  void start(RecordingSchedule schedule) {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final target = schedule.startTime;
      final diff = target.difference(now).inSeconds;

      if (diff == 600) {  // T-10분
        HealthCheckService.runChecks();
      } else if (diff == 120) {  // T-2분
        WarmupService.run();
      } else if (diff <= 3 && diff >= -3) {  // T0±3초
        _startRecording();
        timer.cancel();
      }
    });
  }
}
```

**검증 포인트**:
```
1. 현재 시간 + 15분 예약 생성
2. T-10분: 헬스체크 로그 확인
3. T-2분: 워밍업 로그 확인
4. T0: Zoom 입장 + 녹화 시작
5. 메타 JSON에서 actual_start_time - scheduled_start_time < 3000ms 확인
```

---

#### 4.4 세그먼트 저장 (4일)

**체크리스트**:
- [ ] **[L2]** FFmpeg segment 옵션 적용 (45분 기본)
- [ ] **[L2]** 파일명 생성: `_part001.mp4`, `_part002.mp4`
- [ ] **[L2]** Fragmented MP4 옵션 적용 (각 세그먼트)
- [ ] **[L2]** 세그먼트 전환 시 프레임 연속성 확인

**산출물**:
- `lib/services/segment_manager.dart`

**FFmpeg 명령어**:
```bash
ffmpeg -i video -i audio \
  -c:v h264_nvenc -c:a aac \
  -f segment -segment_time 2700 \
  -segment_format_options movflags=frag_keyframe+empty_moov:flush_packets=1 \
  -reset_timestamps 1 \
  output_%03d.mp4
```

**검증 포인트**:
```
1. 90분 녹화 시작
2. 45분 시점: part001.mp4 완료
3. 90분 시점: part002.mp4 완료
4. 각 파일 독립 재생 가능 확인
```

---

#### 4.5 크래시 복구 (4일)

**체크리스트**:
- [ ] **[L2]** 녹화 중 `.recording` 임시 확장자 사용
- [ ] **[L2]** 정상 종료 시 `.mp4`로 rename
- [ ] **[L2]** 앱 재시작 시 `.recording` 파일 감지
- [ ] **[L2]** 복구 다이얼로그 노출 및 사용자 선택

**산출물**:
- `lib/services/crash_recovery_service.dart`

**구현 예시**:
```dart
class CrashRecoveryService {
  static Future<List<File>> findUnfinishedRecordings() async {
    final dir = Directory('D:/SaturdayZoomRec');
    return dir.listSync()
        .where((f) => f.path.endsWith('.recording'))
        .map((f) => File(f.path))
        .toList();
  }

  static Future<void> recover(File file) async {
    final newPath = file.path.replaceAll('.recording', '.mp4');
    await file.rename(newPath);
    logger.i('복구 완료: $newPath');
  }
}
```

**검증 포인트**:
```
1. 녹화 중 프로세스 강제 종료
2. 앱 재시작
3. "미완료 녹화 발견" 다이얼로그 표시
4. "복구" 선택 → .mp4로 변환
5. 파일 재생 가능 확인 (Fragmented MP4)
```

---

### Phase 4 완료 기준

- ✅ T-10분 헬스체크 작동
- ✅ T-2분 워밍업 작동
- ✅ T0±3초 정시 시작 (4주 연속 95% 달성)
- ✅ 세그먼트 저장 작동 (45분 단위)
- ✅ 크래시 복구 작동 (Fragmented MP4)
- ✅ **마일스톤 M2 완료**: 정시 자동화
- ✅ **마일스톤 M3 시작**: 안정성 강화

**다음 단계**: Phase 5 (UX & 배포)

---

## Phase 5: UX & 배포 (1-2주)

**목표**: 트레이 아이콘, 핫키, 메트릭 대시보드, 패키징

**의존성**: Phase 4 완료

### 작업 항목

#### 5.1 트레이 아이콘 (3일)

**체크리스트**:
- [ ] **[L3]** system_tray 패키지로 트레이 아이콘 구현
- [ ] **[L3]** 상태별 아이콘 변경 (대기/녹화/경고/오류)
- [ ] **[L3]** 컨텍스트 메뉴 (시작/중지/설정/종료)

**산출물**:
- `lib/services/tray_service.dart`

**검증 포인트**:
```
1. 앱 최소화 → 트레이 아이콘 표시
2. 녹화 시작 → 아이콘 색상 변경
3. 우클릭 → 메뉴 표시
```

---

#### 5.2 글로벌 핫키 (2일)

**체크리스트**:
- [ ] **[L3]** hotkey_manager 패키지로 핫키 등록
- [ ] **[L3]** Ctrl+Shift+R: 녹화 시작/중지
- [ ] **[L3]** Ctrl+Shift+S: 설정 열기

**산출물**:
- `lib/services/hotkey_service.dart`

**검증 포인트**:
```
1. Ctrl+Shift+R 입력 → 녹화 시작
2. 다시 Ctrl+Shift+R → 녹화 중지
```

---

#### 5.3 메트릭 대시보드 (3일)

**체크리스트**:
- [ ] **[L3]** 최근 4주 성공률 표시
- [ ] **[L3]** 상세 보고서 (날짜별 상태)
- [ ] **[L3]** validation_report.json 로드 및 시각화

**산출물**:
- `lib/ui/screens/metrics_screen.dart`
- `lib/widgets/metrics_dashboard.dart`

**검증 포인트**:
```
1. 메뉴 → 메트릭 열기
2. "최근 4주 성공률: 96%" 표시
3. 상세 보고서에서 날짜별 녹화 상태 확인
```

---

#### 5.4 Windows 패키징 (3일)

**체크리스트**:
- [ ] **[L3]** `flutter build windows --release`
- [ ] **[L3]** 산출물에 FFmpeg 바이너리 포함
- [ ] **[L3]** MSIX 또는 ZIP + 런처 스크립트
- [ ] **[L3]** 설치 가이드 문서 작성

**산출물**:
- `build/windows/x64/runner/Release/sat_lec_rec.exe`
- `dist/sat-lec-rec-v1.0.0.msix` (또는 .zip)
- `doc/installation-guide.md`

**검증 포인트**:
```
1. 패키지 설치 (다른 PC)
2. 앱 실행
3. 10초 테스트 성공
4. 예약 → 녹화 성공
```

---

### Phase 5 완료 기준

- ✅ 트레이 아이콘 작동
- ✅ 글로벌 핫키 작동
- ✅ 메트릭 대시보드 작동
- ✅ Windows 패키징 완료
- ✅ **마일스톤 M4 완료**: UX/배포

---

## Critical Path (핵심 경로)

개발 속도를 최대화하려면 다음 순서를 엄수하세요:

```
M0 환경 설정
  ↓
Phase 1.1 FFI 기초 (2일)
  ↓
Phase 1.2 FFmpeg 통합 (3일)
  ↓
Phase 1.3 Named Pipe (4일)
  ↓
Phase 2.1 화면 캡처 (5일)  ←--- 병렬 가능
Phase 2.2 오디오 캡처 (5일) ←-/
  ↓
Phase 2.3 파이프라인 연결 (5일)
  ↓
Phase 2.4 UI 연동 (2일)
  ↓
▶ M1 완료: 10초 녹화 성공
  ↓
Phase 3.1 예약 구조 (2일)
  ↓
Phase 3.2 Zoom 런처 (3일)
  ↓
Phase 3.3 수동 플로우 (3일)
  ↓
▶ M2 시작: 수동 예약 작동
  ↓
Phase 4.1 헬스체크 (4일)  ←--- 병렬 가능
Phase 4.2 워밍업 (3일)     ←-/
  ↓
Phase 4.3 스케줄러 (5일)
  ↓
Phase 4.4 세그먼트 (4일)   ←--- 병렬 가능
Phase 4.5 복구 (4일)       ←-/
  ↓
▶ M2-M3 완료: 자동화 & 안정성
  ↓
Phase 5 UX & 배포 (1-2주)
  ↓
▶ M4 완료: 프로덕션 준비
```

**총 예상 기간**: 8~12주 (병렬 작업 활용 시 단축 가능)

---

## 주간 진행 체크리스트

### Week 1-2: Phase 1 (기초 인프라)
- [ ] FFI Hello World 성공
- [ ] FFmpeg 테스트 인코딩 성공
- [ ] Named Pipe 더미 프레임 인코딩 성공

### Week 3-5: Phase 2 (녹화 코어)
- [ ] 화면 캡처 성공
- [ ] 오디오 캡처 성공
- [ ] 10초 녹화 테스트 성공
- [ ] ▶ M1 완료

### Week 6-7: Phase 3 (예약 시스템)
- [ ] 예약 저장/로드 성공
- [ ] Zoom 자동 입장 성공
- [ ] 수동 트리거 녹화 성공

### Week 8-10: Phase 4 (자동화 & 안정성)
- [ ] 헬스체크 작동
- [ ] 정시 자동 시작 (T0±3초)
- [ ] 세그먼트 저장 작동
- [ ] 크래시 복구 작동
- [ ] ▶ M2-M3 완료

### Week 11-12: Phase 5 (UX & 배포)
- [ ] 트레이 아이콘 작동
- [ ] 메트릭 대시보드 작동
- [ ] Windows 패키징 완료
- [ ] ▶ M4 완료

---

## 리스크 관리

| 리스크 | 대응 방안 |
|--------|----------|
| Windows Graphics Capture API 학습 곡선 | 참고 프로젝트 코드 분석, 1프레임 캡처부터 시작 |
| WASAPI 동기화 복잡도 | FFmpeg Named Pipe 2개 분리 사용, 샘플레이트 고정 |
| 정시성 달성 어려움 | T-2분 워밍업으로 콜드 스타트 제거, 베타 테스트 4주 |
| FFmpeg 크래시 | Fragmented MP4 기본 적용, 세그먼트 저장으로 리스크 분산 |
| Zoom UI 변경 | zoommtg:// 스킴 사용 (UI 독립적), 버전별 모니터링 |

---

## 참고 자료

### 공식 문서
- [Windows Graphics Capture API](https://docs.microsoft.com/en-us/windows/uwp/audio-video-camera/screen-capture)
- [WASAPI Loopback](https://docs.microsoft.com/en-us/windows/win32/coreaudio/loopback-recording)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)

### 참고 프로젝트
- https://github.com/robmikh/Win32CaptureSample
- https://github.com/ffiirree/ffmpeg-tutorials
- https://github.com/clowd/screen-recorder

### 관련 문서
- [M0: 환경 설정](./m0-environment-setup.md)
- [PRD](./sat-lec-rec-prd.md)
- [개발 진행 메모](./developing.md)

---

**작성일**: 2025-10-21
**버전**: v1.0
**작성자**: AI 협업 (Claude Code)
