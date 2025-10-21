# M0: 개발 환경 설정 체크리스트

본 문서는 sat-lec-rec 프로젝트의 개발 환경을 처음부터 설정하는 단계별 가이드입니다.

**목표**: Windows Desktop에서 Flutter 앱 빌드 및 실행 성공, C++ FFI 기초 검증 완료

**예상 소요 시간**: 1.5 ~ 2시간

---

## 전제 조건

- WSL2 (Ubuntu 24.04 권장)
- Windows 11
- 관리자 권한
- 인터넷 연결

---

## 1. WSL 환경 설정 (30분)

### 1.1 WSL 업데이트

```bash
sudo apt update && sudo apt upgrade -y
```

**확인**:
```bash
lsb_release -a
# Ubuntu 24.04.x LTS 출력 확인
```

- [ ] WSL Ubuntu 24.04 설치 및 업데이트 완료

### 1.2 필수 패키지 설치

```bash
sudo apt install -y git rsync curl unzip xz-utils zip libglu1-mesa
```

**확인**:
```bash
git --version
rsync --version
```

- [ ] Git, rsync 설치 완료

### 1.3 WSL Flutter SDK 설치

```bash
# Flutter SDK 클론 (stable 브랜치, 약 1GB)
git clone https://github.com/flutter/flutter.git -b stable ~/.local/flutter --depth 1
```

**소요 시간**: 5~10분 (네트워크 속도에 따라)

- [ ] Flutter SDK 클론 완료

### 1.4 WSL PATH 설정

```bash
# .bashrc에 Flutter PATH 추가
echo 'export PATH="$HOME/.local/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**확인**:
```bash
which flutter
# /home/사용자명/.local/flutter/bin/flutter 출력 확인
```

- [ ] Flutter PATH 설정 완료

### 1.5 Flutter Doctor 실행

```bash
flutter doctor
```

**예상 출력**:
```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.35.6, on Ubuntu 24.04.2, locale ko_KR.UTF-8)
[✗] Android toolchain - develop for Android devices
    ✗ Unable to locate Android SDK.
[✗] Chrome - develop for the web
[✓] Linux toolchain - develop for Linux desktop
[!] Android Studio (not installed)
[!] VS Code (version X.X.X)
[✓] Connected device (1 available)
```

**중요**: Android/Chrome 관련 오류는 무시 (Windows Desktop만 사용)

- [ ] `flutter doctor` 실행 성공 (Flutter 항목 ✓ 확인)

### 1.6 Windows Desktop 활성화

```bash
flutter config --enable-windows-desktop
```

**확인**:
```bash
flutter config | grep windows
# windows: true 출력 확인
```

- [ ] Windows Desktop 활성화 완료

### 1.7 Git 설정 확인

```bash
git config --global user.name
git config --global user.email
```

**미설정 시**:
```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

- [ ] Git 사용자 정보 설정 완료

---

## 2. Windows 환경 설정 (30분)

> **주의**: 이 섹션은 Windows PowerShell (관리자 권한)에서 실행합니다.

### 2.1 Flutter SDK 설치 (Windows)

**방법 1: Git 클론 (권장)**

```powershell
# C:\flutter에 설치
cd C:\
git clone https://github.com/flutter/flutter.git -b stable C:\flutter --depth 1
```

**방법 2: ZIP 다운로드**
- https://docs.flutter.dev/get-started/install/windows 에서 SDK 다운로드
- `C:\flutter`에 압축 해제

**소요 시간**: 5~10분

- [ ] Windows Flutter SDK 설치 완료

### 2.2 Windows PATH 설정

**시스템 환경 변수 편집**:

1. Win + R → `sysdm.cpl` → 고급 → 환경 변수
2. 시스템 변수의 `Path` 선택 → 편집
3. 새로 만들기 → `C:\flutter\bin` 추가
4. 확인 → 확인

**확인** (새 PowerShell 창):
```powershell
flutter --version
```

- [ ] Windows Flutter PATH 설정 완료

### 2.3 Flutter Doctor (Windows)

```powershell
flutter doctor
```

**예상 출력**:
```
[✓] Flutter (Channel stable, 3.35.6, on Windows 11, locale ko_KR)
[!] Windows Version (Unable to confirm if installed Windows version is 10 or greater)
[✗] Visual Studio - develop Windows apps (Visual Studio not found)
[✓] Connected device (1 available)
```

**중요**: Visual Studio 항목이 ✗이면 다음 단계 진행

- [ ] Windows `flutter doctor` 실행 완료

### 2.4 Visual Studio 2022 설치

**다운로드**: https://visualstudio.microsoft.com/ko/downloads/

**버전**: Community Edition (무료)

**워크로드 선택** (중요!):
- ✅ **Desktop development with C++** (필수)
  - Windows 10 SDK
  - C++ CMake tools for Windows
  - MSVC v143 (또는 최신 버전)

**설치 크기**: 약 7GB

**소요 시간**: 20~40분

- [ ] Visual Studio 2022 설치 완료

### 2.5 Visual Studio 확인

**재실행**:
```powershell
flutter doctor
```

**예상 출력**:
```
[✓] Flutter (Channel stable, 3.35.6)
[✓] Windows Version
[✓] Visual Studio - develop Windows apps (Visual Studio Community 2022 17.x.x)
[✓] Connected device (1 available)
```

- [ ] Visual Studio 정상 인식 확인 (✓)

### 2.6 Windows Defender 예외 추가 (선택, 성능 향상)

```powershell
# 작업 폴더를 실시간 검사에서 제외
Add-MpPreference -ExclusionPath "C:\ws-workspace\sat-lec-rec"
Add-MpPreference -ExclusionPath "C:\flutter"
```

**확인**:
```powershell
Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
```

- [ ] Defender 예외 추가 완료 (선택)

---

## 3. FFmpeg 다운로드 및 배치 (15분)

### 3.1 FFmpeg 다운로드

**다운로드 링크**: https://github.com/BtbN/FFmpeg-Builds/releases

**권장 파일**: `ffmpeg-master-latest-win64-gpl.zip` (약 120MB)

**버전**: 최신 master 빌드

- [ ] FFmpeg ZIP 다운로드 완료

### 3.2 압축 해제 및 파일 확인

**압축 해제 후 구조**:
```
ffmpeg-master-latest-win64-gpl/
├── bin/
│   ├── ffmpeg.exe
│   ├── ffplay.exe
│   └── ffprobe.exe
├── doc/
└── LICENSE
```

**필요한 파일**: `ffmpeg.exe`, `ffprobe.exe`

- [ ] FFmpeg 압축 해제 완료

### 3.3 프로젝트 폴더에 배치 (WSL에서 실행)

```bash
# Windows 경로 생성
mkdir -p /mnt/c/ws-workspace/sat-lec-rec/third_party/ffmpeg

# 다운로드 폴더에서 복사 (경로는 실제 다운로드 위치에 맞춰 수정)
# 예시: Downloads 폴더에 압축 해제했다면
cp /mnt/c/Users/사용자명/Downloads/ffmpeg-master-latest-win64-gpl/bin/ffmpeg.exe \
   /mnt/c/ws-workspace/sat-lec-rec/third_party/ffmpeg/

cp /mnt/c/Users/사용자명/Downloads/ffmpeg-master-latest-win64-gpl/bin/ffprobe.exe \
   /mnt/c/ws-workspace/sat-lec-rec/third_party/ffmpeg/
```

**또는 Windows에서 직접 복사**:
1. `ffmpeg.exe`, `ffprobe.exe`를 복사
2. `C:\ws-workspace\sat-lec-rec\third_party\ffmpeg\`에 붙여넣기

- [ ] FFmpeg 바이너리 배치 완료

### 3.4 FFmpeg 실행 테스트

**Windows PowerShell**:
```powershell
cd C:\ws-workspace\sat-lec-rec\third_party\ffmpeg
.\ffmpeg.exe -version
```

**예상 출력**:
```
ffmpeg version N-... Copyright (c) 2000-2025 the FFmpeg developers
built with gcc ...
configuration: --enable-gpl ...
```

- [ ] FFmpeg 실행 테스트 성공

---

## 4. 프로젝트 초기화 및 동기화 테스트 (15분)

### 4.1 프로젝트 클론 (WSL)

```bash
cd ~/projects
git clone git@github.com:Eyebottle/sat-lec-rec.git
cd sat-lec-rec
```

**SSH 키 미설정 시** HTTPS 사용:
```bash
git clone https://github.com/Eyebottle/sat-lec-rec.git
```

- [ ] 프로젝트 클론 완료

### 4.2 Git Safe Directory 설정

```bash
git config --global --add safe.directory /home/사용자명/projects/sat-lec-rec
```

**확인**:
```bash
git status
# 에러 없이 상태 출력되면 성공
```

- [ ] Git safe.directory 설정 완료

### 4.3 Flutter 의존성 설치

```bash
cd ~/projects/sat-lec-rec
flutter pub get
```

**예상 출력**:
```
Running "flutter pub get" in sat-lec-rec...
Resolving dependencies... (X.Xs)
Got dependencies!
```

- [ ] `flutter pub get` 성공

### 4.4 WSL → Windows 동기화 테스트

```bash
# 동기화 스크립트 실행
~/projects/sat-lec-rec/scripts/sync_wsl_to_windows.sh
```

**확인 (Windows)**:
```powershell
# PowerShell에서 확인
Test-Path C:\ws-workspace\sat-lec-rec\pubspec.yaml
# True 출력되면 성공
```

- [ ] 동기화 스크립트 실행 성공

### 4.5 Windows에서 빌드 테스트

**Windows PowerShell**:
```powershell
cd C:\ws-workspace\sat-lec-rec
flutter run -d windows
```

**예상 결과**:
- 빌드 진행 (첫 빌드는 5~10분 소요)
- 앱 창이 열림
- 로그에 "sat-lec-rec 앱 시작" 출력

**종료**: 앱 창 닫기 또는 Ctrl+C

- [ ] Windows에서 `flutter run -d windows` 성공

---

## 5. FFI 기초 검증 (30분)

### 5.1 C++ 헤더 파일 생성

**파일**: `windows/runner/native_recorder_plugin.h`

```cpp
#ifndef NATIVE_RECORDER_PLUGIN_H_
#define NATIVE_RECORDER_PLUGIN_H_

#ifdef __cplusplus
extern "C" {
#endif

// FFI 테스트용 샘플 함수
__declspec(dllexport) const char* NativeHello();

#ifdef __cplusplus
}
#endif

#endif  // NATIVE_RECORDER_PLUGIN_H_
```

- [ ] C++ 헤더 파일 생성 완료

### 5.2 C++ 구현 파일 생성

**파일**: `windows/runner/native_recorder_plugin.cpp`

```cpp
#include "native_recorder_plugin.h"

extern "C" {

__declspec(dllexport) const char* NativeHello() {
    return "Hello from C++ Native Plugin!";
}

}  // extern "C"
```

- [ ] C++ 구현 파일 생성 완료

### 5.3 Dart FFI 바인딩 생성

**폴더 생성**:
```bash
mkdir -p lib/ffi
```

**파일**: `lib/ffi/native_bindings.dart`

```dart
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// C++ 함수 시그니처
typedef NativeHelloNative = Pointer<Utf8> Function();
typedef NativeHelloDart = Pointer<Utf8> Function();

class NativeRecorder {
  static late DynamicLibrary _dylib;
  static late NativeHelloDart _nativeHello;

  /// FFI 초기화
  static void initialize() {
    // Windows DLL 로드
    if (Platform.isWindows) {
      _dylib = DynamicLibrary.executable();
    } else {
      throw UnsupportedError('This platform is not supported');
    }

    // 함수 바인딩
    _nativeHello = _dylib
        .lookup<NativeFunction<NativeHelloNative>>('NativeHello')
        .asFunction();
  }

  /// C++에서 문자열 가져오기
  static String hello() {
    final ptr = _nativeHello();
    return ptr.toDartString();
  }
}
```

- [ ] Dart FFI 바인딩 생성 완료

### 5.4 main.dart 수정

**파일**: `lib/main.dart`

기존 main 함수 수정:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FFI 초기화
  try {
    NativeRecorder.initialize();
    final message = NativeRecorder.hello();
    logger.i('FFI 테스트: $message');
  } catch (e) {
    logger.e('FFI 초기화 실패: $e');
  }

  // Window 관리 초기화
  await windowManager.ensureInitialized();

  // ... (기존 코드)
}
```

**import 추가**:
```dart
import 'ffi/native_bindings.dart';
```

- [ ] main.dart 수정 완료

### 5.5 CMakeLists.txt 수정 (Windows)

**파일**: `windows/runner/CMakeLists.txt`

기존 `target_sources` 블록에 파일 추가:

```cmake
target_sources(${BINARY_NAME} PRIVATE
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "native_recorder_plugin.cpp"  # 이 줄 추가
)
```

- [ ] CMakeLists.txt 수정 완료

### 5.6 빌드 및 실행 (Windows)

```powershell
# WSL에서 동기화
cd ~/projects/sat-lec-rec
bash scripts/sync_wsl_to_windows.sh

# Windows에서 빌드
cd C:\ws-workspace\sat-lec-rec
flutter run -d windows
```

**예상 로그**:
```
[INFO] FFI 테스트: Hello from C++ Native Plugin!
[INFO] sat-lec-rec 앱 시작
```

- [ ] FFI 테스트 성공 (로그 확인)

---

## 6. 환경 검증 완료 체크포인트

모든 항목이 ✓이면 M0 단계 완료입니다.

### WSL 환경
- [ ] Flutter SDK 설치 및 PATH 설정
- [ ] `flutter doctor` Flutter 항목 ✓
- [ ] Windows Desktop 활성화
- [ ] Git 설정 완료

### Windows 환경
- [ ] Flutter SDK 설치 및 PATH 설정
- [ ] Visual Studio 2022 설치 (C++ 워크로드)
- [ ] `flutter doctor` 모든 항목 ✓
- [ ] FFmpeg 바이너리 배치

### 프로젝트
- [ ] 프로젝트 클론 완료
- [ ] `flutter pub get` 성공
- [ ] WSL → Windows 동기화 작동
- [ ] `flutter run -d windows` 성공

### FFI 검증
- [ ] C++ 코드 작성 및 빌드 성공
- [ ] Dart ↔ C++ 함수 호출 성공
- [ ] 로그에 "Hello from C++" 출력

---

## 트러블슈팅

### 문제: `flutter: command not found`

**원인**: PATH 설정 미반영

**해결**:
```bash
source ~/.bashrc
# 또는 터미널 재시작
```

### 문제: Visual Studio 인식 안됨

**원인**: C++ 워크로드 미설치

**해결**:
1. Visual Studio Installer 실행
2. 수정 → Desktop development with C++ 체크
3. 설치

### 문제: FFmpeg 실행 안됨

**원인**: 파일 경로 오류 또는 권한 문제

**해결**:
```powershell
# 파일 존재 확인
Test-Path C:\ws-workspace\sat-lec-rec\third_party\ffmpeg\ffmpeg.exe

# 실행 권한 확인 (속성 → 차단 해제)
```

### 문제: FFI 함수 찾을 수 없음

**원인**: CMakeLists.txt에 .cpp 파일 미추가

**해결**: CMakeLists.txt의 `target_sources`에 `native_recorder_plugin.cpp` 추가 확인

### 문제: Git safe.directory 경고

**원인**: WSL/Windows 파일 시스템 경계

**해결**:
```bash
git config --global --add safe.directory /home/사용자명/projects/sat-lec-rec
```

---

## 다음 단계

M0 완료 후:
- [development-roadmap.md](./development-roadmap.md) 참조
- **Phase 1: 기초 인프라** (FFmpeg Named Pipe 통합)
- **Phase 2: 녹화 코어** (화면/오디오 캡처)

---

**작성일**: 2025-10-21
**버전**: v1.0
**관련 문서**: [sat-lec-rec-prd.md](./sat-lec-rec-prd.md), [development-roadmap.md](./development-roadmap.md)
