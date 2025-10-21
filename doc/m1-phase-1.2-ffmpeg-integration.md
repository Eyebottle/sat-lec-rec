# M1 Phase 1.2: FFmpeg 런타임 통합 계획

**목표**: C++에서 FFmpeg 프로세스를 실행하고 Named Pipe를 통해 데이터를 전달하는 기초 구조 구축

**예상 소요 시간**: 2~3시간

**의존성**: M0 완료, FFI 기초 동작 확인

---

## 1. FFmpeg 바이너리 준비

### 1.1 다운로드
- **소스**: https://github.com/BtbN/FFmpeg-Builds/releases
- **버전**: 최신 Release (GPL, full build)
- **파일**: `ffmpeg-master-latest-win64-gpl.zip`

### 1.2 배치 구조
```
sat-lec-rec/
├── third_party/
│   └── ffmpeg/
│       ├── ffmpeg.exe
│       ├── ffprobe.exe
│       └── README.md  (버전 정보 기록)
└── .gitignore  (third_party/ffmpeg/*.exe 제외)
```

### 1.3 검증
```bash
# Windows PowerShell
cd C:\ws-workspace\sat-lec-rec\third_party\ffmpeg
.\ffmpeg.exe -version
.\ffprobe.exe -version
```

---

## 2. C++ FFmpeg 실행 인프라

### 2.1 파일 구조
```
windows/runner/
├── ffmpeg_runner.h       (새로 생성)
├── ffmpeg_runner.cpp     (새로 생성)
├── native_recorder_plugin.h  (기존)
└── native_recorder_plugin.cpp  (수정)
```

### 2.2 FFmpegRunner 클래스 설계

#### ffmpeg_runner.h
```cpp
#ifndef FFMPEG_RUNNER_H_
#define FFMPEG_RUNNER_H_

#include <windows.h>
#include <string>

/// FFmpeg 프로세스 관리 클래스
///
/// 책임:
/// - FFmpeg 바이너리 경로 확인
/// - 프로세스 생성 및 종료
/// - Named Pipe 생성 및 관리
class FFmpegRunner {
 public:
  FFmpegRunner();
  ~FFmpegRunner();

  /// FFmpeg 바이너리 존재 여부 확인
  ///
  /// @return true if ffmpeg.exe exists
  bool CheckFFmpegExists();

  /// FFmpeg 프로세스 시작 (테스트용)
  ///
  /// @param args 명령줄 인수 (예: "-version")
  /// @param output_file 출력 파일 경로 (선택)
  /// @return true if process started successfully
  bool StartFFmpeg(const std::wstring& args, const std::wstring& output_file = L"");

  /// FFmpeg 프로세스 종료
  void StopFFmpeg();

  /// FFmpeg 실행 중 여부
  ///
  /// @return true if process is running
  bool IsRunning();

 private:
  PROCESS_INFORMATION process_info_;
  HANDLE pipe_handle_;
  bool is_running_;

  /// FFmpeg 실행 파일 경로 획득
  ///
  /// @return 절대 경로 (예: C:\...\sat-lec-rec\third_party\ffmpeg\ffmpeg.exe)
  std::wstring GetFFmpegPath();
};

#endif  // FFMPEG_RUNNER_H_
```

#### ffmpeg_runner.cpp (초기 구현)
```cpp
#include "ffmpeg_runner.h"
#include <shlwapi.h>
#include <filesystem>

#pragma comment(lib, "shlwapi.lib")

namespace fs = std::filesystem;

FFmpegRunner::FFmpegRunner()
    : process_info_{}, pipe_handle_(INVALID_HANDLE_VALUE), is_running_(false) {}

FFmpegRunner::~FFmpegRunner() {
  StopFFmpeg();
}

std::wstring FFmpegRunner::GetFFmpegPath() {
  // 실행 파일의 디렉토리 획득
  wchar_t exe_path[MAX_PATH];
  GetModuleFileNameW(NULL, exe_path, MAX_PATH);

  fs::path exe_dir = fs::path(exe_path).parent_path();
  fs::path ffmpeg_path = exe_dir / "data" / "flutter_assets" / "assets" / "ffmpeg" / "ffmpeg.exe";

  // 개발 환경: 프로젝트 루트에서 상대 경로
  if (!fs::exists(ffmpeg_path)) {
    ffmpeg_path = exe_dir.parent_path().parent_path() / "third_party" / "ffmpeg" / "ffmpeg.exe";
  }

  return ffmpeg_path.wstring();
}

bool FFmpegRunner::CheckFFmpegExists() {
  std::wstring path = GetFFmpegPath();
  return fs::exists(path);
}

bool FFmpegRunner::StartFFmpeg(const std::wstring& args, const std::wstring& output_file) {
  if (is_running_) {
    return false;
  }

  std::wstring ffmpeg_path = GetFFmpegPath();
  if (!fs::exists(ffmpeg_path)) {
    return false;
  }

  // 명령줄 구성
  std::wstring cmdline = L"\"" + ffmpeg_path + L"\" " + args;
  if (!output_file.empty()) {
    cmdline += L" \"" + output_file + L"\"";
  }

  // 프로세스 시작
  STARTUPINFOW si = {};
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESTDHANDLES;

  BOOL success = CreateProcessW(
    NULL,
    const_cast<LPWSTR>(cmdline.c_str()),
    NULL, NULL, FALSE, CREATE_NO_WINDOW,
    NULL, NULL, &si, &process_info_
  );

  if (success) {
    is_running_ = true;
    return true;
  }

  return false;
}

void FFmpegRunner::StopFFmpeg() {
  if (!is_running_) {
    return;
  }

  TerminateProcess(process_info_.hProcess, 0);
  CloseHandle(process_info_.hProcess);
  CloseHandle(process_info_.hThread);

  is_running_ = false;
}

bool FFmpegRunner::IsRunning() {
  if (!is_running_) {
    return false;
  }

  DWORD exit_code;
  if (GetExitCodeProcess(process_info_.hProcess, &exit_code)) {
    if (exit_code != STILL_ACTIVE) {
      is_running_ = false;
      return false;
    }
  }

  return true;
}
```

### 2.3 Dart FFI 바인딩 추가

#### lib/ffi/native_bindings.dart (수정)
```dart
// 기존 import 유지
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// 새로운 typedef 추가
typedef CheckFFmpegNative = Int8 Function();
typedef CheckFFmpegDart = int Function();

class NativeRecorder {
  // 기존 코드 유지
  static late DynamicLibrary _dylib;
  static late NativeHelloDart _nativeHello;
  static late CheckFFmpegDart _checkFFmpeg;
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;

    if (!Platform.isWindows) {
      throw UnsupportedError('This platform is not supported. Windows only.');
    }

    _dylib = DynamicLibrary.executable();

    // 기존 함수
    _nativeHello = _dylib
        .lookup<NativeFunction<NativeHelloNative>>('NativeHello')
        .asFunction();

    // 새 함수: FFmpeg 체크
    _checkFFmpeg = _dylib
        .lookup<NativeFunction<CheckFFmpegNative>>('CheckFFmpegExists')
        .asFunction();

    _initialized = true;
  }

  // 기존 hello() 유지
  static String hello() {
    // ...
  }

  /// FFmpeg 바이너리 존재 여부 확인
  ///
  /// @return true if ffmpeg.exe exists
  static bool checkFFmpeg() {
    if (!_initialized) {
      throw StateError('NativeRecorder not initialized. Call initialize() first.');
    }
    return _checkFFmpeg() == 1;
  }
}
```

### 2.4 C++ Export 함수 추가

#### windows/runner/native_recorder_plugin.cpp (수정)
```cpp
#include "native_recorder_plugin.h"
#include "ffmpeg_runner.h"

extern "C" {

// 기존 함수 유지
__declspec(dllexport) const char* NativeHello() {
    return "Hello from C++ Native Plugin!";
}

// 새 함수: FFmpeg 체크
__declspec(dllexport) int CheckFFmpegExists() {
    FFmpegRunner runner;
    return runner.CheckFFmpegExists() ? 1 : 0;
}

}  // extern "C"
```

---

## 3. CMakeLists.txt 수정

### windows/runner/CMakeLists.txt
```cmake
# 기존 코드 유지, add_executable에 파일 추가
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "native_recorder_plugin.cpp"
  "ffmpeg_runner.cpp"  # 추가
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)
```

---

## 4. UI 테스트 화면 추가

### lib/main.dart (수정)
```dart
// main() 함수의 FFI 테스트 부분 수정
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    NativeRecorder.initialize();
    final message = NativeRecorder.hello();
    logger.i('FFI 테스트 성공: $message');

    // FFmpeg 체크 추가
    final ffmpegExists = NativeRecorder.checkFFmpeg();
    if (ffmpegExists) {
      logger.i('✅ FFmpeg 바이너리 확인됨');
    } else {
      logger.w('⚠️ FFmpeg 바이너리를 찾을 수 없습니다');
    }
  } catch (e, stackTrace) {
    logger.e('FFI 초기화 실패', error: e, stackTrace: stackTrace);
  }

  // ... 나머지 코드 유지
}
```

---

## 5. 테스트 시나리오

### 5.1 FFmpeg 바이너리 없는 상태
1. `third_party/ffmpeg/` 폴더가 비어있는 상태로 빌드
2. 앱 실행 시 로그 확인: `⚠️ FFmpeg 바이너리를 찾을 수 없습니다`

### 5.2 FFmpeg 바이너리 배치 후
1. FFmpeg 다운로드 및 배치
2. 앱 재실행
3. 로그 확인: `✅ FFmpeg 바이너리 확인됨`

### 5.3 FFmpeg 버전 테스트 (다음 단계)
1. UI에 "FFmpeg 버전 확인" 버튼 추가
2. C++에서 `ffmpeg -version` 실행
3. 결과를 Dart로 전달하여 UI에 표시

---

## 6. 체크리스트

- [ ] FFmpeg 바이너리 다운로드 및 배치
- [ ] `ffmpeg_runner.h` 생성
- [ ] `ffmpeg_runner.cpp` 생성
- [ ] `native_recorder_plugin.cpp` 수정 (CheckFFmpegExists 추가)
- [ ] `lib/ffi/native_bindings.dart` 수정 (checkFFmpeg 추가)
- [ ] `lib/main.dart` 수정 (FFmpeg 체크 로그 추가)
- [ ] `CMakeLists.txt` 수정 (ffmpeg_runner.cpp 추가)
- [ ] `.gitignore` 업데이트 (*.exe 제외)
- [ ] WSL → Windows 동기화
- [ ] Windows에서 빌드 및 실행
- [ ] 로그 확인: FFmpeg 바이너리 존재 여부

---

## 7. 다음 단계 (Phase 1.3)

- Named Pipe 생성 및 테스트
- FFmpeg 프로세스에 stdin으로 데이터 전달
- 간단한 테스트 영상 인코딩 (컬러바 패턴 → MP4)

---

## 참고 자료

- [FFmpeg Windows Builds](https://github.com/BtbN/FFmpeg-Builds)
- [Windows CreateProcess 문서](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw)
- [Named Pipes 가이드](https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipes)
