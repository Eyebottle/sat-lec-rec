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

// DXGI Desktop Duplication API 헤더
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")

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

    // 2. 주 출력(모니터) 가져오기
    printf("[C++] 2/4: 주 모니터 출력 가져오기...\n");
    fflush(stdout);

    IDXGIOutput* dxgi_output = nullptr;
    hr = dxgi_adapter->EnumOutputs(0, &dxgi_output);  // 첫 번째 모니터
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

// 프레임 캡처 (DXGI Desktop Duplication)
static bool CaptureFrame() {
    HRESULT hr;
    DXGI_OUTDUPL_FRAME_INFO frame_info;
    IDXGIResource* desktop_resource = nullptr;

    // 1. 프레임 가져오기 (타임아웃 100ms)
    hr = g_dxgi_duplication->AcquireNextFrame(100, &frame_info, &desktop_resource);
    if (hr == DXGI_ERROR_WAIT_TIMEOUT) {
        return true;  // 타임아웃은 정상 (새 프레임 없음)
    }
    if (FAILED(hr)) {
        SetLastError("프레임 가져오기 실패");
        return false;
    }

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

    // TODO Phase 2.2: WASAPI Loopback 초기화
    // TODO Phase 2.3: Media Foundation 인코더 설정

    // 임시: 매개변수 미사용 경고 제거
    (void)output_path;
    (void)width;
    (void)height;
    (void)fps;

    // 메인 캡처 루프
    int frame_count = 0;
    printf("[C++] 프레임 캡처 루프 시작...\n");
    fflush(stdout);

    while (g_is_recording) {
        if (CaptureFrame()) {
            frame_count++;
            if (frame_count == 1) {
                printf("[C++] 🎬 첫 번째 프레임 캡처 성공!\n");
                fflush(stdout);
            }
            if (frame_count % 24 == 0) {  // 1초마다 로그 (24fps 기준)
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

    // 정리
    CleanupDXGIDuplication();
    printf("[C++] DXGI 리소스 정리 완료\n");
    fflush(stdout);
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

}  // extern "C"
