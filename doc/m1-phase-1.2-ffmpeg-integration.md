# M1 Phase 1.2: 네이티브 화면 녹화 인프라 구축 (아키텍처 v3.0)

**목표**: Windows Native API(Graphics Capture + WASAPI)를 C++로 구현하고 Flutter FFI로 연결

**예상 소요 시간**: 6~8시간 (FFI 심볼 export 문제 해결 포함)

**의존성**: M0 완료, M1 Phase 1.1 FFI 기초 구조 구축

**작성일**: 2025-10-23 (3차 재설계)

---

## 아키텍처 변천사

### v1.0: C++ FFI + FFmpeg 프로세스 ❌
```
복잡도: Dart → C++ FFI → FFmpeg 프로세스 → Named Pipe → 인코딩

문제점:
- FFmpeg 경로 해결 실패 (fs::exists 문제, 5회 빌드 실패)
- 플랫폼 종속적 (Windows 전용)
- 수동 바이너리 관리 필요 (170MB ffmpeg.exe)
- 복잡한 디버깅
```

### v2.0: Flutter 패키지 (desktop_screen_recorder) ❌
```
단순화: Dart → desktop_screen_recorder → 자동 인코딩

문제점:
- desktop_screen_recorder 0.0.1은 스켈레톤 코드 (실제 기능 없음)
- getPlatformVersion() 메서드만 구현됨
- Flutter 생태계에 Windows 화면 녹화 패키지 부재
```

### v3.0: Windows Native API + FFI (현재 구현) ✅
```
구조: Dart FFI → C++ (Graphics Capture + WASAPI) → H.264/AAC → MP4

장점:
- 경로 문제 원천 차단 (외부 실행 파일 불필요)
- 단일 언어 스택 (C++ ↔ Dart FFI)
- Visual Studio 직접 디버깅 가능
- 배포 단순화 (단일 EXE)
- 코드 관리 용이

단점:
- 초기 구현 시간 증가 (Phase 2.1~2.4로 분산)
- Windows API 학습 곡선
```

---

## 완료된 작업 (Phase 1.2 기반 구축)

### 1. 기존 코드 정리 ✅

**삭제된 파일**:
- `windows/runner/ffmpeg_runner.h/cpp`
- `windows/runner/native_recorder_plugin.h/cpp` (초기 FFI 테스트용)
- `lib/ffi/native_bindings.dart` (v1 버전)
- `third_party/ffmpeg/` 폴더 (더 이상 불필요)

**복원된 파일**:
- `windows/runner/CMakeLists.txt` (Flutter 기본 구조로 원복)
- `lib/main.dart` (FFI 테스트 코드 제거)

**커밋**: `ab8b907` "refactor: 기존 C++ FFI 코드 제거"

---

### 2. C++ 네이티브 인프라 구축 ✅

#### 2.1 헤더 파일 작성
**파일**: `windows/runner/native_screen_recorder.h`

**주요 내용**:
- `NATIVE_RECORDER_EXPORT` 매크로 정의 (`__declspec(dllexport)`)
- C 스타일 FFI 인터페이스 선언 (`extern "C"`)
- 6개 네이티브 함수 export:
  - `NativeRecorder_Initialize()`
  - `NativeRecorder_StartRecording()`
  - `NativeRecorder_StopRecording()`
  - `NativeRecorder_IsRecording()`
  - `NativeRecorder_Cleanup()`
  - `NativeRecorder_GetLastError()`

```cpp
// 예시
#define NATIVE_RECORDER_EXPORT __declspec(dllexport)

extern "C" {
NATIVE_RECORDER_EXPORT int32_t NativeRecorder_Initialize();
NATIVE_RECORDER_EXPORT int32_t NativeRecorder_StartRecording(
    const char* output_path,
    int32_t width,
    int32_t height,
    int32_t fps
);
// ...
}
```

#### 2.2 구현 파일 작성 (스텁)
**파일**: `windows/runner/native_screen_recorder.cpp`

**현재 상태**: 스텁 구현 (실제 캡처 로직은 Phase 2에서 구현)

**구현 내용**:
- 멀티스레드 구조 준비 (캡처 스레드 분리)
- 에러 처리 구조 (`SetLastError`, `GetLastError`)
- 녹화 상태 관리 (`g_is_recording`, `g_capture_thread`)
- `extern "C"` 블록으로 모든 함수 감싸기 (C 링크 보장)

```cpp
extern "C" {

int32_t NativeRecorder_Initialize() {
    // TODO: COM 초기화 (CoInitializeEx)
    // TODO: Windows Runtime 초기화
    SetLastError("");
    return 0;  // 성공
}

int32_t NativeRecorder_StartRecording(...) {
    g_is_recording = true;
    g_capture_thread = std::thread(CaptureThreadFunc, ...);
    return 0;
}

}  // extern "C"
```

#### 2.3 CMake 설정
**파일**: `windows/runner/CMakeLists.txt`

**변경 사항**:
1. 소스 파일 추가: `native_screen_recorder.cpp`
2. **심볼 export 설정 추가**:
   ```cmake
   set_target_properties(${BINARY_NAME} PROPERTIES ENABLE_EXPORTS ON)
   ```
   → 이 설정이 없으면 EXE가 심볼을 export하지 않음

**커밋**: `788d9ff` "feat: 네이티브 화면 녹화 C++ 인프라 추가 (스텁)"

---

### 3. Dart FFI 바인딩 연결 ✅

#### 3.1 FFI 바인딩 파일 작성
**파일**: `lib/ffi/native_bindings.dart`

**구현 내용**:
- `DynamicLibrary.executable()` 사용 (Windows EXE에서 심볼 로드)
- 6개 네이티브 함수 바인딩
- 헬퍼 함수: `getNativeLastError()` (에러 메시지 String 변환)

```dart
class NativeRecorderBindings {
  static final ffi.DynamicLibrary _lib = ffi.DynamicLibrary.executable();

  static final DartInitializeFunc initialize = _lib
      .lookup<ffi.NativeFunction<NativeInitializeFunc>>('NativeRecorder_Initialize')
      .asFunction();

  // 나머지 함수들...
}
```

#### 3.2 RecorderService 통합
**파일**: `lib/services/recorder_service.dart`

**구현 내용**:
- `initialize()`: 네이티브 초기화
- `startRecording()`: 네이티브 함수 호출, 경로 전달 (UTF-8)
- `stopRecording()`: 네이티브 중지, 파일 존재 확인
- `dispose()`: 네이티브 리소스 정리
- 에러 처리 및 로깅

**주요 코드**:
```dart
Future<String?> startRecording({required int durationSeconds}) async {
  final outputPath = await _generateOutputPath();

  // 네이티브 녹화 시작
  final pathPtr = outputPath.toNativeUtf8();
  try {
    final result = NativeRecorderBindings.startRecording(
      pathPtr,
      1920, 1080, 24,  // 해상도, FPS
    );

    if (result != 0) {
      throw Exception('네이티브 녹화 시작 실패: ${getNativeLastError()}');
    }
  } finally {
    malloc.free(pathPtr);
  }

  // 10초 후 자동 중지
  Timer(Duration(seconds: durationSeconds), () async {
    await stopRecording();
  });

  return outputPath;
}
```

**커밋**: `e1e1f8f` "feat: Dart FFI 바인딩 연결 및 RecorderService 네이티브 통합"

---

### 4. FFI 심볼 Export 문제 해결 ✅

#### 4.1 문제 발생
**에러**:
```
Invalid argument(s): Failed to lookup symbol 'NativeRecorder_Initialize':
The specified procedure could not be found. (error code: 127)
```

**원인**:
- Windows EXE는 기본적으로 함수를 export하지 않음
- `extern "C"`만으로는 부족 (C 링크는 되지만 export는 안 됨)
- `DynamicLibrary.executable()`이 exported symbols table을 검색하는데, 그곳에 심볼이 없음

#### 4.2 해결 방법

**Step 1**: 헤더에 export 지시자 추가
```cpp
// native_screen_recorder.h
#if defined(_WIN32)
  #define NATIVE_RECORDER_EXPORT __declspec(dllexport)
#else
  #define NATIVE_RECORDER_EXPORT
#endif

extern "C" {
NATIVE_RECORDER_EXPORT int32_t NativeRecorder_Initialize();
// ...
}
```

**Step 2**: CMake에서 ENABLE_EXPORTS 설정
```cmake
# CMakeLists.txt
set_target_properties(${BINARY_NAME} PROPERTIES ENABLE_EXPORTS ON)
```

**Step 3**: extern "C" 블록으로 구현부 감싸기
```cpp
// native_screen_recorder.cpp
extern "C" {

int32_t NativeRecorder_Initialize() {
    // 구현...
}

}  // extern "C"
```

**커밋**:
- `86fd026` "fix: C++ 함수에 extern "C" 링크 명시적 적용"
- `3cda7c1` "fix: Windows EXE에서 FFI 심볼 export 설정 추가"

#### 4.3 검증 성공
**테스트**: `flutter run -d windows` → "10초 테스트" 버튼 클릭

**로그**:
```
✅ 네이티브 녹화 초기화 완료
🎬 녹화 시작 요청 (10초)
📁 저장 경로: C:\Users\user\OneDrive\문서/SaturdayZoomRec/20251023_0848_test.mp4
✅ 녹화 시작 완료
⏹️  녹화 중지 요청
📊 세션 통계:
  - 시작 시각: 2025-10-23T08:48:34.703210
  - 총 녹화 시간: 10초
✅ 녹화 중지 완료
```

**결과**: FFI 통신 완벽 작동 ✅

---

## 다음 단계: Phase 2 실제 캡처 구현

현재는 **스텁 상태**로, 실제 화면/오디오 캡처는 구현되지 않았습니다.

### Phase 2.1: Windows Graphics Capture API (3~4일)
- Direct3D11 초기화
- GraphicsCaptureItem 생성 (모니터 또는 특정 창)
- GraphicsCaptureSession 시작
- FrameArrived 이벤트 핸들러
- BGRA 프레임 → RGB 변환
- 프레임 버퍼 관리

**참고 문서**: `doc/m2-phase-2.1-graphics-capture.md` (작성 예정)

### Phase 2.2: WASAPI Loopback 오디오 캡처 (2~3일)
- IMMDeviceEnumerator로 오디오 장치 가져오기
- IAudioClient 초기화 (Loopback 모드)
- IAudioCaptureClient로 샘플 캡처
- 오디오/비디오 타임스탬프 동기화

**참고 문서**: `doc/m2-phase-2.2-wasapi-audio.md` (작성 예정)

### Phase 2.3: H.264/AAC 인코딩 (3~4일)
- Media Foundation 초기화
- IMFSinkWriter 생성 (MP4 출력)
- H.264 비디오 스트림 설정
- AAC 오디오 스트림 설정
- 프레임/샘플 인코딩 및 mux

### Phase 2.4: Fragmented MP4 저장 (2일)
- Fragmented MP4 포맷 설정
- 실시간 저장 (크래시 시 복구 가능)
- 파일 크기 모니터링
- 메타데이터 저장 (JSON)

---

## 학습 교훈

### ✅ 성공 요인
1. **CodeX 조언 채택**: FFmpeg 프로세스 방식 포기, 네이티브 구현 선택
2. **철저한 조사**: Flutter 패키지 생태계 한계 파악
3. **단계적 접근**: 스텁 → FFI 연결 → 심볼 export → 실제 구현
4. **문서화**: 시행착오 과정을 상세히 기록

### ⚠️ 주의사항
1. **Windows EXE export**: `__declspec(dllexport)` + `ENABLE_EXPORTS ON` 필수
2. **extern "C" 블록**: 선언뿐 아니라 **구현부도** 감싸야 함
3. **UTF-8 문자열**: `toNativeUtf8()` 후 반드시 `malloc.free()`
4. **멀티스레드**: 캡처 스레드와 메인 스레드 분리 필수

---

## 체크리스트

### Phase 1.2 완료 항목
- [x] 기존 C++ FFI 코드 제거
- [x] `third_party/ffmpeg/` 폴더 삭제
- [x] C++ 네이티브 인프라 구축 (헤더/구현/CMake)
- [x] Dart FFI 바인딩 작성
- [x] RecorderService 네이티브 통합
- [x] FFI 심볼 export 문제 해결
- [x] 10초 테스트 성공 (스텁)

### Phase 2 준비 항목
- [ ] Phase 2.1 문서 작성 (Graphics Capture API)
- [ ] Phase 2.2 문서 작성 (WASAPI)
- [ ] Direct3D11 학습 자료 수집
- [ ] Media Foundation 샘플 코드 분석

---

**작성일**: 2025-10-23
**버전**: v3.0 (Windows Native API + FFI)
**작성자**: AI 협업 (Claude Code)
**상태**: Phase 1.2 완료, Phase 2 준비 중
