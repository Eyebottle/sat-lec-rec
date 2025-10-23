// windows/runner/native_screen_recorder.cpp
// Windows Graphics Capture API + WASAPI를 사용한 화면 + 오디오 녹화 구현
//
// 목적:
//   1. Graphics Capture API로 화면 캡처
//   2. WASAPI Loopback으로 오디오 캡처
//   3. Media Foundation으로 H.264/AAC 인코딩하여 MP4 저장
//
// 작성일: 2025-10-22

#include "native_screen_recorder.h"

#include <windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <string>
#include <atomic>
#include <thread>
#include <mutex>
#include <queue>
#include <condition_variable>

// C++/WinRT 헤더 (Windows Graphics Capture API)
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Graphics.Capture.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "windowsapp.lib")  // C++/WinRT 필요

// C++/WinRT 네임스페이스
using namespace winrt;
using namespace Windows::Graphics::Capture;
using namespace Windows::Graphics::DirectX::Direct3D11;

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

// 프레임 데이터 구조
struct FrameData {
    std::vector<uint8_t> pixels;  // BGRA 픽셀 데이터
    int width;
    int height;
    uint64_t timestamp;  // QueryPerformanceCounter 값
};

// 프레임 버퍼 큐
static std::queue<FrameData> g_frame_queue;
static std::mutex g_queue_mutex;
static std::condition_variable g_queue_cv;
static const size_t MAX_QUEUE_SIZE = 60;  // 최대 60 프레임 (약 2.5초 @ 24fps)

// 에러 메시지 설정 헬퍼
static void SetLastError(const std::string& error) {
    std::lock_guard<std::mutex> lock(g_error_mutex);
    g_last_error = error;
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

// 녹화 스레드 함수 (스텁 - 실제 캡처 로직은 Phase 2에서 구현)
static void CaptureThreadFunc(
    std::string output_path,
    int32_t width,
    int32_t height,
    int32_t fps
) {
    // TODO Phase 2.1: Windows Graphics Capture API 초기화
    // - GraphicsCaptureSession 생성
    // - Direct3D11CaptureFramePool 설정
    // - FrameArrived 이벤트 핸들러 등록

    // TODO Phase 2.2: WASAPI Loopback 초기화
    // - IMMDeviceEnumerator로 기본 오디오 장치 가져오기
    // - IAudioClient 초기화
    // - IAudioCaptureClient로 오디오 데이터 캡처

    // TODO Phase 2.3: Media Foundation 인코더 설정
    // - IMFSinkWriter 생성 (MP4 출력)
    // - H.264 비디오 스트림 추가
    // - AAC 오디오 스트림 추가

    // TODO Phase 2.4: 메인 캡처 루프
    // 임시: 프레임 버퍼 테스트 (경고 제거용)
    // 실제 구현 시 FrameArrived에서 EnqueueFrame() 호출
    (void)output_path;  // 미사용 경고 제거
    (void)width;
    (void)height;
    (void)fps;

    // 현재는 스텁: 단순히 대기만 함
    while (g_is_recording) {
        Sleep(100);  // 100ms 대기

        // 프레임 큐 함수는 나중에 FrameArrived에서 사용 예정
        // (void)EnqueueFrame;  // 함수 참조로 경고 제거
        // (void)DequeueFrame;
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

        // Windows Runtime 초기화 (C++/WinRT)
        init_apartment();

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

}  // extern "C"
