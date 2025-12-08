# M3 Phase 3: 프로덕션 준비 로드맵

**목표**: 실제 토요일 강의 녹화에 사용할 수 있는 완성도 높은 애플리케이션 구축

**예상 소요 시간**: 5~7일

**작성일**: 2025-10-24

---

## 개요

Phase 2에서 완성한 핵심 녹화 기능을 기반으로, 프로덕션 환경에서 안정적으로 사용할 수 있는 완성된 애플리케이션을 구축합니다.

**핵심 가치 재확인**:
1. **정시성**: T0±3초 내 녹화 시작
2. **완성률**: 4주 연속 95% 이상 성공률
3. **안정성**: Fragmented MP4 기반 크래시 복구
4. **단순함**: 링크·시각·시간 3가지만 입력

---

## Phase 3.1: UI 개선 및 사용성 향상

**목표**: 녹화 상태를 직관적으로 파악하고 제어할 수 있는 UI 구축

**예상 소요**: 1~2일

### 3.1.1 녹화 진행률 표시

**요구사항**:
- 경과 시간 표시 (MM:SS 형식)
- 캡처된 프레임 수 표시
- 녹화 파일 크기 실시간 업데이트
- 진행률 바 (예상 종료 시각 기준)

**구현**:
```dart
// lib/ui/widgets/recording_progress.dart
class RecordingProgressWidget extends StatelessWidget {
  final Duration elapsed;
  final int framesCaptured;
  final int audioSamplesCaptured;
  final double fileSizeMB;
  final Duration? totalDuration;

  // Progress bar, time display, stats
}
```

**C++ FFI 연동**:
```cpp
// windows/runner/native_screen_recorder.h
int64_t NativeRecorder_GetFrameCount();
int64_t NativeRecorder_GetAudioSampleCount();
int64_t NativeRecorder_GetElapsedTimeMs();
```

---

### 3.1.2 실시간 오디오 레벨 표시

**요구사항**:
- 오디오 입력 레벨 미터 (VU Meter)
- 무음 감지 경고
- 피크 레벨 표시

**구현**:
```cpp
// windows/runner/native_screen_recorder.cpp
float CalculateAudioLevel(const AudioSample& sample) {
    // RMS (Root Mean Square) 계산
    float sum = 0.0f;
    for (size_t i = 0; i < sample.data.size(); i++) {
        float val = sample.data[i];
        sum += val * val;
    }
    return sqrt(sum / sample.data.size());
}
```

**Dart UI**:
```dart
// lib/ui/widgets/audio_level_meter.dart
class AudioLevelMeter extends StatelessWidget {
  final double level; // 0.0 ~ 1.0

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: level,
      backgroundColor: Colors.grey[300],
      color: level > 0.8 ? Colors.red : Colors.green,
    );
  }
}
```

---

### 3.1.3 저장 경로 선택 UI

**요구사항**:
- 기본 경로: `C:\Users\{user}\OneDrive\문서\SaturdayZoomRec`
- 폴더 선택 다이얼로그
- 경로 유효성 검증 (쓰기 권한, 충분한 공간)
- SharedPreferences에 저장

**구현**:
```dart
// lib/ui/screens/settings_screen.dart
Future<void> _selectOutputDirectory() async {
  final directory = await getDirectoryPath();
  if (directory != null) {
    await _prefs.setString('output_directory', directory);
    setState(() => _outputDirectory = directory);
  }
}
```

**패키지 추가**:
```yaml
# pubspec.yaml
dependencies:
  file_picker: ^8.0.0  # 폴더 선택
```

---

### 3.1.4 녹화 상태 표시 개선

**요구사항**:
- 아이콘 기반 상태 표시 (대기/준비/녹화 중/일시정지/완료)
- 색상 코딩 (회색/노란색/빨간색/주황색/초록색)
- 상태 전환 애니메이션

**상태 정의**:
```dart
enum RecordingState {
  idle,        // 대기 (회색)
  preparing,   // 준비 중 (노란색)
  recording,   // 녹화 중 (빨간색)
  paused,      // 일시정지 (주황색)
  completed,   // 완료 (초록색)
  error,       // 에러 (빨간색 깜빡임)
}
```

---

## Phase 3.2: 스케줄링 및 자동화

**목표**: 예약된 시각에 자동으로 녹화 시작/종료

**예상 소요**: 2~3일

### 3.2.1 Cron 기반 예약 녹화

**요구사항**:
- 매주 토요일 N시 M분 녹화 시작
- 지정된 시간 후 자동 종료
- 여러 예약 관리 (리스트)

**구현**:
```dart
// lib/services/schedule_service.dart
class ScheduleService {
  final Cron _cron = Cron();

  void scheduleRecording(
    DayOfWeek day,
    TimeOfDay startTime,
    Duration duration,
    String zoomLink,
  ) {
    // Cron 표현식 생성
    final cronExpression = '${startTime.minute} ${startTime.hour} * * ${day.index}';

    _cron.schedule(Schedule.parse(cronExpression), () async {
      await _startScheduledRecording(zoomLink, duration);
    });
  }
}
```

**UI**:
```dart
// lib/ui/screens/schedule_screen.dart
class ScheduleScreen extends StatefulWidget {
  // 예약 리스트, 추가/삭제/편집
}
```

---

### 3.2.2 T-10분 헬스체크

**요구사항**:
- 녹화 10분 전 시스템 상태 확인
- Zoom 링크 접속 가능 여부 확인
- 오디오/비디오 장치 확인
- 디스크 공간 확인
- 실패 시 사용자에게 알림

**구현**:
```dart
// lib/services/health_check_service.dart
class HealthCheckService {
  Future<HealthCheckResult> performHealthCheck(String zoomLink) async {
    final result = HealthCheckResult();

    // 1. 네트워크 연결 확인
    result.networkOk = await _checkNetwork();

    // 2. Zoom 링크 유효성 확인
    result.zoomLinkOk = await _checkZoomLink(zoomLink);

    // 3. 오디오 장치 확인
    result.audioDeviceOk = await _checkAudioDevice();

    // 4. 디스크 공간 확인 (최소 5GB)
    result.diskSpaceOk = await _checkDiskSpace(5 * 1024 * 1024 * 1024);

    return result;
  }
}
```

---

### 3.2.3 자동 시작/종료

**요구사항**:
- 예약 시각에 자동으로 앱 실행 (Task Scheduler)
- 녹화 완료 후 자동 종료 옵션
- 시스템 트레이에서 대기 (최소화)

**Task Scheduler 연동**:
```dart
// lib/services/task_scheduler_service.dart
class TaskSchedulerService {
  Future<void> registerAutoStart() async {
    // Windows Task Scheduler XML 생성
    final taskXml = '''
    <Task>
      <Triggers>
        <CalendarTrigger>
          <StartBoundary>2025-10-26T09:50:00</StartBoundary>
        </CalendarTrigger>
      </Triggers>
      <Actions>
        <Exec>
          <Command>C:\\path\\to\\sat_lec_rec.exe</Command>
        </Exec>
      </Actions>
    </Task>
    ''';

    // schtasks.exe를 통해 등록
    await Process.run('schtasks', [
      '/Create',
      '/TN', 'SatLecRecAutoStart',
      '/XML', taskXmlPath,
    ]);
  }
}
```

---

### 3.2.4 절전 모드 방지

**요구사항**:
- 녹화 중 화면 꺼짐 방지
- 절전 모드 진입 방지
- 녹화 완료 후 자동 복원

**구현** (C++ FFI):
```cpp
// windows/runner/native_screen_recorder.cpp
void PreventSleep() {
    SetThreadExecutionState(
        ES_CONTINUOUS |
        ES_SYSTEM_REQUIRED |
        ES_DISPLAY_REQUIRED
    );
}

void AllowSleep() {
    SetThreadExecutionState(ES_CONTINUOUS);
}
```

---

## Phase 3.3: 안정성 및 에러 처리

**목표**: 예상치 못한 상황에서도 녹화를 완료할 수 있는 안정성 확보

**예상 소요**: 2~3일

### 3.3.1 네트워크 단절 처리

**요구사항**:
- Zoom 연결 끊김 감지
- 자동 재접속 시도 (최대 3회)
- 재접속 실패 시 사용자 알림

**구현**:
```dart
// lib/services/network_monitor_service.dart
class NetworkMonitorService {
  final _connectivity = Connectivity();
  StreamSubscription? _subscription;

  void startMonitoring(Function() onDisconnected) {
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        onDisconnected();
      }
    });
  }
}
```

---

### 3.3.2 디스크 공간 모니터링

**요구사항**:
- 녹화 중 디스크 공간 주기적 확인 (1분마다)
- 공간 부족 시 경고 (< 1GB)
- 임계값 이하 시 자동 정지 (< 500MB)

**구현**:
```dart
// lib/services/disk_space_service.dart
class DiskSpaceService {
  Future<int> getAvailableSpace(String path) async {
    if (Platform.isWindows) {
      final result = await Process.run('fsutil', ['volume', 'diskfree', path]);
      // Parse output
    }
    return availableBytes;
  }

  void startMonitoring(String path, Function(int) onLowSpace) {
    Timer.periodic(Duration(minutes: 1), (timer) async {
      final space = await getAvailableSpace(path);
      if (space < 1024 * 1024 * 1024) { // < 1GB
        onLowSpace(space);
      }
    });
  }
}
```

---

### 3.3.3 오디오/비디오 장치 변경 감지

**요구사항**:
- 녹화 중 장치 변경 감지 (플러그 뽑힘 등)
- 자동으로 다른 장치로 전환 시도
- 전환 실패 시 녹화 일시정지 및 알림

**구현** (C++ FFI):
```cpp
// windows/runner/device_monitor.cpp
class DeviceMonitor {
public:
    void RegisterDeviceChangeNotification(HWND hwnd) {
        DEV_BROADCAST_DEVICEINTERFACE filter = {};
        filter.dbcc_size = sizeof(filter);
        filter.dbcc_devicetype = DBT_DEVTYP_DEVICEINTERFACE;

        // Audio device GUID
        filter.dbcc_classguid = KSCATEGORY_AUDIO;

        RegisterDeviceNotification(
            hwnd,
            &filter,
            DEVICE_NOTIFY_WINDOW_HANDLE
        );
    }

    // WM_DEVICECHANGE 메시지 처리
    void OnDeviceChange(WPARAM wParam) {
        if (wParam == DBT_DEVICEREMOVECOMPLETE) {
            // 장치 제거됨
            OnAudioDeviceRemoved();
        } else if (wParam == DBT_DEVICEARRIVAL) {
            // 새 장치 추가됨
            OnAudioDeviceAdded();
        }
    }
};
```

---

### 3.3.4 Fragmented MP4 지원 (크래시 복구)

**요구사항**:
- 앱 크래시 시에도 녹화된 데이터 복구 가능
- Fragmented MP4 (fMP4) 형식 사용
- 마지막 프레임까지 재생 가능한 파일 생성

**배경**:
- 일반 MP4: 파일 끝에 moov 박스 (메타데이터) 작성 → 크래시 시 파일 손상
- Fragmented MP4: 주기적으로 moof 박스 (메타데이터) 작성 → 크래시 시 마지막 fragment까지 복구 가능

**구현** (Media Foundation):
```cpp
// windows/runner/native_screen_recorder.cpp
static bool CreateSinkWriter(const wchar_t* output_file) {
    IMFAttributes* attributes = nullptr;
    hr = MFCreateAttributes(&attributes, 2);

    // 하드웨어 가속
    attributes->SetUINT32(MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS, TRUE);

    // Fragmented MP4 활성화
    attributes->SetUINT32(MF_SINK_WRITER_DISABLE_THROTTLING, TRUE);
    attributes->SetUINT32(MF_LOW_LATENCY, TRUE);

    // Fragment 간격: 5초
    attributes->SetUINT32(MF_MPEG4SINK_MOOV_BEFORE_MDAT, FALSE);

    hr = MFCreateSinkWriterFromURL(
        output_file,
        nullptr,
        attributes,
        &g_sink_writer
    );
    attributes->Release();

    return SUCCEEDED(hr);
}
```

**복구 도구**:
```dart
// lib/utils/mp4_recovery.dart
class Mp4RecoveryTool {
  Future<bool> recoverFragmentedMp4(String corruptedFile) async {
    // ffmpeg를 사용한 복구
    final result = await Process.run('ffmpeg', [
      '-i', corruptedFile,
      '-c', 'copy',
      '-f', 'mp4',
      '${corruptedFile}_recovered.mp4',
    ]);

    return result.exitCode == 0;
  }
}
```

---

### 3.3.5 에러 로깅 및 보고

**요구사항**:
- 모든 에러를 로그 파일에 기록
- 로그 파일 순환 보존 (30일 또는 1GB)
- 심각한 에러 발생 시 사용자에게 알림

**구현**:
```dart
// lib/services/logger_service.dart
class LoggerService {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    output: MultiOutput([
      ConsoleOutput(),
      FileOutput(file: File('logs/app.log')),
    ]),
  );

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
```

---

## Phase 3.4: 최적화 (선택 사항)

**목표**: 성능 향상 및 리소스 사용 최적화

**예상 소요**: 1~2일

### 3.4.1 하드웨어 가속 인코딩

**요구사항**:
- Intel Quick Sync Video 지원
- NVIDIA NVENC 지원
- CPU 인코딩 대비 3~5배 빠른 속도

**구현** (Media Foundation):
```cpp
// windows/runner/hardware_encoder.cpp
bool TryEnableHardwareAcceleration() {
    IMFAttributes* attributes = nullptr;
    g_sink_writer->GetSinkWriterAttributes(&attributes);

    // Hardware codec 활성화
    HRESULT hr = attributes->SetUINT32(
        CODECAPI_AVEncCommonRateControlMode,
        eAVEncCommonRateControlMode_Quality
    );

    if (SUCCEEDED(hr)) {
        printf("[C++] ✅ 하드웨어 가속 인코딩 활성화\n");
        return true;
    }

    return false;
}
```

---

### 3.4.2 적응형 비트레이트

**요구사항**:
- CPU 사용률에 따라 비트레이트 조정
- 네트워크 상태에 따라 품질 조정

---

### 3.4.3 프레임 드롭 최소화

**요구사항**:
- 인코더가 프레임을 처리할 수 없을 때 스킵하지 않고 대기
- 큐 크기 동적 조정

---

## 체크리스트

### Phase 3.1: UI 개선
- [ ] 녹화 진행률 표시 구현
- [ ] 실시간 오디오 레벨 미터 구현
- [ ] 저장 경로 선택 UI 구현
- [ ] 녹화 상태 표시 개선

### Phase 3.2: 스케줄링
- [ ] Cron 기반 예약 녹화 구현
- [ ] T-10분 헬스체크 구현
- [ ] Task Scheduler 연동
- [ ] 절전 모드 방지 구현

### Phase 3.3: 안정성
- [ ] 네트워크 단절 처리 구현
- [ ] 디스크 공간 모니터링 구현
- [ ] 장치 변경 감지 구현
- [ ] Fragmented MP4 지원 구현
- [ ] 에러 로깅 구현

### Phase 3.4: 최적화 (선택)
- [ ] 하드웨어 가속 인코딩 구현
- [ ] 적응형 비트레이트 구현
- [ ] 프레임 드롭 최소화 구현

---

## 참고 자료

### Windows API
- [Task Scheduler](https://docs.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page)
- [Power Management](https://docs.microsoft.com/en-us/windows/win32/power/power-management-portal)
- [Device Notifications](https://docs.microsoft.com/en-us/windows/win32/devio/registering-for-device-notification)

### Flutter 패키지
- [cron](https://pub.dev/packages/cron) - Cron 스케줄링
- [file_picker](https://pub.dev/packages/file_picker) - 파일/폴더 선택
- [connectivity_plus](https://pub.dev/packages/connectivity_plus) - 네트워크 모니터링

---

**작성일**: 2025-10-24
**다음 단계**: Phase 3.1.1 - 녹화 진행률 표시 구현
