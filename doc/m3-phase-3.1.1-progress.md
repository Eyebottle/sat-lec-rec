# Phase 3.1.1: 녹화 진행률 표시 - 완료 보고서

**작성일**: 2025-10-24
**단계**: M3 Phase 3.1.1 (UI 개선 - 진행률 표시)
**상태**: ✅ 완료

---

## 📋 목표

녹화 중 실시간 진행 상황을 사용자에게 시각적으로 표시하여 사용성 향상

### 요구사항
- 경과 시간 (MM:SS 형식)
- 비디오 프레임 수
- 오디오 샘플 수
- 예상 파일 크기
- 녹화 중일 때만 표시
- 1초 간격 자동 업데이트

---

## ✅ 완료 항목

### 1. C++ 네이티브 레이어 (`windows/runner/native_screen_recorder.cpp`)

#### 새로 추가된 함수들 (라인 1375-1400)

```cpp
// 현재까지 인코딩된 비디오 프레임 수 가져오기
int64_t NativeRecorder_GetVideoFrameCount() {
    return g_video_frame_count;
}

// 현재까지 인코딩된 오디오 샘플 수 가져오기
int64_t NativeRecorder_GetAudioSampleCount() {
    return g_audio_sample_count;
}

// 녹화 시작 이후 경과 시간 (밀리초)
// 녹화 중이 아니면 0 반환
int64_t NativeRecorder_GetElapsedTimeMs() {
    if (!g_is_recording) {
        return 0;
    }

    LARGE_INTEGER current_qpc;
    QueryPerformanceCounter(&current_qpc);

    // QPC 카운트 차이를 밀리초로 변환
    int64_t elapsed_counts = current_qpc.QuadPart - g_recording_start_qpc.QuadPart;
    int64_t elapsed_ms = (elapsed_counts * 1000LL) / g_qpc_frequency.QuadPart;

    return elapsed_ms;
}
```

**구현 특징**:
- **QueryPerformanceCounter 사용**: 고정밀 타이머 (마이크로초 단위 정확도)
- **Int64 반환**: Dart에서 큰 숫자 처리 가능
- **Thread-safe**: 전역 atomic/mutex 변수 읽기만 수행

#### 헤더 파일 업데이트 (`windows/runner/native_screen_recorder.h`)

```cpp
/// 현재까지 인코딩된 비디오 프레임 수 가져오기
/// @return 비디오 프레임 수
NATIVE_RECORDER_EXPORT int64_t NativeRecorder_GetVideoFrameCount();

/// 현재까지 인코딩된 오디오 샘플 수 가져오기
/// @return 오디오 샘플 수
NATIVE_RECORDER_EXPORT int64_t NativeRecorder_GetAudioSampleCount();

/// 녹화 시작 이후 경과 시간 가져오기 (밀리초)
/// @return 경과 시간 (ms), 녹화 중이 아니면 0
NATIVE_RECORDER_EXPORT int64_t NativeRecorder_GetElapsedTimeMs();
```

---

### 2. Dart FFI 바인딩 (`lib/ffi/native_bindings.dart`)

#### typedef 추가

```dart
// Phase 3.1.1: 녹화 진행률 조회 함수
typedef NativeGetVideoFrameCountFunc = ffi.Int64 Function();
typedef NativeGetAudioSampleCountFunc = ffi.Int64 Function();
typedef NativeGetElapsedTimeMsFunc = ffi.Int64 Function();

// Phase 3.1.1: Dart 진행률 조회 함수 시그니처
typedef DartGetVideoFrameCountFunc = int Function();
typedef DartGetAudioSampleCountFunc = int Function();
typedef DartGetElapsedTimeMsFunc = int Function();
```

#### NativeRecorderBindings 클래스 확장

```dart
/// Phase 3.1.1: 녹화 진행률 조회 함수 바인딩
static final DartGetVideoFrameCountFunc getVideoFrameCount = _lib
    .lookup<ffi.NativeFunction<NativeGetVideoFrameCountFunc>>('NativeRecorder_GetVideoFrameCount')
    .asFunction();

static final DartGetAudioSampleCountFunc getAudioSampleCount = _lib
    .lookup<ffi.NativeFunction<NativeGetAudioSampleCountFunc>>('NativeRecorder_GetAudioSampleCount')
    .asFunction();

static final DartGetElapsedTimeMsFunc getElapsedTimeMs = _lib
    .lookup<ffi.NativeFunction<NativeGetElapsedTimeMsFunc>>('NativeRecorder_GetElapsedTimeMs')
    .asFunction();
```

---

### 3. UI 위젯 (`lib/ui/widgets/recording_progress_widget.dart`)

#### RecordingProgress 데이터 클래스

```dart
class RecordingProgress {
  final int elapsedMs;
  final int videoFrameCount;
  final int audioSampleCount;

  // MM:SS 형식 변환
  String get formattedTime {
    final seconds = elapsedMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // 예상 파일 크기 (H.264 5Mbps + AAC 192kbps ≈ 0.65 MB/초)
  double get estimatedFileSizeMB {
    final seconds = elapsedMs / 1000.0;
    return seconds * 0.65;
  }
}
```

#### RecordingProgressWidget 위젯

**주요 기능**:
- **Timer.periodic(1초)**: FFI 폴링으로 실시간 업데이트
- **조건부 렌더링**: 녹화 중이 아니면 `SizedBox.shrink()` 반환
- **빨간 점 애니메이션**: BoxShadow로 "녹화 중" 시각적 강조
- **숫자 포맷팅**: K/M 단위로 큰 숫자 간결하게 표시

**UI 구성**:
```
┌────────────────────────────────────────┐
│ 🔴 녹화 중              00:15          │
│                                        │
│  📹 비디오 프레임    🎵 오디오 샘플   │
│     360                2.3M           │
│                                        │
│  💾 예상 크기                          │
│     9.8 MB                            │
└────────────────────────────────────────┘
```

---

### 4. 메인 화면 통합 (`lib/main.dart`)

#### import 추가
```dart
import 'ui/widgets/recording_progress_widget.dart';
```

#### 위젯 배치 (예약 카드와 상태 카드 사이)
```dart
const SizedBox(height: 16),
// 녹화 진행률 표시 (Phase 3.1.1)
const RecordingProgressWidget(),
const SizedBox(height: 16),
// 상태 표시 카드
Card(...),
```

---

## 🔧 기술적 세부 사항

### 타이밍 정확도

- **QueryPerformanceCounter**: Windows 고해상도 타이머
  - 주파수: 시스템마다 다름 (일반적으로 ~10MHz)
  - 정확도: 마이크로초 단위
  - 오버헤드: 매우 낮음 (~100ns)

### 메모리 사용량

- **Timer 오버헤드**: 1초마다 FFI 호출 3회
- **상태 객체**: RecordingProgress (~24 bytes)
- **전체 영향**: 무시 가능 수준 (<1MB)

### Thread Safety

- **읽기 전용 접근**: getter 함수는 atomic 변수만 읽음
- **경합 없음**: g_video_frame_count, g_audio_sample_count는 atomic
- **Mutex 불필요**: QueryPerformanceCounter는 thread-safe

---

## 🧪 테스트 결과

### 빌드 테스트
```
✅ Windows 빌드 성공
   - 빌드 시간: 27.8초
   - 출력: build\windows\x64\runner\Release\sat_lec_rec.exe
   - 경고: 없음
   - 에러: 없음
```

### 예상 동작 시나리오

1. **앱 시작 시**: RecordingProgressWidget 숨김 (녹화 중 아님)
2. **"10초 테스트" 클릭**:
   - 0초: 진행률 카드 나타남
   - 1~10초: 경과 시간 증가 (00:01, 00:02, ...)
   - 10초: 녹화 종료, 카드 사라짐
3. **프레임 수**:
   - 24fps 기준 → 10초에 ~240 프레임 표시
4. **오디오 샘플**:
   - 48kHz × 10초 = 480K 샘플 → "480.0K" 표시
5. **예상 크기**:
   - 10초 × 0.65 MB/s ≈ 6.5 MB 표시

---

## 📈 성능 영향

### CPU 사용량
- **FFI 호출**: 1초당 3회 (무시 가능)
- **UI 업데이트**: setState() 1초당 1회
- **예상 증가**: <1% CPU

### 메모리
- **위젯 오버헤드**: ~100 KB
- **Timer 오버헤드**: ~10 KB

### 전력 소비
- **Timer wake-up**: 1초당 1회 (매우 낮음)

---

## 🎯 사용성 개선 효과

### Before (Phase 3.1.1 이전)
- 녹화 시작 후 진행 상황 알 수 없음
- 정상 동작 여부 확인 불가
- 사용자 불안감 증가

### After (Phase 3.1.1 이후)
- ✅ 실시간 경과 시간 표시
- ✅ 프레임/샘플 수로 녹화 활동 확인
- ✅ 예상 파일 크기로 디스크 공간 예측
- ✅ 빨간 점으로 녹화 중 명확한 시각적 표시

---

## 📝 코드 변경 통계

| 파일 | 추가 | 수정 | 삭제 |
|------|------|------|------|
| `windows/runner/native_screen_recorder.cpp` | +35 | 0 | 0 |
| `windows/runner/native_screen_recorder.h` | +12 | 0 | 0 |
| `lib/ffi/native_bindings.dart` | +18 | 0 | 0 |
| `lib/ui/widgets/recording_progress_widget.dart` | +237 | 0 | 0 |
| `lib/main.dart` | +4 | +2 | 0 |
| **합계** | **+306** | **+2** | **0** |

---

## 🚀 다음 단계

### Phase 3.1.2: 실시간 오디오 레벨 미터
- C++ FFI: `GetAudioLevel()` 추가 (RMS 또는 Peak 레벨)
- Dart UI: `AudioLevelMeter` 위젯 작성
- 녹화 진행률 카드에 통합

### Phase 3.2: 스케줄링 (예정)
- Cron 기반 예약
- T-10 헬스체크

### Phase 3.3: 안정성 (중요!)
- 네트워크 단절 처리
- 디스크 공간 모니터링
- Fragmented MP4 (중단 시 복구)

---

## 📚 참고 자료

- **Windows API**: [QueryPerformanceCounter](https://learn.microsoft.com/en-us/windows/win32/api/profileapi/nf-profileapi-queryperformancecounter)
- **Flutter Timer**: [Timer class](https://api.flutter.dev/flutter/dart-async/Timer-class.html)
- **Material 3 Design**: [Cards](https://m3.material.io/components/cards/overview)

---

**작성자**: Claude Code
**검토**: Phase 3.1.1 완료 후 작성
**다음 문서**: `m3-phase-3.1.2-progress.md` (Phase 3.1.2 완료 시)
