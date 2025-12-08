# Phase 3.1.2: 실시간 오디오 레벨 미터 - 완료 보고서

**작성일**: 2025-10-24
**단계**: M3 Phase 3.1.2 (UI 개선 - 오디오 레벨 표시)
**상태**: ✅ 완료

---

## 📋 목표

녹화 중 실시간 오디오 입력 레벨을 시각적으로 표시하여 사용자가 오디오 입력 상태를 모니터링할 수 있도록 함

### 요구사항
- RMS (Root Mean Square) 레벨 계산
- Peak 레벨 추적
- 시각적 레벨 미터 (색상 코드)
- dB 스케일 지원
- 1초 간격 업데이트

---

## ✅ 완료 항목

### 1. C++ 오디오 레벨 계산 (`windows/runner/native_screen_recorder.cpp`)

#### 전역 변수 추가 (라인 109-111)

```cpp
// Phase 3.1.2: 오디오 레벨 추적 (0.0 ~ 1.0)
static std::atomic<float> g_current_audio_level(0.0f);  // RMS 레벨
static std::atomic<float> g_peak_audio_level(0.0f);     // Peak 레벨
```

#### RMS 계산 함수 (라인 119-152)

```cpp
// Phase 3.1.2: 오디오 레벨 계산 헬퍼 (Float32 PCM 데이터용)
// RMS (Root Mean Square) 계산: 소리의 "에너지"를 나타냄
// 반환값: 0.0 (무음) ~ 1.0 (최대)
static float CalculateAudioLevel(const BYTE* data, UINT32 frames, UINT16 channels) {
    if (data == nullptr || frames == 0) {
        return 0.0f;
    }

    // WASAPI는 Float32 PCM (-1.0 ~ +1.0) 반환
    const float* samples = reinterpret_cast<const float*>(data);
    UINT32 total_samples = frames * channels;

    // RMS 계산: sqrt(sum(x^2) / n)
    double sum_squares = 0.0;
    float peak = 0.0f;

    for (UINT32 i = 0; i < total_samples; i++) {
        float sample = samples[i];
        sum_squares += sample * sample;

        // Peak 레벨도 추적
        float abs_sample = std::abs(sample);
        if (abs_sample > peak) {
            peak = abs_sample;
        }
    }

    float rms = static_cast<float>(std::sqrt(sum_squares / total_samples));

    // Peak 레벨 업데이트 (atomic)
    g_peak_audio_level.store(peak);

    return rms;
}
```

**구현 특징**:
- **Float32 PCM**: WASAPI는 -1.0 ~ +1.0 범위 반환
- **RMS**: 소리의 "평균 에너지" 측정
- **Peak**: 최대 진폭 추적
- **Thread-safe**: `std::atomic<float>` 사용

#### 오디오 캡처 스레드 통합 (라인 989-1026)

```cpp
// 무음 플래그 확인
if (!(flags & AUDCLNT_BUFFERFLAGS_SILENT)) {
    // Phase 3.1.2: 오디오 레벨 계산 및 업데이트
    float audio_level = CalculateAudioLevel(data, frames_available, g_wave_format->nChannels);
    g_current_audio_level.store(audio_level);

    // ... (기존 오디오 샘플 처리 코드)
} else {
    // Phase 3.1.2: 무음일 때 레벨 0으로 설정
    g_current_audio_level.store(0.0f);
    g_peak_audio_level.store(0.0f);
}
```

#### FFI Export 함수 (라인 1454-1464)

```cpp
// 현재 오디오 RMS 레벨 가져오기 (0.0 ~ 1.0)
// RMS (Root Mean Square)는 소리의 평균 에너지를 나타냄
float NativeRecorder_GetAudioLevel() {
    return g_current_audio_level.load();
}

// 현재 오디오 Peak 레벨 가져오기 (0.0 ~ 1.0)
// Peak는 최대 진폭을 나타냄
float NativeRecorder_GetAudioPeakLevel() {
    return g_peak_audio_level.load();
}
```

#### 헤더 파일 업데이트 (`windows/runner/native_screen_recorder.h`)

```cpp
/// 현재 오디오 RMS 레벨 가져오기 (Phase 3.1.2)
/// @return RMS 레벨 (0.0 ~ 1.0), 녹화 중이 아니면 0.0
NATIVE_RECORDER_EXPORT float NativeRecorder_GetAudioLevel();

/// 현재 오디오 Peak 레벨 가져오기 (Phase 3.1.2)
/// @return Peak 레벨 (0.0 ~ 1.0), 녹화 중이 아니면 0.0
NATIVE_RECORDER_EXPORT float NativeRecorder_GetAudioPeakLevel();
```

---

### 2. Dart FFI 바인딩 (`lib/ffi/native_bindings.dart`)

#### typedef 추가

```dart
// Phase 3.1.2: 오디오 레벨 조회 함수
typedef NativeGetAudioLevelFunc = ffi.Float Function();
typedef NativeGetAudioPeakLevelFunc = ffi.Float Function();

// Phase 3.1.2: Dart 오디오 레벨 조회 함수 시그니처
typedef DartGetAudioLevelFunc = double Function();
typedef DartGetAudioPeakLevelFunc = double Function();
```

#### NativeRecorderBindings 확장

```dart
/// Phase 3.1.2: 오디오 레벨 조회 함수 바인딩
static final DartGetAudioLevelFunc getAudioLevel = _lib
    .lookup<ffi.NativeFunction<NativeGetAudioLevelFunc>>('NativeRecorder_GetAudioLevel')
    .asFunction();

static final DartGetAudioPeakLevelFunc getAudioPeakLevel = _lib
    .lookup<ffi.NativeFunction<NativeGetAudioPeakLevelFunc>>('NativeRecorder_GetAudioPeakLevel')
    .asFunction();
```

---

### 3. UI 통합 (`lib/ui/widgets/recording_progress_widget.dart`)

#### RecordingProgress 데이터 클래스 확장

```dart
class RecordingProgress {
  final int elapsedMs;
  final int videoFrameCount;
  final int audioSampleCount;

  /// 오디오 RMS 레벨 (0.0 ~ 1.0) - Phase 3.1.2
  final double audioLevel;

  /// 오디오 Peak 레벨 (0.0 ~ 1.0) - Phase 3.1.2
  final double audioPeakLevel;

  RecordingProgress({
    required this.elapsedMs,
    required this.videoFrameCount,
    required this.audioSampleCount,
    required this.audioLevel,
    required this.audioPeakLevel,
  });
}
```

#### 오디오 레벨 조회 (_updateProgress 메서드)

```dart
// Phase 3.1.2: 오디오 레벨 조회
final audioLevel = NativeRecorderBindings.getAudioLevel();
final audioPeakLevel = NativeRecorderBindings.getAudioPeakLevel();

setState(() {
  _isRecording = true;
  _progress = RecordingProgress(
    elapsedMs: elapsedMs,
    videoFrameCount: videoFrameCount,
    audioSampleCount: audioSampleCount,
    audioLevel: audioLevel,
    audioPeakLevel: audioPeakLevel,
  );
});
```

#### 오디오 레벨 미터 위젯

```dart
Widget _buildAudioLevelMeter(BuildContext context, RecordingProgress progress) {
  // RMS 레벨을 dB로 변환 (-60dB ~ 0dB)
  final rmsDb = progress.audioLevel > 0.0
      ? (20 * (progress.audioLevel.clamp(0.0001, 1.0)).log10())
      : -60.0;

  // -60dB ~ 0dB를 0.0 ~ 1.0으로 정규화
  final normalizedLevel = ((rmsDb + 60) / 60).clamp(0.0, 1.0);

  // 레벨에 따라 색상 결정
  Color levelColor;
  if (normalizedLevel > 0.9) {
    levelColor = Colors.red;      // 클리핑 위험
  } else if (normalizedLevel > 0.7) {
    levelColor = Colors.orange;   // 높음
  } else if (normalizedLevel > 0.3) {
    levelColor = Colors.green;    // 적정
  } else {
    levelColor = Colors.blue;     // 낮음
  }

  return Column(
    children: [
      Row(
        children: [
          Icon(Icons.graphic_eq, size: 16),
          Text('오디오 레벨'),
          Spacer(),
          Text('${(normalizedLevel * 100).toStringAsFixed(0)}%'),
        ],
      ),
      SizedBox(height: 6),
      // 레벨 바 (ClipRRect + FractionallySizedBox)
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 8,
          child: FractionallySizedBox(
            widthFactor: normalizedLevel,
            child: Container(
              color: levelColor,
              boxShadow: [BoxShadow(color: levelColor.withOpacity(0.5))],
            ),
          ),
        ),
      ),
    ],
  );
}
```

**UI 특징**:
- **dB 스케일**: -60dB ~ 0dB → 0~100% 정규화
- **색상 코드**:
  - 파란색: 0~30% (낮음)
  - 초록색: 30~70% (적정)
  - 주황색: 70~90% (높음)
  - 빨간색: 90~100% (클리핑 위험)
- **실시간 업데이트**: 1초마다 FFI 폴링

---

## 🔧 기술적 세부 사항

### RMS vs Peak

| 지표 | 설명 | 용도 |
|------|------|------|
| **RMS** | 소리의 평균 에너지 | 전체적인 음량 표시 |
| **Peak** | 최대 진폭 | 클리핑 방지 모니터링 |

### dB 변환 공식

```
dB = 20 * log10(amplitude)

예시:
- 1.0 (최대) → 0 dB
- 0.5        → -6 dB
- 0.1        → -20 dB
- 0.01       → -40 dB
- 0.001      → -60 dB
```

### Thread Safety

- **C++**: `std::atomic<float>` 사용
- **읽기 작업**: lock-free (atomic load)
- **쓰기 작업**: 오디오 캡처 스레드에서만 수행
- **경합 없음**: 단일 writer, 단일 reader

---

## 🧪 빌드 결과

```
✅ Windows 빌드 성공
   - 빌드 시간: 22.8초
   - 출력: build\windows\x64\runner\Release\sat_lec_rec.exe
   - 경고: 없음
   - 에러: 1개 수정 (log10 함수 인자)
```

### 에러 수정

**에러**: `Too few positional arguments: 1 required, 0 given`
```dart
// 잘못된 코드
double log10() {
  return log() / ln10;  // ❌ log() 인자 누락
}

// 수정된 코드
double log10() {
  return log(this) / ln10;  // ✅ this 전달
}
```

---

## 📈 예상 동작

### 무음 상태
- RMS 레벨: 0.0
- Peak 레벨: 0.0
- UI: 파란색 바 (0%)

### 정상 대화 (Zoom 강의)
- RMS 레벨: 0.1 ~ 0.3 (-20dB ~ -10dB)
- UI: 초록색 바 (30~70%)

### 높은 음량
- RMS 레벨: 0.5 ~ 0.7 (-6dB ~ -3dB)
- UI: 주황색 바 (70~90%)

### 클리핑 위험
- RMS 레벨: 0.9+ (-1dB ~ 0dB)
- UI: 빨간색 바 (90~100%)

---

## 📝 코드 변경 통계

| 파일 | 추가 | 수정 | 삭제 |
|------|------|------|------|
| `windows/runner/native_screen_recorder.cpp` | +53 | +8 | 0 |
| `windows/runner/native_screen_recorder.h` | +8 | 0 | 0 |
| `lib/ffi/native_bindings.dart` | +12 | 0 | 0 |
| `lib/ui/widgets/recording_progress_widget.dart` | +93 | +12 | 0 |
| **합계** | **+166** | **+20** | **0** |

---

## 🎯 사용성 개선 효과

### Before (Phase 3.1.2 이전)
- 오디오 입력 상태 알 수 없음
- 마이크 음소거 여부 확인 불가
- 음량 과다/부족 감지 불가

### After (Phase 3.1.2 이후)
- ✅ 실시간 오디오 레벨 모니터링
- ✅ 색상 코드로 즉각적인 피드백
- ✅ 클리핑 위험 사전 경고
- ✅ 마이크 입력 정상 동작 확인

---

## 🚀 다음 단계

### Phase 3.2: 스케줄링 (계획)
- **3.2.1**: Cron 기반 예약 녹화
- **3.2.2**: T-10 헬스체크 (Zoom 창 확인)
- **3.2.3**: Windows Task Scheduler 통합

### Phase 3.3: 안정성 (중요!)
- **3.3.1**: 네트워크 단절 처리
- **3.3.2**: 디스크 공간 모니터링
- **3.3.3**: **Fragmented MP4 (중단 복구 핵심!)**
- **3.3.4**: 오디오/비디오 장치 변경 대응

---

## 📚 참고 자료

- **오디오 레벨 측정**: [RMS vs Peak Explained](https://www.audiologyonline.com/)
- **dB 스케일**: [Decibel Scale Calculator](https://www.sengpielaudio.com/calculator-db.htm)
- **WASAPI Audio**: [Microsoft Docs - WASAPI](https://learn.microsoft.com/en-us/windows/win32/coreaudio/wasapi)
- **Flutter CustomPainter**: [Custom Paint Tutorial](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)

---

**작성자**: Claude Code
**검토**: Phase 3.1.2 완료 후 작성
**다음 문서**: `m3-phase-3.2-progress.md` (Phase 3.2 완료 시)
