// windows/runner/native_screen_recorder.cpp
// DXGI Desktop Duplication + WASAPI Loopback + FFmpeg 파이프라인을 사용한 화면 + 오디오 녹화 구현
//
// 목적:
//   1. DXGI Desktop Duplication으로 화면 캡처
//   2. WASAPI Loopback으로 오디오 캡처
//   3. FFmpeg Named Pipe로 Fragmented MP4 저장
//
// 작성일: 2025-10-22

#include "native_screen_recorder.h"

#include <windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <string>
#include <atomic>
#include <thread>
#include <mutex>
#include <queue>
#include <condition_variable>
#include <cmath>  // Phase 3.1.2: std::sqrt, std::abs
#include <memory>

// DXGI Desktop Duplication API 헤더
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")

// WASAPI 헤더
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "winmm.lib")
#include "libav_encoder.h"

// 전역 상태
static std::atomic<bool> g_is_recording(false);
static std::string g_last_error;
static std::mutex g_error_mutex;
static std::thread g_capture_thread;

// Direct3D11 관련
static ID3D11Device* g_d3d_device = nullptr;
static ID3D11DeviceContext* g_d3d_context = nullptr;
static ID3D11Texture2D* g_staging_texture = nullptr;
static bool g_com_initialized = false;

// DXGI Desktop Duplication 관련
static IDXGIOutputDuplication* g_dxgi_duplication = nullptr;

// WASAPI 오디오 캡처 관련
static IMMDevice* g_audio_device = nullptr;
static IAudioClient* g_audio_client = nullptr;
static IAudioCaptureClient* g_audio_capture_client = nullptr;
static WAVEFORMATEX* g_wave_format = nullptr;
static std::thread g_audio_thread;

static std::thread g_encoder_thread;
static std::unique_ptr<LibavEncoder> g_libav_encoder;
static bool g_video_only = false;  // 비디오만 녹화할지 여부 (기본값: 오디오도 함께 녹화)

// 타임스탬프 관리
static LARGE_INTEGER g_recording_start_qpc;
static LARGE_INTEGER g_qpc_frequency;
static LONGLONG g_video_frame_count = 0;
static LONGLONG g_audio_sample_count = 0;
static int g_video_width = 0;
static int g_video_height = 0;
static int g_video_fps = 30;

// 프레임 데이터 구조
struct FrameData {
    std::vector<uint8_t> pixels;  // BGRA 픽셀 데이터
    int width;
    int height;
    uint64_t timestamp;  // QueryPerformanceCounter 값
};

// 오디오 샘플 데이터 구조
struct AudioSample {
    std::vector<uint8_t> data;     // PCM 오디오 데이터
    uint32_t frame_count;          // 오디오 프레임 수
    uint32_t sample_rate;          // 샘플레이트 (Hz)
    uint16_t channels;             // 채널 수 (2 = 스테레오)
    uint16_t bits_per_sample;      // 비트 깊이
    uint64_t timestamp;            // QueryPerformanceCounter 값
};

// 프레임 버퍼 큐
static std::queue<FrameData> g_frame_queue;
static std::mutex g_queue_mutex;
static std::condition_variable g_queue_cv;
static const size_t MAX_QUEUE_SIZE = 60;  // 최대 60 프레임 (약 2.5초 @ 24fps)

// 마지막 캡처된 프레임 (DXGI 타임아웃 시 재사용)
// ⚠️ 중요: 정적 화면에서도 비디오 스트림 연속성 유지를 위해 필요
static FrameData g_last_captured_frame;
static bool g_has_last_frame = false;

// 오디오 버퍼 큐
static std::queue<AudioSample> g_audio_queue;
static std::mutex g_audio_queue_mutex;
static std::condition_variable g_audio_queue_cv;
static const size_t MAX_AUDIO_QUEUE_SIZE = 100;  // 최대 100 샘플

// Phase 3.1.2: 오디오 레벨 추적 (0.0 ~ 1.0)
static std::atomic<float> g_current_audio_level(0.0f);  // RMS 레벨
static std::atomic<float> g_peak_audio_level(0.0f);     // Peak 레벨

// 에러 메시지 설정 헬퍼
static void SetLastError(const std::string& error) {
    std::lock_guard<std::mutex> lock(g_error_mutex);
    g_last_error = error;
}

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

// Direct3D11 디바이스 생성
static bool CreateD3D11Device() {
    if (g_d3d_device) {
        return true;  // 이미 생성됨
    }

    UINT creation_flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
#ifdef _DEBUG
    creation_flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

    D3D_FEATURE_LEVEL feature_levels[] = {
        D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0
    };

    D3D_FEATURE_LEVEL feature_level;

    HRESULT hr = D3D11CreateDevice(
        nullptr,                        // 기본 어댑터
        D3D_DRIVER_TYPE_HARDWARE,       // 하드웨어 가속
        nullptr,
        creation_flags,
        feature_levels,
        ARRAYSIZE(feature_levels),
        D3D11_SDK_VERSION,
        &g_d3d_device,
        &feature_level,
        &g_d3d_context
    );

    if (FAILED(hr)) {
        SetLastError("D3D11 디바이스 생성 실패");
        return false;
    }

    return true;
}

// Direct3D11 리소스 정리
static void CleanupD3D11() {
    if (g_staging_texture) {
        g_staging_texture->Release();
        g_staging_texture = nullptr;
    }

    if (g_d3d_context) {
        g_d3d_context->Release();
        g_d3d_context = nullptr;
    }

    if (g_d3d_device) {
        g_d3d_device->Release();
        g_d3d_device = nullptr;
    }
}

// DXGI Desktop Duplication 초기화
static bool InitializeDXGIDuplication() {
    HRESULT hr;

    // 1. DXGI 어댑터 가져오기
    printf("[C++] 1/4: DXGI 어댑터 가져오기...\n");
    fflush(stdout);

    IDXGIDevice* dxgi_device = nullptr;
    hr = g_d3d_device->QueryInterface(__uuidof(IDXGIDevice), (void**)&dxgi_device);
    if (FAILED(hr)) {
        printf("[C++] ❌ DXGI 디바이스 가져오기 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("DXGI 디바이스 가져오기 실패");
        return false;
    }

    IDXGIAdapter* dxgi_adapter = nullptr;
    hr = dxgi_device->GetAdapter(&dxgi_adapter);
    dxgi_device->Release();
    if (FAILED(hr)) {
        printf("[C++] ❌ DXGI 어댑터 가져오기 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("DXGI 어댑터 가져오기 실패");
        return false;
    }

    // 2. 두 번째 모니터(2번) 출력 가져오기
    printf("[C++] 2/4: 2번 모니터 출력 가져오기...\n");
    fflush(stdout);

    IDXGIOutput* dxgi_output = nullptr;
    hr = dxgi_adapter->EnumOutputs(1, &dxgi_output);  // 두 번째 모니터 (인덱스 1)
    dxgi_adapter->Release();
    if (FAILED(hr)) {
        printf("[C++] ❌ DXGI 출력 가져오기 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("DXGI 출력 가져오기 실패");
        return false;
    }

    // 3. IDXGIOutput1로 변환
    printf("[C++] 3/4: IDXGIOutput1 변환...\n");
    fflush(stdout);

    IDXGIOutput1* dxgi_output1 = nullptr;
    hr = dxgi_output->QueryInterface(__uuidof(IDXGIOutput1), (void**)&dxgi_output1);
    dxgi_output->Release();
    if (FAILED(hr)) {
        printf("[C++] ❌ IDXGIOutput1 가져오기 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("IDXGIOutput1 가져오기 실패");
        return false;
    }

    // 4. Desktop Duplication 생성
    printf("[C++] 4/4: Desktop Duplication 생성...\n");
    fflush(stdout);

    hr = dxgi_output1->DuplicateOutput(g_d3d_device, &g_dxgi_duplication);
    dxgi_output1->Release();
    if (FAILED(hr)) {
        printf("[C++] ❌ Desktop Duplication 생성 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("Desktop Duplication 생성 실패");
        return false;
    }

    printf("[C++] ✅ Desktop Duplication 생성 성공\n");
    fflush(stdout);

    return true;
}

// DXGI Duplication 리소스 정리
static void CleanupDXGIDuplication() {
    if (g_dxgi_duplication) {
        g_dxgi_duplication->Release();
        g_dxgi_duplication = nullptr;
    }
}

// DXGI Desktop Duplication 재초기화 (ACCESS_LOST 복구용)
// 녹화 중 DXGI_ERROR_ACCESS_LOST 발생 시 호출됨
static bool ReinitializeDXGIDuplication() {
    printf("[C++] DXGI Duplication 재초기화 시작...\\n");
    fflush(stdout);
    
    // 기존 리소스가 남아있다면 정리
    CleanupDXGIDuplication();
    
    // D3D 디바이스가 유효한지 확인
    if (!g_d3d_device) {
        printf("[C++] ❌ D3D 디바이스가 없습니다\\n");
        fflush(stdout);
        return false;
    }
    
    // 재초기화 시도 (최대 3회)
    for (int attempt = 1; attempt <= 3; attempt++) {
        printf("[C++] 재초기화 시도 %d/3...\\n", attempt);
        fflush(stdout);
        
        if (InitializeDXGIDuplication()) {
            printf("[C++] ✅ DXGI Duplication 재초기화 성공 (시도 %d)\\n", attempt);
            fflush(stdout);
            return true;
        }
        
        // 실패 시 잠시 대기 후 재시도
        if (attempt < 3) {
            printf("[C++] 재초기화 실패, 1초 후 재시도...\\n");
            fflush(stdout);
            Sleep(1000);
        }
    }
    
    printf("[C++] ❌ DXGI Duplication 재초기화 모든 시도 실패\\n");
    fflush(stdout);
    return false;
}

// WASAPI 초기화
static bool InitializeWASAPI() {
    HRESULT hr;

    printf("[C++] WASAPI 초기화 시작...\n");
    fflush(stdout);

    // 1. IMMDeviceEnumerator 생성
    printf("[C++] 1/4: IMMDeviceEnumerator 생성...\n");
    fflush(stdout);

    IMMDeviceEnumerator* enumerator = nullptr;
    hr = CoCreateInstance(
        __uuidof(MMDeviceEnumerator),
        nullptr,
        CLSCTX_ALL,
        __uuidof(IMMDeviceEnumerator),
        (void**)&enumerator
    );
    if (FAILED(hr)) {
        printf("[C++] ❌ IMMDeviceEnumerator 생성 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("IMMDeviceEnumerator 생성 실패");
        return false;
    }

    // 2. 기본 렌더 디바이스 가져오기 (스피커)
    printf("[C++] 2/4: 기본 오디오 장치 가져오기...\n");
    fflush(stdout);

    hr = enumerator->GetDefaultAudioEndpoint(
        eRender,      // 렌더 (출력) 장치
        eConsole,     // 콘솔 역할
        &g_audio_device
    );
    enumerator->Release();

    if (FAILED(hr)) {
        printf("[C++] ❌ 기본 오디오 장치 가져오기 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("기본 오디오 장치 가져오기 실패");
        return false;
    }

    // 3. IAudioClient 생성
    printf("[C++] 3/4: IAudioClient 생성...\n");
    fflush(stdout);

    hr = g_audio_device->Activate(
        __uuidof(IAudioClient),
        CLSCTX_ALL,
        nullptr,
        (void**)&g_audio_client
    );
    if (FAILED(hr)) {
        printf("[C++] ❌ IAudioClient 생성 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("IAudioClient 생성 실패");
        return false;
    }

    // 4. 오디오 포맷 가져오기
    printf("[C++] 4/4: 오디오 포맷 가져오기...\n");
    fflush(stdout);

    hr = g_audio_client->GetMixFormat(&g_wave_format);
    if (FAILED(hr)) {
        printf("[C++] ❌ 오디오 포맷 가져오기 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("오디오 포맷 가져오기 실패");
        return false;
    }

    printf("[C++] ✅ 오디오 포맷: %d Hz, %d channels, %d bits\n",
           g_wave_format->nSamplesPerSec,
           g_wave_format->nChannels,
           g_wave_format->wBitsPerSample);
    fflush(stdout);

    // 5. Loopback 모드로 초기화
    REFERENCE_TIME buffer_duration = 1000 * 10000;  // 100ms in 100-nanosecond units

    hr = g_audio_client->Initialize(
        AUDCLNT_SHAREMODE_SHARED,        // Shared 모드
        AUDCLNT_STREAMFLAGS_LOOPBACK,    // Loopback 플래그 (핵심!)
        buffer_duration,
        0,
        g_wave_format,
        nullptr
    );
    if (FAILED(hr)) {
        printf("[C++] ❌ AudioClient 초기화 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("AudioClient 초기화 실패");
        return false;
    }

    // 6. IAudioCaptureClient 가져오기
    hr = g_audio_client->GetService(
        __uuidof(IAudioCaptureClient),
        (void**)&g_audio_capture_client
    );
    if (FAILED(hr)) {
        printf("[C++] ❌ IAudioCaptureClient 가져오기 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("IAudioCaptureClient 가져오기 실패");
        return false;
    }

    // 7. 캡처 시작
    hr = g_audio_client->Start();
    if (FAILED(hr)) {
        printf("[C++] ❌ 오디오 캡처 시작 실패 (HRESULT: 0x%08X)\n", hr);
        fflush(stdout);
        SetLastError("오디오 캡처 시작 실패");
        return false;
    }

    printf("[C++] ✅ WASAPI 초기화 완료 (Loopback 모드)\n");
    fflush(stdout);

    return true;
}

// WASAPI 리소스 정리
static void CleanupWASAPI() {
    printf("[C++] WASAPI 리소스 정리 시작...\n");
    fflush(stdout);

    if (g_audio_client) {
        g_audio_client->Stop();
    }

    if (g_audio_capture_client) {
        g_audio_capture_client->Release();
        g_audio_capture_client = nullptr;
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

    printf("[C++] ✅ WASAPI 리소스 정리 완료\n");
    fflush(stdout);
}

//==============================================================================
// FFmpeg 파이프라인 보조 함수
//==============================================================================

// 입력: 없음
// 출력: 타임스탬프와 카운터 초기화
// 예외: 없음
static void ResetRecordingStats() {
    QueryPerformanceFrequency(&g_qpc_frequency);
    QueryPerformanceCounter(&g_recording_start_qpc);
    g_video_frame_count = 0;
    g_audio_sample_count = 0;
}

// 입력: 없음 (큐 내부 데이터 사용)
// 출력: 비디오 프레임을 FFmpeg 파이프에 전송했는지 여부
// 예외: 파이프 오류 시 false, last_error 갱신
static bool ProcessNextVideoFrame() {
    std::unique_lock<std::mutex> lock(g_queue_mutex);
    if (g_frame_queue.empty()) {
        return false;
    }

    FrameData frame = std::move(g_frame_queue.front());
    g_frame_queue.pop();
    lock.unlock();

    if (!g_libav_encoder || !g_libav_encoder->IsRunning()) {
        SetLastError("LibavEncoder가 실행 중이 아닙니다.");
        return false;
    }

    // ⚠️ 중요: 캡처 시점의 QPC 타임스탬프를 인코더에 전달 (A/V 동기화 핵심)
    // 기존 카운터 기반 PTS 대신 실제 벽시계 시간 사용
    if (!g_libav_encoder->EncodeVideo(frame.pixels.data(), frame.pixels.size(), frame.timestamp)) {
        SetLastError(g_libav_encoder->GetLastError());
        return false;
    }

    g_video_frame_count++;
    if (g_video_frame_count == 1 || g_video_frame_count % 300 == 0) {
        printf("[C++] 비디오 프레임 #%lld 전송 완료\n", g_video_frame_count);
        fflush(stdout);
    }
    return true;
}

// 입력: 없음 (큐 내부 데이터 사용)
// 출력: 오디오 샘플을 FFmpeg 파이프에 전송했는지 여부
// 예외: 파이프 오류 시 false, last_error 갱신
static bool ProcessNextAudioSample() {
    static int audio_packet_count = 0;
    static int audio_debug_log_count = 0;

    std::unique_lock<std::mutex> lock(g_audio_queue_mutex);
    if (g_audio_queue.empty()) {
        return false;
    }

    size_t queue_size_before_pop = g_audio_queue.size();
    AudioSample audio = std::move(g_audio_queue.front());
    g_audio_queue.pop();
    lock.unlock();

    size_t queue_remaining = queue_size_before_pop > 0 ? queue_size_before_pop - 1 : 0;

    if (!g_libav_encoder || !g_libav_encoder->IsRunning()) {
        SetLastError("LibavEncoder가 실행 중이 아닙니다.");
        return false;
    }

    int next_packet_index = audio_packet_count + 1;
    double elapsed_ms = 0.0;
    if (g_qpc_frequency.QuadPart > 0) {
        long double start_qpc = static_cast<long double>(g_recording_start_qpc.QuadPart);
        long double audio_qpc = static_cast<long double>(audio.timestamp);
        long double delta = audio_qpc - start_qpc;
        if (delta < 0.0L) {
            delta = 0.0L;
        }
        elapsed_ms = static_cast<double>(delta * 1000.0L /
                                         static_cast<long double>(g_qpc_frequency.QuadPart));
    }

    if (audio_debug_log_count < 5) {
        printf("[C++] 오디오 패킷 #%d 준비 - 바이트:%llu, 프레임:%u, 잔여 큐:%llu, 경과:%.2fms\n",
               next_packet_index,
               static_cast<unsigned long long>(audio.data.size()),
               audio.frame_count,
               static_cast<unsigned long long>(queue_remaining),
               elapsed_ms);
        fflush(stdout);
        audio_debug_log_count++;
    }

    // ⚠️ 중요: 캡처 시점의 QPC 타임스탬프를 인코더에 전달 (A/V 동기화 핵심)
    // 비디오와 동일한 벽시계 기준으로 PTS 계산됨
    if (!g_libav_encoder->EncodeAudio(audio.data.data(), audio.data.size(), audio.timestamp)) {
        const std::string encoder_error = g_libav_encoder->GetLastError();
        printf("[C++] ❌ 오디오 패킷 #%d 인코딩 실패\n", next_packet_index);
        printf("[C++]    에러 메시지: %s\n", encoder_error.c_str());
        printf("[C++]    데이터 크기: %llu bytes\n", static_cast<unsigned long long>(audio.data.size()));
        printf("[C++]    프레임 수: %u\n", audio.frame_count);
        printf("[C++]    인코더 실행 중: %s\n", g_libav_encoder->IsRunning() ? "예" : "아니오");
        fflush(stdout);
        SetLastError(encoder_error.empty() ? "오디오 인코딩 실패" : encoder_error);
        return false;
    }

    g_audio_sample_count += audio.frame_count;

    audio_packet_count++;
    if (audio_packet_count == 1 || audio_packet_count % 500 == 0) {
        printf("[C++] 오디오 패킷 #%d 전송 완료\n", audio_packet_count);
        fflush(stdout);
    }

    return true;
}

// 입력: 없음
// 출력: 없음 (파이프에 데이터 지속 전송)
// 예외: 파이프 오류 시 last_error 갱신 후 루프 종료
static void EncoderThreadFunc() {
    try {
        printf("[C++] FFmpeg 파이프 인코더 스레드 시작...\n");
        fflush(stdout);

    ResetRecordingStats();

    // ⚠️ 스레드 안전성: 큐 접근 시 항상 뮤텍스 보호 필요
    auto should_continue = [&]() {
        bool has_frames = false;
        bool has_audio = false;

        {
            std::lock_guard<std::mutex> lock(g_queue_mutex);
            has_frames = !g_frame_queue.empty();
        }

        {
            std::lock_guard<std::mutex> audio_lock(g_audio_queue_mutex);
            has_audio = !g_audio_queue.empty();
        }

        return g_is_recording || has_frames || has_audio;
    };

    while (should_continue()) {
        bool processed = false;
        processed |= ProcessNextVideoFrame();
        processed |= ProcessNextAudioSample();

        if (!processed) {
            Sleep(2);
        }
    }

    // 잔여 데이터 비우기
    while (ProcessNextVideoFrame() || ProcessNextAudioSample()) {
        // 잔여 데이터 비우기
    }

    printf("[C++] FFmpeg 파이프 인코더 스레드 종료\n");
    fflush(stdout);
    } catch (const std::exception& e) {
        printf("[C++] ❌ 인코더 스레드 예외 발생: %s\n", e.what());
        fflush(stdout);
    } catch (...) {
        printf("[C++] ❌ 인코더 스레드 알 수 없는 예외 발생\n");
        fflush(stdout);
    }
}

// 프레임 큐에 추가 (나중에 FrameArrived에서 사용)
[[maybe_unused]] static void EnqueueFrame(const FrameData& frame) {
    std::lock_guard<std::mutex> lock(g_queue_mutex);

    if (g_frame_queue.size() >= MAX_QUEUE_SIZE) {
        // 큐가 가득 찬 경우: 가장 오래된 프레임 버림
        g_frame_queue.pop();
    }

    g_frame_queue.push(frame);
    g_queue_cv.notify_one();
}

// 프레임 큐에서 가져오기 (나중에 인코더 스레드에서 사용)
[[maybe_unused]] static FrameData DequeueFrame() {
    std::unique_lock<std::mutex> lock(g_queue_mutex);
    g_queue_cv.wait(lock, [] {
        return !g_frame_queue.empty() || !g_is_recording;
    });

    if (g_frame_queue.empty()) return FrameData{};

    FrameData frame = g_frame_queue.front();
    g_frame_queue.pop();
    return frame;
}

// 오디오 샘플 큐에 추가
[[maybe_unused]] static void EnqueueAudioSample(const AudioSample& sample) {
    std::lock_guard<std::mutex> lock(g_audio_queue_mutex);

    if (g_audio_queue.size() >= MAX_AUDIO_QUEUE_SIZE) {
        // 큐가 가득 찬 경우: 가장 오래된 샘플 버림
        g_audio_queue.pop();
    }

    g_audio_queue.push(sample);
    g_audio_queue_cv.notify_one();
}

// 오디오 샘플 큐에서 가져오기
[[maybe_unused]] static AudioSample DequeueAudioSample() {
    std::unique_lock<std::mutex> lock(g_audio_queue_mutex);
    g_audio_queue_cv.wait(lock, [] {
        return !g_audio_queue.empty() || !g_is_recording;
    });

    if (g_audio_queue.empty()) return AudioSample{};

    AudioSample sample = g_audio_queue.front();
    g_audio_queue.pop();
    return sample;
}

// 오디오 캡처 루프 (별도 스레드에서 실행)
static void AudioCaptureThreadFunc() {
    try {
        printf("[C++] 오디오 캡처 스레드 시작...\n");
        fflush(stdout);

    HRESULT hr;
    int sample_count = 0;

    while (g_is_recording) {
        // 사용 가능한 패킷 확인
        UINT32 packet_length = 0;
        hr = g_audio_capture_client->GetNextPacketSize(&packet_length);
        if (FAILED(hr)) {
            printf("[C++] ❌ GetNextPacketSize 실패 (HRESULT: 0x%08X)\n", hr);
            fflush(stdout);
            break;
        }

        while (packet_length != 0) {
            // 오디오 데이터 가져오기
            BYTE* data = nullptr;
            UINT32 frames_available = 0;
            DWORD flags = 0;

            hr = g_audio_capture_client->GetBuffer(
                &data,
                &frames_available,
                &flags,
                nullptr,
                nullptr
            );

            if (FAILED(hr)) {
                printf("[C++] ❌ GetBuffer 실패 (HRESULT: 0x%08X)\n", hr);
                fflush(stdout);
                break;
            }

            // 오디오 샘플 생성 (무음 여부와 관계없이 항상 전송)
            // ⚠️ 중요: 무음 구간에서도 데이터를 보내야 A/V 동기화 유지됨
            AudioSample sample;
            sample.frame_count = frames_available;
            sample.sample_rate = g_wave_format->nSamplesPerSec;
            sample.channels = g_wave_format->nChannels;
            sample.bits_per_sample = g_wave_format->wBitsPerSample;

            // 데이터 크기 계산
            UINT32 data_size = frames_available * g_wave_format->nBlockAlign;
            sample.data.resize(data_size);

            // 무음 플래그 확인
            if (flags & AUDCLNT_BUFFERFLAGS_SILENT) {
                // 무음일 때: 0으로 채운 데이터 전송
                memset(sample.data.data(), 0, data_size);
                g_current_audio_level.store(0.0f);
                g_peak_audio_level.store(0.0f);
            } else {
                // 실제 오디오 데이터 복사
                memcpy(sample.data.data(), data, data_size);

                // 오디오 레벨 계산 및 업데이트
                float audio_level = CalculateAudioLevel(data, frames_available, g_wave_format->nChannels);
                g_current_audio_level.store(audio_level);
            }

            // 타임스탬프 설정
            LARGE_INTEGER qpc;
            QueryPerformanceCounter(&qpc);
            sample.timestamp = qpc.QuadPart;

            // 큐에 추가 (무음 포함 항상)
            EnqueueAudioSample(sample);

            sample_count++;
            if (sample_count == 1) {
                printf("[C++] 🎤 첫 번째 오디오 샘플 캡처 성공! (%d frames)\n", frames_available);
                fflush(stdout);
            }
            if (sample_count % 500 == 0) {
                printf("[C++] 📊 오디오 샘플: %d개 캡처됨\n", sample_count);
                fflush(stdout);
            }

            // 버퍼 해제
            g_audio_capture_client->ReleaseBuffer(frames_available);

            // 다음 패킷 확인
            g_audio_capture_client->GetNextPacketSize(&packet_length);
        }

        // 10ms 대기 (CPU 절약)
        Sleep(10);
    }

    printf("[C++] 오디오 캡처 스레드 종료, 총 %d개 샘플 캡처됨\n", sample_count);
    fflush(stdout);
    } catch (const std::exception& e) {
        printf("[C++] ❌ 오디오 스레드 예외 발생: %s\n", e.what());
        fflush(stdout);
    } catch (...) {
        printf("[C++] ❌ 오디오 스레드 알 수 없는 예외 발생\n");
        fflush(stdout);
    }
}

// DXGI 복구를 위한 재초기화 함수 (forward declaration)
static bool ReinitializeDXGIDuplication();

// 연속 실패 카운터 (복구 시도용)
static int g_capture_failure_count = 0;
static const int MAX_CAPTURE_FAILURES = 5;  // 5회 연속 실패 시 복구 시도

// 프레임 캡처 (DXGI Desktop Duplication)
static bool CaptureFrame() {
    HRESULT hr;
    DXGI_OUTDUPL_FRAME_INFO frame_info;
    IDXGIResource* desktop_resource = nullptr;

    // 1. 프레임 가져오기 (타임아웃 100ms)
    hr = g_dxgi_duplication->AcquireNextFrame(100, &frame_info, &desktop_resource);
    if (hr == DXGI_ERROR_WAIT_TIMEOUT) {
        // 타임아웃: 화면 변화 없음 → 마지막 프레임 재사용
        // ⚠️ 중요: 정적 화면(PPT, 문서 등)에서도 비디오 스트림 유지 필요
        if (g_has_last_frame) {
            // 새 타임스탬프로 마지막 프레임 복제하여 큐에 추가
            FrameData repeat_frame = g_last_captured_frame;
            LARGE_INTEGER qpc;
            QueryPerformanceCounter(&qpc);
            repeat_frame.timestamp = qpc.QuadPart;
            EnqueueFrame(repeat_frame);
        }
        return true;
    }
    
    // DXGI_ERROR_ACCESS_LOST: Desktop Duplication 세션이 무효화됨
    // 원인: 전체화면 앱 전환, 디스플레이 설정 변경, DWM 재시작 등
    if (hr == DXGI_ERROR_ACCESS_LOST) {
        printf("[C++] ⚠️ DXGI_ERROR_ACCESS_LOST 발생 - Desktop Duplication 재초기화 시도...\\n");
        fflush(stdout);
        
        // 기존 Duplication 정리
        if (g_dxgi_duplication) {
            g_dxgi_duplication->Release();
            g_dxgi_duplication = nullptr;
        }
        
        // 스테이징 텍스처도 정리 (해상도 변경 가능성)
        if (g_staging_texture) {
            g_staging_texture->Release();
            g_staging_texture = nullptr;
        }
        
        // 잠시 대기 후 재초기화
        Sleep(500);
        
        if (ReinitializeDXGIDuplication()) {
            printf("[C++] ✅ Desktop Duplication 재초기화 성공, 녹화 계속...\\n");
            fflush(stdout);
            g_capture_failure_count = 0;
            return true;  // 재시도
        } else {
            printf("[C++] ❌ Desktop Duplication 재초기화 실패\\n");
            fflush(stdout);
            SetLastError("DXGI 세션 복구 실패");
            return false;
        }
    }
    
    if (FAILED(hr)) {
        g_capture_failure_count++;
        printf("[C++] ⚠️ 프레임 가져오기 실패 (HRESULT: 0x%08X, 연속실패: %d/%d)\\n",
               hr, g_capture_failure_count, MAX_CAPTURE_FAILURES);
        fflush(stdout);
        
        // 연속 실패가 임계값 미만이면 재시도
        if (g_capture_failure_count < MAX_CAPTURE_FAILURES) {
            Sleep(50);  // 잠시 대기 후 재시도
            return true;
        }
        
        SetLastError("프레임 가져오기 연속 실패");
        return false;
    }
    
    // 성공 시 실패 카운터 리셋
    g_capture_failure_count = 0;

    // 2. ID3D11Texture2D로 변환
    ID3D11Texture2D* desktop_texture = nullptr;
    hr = desktop_resource->QueryInterface(__uuidof(ID3D11Texture2D), (void**)&desktop_texture);
    desktop_resource->Release();
    if (FAILED(hr)) {
        g_dxgi_duplication->ReleaseFrame();
        SetLastError("Texture 변환 실패");
        return false;
    }

    // 3. Staging Texture로 복사 (GPU → CPU)
    D3D11_TEXTURE2D_DESC desc;
    desktop_texture->GetDesc(&desc);

    if (!g_staging_texture) {
        // Staging Texture 생성 (최초 1회)
        desc.Usage = D3D11_USAGE_STAGING;
        desc.BindFlags = 0;
        desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
        desc.MiscFlags = 0;
        g_d3d_device->CreateTexture2D(&desc, nullptr, &g_staging_texture);
    }

    g_d3d_context->CopyResource(g_staging_texture, desktop_texture);
    desktop_texture->Release();

    // 4. CPU 메모리로 읽기
    D3D11_MAPPED_SUBRESOURCE mapped;
    hr = g_d3d_context->Map(g_staging_texture, 0, D3D11_MAP_READ, 0, &mapped);
    if (SUCCEEDED(hr)) {
        FrameData frame;
        frame.width = desc.Width;
        frame.height = desc.Height;

        // 픽셀 데이터 복사 (행 단위)
        size_t pixel_count = desc.Width * desc.Height * 4;  // BGRA
        frame.pixels.resize(pixel_count);

        uint8_t* src = (uint8_t*)mapped.pData;
        uint8_t* dst = frame.pixels.data();

        for (UINT y = 0; y < desc.Height; y++) {
            memcpy(dst + y * desc.Width * 4, src + y * mapped.RowPitch, desc.Width * 4);
        }

        g_d3d_context->Unmap(g_staging_texture, 0);

        // 타임스탬프 설정
        LARGE_INTEGER qpc;
        QueryPerformanceCounter(&qpc);
        frame.timestamp = qpc.QuadPart;

        // 마지막 프레임으로 저장 (타임아웃 시 재사용)
        g_last_captured_frame = frame;
        g_has_last_frame = true;

        // 프레임 큐에 추가
        EnqueueFrame(frame);
    }

    // 5. 프레임 해제
    g_dxgi_duplication->ReleaseFrame();

    return true;
}

// 녹화 스레드 함수
static void CaptureThreadFunc(
    std::string output_path,
    int32_t width,
    int32_t height,
    int32_t fps
) {
    try {
        // DXGI Desktop Duplication 초기화
        printf("[C++] DXGI Desktop Duplication 초기화 시작...\n");
        fflush(stdout);

    if (!InitializeDXGIDuplication()) {
        printf("[C++] ❌ Desktop Duplication 초기화 실패\n");
        fflush(stdout);
        SetLastError("Desktop Duplication 초기화 실패");
        g_is_recording = false;
        return;
    }

    printf("[C++] ✅ DXGI Desktop Duplication 초기화 완료\n");
    fflush(stdout);

    // WASAPI 초기화
    if (!InitializeWASAPI()) {
        printf("[C++] ❌ WASAPI 초기화 실패\n");
        fflush(stdout);
        SetLastError("WASAPI 초기화 실패");
        CleanupDXGIDuplication();
        g_is_recording = false;
        return;
    }
    printf("[C++] ✅ WASAPI 초기화 완료\n");
    fflush(stdout);

    // 오디오 캡처 스레드 시작
    g_audio_thread = std::thread(AudioCaptureThreadFunc);
    printf("[C++] ✅ 오디오 캡처 스레드 시작됨\n");
    fflush(stdout);

    // 출력 파일 경로를 wchar_t로 변환 (UTF-8 → UTF-16)
    int wide_length = MultiByteToWideChar(CP_UTF8, 0, output_path.c_str(), -1, nullptr, 0);
    if (wide_length <= 1) {
        printf("[C++] ❌ 출력 경로 UTF-16 변환 실패\n");
        fflush(stdout);
        CleanupWASAPI();
        if (g_audio_thread.joinable()) g_audio_thread.join();
        CleanupDXGIDuplication();
        g_is_recording = false;
        return;
    }

    std::wstring w_output_path(wide_length - 1, 0);
    MultiByteToWideChar(CP_UTF8, 0, output_path.c_str(), -1, w_output_path.data(), wide_length);

    // LibavEncoder 준비
    g_video_width = width;
    g_video_height = height;
    g_video_fps = fps;

    LibavEncoderConfig encoder_config;
    encoder_config.output_path = w_output_path;
    encoder_config.video_width = width;
    encoder_config.video_height = height;
    encoder_config.video_fps = fps;

    // Audio 설정 (g_wave_format 사용)
    if (g_wave_format) {
        encoder_config.audio_sample_rate = g_wave_format->nSamplesPerSec;
        encoder_config.audio_channels = g_wave_format->nChannels;
    } else {
        encoder_config.audio_sample_rate = 48000;
        encoder_config.audio_channels = 2;
    }

    encoder_config.enable_fragmented_mp4 = true;
    encoder_config.h264_crf = 23;
    encoder_config.h264_preset = "veryfast";
    encoder_config.aac_bitrate = 192000;

    try {
        g_libav_encoder = std::make_unique<LibavEncoder>();
        if (!g_libav_encoder->Start(encoder_config)) {
            printf("[C++] ❌ LibavEncoder 시작 실패: %s\n", g_libav_encoder->GetLastError().c_str());
            fflush(stdout);
            g_libav_encoder.reset();
            CleanupWASAPI();
            if (g_audio_thread.joinable()) g_audio_thread.join();
            CleanupDXGIDuplication();
            g_is_recording = false;
            return;
        }
    } catch (const std::exception& e) {
        printf("[C++] ❌ LibavEncoder 시작 중 예외 발생: %s\n", e.what());
        fflush(stdout);
        SetLastError(std::string("LibavEncoder 시작 예외: ") + e.what());
        g_libav_encoder.reset();
        CleanupWASAPI();
        if (g_audio_thread.joinable()) g_audio_thread.join();
        CleanupDXGIDuplication();
        g_is_recording = false;
        return;
    } catch (...) {
        printf("[C++] ❌ LibavEncoder 시작 중 알 수 없는 예외 발생\n");
        fflush(stdout);
        SetLastError("LibavEncoder 시작 중 알 수 없는 예외 발생");
        g_libav_encoder.reset();
        CleanupWASAPI();
        if (g_audio_thread.joinable()) g_audio_thread.join();
        CleanupDXGIDuplication();
        g_is_recording = false;
        return;
    }

    // 인코더 스레드 시작
    g_encoder_thread = std::thread(EncoderThreadFunc);

    printf("[C++] ✅ 모든 초기화 완료, 녹화 시작\\n");
    fflush(stdout);

    // 메인 캡처 루프
    int frame_count = 0;
    g_capture_failure_count = 0;  // 실패 카운터 초기화
    printf("[C++] 프레임 캡처 루프 시작...\\n");
    fflush(stdout);

    while (g_is_recording) {
        if (CaptureFrame()) {
            frame_count++;
            if (frame_count == 1) {
                printf("[C++] 🎬 첫 번째 프레임 캡처 성공!\n");
                fflush(stdout);
            }
            if (frame_count % 300 == 0) {  // 10초마다 로그 (30fps 기준)
                printf("[C++] 📊 캡처된 프레임: %d\n", frame_count);
                fflush(stdout);
            }
        } else {
            // 캡처 실패 시 루프 종료
            printf("[C++] ❌ 프레임 캡처 실패, 루프 종료 (총 %d 프레임)\n", frame_count);
            fflush(stdout);
            g_is_recording = false;
            break;
        }
    }

    printf("[C++] 캡처 루프 종료, 총 %d 프레임 캡처됨\n", frame_count);
    fflush(stdout);

    // 인코더 스레드 종료 대기
    if (g_encoder_thread.joinable()) {
        printf("[C++] 인코더 스레드 종료 대기...\n");
        fflush(stdout);
        g_encoder_thread.join();
    }

    // Video-only 모드가 아닐 때만 오디오 스레드 종료 대기
    if (!g_video_only && g_audio_thread.joinable()) {
        printf("[C++] 오디오 스레드 종료 대기...\n");
        fflush(stdout);
        g_audio_thread.join();
    }

    // 정리
    if (g_libav_encoder) {
        g_libav_encoder->Stop();
        g_libav_encoder.reset();
    }

    // WASAPI 정리
    CleanupWASAPI();

    CleanupDXGIDuplication();
    printf("[C++] 모든 리소스 정리 완료\n");
    fflush(stdout);
    } catch (const std::exception& e) {
        printf("[C++] ❌ 캡처 스레드 예외 발생: %s\n", e.what());
        fflush(stdout);
        // 예외 발생 시에도 정리 시도
        g_is_recording = false;
        CleanupWASAPI();
        CleanupDXGIDuplication();
    } catch (...) {
        printf("[C++] ❌ 캡처 스레드 알 수 없는 예외 발생\n");
        fflush(stdout);
        g_is_recording = false;
        CleanupWASAPI();
        CleanupDXGIDuplication();
    }
}

// ========== C 인터페이스 구현 (extern "C" 링크) ==========

extern "C" {

// 녹화 초기화
int32_t NativeRecorder_Initialize() {
    try {
        // COM 초기화 (멀티스레드 아파트)
        HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
            SetLastError("COM 초기화 실패");
            return -1;
        }
        g_com_initialized = true;

        // Direct3D11 디바이스 생성
        if (!CreateD3D11Device()) {
            SetLastError("D3D11 디바이스 생성 실패");
            return -2;
        }

        SetLastError("");
        return 0;  // 성공
    } catch (const std::exception& e) {
        SetLastError(std::string("Initialize failed: ") + e.what());
        return -1;
    }
}

// 녹화 시작
int32_t NativeRecorder_StartRecording(
    const char* output_path,
    int32_t width,
    int32_t height,
    int32_t fps
) {
    if (g_is_recording) {
        SetLastError("Already recording");
        return -2;
    }

    if (!output_path || strlen(output_path) == 0) {
        SetLastError("Invalid output path");
        return -3;
    }

    try {
        g_is_recording = true;

        // 캡처 스레드 시작
        g_capture_thread = std::thread(
            CaptureThreadFunc,
            std::string(output_path),
            width,
            height,
            fps
        );

        SetLastError("");
        return 0;  // 성공
    } catch (const std::exception& e) {
        g_is_recording = false;
        SetLastError(std::string("StartRecording failed: ") + e.what());
        return -1;
    }
}

// 녹화 중지
int32_t NativeRecorder_StopRecording() {
    if (!g_is_recording) {
        SetLastError("Not recording");
        return -2;
    }

    try {
        g_is_recording = false;

        // 캡처 스레드 종료 대기
        if (g_capture_thread.joinable()) {
            g_capture_thread.join();
        }

        // 마지막 프레임 상태 리셋
        g_has_last_frame = false;
        g_last_captured_frame = FrameData();

        SetLastError("");
        return 0;  // 성공
    } catch (const std::exception& e) {
        SetLastError(std::string("StopRecording failed: ") + e.what());
        return -1;
    }
}

// 녹화 중 여부 확인
int32_t NativeRecorder_IsRecording() {
    return g_is_recording ? 1 : 0;
}

// 리소스 정리
void NativeRecorder_Cleanup() {
    if (g_is_recording) {
        NativeRecorder_StopRecording();
    }

    // 오디오 스레드 종료 대기
    if (g_audio_thread.joinable()) {
        g_audio_thread.join();
    }

    if (g_libav_encoder) {
        g_libav_encoder->Stop();
        g_libav_encoder.reset();
    }

    // WASAPI 리소스 정리
    CleanupWASAPI();

    // DXGI Duplication 리소스 정리
    CleanupDXGIDuplication();

    // Direct3D11 리소스 정리
    CleanupD3D11();

    // COM 종료
    if (g_com_initialized) {
        CoUninitialize();
        g_com_initialized = false;
    }
}

// 마지막 에러 메시지 가져오기
const char* NativeRecorder_GetLastError() {
    std::lock_guard<std::mutex> lock(g_error_mutex);
    return g_last_error.c_str();
}

// ============================================================================
// Phase 3.1.1: 녹화 진행률 조회 함수들
// ============================================================================

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

// ============================================================================
// Phase 3.1.2: 오디오 레벨 조회 함수들
// ============================================================================

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

}  // extern "C"
