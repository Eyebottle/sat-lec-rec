# M2 Phase 2.3: Media Foundation 인코더

**목표**: Media Foundation을 사용하여 H.264/AAC 인코딩 및 MP4 파일 저장

**예상 소요 시간**: 3~5일

**의존성**: M2 Phase 2.1 완료, M2 Phase 2.2 완료

**작성일**: 2025-10-23

---

## 개요

### Media Foundation이란?

Windows Vista부터 도입된 멀티미디어 프레임워크로, 비디오/오디오 캡처, 인코딩, 디코딩, 재생을 지원합니다.

**Sink Writer**:
- 비디오/오디오 스트림을 파일로 저장
- H.264 비디오 + AAC 오디오 → MP4 컨테이너
- 타임스탬프 기반 자동 인터리빙
- Hardware acceleration 지원 (Intel QSV, NVIDIA NVENC)

**장점**:
- Windows 기본 내장 (추가 설치 불필요)
- 하드웨어 가속 자동 선택
- 안정적인 MP4 생성
- 낮은 CPU 오버헤드

---

## 아키텍처

```
[DXGI Capture Thread]          [WASAPI Capture Thread]
        ↓                               ↓
[Video Frame Queue]            [Audio Sample Queue]
        ↓                               ↓
        └──────────┬────────────────────┘
                   ↓
        [Encoder Thread]
                   ↓
        [IMFSinkWriter]
           ↓         ↓
    [Video Stream] [Audio Stream]
       (H.264)       (AAC)
           ↓         ↓
           └────┬────┘
                ↓
           [MP4 File]
```

**핵심 개념**:
1. **Sink Writer**: MP4 파일 작성기
2. **Video Stream**: H.264 인코더 연결
3. **Audio Stream**: AAC 인코더 연결
4. **Sample 전달**: 타임스탬프 순서로 프레임/샘플 전달
5. **Interleaving**: A/V 자동 믹싱

---

## 구현 단계

### 1. Media Foundation 초기화

#### 1.1 헤더 및 라이브러리 추가

**파일**: `windows/runner/native_screen_recorder.cpp`

```cpp
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <codecapi.h>

#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
```

#### 1.2 전역 변수 추가

```cpp
// Media Foundation 관련
static IMFSinkWriter* g_sink_writer = nullptr;
static DWORD g_video_stream_index = 0;
static DWORD g_audio_stream_index = 0;
static std::thread g_encoder_thread;

// 타임스탬프 관리
static LARGE_INTEGER g_recording_start_qpc;
static LARGE_INTEGER g_qpc_frequency;
static LONGLONG g_video_frame_count = 0;
static LONGLONG g_audio_sample_count = 0;
```

#### 1.3 InitializeMediaFoundation() 함수

```cpp
static bool InitializeMediaFoundation() {
    HRESULT hr;

    // Media Foundation 시작
    hr = MFStartup(MF_VERSION, MFSTARTUP_NOSOCKET);
    if (FAILED(hr)) {
        SetLastError("Media Foundation 초기화 실패");
        return false;
    }

    // 타임스탬프 초기화
    QueryPerformanceFrequency(&g_qpc_frequency);
    QueryPerformanceCounter(&g_recording_start_qpc);

    return true;
}
```

---

### 2. Sink Writer 생성

#### 2.1 출력 파일 생성

```cpp
static bool CreateSinkWriter(const wchar_t* output_file) {
    HRESULT hr;

    // Sink Writer 속성 설정
    IMFAttributes* attributes = nullptr;
    hr = MFCreateAttributes(&attributes, 1);
    if (FAILED(hr)) return false;

    // 하드웨어 가속 활성화
    hr = attributes->SetUINT32(MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS, TRUE);

    // Sink Writer 생성
    hr = MFCreateSinkWriterFromURL(
        output_file,
        nullptr,
        attributes,
        &g_sink_writer
    );
    attributes->Release();

    if (FAILED(hr)) {
        SetLastError("Sink Writer 생성 실패");
        return false;
    }

    return true;
}
```

---

### 3. H.264 비디오 스트림 설정

#### 3.1 출력 미디어 타입 (H.264)

```cpp
static bool ConfigureVideoStream(int width, int height, int fps) {
    HRESULT hr;

    // 출력 미디어 타입 (H.264)
    IMFMediaType* video_output_type = nullptr;
    hr = MFCreateMediaType(&video_output_type);
    if (FAILED(hr)) return false;

    // H.264 포맷 설정
    video_output_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    video_output_type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
    video_output_type->SetUINT32(MF_MT_AVG_BITRATE, 5000000);  // 5 Mbps
    video_output_type->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
    video_output_type->SetUINT32(MF_MT_MPEG2_PROFILE, eAVEncH264VProfile_High);

    // 해상도 설정
    hr = MFSetAttributeSize(video_output_type, MF_MT_FRAME_SIZE, width, height);

    // 프레임 레이트 설정 (30fps)
    hr = MFSetAttributeRatio(video_output_type, MF_MT_FRAME_RATE, fps, 1);

    // 픽셀 종횡비 (1:1)
    hr = MFSetAttributeRatio(video_output_type, MF_MT_PIXEL_ASPECT_RATIO, 1, 1);

    // 비디오 스트림 추가
    hr = g_sink_writer->AddStream(video_output_type, &g_video_stream_index);
    video_output_type->Release();

    if (FAILED(hr)) {
        SetLastError("비디오 스트림 추가 실패");
        return false;
    }

    return true;
}
```

#### 3.2 입력 미디어 타입 (BGRA32)

```cpp
static bool ConfigureVideoInputType(int width, int height, int fps) {
    HRESULT hr;

    // 입력 미디어 타입 (BGRA32 from DXGI)
    IMFMediaType* video_input_type = nullptr;
    hr = MFCreateMediaType(&video_input_type);
    if (FAILED(hr)) return false;

    video_input_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    video_input_type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);  // BGRA
    video_input_type->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);

    hr = MFSetAttributeSize(video_input_type, MF_MT_FRAME_SIZE, width, height);
    hr = MFSetAttributeRatio(video_input_type, MF_MT_FRAME_RATE, fps, 1);
    hr = MFSetAttributeRatio(video_input_type, MF_MT_PIXEL_ASPECT_RATIO, 1, 1);

    // 입력 타입 설정
    hr = g_sink_writer->SetInputMediaType(g_video_stream_index, video_input_type, nullptr);
    video_input_type->Release();

    if (FAILED(hr)) {
        SetLastError("비디오 입력 타입 설정 실패");
        return false;
    }

    return true;
}
```

---

### 4. AAC 오디오 스트림 설정

#### 4.1 출력 미디어 타입 (AAC)

```cpp
static bool ConfigureAudioStream() {
    HRESULT hr;

    // 출력 미디어 타입 (AAC)
    IMFMediaType* audio_output_type = nullptr;
    hr = MFCreateMediaType(&audio_output_type);
    if (FAILED(hr)) return false;

    // AAC 포맷 설정
    audio_output_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
    audio_output_type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_AAC);
    audio_output_type->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, 48000);
    audio_output_type->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, 2);
    audio_output_type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
    audio_output_type->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, 24000);  // 192 kbps

    // 오디오 스트림 추가
    hr = g_sink_writer->AddStream(audio_output_type, &g_audio_stream_index);
    audio_output_type->Release();

    if (FAILED(hr)) {
        SetLastError("오디오 스트림 추가 실패");
        return false;
    }

    return true;
}
```

#### 4.2 입력 미디어 타입 (PCM Float32)

```cpp
static bool ConfigureAudioInputType() {
    HRESULT hr;

    // 입력 미디어 타입 (PCM Float32 from WASAPI)
    IMFMediaType* audio_input_type = nullptr;
    hr = MFCreateMediaType(&audio_input_type);
    if (FAILED(hr)) return false;

    audio_input_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
    audio_input_type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_Float);  // WASAPI Float32
    audio_input_type->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,
                                 g_wave_format->nSamplesPerSec);
    audio_input_type->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS,
                                 g_wave_format->nChannels);
    audio_input_type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE,
                                 g_wave_format->wBitsPerSample);

    // 입력 타입 설정
    hr = g_sink_writer->SetInputMediaType(g_audio_stream_index, audio_input_type, nullptr);
    audio_input_type->Release();

    if (FAILED(hr)) {
        SetLastError("오디오 입력 타입 설정 실패");
        return false;
    }

    return true;
}
```

---

### 5. 인코더 스레드 구현

#### 5.1 인코더 메인 루프

```cpp
static void EncoderThreadFunc() {
    HRESULT hr;

    // 인코딩 시작
    hr = g_sink_writer->BeginWriting();
    if (FAILED(hr)) {
        SetLastError("인코딩 시작 실패");
        g_is_recording = false;
        return;
    }

    while (g_is_recording) {
        // 비디오 프레임 처리
        if (!g_frame_queue.empty()) {
            ProcessVideoFrame();
        }

        // 오디오 샘플 처리
        if (!g_audio_queue.empty()) {
            ProcessAudioSample();
        }

        // CPU 절약
        Sleep(5);
    }

    // 인코딩 종료
    hr = g_sink_writer->Finalize();
    if (FAILED(hr)) {
        SetLastError("인코딩 종료 실패");
    }
}
```

#### 5.2 비디오 프레임 처리

```cpp
static void ProcessVideoFrame() {
    std::lock_guard<std::mutex> lock(g_frame_queue_mutex);

    if (g_frame_queue.empty()) return;

    FrameData frame = g_frame_queue.front();
    g_frame_queue.pop();

    // IMFSample 생성
    IMFSample* sample = nullptr;
    IMFMediaBuffer* buffer = nullptr;

    HRESULT hr = MFCreateMemoryBuffer(frame.data.size(), &buffer);
    if (FAILED(hr)) return;

    // 데이터 복사
    BYTE* buffer_data = nullptr;
    buffer->Lock(&buffer_data, nullptr, nullptr);
    memcpy(buffer_data, frame.data.data(), frame.data.size());
    buffer->Unlock();
    buffer->SetCurrentLength(frame.data.size());

    // Sample 생성
    hr = MFCreateSample(&sample);
    sample->AddBuffer(buffer);
    buffer->Release();

    // 타임스탬프 설정 (100-nanosecond 단위)
    LONGLONG timestamp = CalculateVideoTimestamp();
    sample->SetSampleTime(timestamp);

    // Duration 설정 (33ms for 30fps)
    LONGLONG duration = 333333;  // 1/30 sec in 100ns units
    sample->SetSampleDuration(duration);

    // Sink Writer에 전달
    hr = g_sink_writer->WriteSample(g_video_stream_index, sample);
    sample->Release();

    if (SUCCEEDED(hr)) {
        g_video_frame_count++;
    }
}
```

#### 5.3 오디오 샘플 처리

```cpp
static void ProcessAudioSample() {
    std::lock_guard<std::mutex> lock(g_audio_queue_mutex);

    if (g_audio_queue.empty()) return;

    AudioSample audio = g_audio_queue.front();
    g_audio_queue.pop();

    // IMFSample 생성
    IMFSample* sample = nullptr;
    IMFMediaBuffer* buffer = nullptr;

    HRESULT hr = MFCreateMemoryBuffer(audio.data.size(), &buffer);
    if (FAILED(hr)) return;

    // 데이터 복사
    BYTE* buffer_data = nullptr;
    buffer->Lock(&buffer_data, nullptr, nullptr);
    memcpy(buffer_data, audio.data.data(), audio.data.size());
    buffer->Unlock();
    buffer->SetCurrentLength(audio.data.size());

    // Sample 생성
    hr = MFCreateSample(&sample);
    sample->AddBuffer(buffer);
    buffer->Release();

    // 타임스탬프 설정
    LONGLONG timestamp = CalculateAudioTimestamp(audio.frame_count);
    sample->SetSampleTime(timestamp);

    // Duration 설정
    LONGLONG duration = (audio.frame_count * 10000000LL) / audio.sample_rate;
    sample->SetSampleDuration(duration);

    // Sink Writer에 전달
    hr = g_sink_writer->WriteSample(g_audio_stream_index, sample);
    sample->Release();

    if (SUCCEEDED(hr)) {
        g_audio_sample_count++;
    }
}
```

---

### 6. 타임스탬프 동기화

#### 6.1 상대 타임스탬프 계산

```cpp
static LONGLONG CalculateVideoTimestamp() {
    // 프레임 번호 기반 타임스탬프 (30fps 가정)
    return (g_video_frame_count * 10000000LL) / 30;
}

static LONGLONG CalculateAudioTimestamp(UINT32 frame_count) {
    // 누적 샘플 수 기반 타임스탬프
    LONGLONG timestamp = (g_audio_sample_count * 10000000LL) / 48000;
    return timestamp;
}
```

**주의사항**:
- 비디오와 오디오는 각각 독립적으로 타임스탬프 계산
- Sink Writer가 자동으로 인터리빙
- 드리프트 발생 시 QPC 기반으로 재동기화 필요 (Phase 3)

---

### 7. 리소스 정리

```cpp
static void CleanupMediaFoundation() {
    if (g_sink_writer) {
        g_sink_writer->Release();
        g_sink_writer = nullptr;
    }

    MFShutdown();
}
```

---

## 통합 시나리오

### 녹화 시작 플로우

```cpp
bool StartRecording(const wchar_t* output_file, int width, int height) {
    // 1. Media Foundation 초기화
    if (!InitializeMediaFoundation()) return false;

    // 2. Sink Writer 생성
    if (!CreateSinkWriter(output_file)) return false;

    // 3. 비디오 스트림 설정
    if (!ConfigureVideoStream(width, height, 30)) return false;
    if (!ConfigureVideoInputType(width, height, 30)) return false;

    // 4. 오디오 스트림 설정
    if (!ConfigureAudioStream()) return false;
    if (!ConfigureAudioInputType()) return false;

    // 5. DXGI/WASAPI 초기화
    if (!InitializeDXGIDuplication()) return false;
    if (!InitializeWASAPI()) return false;

    // 6. 캡처 스레드 시작
    g_is_recording = true;
    g_capture_thread = std::thread(CaptureThreadFunc);
    g_audio_thread = std::thread(AudioCaptureThreadFunc);
    g_encoder_thread = std::thread(EncoderThreadFunc);

    return true;
}
```

### 녹화 중지 플로우

```cpp
void StopRecording() {
    g_is_recording = false;

    // 스레드 종료 대기
    if (g_capture_thread.joinable()) g_capture_thread.join();
    if (g_audio_thread.joinable()) g_audio_thread.join();
    if (g_encoder_thread.joinable()) g_encoder_thread.join();

    // 리소스 정리
    CleanupWASAPI();
    CleanupDXGIDuplication();
    CleanupMediaFoundation();
}
```

---

## 테스트 시나리오

### 테스트 1: MP4 파일 생성 확인

**방법**: 10초 녹화 후 파일 확인

**예상 결과**:
```
output.mp4 파일 생성됨 (약 6~10MB)
VLC/Windows Media Player에서 재생 가능
```

### 테스트 2: 비디오 품질 확인

**방법**: YouTube 4K 동영상 녹화

**확인 항목**:
- 해상도 정확한지
- 프레임 드롭 없는지
- 색상 왜곡 없는지

### 테스트 3: 오디오/비디오 싱크

**방법**: 음악 MV 녹화

**확인 항목**:
- 립싱크 정확한지
- 오디오 끊김 없는지
- A/V 드리프트 없는지

### 테스트 4: 장시간 녹화 (60분)

**확인 항목**:
- 파일 크기 정상 (약 2GB)
- CPU 사용률 50% 이하
- 메모리 누수 없음

---

## 체크리스트

### Phase 2.3 작업 항목
- [ ] Media Foundation 헤더 및 라이브러리 추가
- [ ] InitializeMediaFoundation() 구현
- [ ] CreateSinkWriter() 구현
- [ ] H.264 비디오 스트림 설정
- [ ] AAC 오디오 스트림 설정
- [ ] 인코더 스레드 구현
- [ ] 비디오 프레임 → IMFSample 변환
- [ ] 오디오 샘플 → IMFSample 변환
- [ ] 타임스탬프 동기화 로직
- [ ] MP4 파일 생성 테스트
- [ ] 재생 가능 여부 확인
- [ ] A/V 싱크 확인

---

## 일반적인 문제 및 해결

### 문제 1: "Unsupported media type" 에러

**원인**: 입력/출력 미디어 타입 불일치

**해결**:
- 입력 타입 (BGRA32, Float32)과 출력 타입 (H.264, AAC) 정확히 설정
- MF_MT_FRAME_SIZE, MF_MT_FRAME_RATE 일치 확인

### 문제 2: MP4 파일이 재생 안 됨

**원인**: Finalize() 호출 안 함

**해결**:
- 녹화 종료 시 반드시 `g_sink_writer->Finalize()` 호출
- Finalize() 전에 모든 Sample 전달 완료 확인

### 문제 3: A/V 싱크 어긋남

**원인**: 타임스탬프 계산 오류

**해결**:
- 비디오: 프레임 번호 × (1/fps)
- 오디오: 샘플 수 × (1/sample_rate)
- 단위는 100-nanosecond (10^-7초)

### 문제 4: 하드웨어 가속 안 됨

**확인**: Task Manager → Performance → GPU → Video Encode

**해결**: Intel QSV/NVIDIA NVENC 드라이버 최신화

---

## 참고 자료

### 공식 문서
- [Media Foundation](https://docs.microsoft.com/en-us/windows/win32/medfound/microsoft-media-foundation-sdk)
- [Sink Writer](https://docs.microsoft.com/en-us/windows/win32/medfound/sink-writer)
- [H.264 Video Encoder](https://docs.microsoft.com/en-us/windows/win32/medfound/h-264-video-encoder)

### 샘플 코드
- [MFCaptureToFile](https://github.com/microsoft/Windows-classic-samples/tree/main/Samples/Win7Samples/multimedia/mediafoundation/MFCaptureToFile)

---

**작성일**: 2025-10-23
**다음 단계**: Phase 3.1 (실시간 모니터링 UI)
**예상 완료일**: 2025-10-28
