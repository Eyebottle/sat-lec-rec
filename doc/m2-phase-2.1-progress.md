# M2 Phase 2.1 진행 상황

**시작일**: 2025-10-23
**목표**: Windows Graphics Capture API로 화면 캡처 구현
**참고 문서**: `m2-phase-2.1-graphics-capture.md`

---

## 진행 상황 요약

### 완료된 작업 (40%)

#### 1. COM 및 Direct3D11 초기화 ✅

**파일**: `windows/runner/native_screen_recorder.cpp`

**구현 내용**:
- `CreateD3D11Device()`: D3D11 디바이스 및 컨텍스트 생성
  - Feature Level: 11.1, 11.0, 10.1, 10.0 지원
  - `D3D11_CREATE_DEVICE_BGRA_SUPPORT` 플래그 (Graphics Capture 필수)
  - Debug 모드에서 `D3D11_CREATE_DEVICE_DEBUG` 추가

- `NativeRecorder_Initialize()` 수정:
  ```cpp
  // COM 초기화 (멀티스레드 아파트)
  HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);

  // Direct3D11 디바이스 생성
  if (!CreateD3D11Device()) {
      SetLastError("D3D11 디바이스 생성 실패");
      return -2;
  }
  ```

- `CleanupD3D11()`: 리소스 정리 함수
  - Staging Texture 해제
  - Device Context 해제
  - Device 해제

**테스트 결과**:
```
✅ RecorderService 초기화 시작...
✅ 네이티브 녹화 초기화 완료
✅ RecorderService 초기화 완료
```

**커밋**: `39dc0b9`

---

#### 2. 프레임 버퍼 관리 인프라 ✅

**파일**: `windows/runner/native_screen_recorder.cpp`

**구현 내용**:

**FrameData 구조체**:
```cpp
struct FrameData {
    std::vector<uint8_t> pixels;  // BGRA 픽셀 데이터
    int width;
    int height;
    uint64_t timestamp;  // QueryPerformanceCounter 값
};
```

**스레드 안전 큐**:
- `std::queue<FrameData>` 사용
- `std::mutex` + `std::condition_variable`로 동기화
- 최대 큐 크기: 60 프레임 (약 2.5초 @ 24fps)
- FIFO 방식: 큐 가득 차면 가장 오래된 프레임 버림

**함수**:
- `EnqueueFrame(const FrameData& frame)`: 프레임 큐에 추가
- `DequeueFrame()`: 프레임 큐에서 가져오기 (블로킹)

**설계 의도**:
- 캡처 스레드와 인코딩 스레드 분리
- 프레임 드롭 시 가장 오래된 것부터 버려 최신 프레임 유지
- `condition_variable`로 대기 → CPU 절약

**커밋**: `39dc0b9`

---

#### 3. CMakeLists.txt C++17 설정 ✅

**파일**: `windows/runner/CMakeLists.txt`

**추가 내용**:
```cmake
# C++/WinRT 지원을 위한 C++17 설정
set_target_properties(${BINARY_NAME} PROPERTIES CXX_STANDARD 17)
set_target_properties(${BINARY_NAME} PROPERTIES CXX_STANDARD_REQUIRED ON)
```

**이유**:
- C++/WinRT는 C++17 이상 필요
- `std::optional`, `if constexpr` 등 모던 C++ 기능 사용

**커밋**: `39dc0b9`

---

#### 4. 자동 초기화 구현 ✅

**파일**: `lib/main.dart`

**구현 내용**:
```dart
@override
void initState() {
  super.initState();
  windowManager.addListener(this);
  _initializeRecorder();
}

Future<void> _initializeRecorder() async {
  try {
    logger.i('RecorderService 초기화 시작...');
    await _recorderService.initialize();
    logger.i('✅ RecorderService 초기화 완료');
  } catch (e, stackTrace) {
    logger.e('❌ RecorderService 초기화 실패', error: e, stackTrace: stackTrace);
  }
}
```

**효과**:
- 앱 시작 시 자동으로 COM/D3D11 초기화
- 로그를 통해 초기화 성공 여부 즉시 확인 가능
- 버튼 클릭 없이도 테스트 가능

**커밋**: `39dc0b9`

---

## 다음 작업 (60%)

### 5. C++/WinRT 헤더 추가 및 빌드 검증 (다음 단계)

**목표**: C++/WinRT를 사용한 Windows Runtime API 호출 준비

**작업 항목**:
- [ ] `native_screen_recorder.cpp`에 WinRT 헤더 추가:
  ```cpp
  #include <winrt/Windows.Foundation.h>
  #include <winrt/Windows.Graphics.Capture.h>
  #include <winrt/Windows.Graphics.DirectX.Direct3D11.h>
  ```
- [ ] Windows SDK 버전 확인 (10.0.17134 이상 필요)
- [ ] 빌드 테스트 (헤더만 추가하고 컴파일 확인)
- [ ] C++/WinRT 네임스페이스 사용:
  ```cpp
  using namespace winrt;
  using namespace Windows::Graphics::Capture;
  ```

**예상 문제**:
- Windows SDK 버전 불일치
- C++/WinRT NuGet 패키지 필요 여부
- 링커 에러 (`windowsapp.lib` 필요)

**해결 방법**:
- CMakeLists.txt에 `windowsapp.lib` 추가:
  ```cmake
  target_link_libraries(${BINARY_NAME} PRIVATE "windowsapp.lib")
  ```

---

### 6. GraphicsCaptureItem 생성

**목표**: 캡처할 대상(모니터 또는 창) 선택

**작업 항목**:
- [ ] `CreateCaptureItemForPrimaryMonitor()` 함수 구현
  - `IGraphicsCaptureItemInterop` 사용
  - 주 모니터 핸들 가져오기 (`MonitorFromPoint`)
  - GraphicsCaptureItem 생성

- [ ] (선택) `FindZoomWindow()` 함수 구현
  - `FindWindowW(nullptr, L"Zoom Meeting")` 사용
  - Zoom 창 핸들 반환

**참고 코드** (`m2-phase-2.1-graphics-capture.md` 참조):
```cpp
GraphicsCaptureItem CreateCaptureItemForPrimaryMonitor() {
    HMONITOR primary_monitor = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);

    auto interop = get_activation_factory<GraphicsCaptureItem, IGraphicsCaptureItemInterop>();
    GraphicsCaptureItem item = nullptr;
    interop->CreateForMonitor(primary_monitor, guid_of<GraphicsCaptureItem>(), put_abi(item));

    return item;
}
```

---

### 7. GraphicsCaptureSession 시작

**목표**: 실제 캡처 세션 생성 및 시작

**작업 항목**:
- [ ] Direct3D11 → WinRT IDirect3DDevice 변환
  - `CreateDirect3DDevice(ID3D11Device*)` 함수 구현
  - `CreateDirect3D11DeviceFromDXGIDevice` 사용

- [ ] `Direct3D11CaptureFramePool` 생성
  - 픽셀 포맷: `B8G8R8A8UIntNormalized` (BGRA)
  - 버퍼 수: 2 프레임

- [ ] `GraphicsCaptureSession` 생성 및 설정
  - `IsCursorCaptureEnabled(false)` 설정 (마우스 커서 제외)
  - `StartCapture()` 호출

**참고 코드**:
```cpp
g_frame_pool = Direct3D11CaptureFramePool::CreateFreeThreaded(
    d3d_device_winrt,
    DirectXPixelFormat::B8G8R8A8UIntNormalized,
    2,  // 버퍼 수
    g_capture_item.Size()
);

g_frame_pool.FrameArrived([](auto&& sender, auto&&) {
    OnFrameArrived(sender);
});

g_session = g_frame_pool.CreateCaptureSession(g_capture_item);
g_session.StartCapture();
```

---

### 8. FrameArrived 이벤트 핸들러 구현

**목표**: 프레임 캡처 이벤트 처리

**작업 항목**:
- [ ] `OnFrameArrived()` 함수 구현
  - `TryGetNextFrame()` 호출
  - Surface → `ID3D11Texture2D` 변환
  - Staging Texture로 복사

- [ ] GPU → CPU 복사 로직
  - Staging Texture 생성 (`D3D11_USAGE_STAGING`)
  - `CopyResource()` 사용
  - `Map()` / `Unmap()`으로 픽셀 데이터 읽기

- [ ] `EnqueueFrame()` 호출로 큐에 추가

**참고 코드**:
```cpp
void OnFrameArrived(Direct3D11CaptureFramePool const& sender) {
    auto frame = sender.TryGetNextFrame();
    if (!frame) return;

    auto surface = frame.Surface();
    auto access = surface.as<IDirect3DDxgiInterfaceAccess>();

    com_ptr<ID3D11Texture2D> texture;
    access->GetInterface(guid_of<ID3D11Texture2D>(), texture.put_void());

    CopyFrameToStagingTexture(texture.get());
    EnqueueFrame(ReadStagingTexture());
}
```

---

### 9. GPU → CPU 프레임 복사

**목표**: GPU 메모리에서 CPU로 픽셀 데이터 복사

**작업 항목**:
- [ ] `CopyFrameToStagingTexture()` 구현
  - 최초 1회 Staging Texture 생성
  - `CopyResource()` 호출

- [ ] `ReadStagingTexture()` 구현
  - `Map()` 호출로 CPU 접근
  - 행 단위 복사 (RowPitch 고려)
  - `Unmap()` 호출
  - `FrameData` 반환

**주의사항**:
- RowPitch와 실제 너비가 다를 수 있음 (패딩)
- BGRA 포맷 (4 bytes per pixel)

---

### 10. 전체 모니터 캡처 테스트

**목표**: 1프레임 이상 캡처 성공 확인

**테스트 시나리오**:
1. 앱 시작
2. 초기화 로그 확인
3. 녹화 시작 (10초 테스트)
4. FrameArrived 로그 확인
5. 큐에 프레임 추가 확인

**예상 로그**:
```
✅ RecorderService 초기화 시작...
✅ 네이티브 녹화 초기화 완료
✅ RecorderService 초기화 완료
✅ 녹화 시작 (10초)
🎬 프레임 캡처: 1 (1920x1080)
🎬 프레임 캡처: 2 (1920x1080)
...
✅ 녹화 종료
```

---

## 블로커 및 리스크

### 현재 블로커

1. **C++/WinRT 헤더 빌드 검증 필요**
   - Windows SDK 버전 확인
   - 링커 설정 (`windowsapp.lib`)

2. **GraphicsCapture API 미경험**
   - 공식 샘플 코드 참고 필요
   - WinRT Interop 복잡도

### 예상 리스크

1. **성능 문제**
   - GPU → CPU 복사 오버헤드
   - 해결: Staging Texture 재사용, 비동기 복사

2. **프레임 드롭**
   - 큐 크기 부족 또는 인코더 느림
   - 해결: 큐 크기 조정, 로그로 모니터링

3. **메모리 누수**
   - WinRT 객체 수명 관리
   - 해결: RAII 패턴, 스마트 포인터 사용

---

## 참고 자료

### 공식 문서
- [Windows.Graphics.Capture Namespace](https://docs.microsoft.com/en-us/uwp/api/windows.graphics.capture)
- [Screen Capture - Win32 apps](https://docs.microsoft.com/en-us/windows/uwp/audio-video-camera/screen-capture)

### 샘플 코드
- [robmikh/Win32CaptureSample](https://github.com/robmikh/Win32CaptureSample)
- [Windows Universal Samples - ScreenCaptureforHWND](https://github.com/microsoft/Windows-universal-samples/tree/main/Samples/ScreenCaptureforHWND)

### C++/WinRT 가이드
- [C++/WinRT Introduction](https://docs.microsoft.com/en-us/windows/uwp/cpp-and-winrt-apis/)

---

## 체크리스트 (전체)

### 기반 인프라 (완료)
- [x] COM 초기화
- [x] Direct3D11 디바이스 생성
- [x] FrameData 구조체 정의
- [x] 프레임 버퍼 큐 구현
- [x] CMakeLists.txt C++17 설정
- [x] 자동 초기화 구현

### Graphics Capture API (진행 중)
- [ ] C++/WinRT 헤더 추가 및 빌드 검증
- [ ] GraphicsCaptureItem 생성 (모니터)
- [ ] GraphicsCaptureSession 시작
- [ ] FrameArrived 이벤트 핸들러 구현
- [ ] GPU → CPU 프레임 복사
- [ ] 전체 모니터 캡처 테스트 (1프레임)

### 선택 작업 (나중에)
- [ ] Zoom 창 타깃 캡처
- [ ] 창 캡처 실패 시 폴백 로직
- [ ] 프레임 드롭 카운터
- [ ] BGRA → RGB 변환 최적화

---

**최종 업데이트**: 2025-10-23
**다음 세션 시작 지점**: C++/WinRT 헤더 추가 및 빌드 검증
