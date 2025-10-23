# M2 Phase 2.2: WASAPI Loopback 오디오 캡처

**목표**: WASAPI (Windows Audio Session API)를 사용하여 시스템 오디오(Loopback) 캡처

**예상 소요 시간**: 2~3일

**의존성**: M1 Phase 1.2 완료, M2 Phase 2.1 진행 중 (병렬 가능)

**작성일**: 2025-10-23

---

## 개요

### WASAPI란?

Windows Vista부터 도입된 저수준 오디오 API로, 낮은 지연시간과 높은 품질의 오디오 캡처/재생을 지원합니다.

**Loopback 모드**:
- 스피커로 출력되는 모든 오디오를 캡처
- Zoom 소리, 시스템 소리 등 모두 포함
- 마이크는 별도로 믹싱 필요 (Phase 3)

**장점**:
- 낮은 CPU 사용률
- 고품질 PCM 오디오
- 실시간 캡처 가능

---

## 아키텍처

```
[시스템 오디오]
       ↓
[IMMDeviceEnumerator] → 기본 Render 장치 가져오기
       ↓
[IMMDevice] (Loopback)
       ↓
[IAudioClient] → 초기화 (Loopback 모드)
       ↓
[IAudioCaptureClient]
       ↓
[오디오 샘플 읽기 루프]
       ↓
[오디오 버퍼 큐] → Phase 2.3 (인코더)
```

---

## 구현 단계

### 1. 기본 오디오 장치 가져오기

#### 1.1 IMMDeviceEnumerator 초기화

**파일**: `windows/runner/audio_capture.cpp` (신규 파일)

```cpp
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <comdef.h>

// 전역 변수
static IMMDevice* g_audio_device = nullptr;
static IAudioClient* g_audio_client = nullptr;
static IAudioCaptureClient* g_capture_client = nullptr;
static WAVEFORMATEX* g_wave_format = nullptr;

bool InitializeAudioDevice() {
    HRESULT hr;

    // Device Enumerator 생성
    IMMDeviceEnumerator* enumerator = nullptr;
    hr = CoCreateInstance(
        __uuidof(MMDeviceEnumerator),
        nullptr,
        CLSCTX_ALL,
        __uuidof(IMMDeviceEnumerator),
        (void**)&enumerator
    );
    if (FAILED(hr)) {
        SetLastError("MMDeviceEnumerator 생성 실패");
        return false;
    }

    // 기본 Render 장치 가져오기 (스피커 출력)
    hr = enumerator->GetDefaultAudioEndpoint(
        eRender,      // 렌더 (출력) 장치
        eConsole,     // 콘솔 역할
        &g_audio_device
    );
    enumerator->Release();

    if (FAILED(hr)) {
        SetLastError("기본 오디오 장치 가져오기 실패");
        return false;
    }

    return true;
}
```

---

### 2. IAudioClient 초기화 (Loopback 모드)

#### 2.1 AudioClient 생성 및 포맷 가져오기

```cpp
bool InitializeAudioClient() {
    HRESULT hr;

    // IAudioClient 가져오기
    hr = g_audio_device->Activate(
        __uuidof(IAudioClient),
        CLSCTX_ALL,
        nullptr,
        (void**)&g_audio_client
    );
    if (FAILED(hr)) {
        SetLastError("IAudioClient 생성 실패");
        return false;
    }

    // 오디오 포맷 가져오기
    hr = g_audio_client->GetMixFormat(&g_wave_format);
    if (FAILED(hr)) {
        SetLastError("오디오 포맷 가져오기 실패");
        return false;
    }

    // 포맷 정보 로깅
    char log_msg[256];
    sprintf(log_msg, "오디오 포맷: %d Hz, %d channels, %d bits",
            g_wave_format->nSamplesPerSec,
            g_wave_format->nChannels,
            g_wave_format->wBitsPerSample);
    // 로그 출력

    return true;
}
```

#### 2.2 Loopback 모드로 초기화

```cpp
bool StartAudioCapture() {
    HRESULT hr;

    // 버퍼 크기 계산 (100ms)
    REFERENCE_TIME buffer_duration = 100 * 10000;  // 100ms in 100-nanosecond units

    // Loopback 모드로 초기화
    hr = g_audio_client->Initialize(
        AUDCLNT_SHAREMODE_SHARED,        // Shared 모드
        AUDCLNT_STREAMFLAGS_LOOPBACK,    // Loopback 플래그 (핵심!)
        buffer_duration,
        0,
        g_wave_format,
        nullptr
    );
    if (FAILED(hr)) {
        SetLastError("AudioClient 초기화 실패");
        return false;
    }

    // 실제 버퍼 크기 가져오기
    UINT32 buffer_frame_count;
    g_audio_client->GetBufferSize(&buffer_frame_count);

    // IAudioCaptureClient 가져오기
    hr = g_audio_client->GetService(
        __uuidof(IAudioCaptureClient),
        (void**)&g_capture_client
    );
    if (FAILED(hr)) {
        SetLastError("IAudioCaptureClient 가져오기 실패");
        return false;
    }

    // 캡처 시작
    hr = g_audio_client->Start();
    if (FAILED(hr)) {
        SetLastError("오디오 캡처 시작 실패");
        return false;
    }

    return true;
}
```

---

### 3. 오디오 샘플 캡처 루프

#### 3.1 캡처 스레드 함수

```cpp
void AudioCaptureThreadFunc() {
    HRESULT hr;
    UINT32 packet_length = 0;

    while (g_is_recording) {
        // 사용 가능한 패킷 확인
        hr = g_capture_client->GetNextPacketSize(&packet_length);
        if (FAILED(hr)) break;

        while (packet_length != 0) {
            // 오디오 데이터 가져오기
            BYTE* data;
            UINT32 frames_available;
            DWORD flags;

            hr = g_capture_client->GetBuffer(
                &data,
                &frames_available,
                &flags,
                nullptr,
                nullptr
            );

            if (FAILED(hr)) break;

            // 무음 플래그 확인
            if (!(flags & AUDCLNT_BUFFERFLAGS_SILENT)) {
                // 오디오 데이터 처리
                ProcessAudioData(data, frames_available);
            }

            // 버퍼 해제
            g_capture_client->ReleaseBuffer(frames_available);

            // 다음 패킷 확인
            g_capture_client->GetNextPacketSize(&packet_length);
        }

        // 10ms 대기 (CPU 절약)
        Sleep(10);
    }
}
```

#### 3.2 오디오 데이터 처리

```cpp
struct AudioSample {
    std::vector<uint8_t> data;  // PCM 데이터
    UINT32 frame_count;
    UINT64 timestamp;           // 100-nanosecond 단위
};

void ProcessAudioData(BYTE* data, UINT32 frame_count) {
    AudioSample sample;

    // 데이터 크기 계산
    UINT32 data_size = frame_count * g_wave_format->nBlockAlign;

    // 데이터 복사
    sample.data.resize(data_size);
    memcpy(sample.data.data(), data, data_size);

    sample.frame_count = frame_count;

    // 타임스탬프 설정
    LARGE_INTEGER qpc;
    QueryPerformanceCounter(&qpc);
    sample.timestamp = qpc.QuadPart;

    // 오디오 버퍼 큐에 추가
    EnqueueAudioSample(sample);
}
```

---

### 4. 오디오 버퍼 관리

#### 4.1 스레드 안전 큐

```cpp
#include <queue>
#include <mutex>
#include <condition_variable>

// 전역 변수
static std::queue<AudioSample> g_audio_queue;
static std::mutex g_audio_queue_mutex;
static std::condition_variable g_audio_queue_cv;
static const size_t MAX_AUDIO_QUEUE_SIZE = 100;  // 100 패킷

void EnqueueAudioSample(const AudioSample& sample) {
    std::lock_guard<std::mutex> lock(g_audio_queue_mutex);

    if (g_audio_queue.size() >= MAX_AUDIO_QUEUE_SIZE) {
        // 큐가 가득 찬 경우: 가장 오래된 샘플 버림
        g_audio_queue.pop();
    }

    g_audio_queue.push(sample);
    g_audio_queue_cv.notify_one();
}

AudioSample DequeueAudioSample() {
    std::unique_lock<std::mutex> lock(g_audio_queue_mutex);
    g_audio_queue_cv.wait(lock, [] {
        return !g_audio_queue.empty() || !g_is_recording;
    });

    if (g_audio_queue.empty()) return AudioSample{};

    AudioSample sample = g_audio_queue.front();
    g_audio_queue.pop();
    return sample;
}
```

---

### 5. 오디오/비디오 동기화

#### 5.1 타임스탬프 동기화 전략

**문제**: 비디오 프레임과 오디오 샘플의 타임스탬프가 다름

**해결**:
1. 녹화 시작 시점의 QPC(QueryPerformanceCounter) 저장
2. 모든 프레임/샘플에 상대 타임스탬프 부여
3. 인코더에서 A/V 동기화

```cpp
// 전역 변수
static LARGE_INTEGER g_recording_start_qpc;
static LARGE_INTEGER g_qpc_frequency;

void InitializeTimestamps() {
    QueryPerformanceFrequency(&g_qpc_frequency);
    QueryPerformanceCounter(&g_recording_start_qpc);
}

REFERENCE_TIME GetRelativeTimestamp() {
    LARGE_INTEGER now;
    QueryPerformanceCounter(&now);

    // 상대 시간 계산 (100-nanosecond 단위)
    LONGLONG elapsed_qpc = now.QuadPart - g_recording_start_qpc.QuadPart;
    return (elapsed_qpc * 10000000) / g_qpc_frequency.QuadPart;
}
```

---

### 6. 리소스 정리

```cpp
void StopAudioCapture() {
    if (g_audio_client) {
        g_audio_client->Stop();
    }

    if (g_capture_client) {
        g_capture_client->Release();
        g_capture_client = nullptr;
    }

    if (g_audio_client) {
        g_audio_client->Release();
        g_audio_client = nullptr;
    }

    if (g_audio_device) {
        g_audio_device->Release();
        g_audio_device = nullptr;
    }

    if (g_wave_format) {
        CoTaskMemFree(g_wave_format);
        g_wave_format = nullptr;
    }
}
```

---

## 테스트 시나리오

### 테스트 1: 오디오 장치 초기화

**예상 로그**:
```
오디오 포맷: 48000 Hz, 2 channels, 32 bits
✅ 오디오 장치 초기화 완료
```

### 테스트 2: Loopback 캡처 시작

**방법**: YouTube 동영상 재생 후 녹화 시작

**예상 로그**:
```
✅ 오디오 캡처 시작
오디오 샘플 캡처: 480 frames (10ms @ 48kHz)
오디오 샘플 캡처: 480 frames (10ms @ 48kHz)
...
```

### 테스트 3: 무음 구간 처리

**방법**: 오디오 없이 10초 녹화

**예상 결과**:
- 샘플은 캡처되지만 AUDCLNT_BUFFERFLAGS_SILENT 플래그 설정
- 인코더에서 무음 프레임으로 처리

---

## 체크리스트

### Phase 2.2 작업 항목
- [ ] IMMDeviceEnumerator로 기본 오디오 장치 가져오기
- [ ] IAudioClient 초기화 (Loopback 모드)
- [ ] IAudioCaptureClient로 샘플 캡처
- [ ] 오디오 캡처 스레드 구현
- [ ] 오디오 버퍼 큐 구현
- [ ] 타임스탬프 동기화 구조 설계
- [ ] 오디오 캡처 테스트 (YouTube 재생)

### 선택 작업 (Phase 3)
- [ ] 마이크 오디오 믹싱
- [ ] 오디오 장치 변경 감지
- [ ] 볼륨 레벨 모니터링
- [ ] 무음 구간 자동 감지

---

## 일반적인 문제 및 해결

### 문제 1: "Access Denied" 에러

**원인**: 관리자 권한 필요

**해결**: 앱을 관리자 권한으로 실행 또는 매니페스트 수정

### 문제 2: 오디오가 캡처되지 않음

**원인**: Loopback 플래그 누락

**해결**: `AUDCLNT_STREAMFLAGS_LOOPBACK` 플래그 확인

### 문제 3: 오디오/비디오 싱크 어긋남

**원인**: 타임스탬프 불일치

**해결**: QPC 기반 상대 타임스탬프 사용

---

## 참고 자료

### 공식 문서
- [WASAPI (Core Audio APIs)](https://docs.microsoft.com/en-us/windows/win32/coreaudio/wasapi)
- [Loopback Recording](https://docs.microsoft.com/en-us/windows/win32/coreaudio/loopback-recording)

### 샘플 코드
- [Windows-classic-samples/WASAPICapture](https://github.com/microsoft/Windows-classic-samples/tree/main/Samples/WASAPICapture)

---

**작성일**: 2025-10-23
**다음 단계**: Phase 2.3 (H.264/AAC 인코딩)
**예상 완료일**: 2025-10-27
