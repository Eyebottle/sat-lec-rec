# M2 Phase 2.1: Windows Graphics Capture API 구현

**목표**: Direct3D11과 Windows.Graphics.Capture API를 사용하여 화면 프레임 캡처

**예상 소요 시간**: 3~4일

**의존성**: M1 Phase 1.2 완료 (FFI 인프라 구축)

**작성일**: 2025-10-23

---

## 개요

### Windows Graphics Capture API란?

Windows 10 1803 (Build 17134)부터 도입된 공식 화면 캡처 API로, 기존의 DXGI Desktop Duplication보다 간단하고 안정적입니다.

**장점**:
- 특정 창만 캡처 가능 (Zoom 창 타게팅)
- 마우스 커서 포함/제외 선택
- DWM(Desktop Window Manager) 통합으로 안정적
- UWP/Win32 모두 지원

**단점**:
- Windows 10 이상만 지원
- WinRT API이므로 C++/WinRT 학습 필요

---

## 아키텍처

```
[Monitor/Window]
       ↓
[GraphicsCaptureItem]
       ↓
[GraphicsCaptureSession]
       ↓
[Direct3D11CaptureFramePool]
       ↓
[FrameArrived Event]
       ↓
[ID3D11Texture2D] (BGRA)
       ↓
[프레임 버퍼 큐] → Phase 2.3 (인코더)
```

---

## 구현 단계

### 1. COM 및 Windows Runtime 초기화

#### 1.1 NativeRecorder_Initialize() 구현

**파일**: `windows/runner/native_screen_recorder.cpp`

**구현 내용**:
```cpp
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Graphics.Capture.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>

using namespace winrt;
using namespace Windows::Graphics::Capture;
using namespace Windows::Graphics::DirectX::Direct3D11;

int32_t NativeRecorder_Initialize() {
    try {
        // COM 초기화 (멀티스레드 아파트)
        HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
            SetLastError("COM 초기화 실패");
            return -1;
        }

        // Windows Runtime 초기화
        init_apartment();

        // Direct3D11 디바이스 생성
        if (!CreateD3DDevice()) {
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
```

#### 1.2 Direct3D11 디바이스 생성

```cpp
// 전역 변수
static ID3D11Device* g_d3d_device = nullptr;
static ID3D11DeviceContext* g_d3d_context = nullptr;

bool CreateD3DDevice() {
    UINT creation_flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
#ifdef _DEBUG
    creation_flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

    D3D_FEATURE_LEVEL feature_levels[] = {
        D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0
    };

    HRESULT hr = D3D11CreateDevice(
        nullptr,                        // 기본 어댑터
        D3D_DRIVER_TYPE_HARDWARE,
        nullptr,
        creation_flags,
        feature_levels,
        ARRAYSIZE(feature_levels),
        D3D11_SDK_VERSION,
        &g_d3d_device,
        nullptr,
        &g_d3d_context
    );

    return SUCCEEDED(hr);
}
```

---

### 2. 캡처 대상 선택 (모니터 또는 창)

#### 2.1 주 모니터 캡처 (간단한 방법)

```cpp
#include <winrt/Windows.Graphics.Capture.h>

GraphicsCaptureItem CreateCaptureItemForPrimaryMonitor() {
    // TODO: GraphicsCapturePicker로 사용자가 선택하도록 하거나
    // 주 모니터를 자동으로 가져오기

    // 임시: Monitor API 사용
    HMONITOR primary_monitor = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);

    // WinRT Interop으로 GraphicsCaptureItem 생성
    auto interop = get_activation_factory<GraphicsCaptureItem, IGraphicsCaptureItemInterop>();
    GraphicsCaptureItem item = nullptr;
    interop->CreateForMonitor(primary_monitor, guid_of<GraphicsCaptureItem>(), put_abi(item));

    return item;
}
```

#### 2.2 특정 창 캡처 (Zoom 창)

```cpp
GraphicsCaptureItem CreateCaptureItemForWindow(HWND hwnd) {
    auto interop = get_activation_factory<GraphicsCaptureItem, IGraphicsCaptureItemInterop>();
    GraphicsCaptureItem item = nullptr;
    interop->CreateForWindow(hwnd, guid_of<GraphicsCaptureItem>(), put_abi(item));
    return item;
}

// Zoom 창 찾기
HWND FindZoomWindow() {
    // "Zoom Meeting" 또는 "Zoom" 타이틀 검색
    return FindWindowW(nullptr, L"Zoom Meeting");
}
```

---

### 3. GraphicsCaptureSession 시작

#### 3.1 세션 생성 및 프레임 풀 설정

```cpp
#include <winrt/Windows.Graphics.Capture.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>

// 전역 변수
static GraphicsCaptureItem g_capture_item = nullptr;
static Direct3D11CaptureFramePool g_frame_pool = nullptr;
static GraphicsCaptureSession g_session = nullptr;

bool StartCaptureSession(int32_t width, int32_t height) {
    try {
        // 1. 캡처 대상 선택
        g_capture_item = CreateCaptureItemForPrimaryMonitor();
        if (!g_capture_item) {
            SetLastError("캡처 대상 생성 실패");
            return false;
        }

        // 2. Direct3D11 디바이스를 WinRT IDirect3DDevice로 래핑
        auto d3d_device_winrt = CreateDirect3DDevice(g_d3d_device);

        // 3. 프레임 풀 생성
        g_frame_pool = Direct3D11CaptureFramePool::CreateFreeThreaded(
            d3d_device_winrt,
            DirectXPixelFormat::B8G8R8A8UIntNormalized,  // BGRA
            2,  // 버퍼 수
            g_capture_item.Size()
        );

        // 4. FrameArrived 이벤트 핸들러 등록
        g_frame_pool.FrameArrived([](auto&& sender, auto&&) {
            OnFrameArrived(sender);
        });

        // 5. 세션 시작
        g_session = g_frame_pool.CreateCaptureSession(g_capture_item);
        g_session.IsCursorCaptureEnabled(false);  // 마우스 커서 제외
        g_session.StartCapture();

        return true;
    } catch (const hresult_error& e) {
        SetLastError(to_string(e.message()));
        return false;
    }
}
```

#### 3.2 Direct3D11 → WinRT 래핑

```cpp
#include <Windows.Graphics.DirectX.Direct3D11.interop.h>

IDirect3DDevice CreateDirect3DDevice(ID3D11Device* d3d_device) {
    com_ptr<IDXGIDevice> dxgi_device;
    d3d_device->QueryInterface(IID_PPV_ARGS(dxgi_device.put()));

    com_ptr<IInspectable> inspectable;
    CreateDirect3D11DeviceFromDXGIDevice(dxgi_device.get(), inspectable.put());

    return inspectable.as<IDirect3DDevice>();
}
```

---

### 4. 프레임 캡처 및 처리

#### 4.1 FrameArrived 이벤트 핸들러

```cpp
void OnFrameArrived(Direct3D11CaptureFramePool const& sender) {
    try {
        // 프레임 가져오기
        auto frame = sender.TryGetNextFrame();
        if (!frame) return;

        // Surface → ID3D11Texture2D 변환
        auto surface = frame.Surface();
        auto access = surface.as<IDirect3DDxgiInterfaceAccess>();

        com_ptr<ID3D11Texture2D> texture;
        access->GetInterface(guid_of<ID3D11Texture2D>(), texture.put_void());

        // 프레임 복사 (GPU → CPU)
        CopyFrameToStagingTexture(texture.get());

        // 프레임 버퍼 큐에 추가 (Phase 2.3에서 인코더가 소비)
        EnqueueFrame(texture.get());

    } catch (const hresult_error& e) {
        // 에러 로깅
    }
}
```

#### 4.2 Staging Texture로 복사 (GPU → CPU)

```cpp
// 전역 변수
static ID3D11Texture2D* g_staging_texture = nullptr;

void CopyFrameToStagingTexture(ID3D11Texture2D* source_texture) {
    // Staging Texture 생성 (최초 1회)
    if (!g_staging_texture) {
        D3D11_TEXTURE2D_DESC desc;
        source_texture->GetDesc(&desc);

        desc.Usage = D3D11_USAGE_STAGING;
        desc.BindFlags = 0;
        desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
        desc.MiscFlags = 0;

        g_d3d_device->CreateTexture2D(&desc, nullptr, &g_staging_texture);
    }

    // GPU → Staging Texture 복사
    g_d3d_context->CopyResource(g_staging_texture, source_texture);
}
```

#### 4.3 CPU 메모리로 읽기

```cpp
struct FrameData {
    std::vector<uint8_t> pixels;  // BGRA 데이터
    int width;
    int height;
    REFERENCE_TIME timestamp;  // 100-nanosecond 단위
};

FrameData ReadStagingTexture() {
    FrameData data;

    D3D11_TEXTURE2D_DESC desc;
    g_staging_texture->GetDesc(&desc);

    data.width = desc.Width;
    data.height = desc.Height;

    // Map (CPU 접근 가능하게)
    D3D11_MAPPED_SUBRESOURCE mapped;
    HRESULT hr = g_d3d_context->Map(g_staging_texture, 0, D3D11_MAP_READ, 0, &mapped);
    if (FAILED(hr)) return data;

    // 픽셀 데이터 복사
    size_t pixel_count = desc.Width * desc.Height * 4;  // BGRA
    data.pixels.resize(pixel_count);

    uint8_t* src = (uint8_t*)mapped.pData;
    uint8_t* dst = data.pixels.data();

    // 행 단위 복사 (패딩 고려)
    for (UINT y = 0; y < desc.Height; y++) {
        memcpy(dst + y * desc.Width * 4, src + y * mapped.RowPitch, desc.Width * 4);
    }

    g_d3d_context->Unmap(g_staging_texture, 0);

    // 타임스탬프 설정 (현재 시각)
    LARGE_INTEGER qpc;
    QueryPerformanceCounter(&qpc);
    data.timestamp = qpc.QuadPart;  // TODO: 정확한 변환 필요

    return data;
}
```

---

### 5. 프레임 버퍼 관리

#### 5.1 스레드 안전 큐

```cpp
#include <queue>
#include <mutex>
#include <condition_variable>

// 전역 변수
static std::queue<FrameData> g_frame_queue;
static std::mutex g_queue_mutex;
static std::condition_variable g_queue_cv;
static const size_t MAX_QUEUE_SIZE = 60;  // 최대 60 프레임 (2.5초 @ 24fps)

void EnqueueFrame(const FrameData& frame) {
    std::lock_guard<std::mutex> lock(g_queue_mutex);

    if (g_frame_queue.size() >= MAX_QUEUE_SIZE) {
        // 큐가 가득 찬 경우: 가장 오래된 프레임 버림
        g_frame_queue.pop();
    }

    g_frame_queue.push(frame);
    g_queue_cv.notify_one();
}

FrameData DequeueFrame() {
    std::unique_lock<std::mutex> lock(g_queue_mutex);
    g_queue_cv.wait(lock, [] { return !g_frame_queue.empty() || !g_is_recording; });

    if (g_frame_queue.empty()) return FrameData{};

    FrameData frame = g_frame_queue.front();
    g_frame_queue.pop();
    return frame;
}
```

---

## 테스트 시나리오

### 테스트 1: 초기화 성공

```dart
// Flutter
final result = NativeRecorderBindings.initialize();
expect(result, 0);
```

**예상 결과**:
- COM 초기화 성공
- D3D11 디바이스 생성 성공
- 로그: "✅ 네이티브 녹화 초기화 완료"

### 테스트 2: 캡처 세션 시작

```dart
final result = NativeRecorderBindings.startRecording(
  pathPtr, 1920, 1080, 24
);
expect(result, 0);
```

**예상 결과**:
- GraphicsCaptureItem 생성 성공
- FramePool 생성 성공
- FrameArrived 이벤트 발생
- 로그: "✅ 캡처 세션 시작"

### 테스트 3: 프레임 캡처 확인

**C++ 로깅 추가**:
```cpp
void OnFrameArrived(...) {
    static int frame_count = 0;
    frame_count++;

    if (frame_count % 24 == 0) {  // 1초마다
        char msg[100];
        sprintf(msg, "캡처된 프레임: %d (큐 크기: %zu)",
                frame_count, g_frame_queue.size());
        // 로그 출력
    }
}
```

**예상 로그**:
```
캡처된 프레임: 24 (큐 크기: 2)
캡처된 프레임: 48 (큐 크기: 3)
...
```

---

## 체크리스트

### Phase 2.1 작업 항목
- [ ] COM 및 Windows Runtime 초기화
- [ ] Direct3D11 디바이스 생성
- [ ] GraphicsCaptureItem 생성 (주 모니터)
- [ ] Direct3D11CaptureFramePool 생성
- [ ] FrameArrived 이벤트 핸들러 구현
- [ ] Staging Texture 복사 (GPU → CPU)
- [ ] 프레임 버퍼 큐 구현
- [ ] 프레임 캡처 테스트 (로그 확인)

### 선택 작업 (나중에)
- [ ] 특정 창 캡처 (Zoom 창 찾기)
- [ ] GraphicsCapturePicker UI (사용자가 선택)
- [ ] BGRA → RGB 변환 최적화
- [ ] 프레임 드롭 카운터

---

## 참고 자료

### 공식 문서
- [Windows.Graphics.Capture Namespace](https://docs.microsoft.com/en-us/uwp/api/windows.graphics.capture)
- [Screen Capture - Win32 apps](https://docs.microsoft.com/en-us/windows/uwp/audio-video-camera/screen-capture)

### 샘플 코드
- [Windows Universal Samples - ScreenCaptureforHWND](https://github.com/microsoft/Windows-universal-samples/tree/main/Samples/ScreenCaptureforHWND)

### C++/WinRT 가이드
- [C++/WinRT Introduction](https://docs.microsoft.com/en-us/windows/uwp/cpp-and-winrt-apis/)

---

**작성일**: 2025-10-23
**다음 단계**: Phase 2.2 (WASAPI 오디오 캡처)
**예상 완료일**: 2025-10-26
