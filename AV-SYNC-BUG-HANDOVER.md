# A/V 싱크 버그 분석 및 해결 방안

## 현재 상황
- **증상**: 영상이 소리보다 앞서감 (비디오가 빠름)
- **발생 조건**: 녹화 시간이 길어질수록 점점 벌어짐
- **테스트 결과**: 15분 녹화 시 명확한 싱크 불일치 확인

---

## 근본 원인 분석

### 1. PTS(Presentation Time Stamp) 계산 방식 문제

현재 코드는 비디오/오디오 PTS를 **독립적인 카운터**로 관리:

```cpp
// libav_encoder.cpp

// 비디오: 프레임마다 1씩 증가
video_frame_->pts = next_video_pts_++;  // 0, 1, 2, 3...

// 오디오: 샘플 수(1024)씩 증가
audio_frame_->pts = next_audio_pts_;
next_audio_pts_ += frame_size;  // 0, 1024, 2048...
```

**문제점**:
- 비디오는 "캡처된 프레임 수" 기준
- 오디오는 "샘플 수" 기준
- **실제 경과 시간과 무관**하게 증가

### 2. DXGI 타임아웃 시 프레임 반복 문제

방금 추가한 코드:
```cpp
// native_screen_recorder.cpp:834-844
if (hr == DXGI_ERROR_WAIT_TIMEOUT) {
    if (g_has_last_frame) {
        FrameData repeat_frame = g_last_captured_frame;
        repeat_frame.timestamp = qpc.QuadPart;
        EnqueueFrame(repeat_frame);  // 프레임 반복 추가
    }
    return true;
}
```

**문제점**:
- 정적 화면에서 100ms마다 프레임 반복 → 초당 10프레임
- 하지만 FPS는 30으로 설정 → PTS 불일치
- 오디오는 실제 시간대로 계속 흐름
- **결과: 비디오가 오디오보다 빠르게 진행**

### 3. 캡처-인코딩 비동기 구조

```
[캡처 스레드]              [인코더 스레드]
     |                          |
 DXGI 캡처                      |
     |                          |
 큐에 추가 ───────────────> 큐에서 꺼냄
     |                          |
     |                      PTS 할당
     |                          |
     |                      인코딩
```

- 캡처 시점의 타임스탬프(`frame.timestamp`)가 있지만 **인코딩 시 사용 안 함**
- 대신 단순 카운터(`next_video_pts_++`)로 PTS 할당

---

## 해결 방안

### 방안 1: 실제 타임스탬프 기반 PTS 계산 (권장)

캡처 시점의 QPC 타임스탬프를 인코더까지 전달하여 PTS 계산:

```cpp
// libav_encoder.h - EncodeVideo 시그니처 변경
bool EncodeVideo(const uint8_t* bgra_data, size_t length, uint64_t capture_timestamp);

// libav_encoder.cpp
bool LibavEncoder::EncodeVideo(const uint8_t* bgra_data, size_t length, uint64_t capture_timestamp) {
    // 실제 경과 시간 계산 (QPC → 초)
    double elapsed_sec = (capture_timestamp - recording_start_qpc_)
                         / static_cast<double>(qpc_frequency_);

    // PTS = 경과 시간 × FPS
    video_frame_->pts = static_cast<int64_t>(elapsed_sec * config_.video_fps);

    // ... 인코딩
}
```

**장점**: 실제 시간과 동기화됨
**단점**: 프레임 건너뛰기/중복 발생 가능

### 방안 2: 오디오 기준 동기화

오디오 스트림을 마스터 클럭으로 사용:

```cpp
// 오디오 PTS에서 현재 시간 역산
double current_audio_time = next_audio_pts_ / static_cast<double>(sample_rate);

// 비디오 PTS = 오디오 시간 × FPS
video_frame_->pts = static_cast<int64_t>(current_audio_time * config_.video_fps);
```

**장점**: A/V 동기화 보장
**단점**: 구현 복잡도 증가

### 방안 3: 고정 프레임 레이트 강제

타임아웃 시 프레임 반복을 제거하고, 인코더에서 듀레이션 기반으로 처리:

```cpp
// DXGI 타임아웃 시 프레임 반복 제거
if (hr == DXGI_ERROR_WAIT_TIMEOUT) {
    return true;  // 프레임 추가 안 함
}

// 대신 인코더에서 마지막 프레임 자동 반복
// FFmpeg의 -vsync cfr 옵션과 유사한 로직 구현
```

**장점**: 단순함
**단점**: 정적 화면에서 영상 멈춤 문제 재발

---

## 권장 해결책: 방안 1 구현

### 수정 파일
1. `windows/runner/libav_encoder.h`
2. `windows/runner/libav_encoder.cpp`
3. `windows/runner/native_screen_recorder.cpp`

### 구현 단계

1. **LibavEncoder에 시작 시간 저장**
```cpp
// libav_encoder.h
class LibavEncoder {
    uint64_t recording_start_qpc_ = 0;
    uint64_t qpc_frequency_ = 0;
};

// libav_encoder.cpp - Start()에서 초기화
LARGE_INTEGER freq, start;
QueryPerformanceFrequency(&freq);
QueryPerformanceCounter(&start);
qpc_frequency_ = freq.QuadPart;
recording_start_qpc_ = start.QuadPart;
```

2. **EncodeVideo에 타임스탬프 파라미터 추가**
```cpp
bool EncodeVideo(const uint8_t* bgra_data, size_t length, uint64_t capture_qpc);
```

3. **실제 시간 기반 PTS 계산**
```cpp
double elapsed_sec = static_cast<double>(capture_qpc - recording_start_qpc_)
                     / static_cast<double>(qpc_frequency_);
video_frame_->pts = static_cast<int64_t>(elapsed_sec * config_.video_fps);
```

4. **native_screen_recorder.cpp에서 타임스탬프 전달**
```cpp
// ProcessNextVideoFrame() 수정
g_libav_encoder->EncodeVideo(frame.pixels.data(), frame.pixels.size(), frame.timestamp);
```

5. **오디오도 동일하게 수정**
```cpp
bool EncodeAudio(const uint8_t* data, size_t length, uint64_t capture_qpc);
```

---

## 테스트 방법

1. **짧은 테스트 (1분)**
   - 음성이 있는 영상 재생하며 녹화
   - 재생 후 립싱크 확인

2. **긴 테스트 (15분)**
   - 시작/중간/끝 지점에서 싱크 확인
   - 점점 벌어지는지 체크

3. **정적 화면 테스트**
   - PPT 등 정적 화면 녹화
   - 오디오와 전환 시점 동기화 확인

---

## 관련 파일

| 파일 | 역할 |
|------|------|
| `windows/runner/native_screen_recorder.cpp` | DXGI/WASAPI 캡처, 큐 관리 |
| `windows/runner/libav_encoder.cpp` | FFmpeg 인코딩, PTS 할당 |
| `windows/runner/libav_encoder.h` | 인코더 인터페이스 |

---

## 참고: 현재 time_base 설정

```cpp
// libav_encoder.cpp
video_codec_ctx_->time_base = AVRational{1, config_.video_fps};  // 1/30
audio_codec_ctx_->time_base = AVRational{1, config_.audio_sample_rate};  // 1/48000
```

- 비디오 PTS 1 = 1/30초 = 33.3ms
- 오디오 PTS 1024 = 1024/48000초 = 21.3ms

---

## 작성일
2025-12-09

## 작성자
Claude (이전 세션)
