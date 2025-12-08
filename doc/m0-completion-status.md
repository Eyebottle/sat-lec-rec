# M0: 환경 설정 완료 현황

**마지막 업데이트**: 2025-10-21
**상태**: ✅ **완료**

## 체크리스트

### WSL 환경
- ✅ **[M0-WSL-1]** Ubuntu 24.04 설치 및 업데이트
- ✅ **[M0-WSL-2]** Git, rsync 설치
- ✅ **[M0-WSL-3]** Flutter SDK 설치 (`~/.local/flutter`)
- ✅ **[M0-WSL-4]** Flutter PATH 설정 및 `flutter doctor` 정상
- ✅ **[M0-WSL-5]** Windows Desktop 활성화
- ✅ **[M0-WSL-6]** Git 사용자 정보 설정

### Windows 환경
- ✅ **[M0-WIN-1]** Flutter SDK 설치 (`C:\flutter`)
- ✅ **[M0-WIN-2]** Flutter PATH 설정 및 Visual Studio 설치 완료
- ✅ **[M0-WIN-3]** Visual Studio 2022 설치 (Desktop development with C++)
- ⚠️ **[M0-WIN-4]** Windows Defender 예외 추가 (선택 사항)

### FFmpeg 설정
- ⏳ **[M0-FFM-1]** FFmpeg 64bit 다운로드 (다음 단계)
- ⏳ **[M0-FFM-2]** 바이너리 배치 (`third_party/ffmpeg/`)
- ⏳ **[M0-FFM-3]** 실행 테스트

### 프로젝트 초기화
- ✅ **[M0-PRJ-1]** 프로젝트 클론
- ✅ **[M0-PRJ-2]** Git safe.directory 설정
- ✅ **[M0-PRJ-3]** `flutter pub get` 성공
- ✅ **[M0-PRJ-4]** WSL → Windows 동기화 테스트 (post-commit 훅 동작 확인)
- ✅ **[M0-PRJ-5]** Windows에서 `flutter run -d windows` 성공

### FFI 기초 검증
- ✅ **[M0-FFI-1]** C++ 헤더/구현 파일 생성
- ✅ **[M0-FFI-2]** Dart FFI 바인딩 생성
- ✅ **[M0-FFI-3]** `main.dart`에서 `NativeHello()` 호출
- ✅ **[M0-FFI-4]** CMakeLists.txt 수정 (C++ 파일 추가 + UTF-8 옵션)
- ✅ **[M0-FFI-5]** 빌드 후 로그에 "Hello from C++ Native Plugin!" 출력 확인

## 해결한 문제들

### 1. Git Safe Directory 경고
**문제**: Cursor에서 "The detected Git repository is potentially unsafe" 경고
**해결**: `git config --global --add safe.directory /home/usereyebottle/projects/sat-lec-rec`

### 2. WSL Flutter PATH 우선순위
**문제**: `which flutter`가 `/mnt/c/flutter`를 가리킴
**해결**: `~/.bashrc`에 `export PATH="$HOME/.local/flutter/bin:$PATH"` 추가

### 3. Dart FFI Utf8 타입 에러
**문제**: `Type 'Utf8' not found` 빌드 에러
**해결**: `lib/ffi/native_bindings.dart`에 `import 'package:ffi/ffi.dart';` 추가

### 4. MSVC UTF-8 인코딩 에러
**문제**: C4819 경고 - 한글 주석이 CP949로 해석됨
**해결**: `windows/runner/CMakeLists.txt`에 `/utf-8` 컴파일 옵션 추가

## M0 완료 기준 달성

✅ **모든 필수 항목 완료** (FFmpeg은 M1 Phase 1.2에서 진행)
✅ **Windows에서 빌드 및 실행 성공**
✅ **FFI 통신 정상 동작 확인**
✅ **WSL ↔ Windows 동기화 워크플로우 확립**

## 다음 단계: M1 (녹화 코어 구현)

### Phase 1.1: FFI 기초 ✅ 완료
- Dart ↔ C++ Hello World 성공

### Phase 1.2: FFmpeg 런타임 통합 (다음)
- [ ] FFmpeg 바이너리 다운로드 및 배치
- [ ] C++에서 FFmpeg 프로세스 실행 테스트
- [ ] Named Pipe 통신 구조 설계

### Phase 1.3: 화면 캡처 (Windows Graphics Capture API)
- [ ] 창 핸들 획득 및 타깃 캡처
- [ ] 프레임 버퍼를 Pipe로 FFmpeg 전달

### Phase 1.4: 오디오 캡처 (WASAPI Loopback)
- [ ] 시스템 오디오 스트림 캡처
- [ ] 오디오 데이터를 Pipe로 FFmpeg 전달

### Phase 1.5: 기본 녹화 파이프라인 통합
- [ ] 화면 + 오디오 동시 캡처
- [ ] FFmpeg H.264/AAC 인코딩
- [ ] MP4 파일 저장 테스트

## 참고 문서
- [PRD](./sat-lec-rec-prd.md)
- [개발 로드맵](./development-roadmap.md)
- [M0 환경 설정 가이드](./m0-environment-setup.md)
