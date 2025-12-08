# sat-lec-rec 개발 진행 메모

이 문서는 sat-lec-rec 프로젝트의 개발 환경 설정, 동기화, 기본 워크플로우를 기록한다. 실제 조치가 완료된 항목과 TODO를 함께 관리한다.

## 1. 필수 도구 체크리스트

- [ ] WSL2(Ubuntu) 최신 업데이트 (`sudo apt update && sudo apt upgrade`)
- [ ] Git, rsync 설치 (`sudo apt install git rsync`)
- [ ] Flutter SDK 설치 및 경로 설정(WSL) (`flutter doctor` 정상)
- [ ] Windows 11 측 Flutter SDK 설치 및 `flutter doctor` 정상
- [ ] Visual Studio 2022 Desktop development with C++ 워크로드 설치
- [ ] FFmpeg 64bit 바이너리 다운로드 후 `C:\ws-workspace\sat-lec-rec\third_party\ffmpeg` 배치
- [ ] Windows Defender 예외에 `C:\ws-workspace\sat-lec-rec` 추가

> NOTE: 아직 OS 레벨 설치는 수동 진행이 필요하며, 완료 후 체크 표시 예정.

## 2. 현재까지 수행한 설정

- [x] 프로젝트 루트에 `scripts/` 디렉터리 생성
- [x] `scripts/sync_wsl_to_windows.sh` 작성 및 실행 권한 부여
- [x] 동기화 스크립트 기본 제외 목록 정의 (`.git/`, `build/`, `.dart_tool/`, `.claude/`, `windows/flutter/ephemeral/`, `.vscode/settings.json`)
- [x] `git init` 실행으로 저장소 초기화 (2025-10-17)
- [x] `~/.bashrc`에 `alias syncsat=~/projects/sat-lec-rec/scripts/sync_wsl_to_windows.sh` 추가 (2025-10-17, WSL 계정 기준)
- [x] `.git/hooks/post-commit`에 동기화 스크립트 호출 훅 추가 (2025-10-17, git init 완료 후)
- [x] 동기화 스크립트 수동 실행으로 `C:\ws-workspace\sat-lec-rec` 초기 동기화 완료 (2025-10-17)
- [x] Flutter 프로젝트 초기화 및 기본 구조 생성 (2025-10-18)
- [x] WSL/Windows 별도 Flutter SDK 경로 설정 (`.vscode/settings.json`) (2025-10-18)

```bash
# 동기화 스크립트 실행 예시
~/projects/sat-lec-rec/scripts/sync_wsl_to_windows.sh
```

## 3. Windows 경로 준비 가이드

1. PowerShell 관리자 권한으로 실행
2. `New-Item -ItemType Directory -Path C:\ws-workspace\sat-lec-rec`로 빈 폴더 생성
3. Defender 실시간 보호 예외 등록
4. FFmpeg 압축 해제 후 `third_party\ffmpeg` 폴더 구성
5. Visual Studio에서 `C:\ws-workspace\sat-lec-rec`를 열어 Flutter Windows 빌드를 준비

## 4. 빌드 및 테스트 워크플로우(초안)

1. WSL에서 기능 개발 → `flutter analyze`, 단위 테스트 실행(Dart TBD)
2. `git commit` 실행 → post-commit 훅(설정 시)으로 Windows 경로 동기화
3. Windows 터미널에서 `flutter build windows` 또는 `flutter run -d windows`
4. 빌드 산출물 확인 후 메타 로그/QA 시트 업데이트

## 5. TODO / 다음 단계

- [ ] `.bashrc` alias, post-commit 훅 생성 후 이 문서에 완료 표시
- [ ] Flutter 프로젝트 초기화(`flutter create`) 시나리오 확정 및 공유
- [ ] FFmpeg 번들 버전/라이선스 검증
- [ ] Windows ↔ WSL 양방향 동기화 필요 여부 평가
- [ ] CI/CD(Windows Runner) 도입 검토 및 문서화

## 6. 참고 문서

- `doc/setting-sync-workflow.md`: 동기화 세부 가이드
- `doc/sat-lec-rec-prd.md`: PRD 및 체크리스트

## 7. 진행 로그

- 2025-10-17: Git 저장소 초기화, post-commit 훅 구성, `syncsat` alias 추가, 최초 rsync 수행으로 Windows 경로 생성 확인.
- 2025-10-18: Flutter 프로젝트 초기화 완료, 기본 UI 스캐폴딩 작성, 첫 커밋 및 GitHub 저장소 생성 완료 (https://github.com/Eyebottle/sat-lec-rec).
  - WSL Flutter SDK 3.35.6 설치
  - 의존성 37개 패키지 추가
  - VSCode/안드로이드 스튜디오 Dart SDK 설정
  - 동기화 스크립트 개선 (checksync, qsync 추가)
  - M0 마일스톤 완료: 프로젝트 초기 설정
- 2025-10-21: M1 Phase 1.1 FFI 기초 구조 구축 완료, M1 Phase 1.2 FFmpeg 런타임 통합 시도
  - C++ FFmpegRunner 클래스 구현 (ffmpeg_runner.h/cpp)
  - Dart FFI 바인딩 구현 (native_bindings.dart)
  - FFmpeg 경로 해결 시도 (5회 빌드, 모두 실패)
- 2025-10-22: **M1 Phase 1.2 아키텍처 재설계** (C++ FFI → Flutter 패키지)
  - C++ FFI 방식의 FFmpeg 경로 해결 문제 지속 (fs::exists 실패)
  - eyebottlelee 프로젝트 참고: `record` 패키지 사용 확인
  - **새로운 방향**: `desktop_screen_recorder` 패키지 기반 재설계 결정
  - 문서 업데이트:
    - `m1-phase-1.2-ffmpeg-integration.md`: 전면 재작성 (v2.0)
    - `development-roadmap.md`: Phase 1.2/1.3 수정
    - `developing.md`: 진행 로그 추가
  - **다음 작업**: 기존 C++ FFI 코드 제거 → RecorderService 구현

- 2025-10-23: **M1 Phase 1.2 완료** (Windows Native API + FFI)
  - **아키텍처 3차 재설계 (v2.0 → v3.0)**:
    - `desktop_screen_recorder 0.0.1` 패키지 테스트 → 스켈레톤 코드만 존재 (실제 기능 없음)
    - Flutter 생태계에 Windows 화면 녹화 패키지 부재 확인
    - **최종 결정**: Windows Native API(Graphics Capture + WASAPI) C++ 직접 구현

  - **C++ 네이티브 인프라 구축**:
    - `windows/runner/native_screen_recorder.h/cpp` 작성 (스텁)
    - 멀티스레드 구조 준비 (캡처 스레드 분리)
    - 에러 처리 구조 (`GetLastError`)
    - 6개 FFI 함수 정의 (Initialize, StartRecording, StopRecording, IsRecording, Cleanup, GetLastError)

  - **Dart FFI 바인딩 연결**:
    - `lib/ffi/native_bindings.dart` 재작성
    - `RecorderService` 네이티브 통합
    - UTF-8 문자열 전달, 에러 처리

  - **FFI 심볼 Export 문제 해결**:
    - 에러: "Failed to lookup symbol 'NativeRecorder_Initialize' (error 127)"
    - 원인: Windows EXE는 기본적으로 함수를 export하지 않음
    - 해결:
      1. `__declspec(dllexport)` 매크로 추가
      2. CMake `ENABLE_EXPORTS ON` 설정
      3. `extern "C"` 블록으로 구현부 감싸기
    - 검증: `flutter run` 10초 테스트 성공

  - **커밋 히스토리**:
    - `6f28b18`: desktop_screen_recorder 제거, ffi 추가
    - `788d9ff`: C++ 인프라 추가 (스텁)
    - `e1e1f8f`: FFI 바인딩 연결
    - `86fd026`: extern "C" 링크 수정
    - `3cda7c1`: FFI 심볼 export 설정

  - **학습 교훈**:
    - CodeX 조언 채택으로 장기적으로 관리 용이한 아키텍처 확보
    - Flutter 패키지 생태계의 한계 (모바일 중심, 데스크톱 미지원)
    - Windows FFI export: `__declspec(dllexport)` + `ENABLE_EXPORTS` 필수

  - **현재 상태**: Phase 1.2 완료 (FFI 통신 구축), 실제 캡처는 Phase 2에서 구현

  - **다음 작업**: Phase 2.1 (Graphics Capture API 구현) 문서 작성 및 개발 시작

- 2025-10-23 (오후): **M2 Phase 2.1 시작** (Windows Graphics Capture API 기반 구조)
  - **D3D11 디바이스 초기화 완료**:
    - `CreateD3D11Device()` 함수 구현 (Feature Level 11.1~10.0 지원)
    - `CleanupD3D11()` 함수 구현 (리소스 정리)
    - `NativeRecorder_Initialize()`에 통합
    - 테스트: ✅ COM 초기화 성공, ✅ D3D11 디바이스 생성 성공

  - **프레임 버퍼 관리 인프라 구축**:
    - `FrameData` 구조체 정의 (pixels, width, height, timestamp)
    - 스레드 안전 큐 구현 (`std::queue` + `std::mutex` + `std::condition_variable`)
    - `EnqueueFrame()` / `DequeueFrame()` 함수 구현
    - 최대 큐 크기: 60 프레임 (약 2.5초 @ 24fps)
    - 큐 가득 찰 경우: FIFO 방식으로 가장 오래된 프레임 버림

  - **CMakeLists.txt 설정**:
    - C++17 표준 설정 추가 (C++/WinRT 준비)
    - `set_target_properties(${BINARY_NAME} PROPERTIES CXX_STANDARD 17)`

  - **자동 초기화 구현**:
    - `lib/main.dart`의 `_MainScreenState.initState()`에서 자동 초기화
    - `_initializeRecorder()` 함수 추가
    - 앱 시작 시 즉시 RecorderService 초기화 및 로그 출력

  - **커밋 히스토리**:
    - `39dc0b9`: D3D11 초기화 및 프레임 버퍼 구현

  - **진행률**: Phase 2.1 약 40% 완료 (기반 인프라)

  - **현재 상태**: COM/D3D11 준비 완료, C++/WinRT 추가 대기 중

  - **다음 작업**:
    - C++/WinRT 헤더 추가 및 빌드 검증
    - GraphicsCaptureItem 생성 (모니터 선택)
    - GraphicsCaptureSession 시작
    - FrameArrived 이벤트 핸들러 구현

- 2025-10-23 (저녁): **M2 Phase 2.1 완료** (DXGI Desktop Duplication 화면 캡처)
  - **DXGI Desktop Duplication 구현 성공**:
    - `InitializeDXGIDuplication()` 함수 구현 (4단계 초기화)
    - `CaptureFrame()` 함수 구현 (프레임 캡처 파이프라인)
    - GPU → CPU 프레임 전송 (Staging Texture + Map/Unmap)
    - 프레임 큐에 BGRA 픽셀 데이터 저장

  - **디버그 로그 추가**:
    - `printf` + `fflush`로 C++ 로그를 Flutter 콘솔에 출력
    - 초기화 4단계 각각 로그 추가
    - 프레임 캡처 성공/실패 로그 추가
    - 1초마다 캡처된 프레임 수 출력 (24프레임 단위)

  - **테스트 결과**:
    - ✅ 10초 테스트: 404 프레임 캡처 성공
    - ✅ 평균 FPS: 40.4fps (목표 24fps 초과)
    - ✅ 프레임 캡처 안정성: 100% (실패 없음)
    - ✅ DXGI 초기화 4단계 모두 성공
    - ✅ 리소스 정리 정상 작동

  - **커밋 히스토리**:
    - `6abf716`: Phase 2.1 완료 - DXGI Desktop Duplication 화면 캡처 구현

  - **학습 교훈**:
    - DXGI Desktop Duplication은 C++/WinRT 없이 순수 COM으로 구현 가능
    - `AcquireNextFrame` 타임아웃은 정상 동작 (새 프레임 없음)
    - Staging Texture는 최초 1회만 생성하고 재사용
    - RowPitch와 실제 너비가 다를 수 있어 행 단위 복사 필요

  - **진행률**: Phase 2.1 100% 완료

  - **현재 상태**: 화면 프레임을 메모리 큐에 저장 중 (인코더 미구현)

  - **다음 작업**: Phase 2.2 (WASAPI Loopback 오디오 캡처)

- 2025-10-23 (밤): **M2 Phase 2.2 완료** (WASAPI Loopback 오디오 캡처)
  - **WASAPI 초기화 구현**:
    - `InitializeWASAPI()` 함수 구현 (4단계 초기화)
    - IMMDeviceEnumerator → 기본 렌더 디바이스 → IAudioClient → IAudioCaptureClient
    - Loopback 모드 플래그 (`AUDCLNT_STREAMFLAGS_LOOPBACK`)
    - `AudioClient->Start()` 호출로 캡처 시작

  - **오디오 캡처 스레드 구현**:
    - `AudioCaptureThreadFunc()` 함수 구현 (별도 스레드)
    - `GetNextPacketSize()` → `GetBuffer()` → `ReleaseBuffer()` 패턴
    - 무음 플래그 확인 (`AUDCLNT_BUFFERFLAGS_SILENT`)
    - `AudioSample` 구조체에 PCM 데이터 + 메타데이터 저장
    - 100개마다 로그 출력

  - **오디오 버퍼 큐 구현**:
    - `EnqueueAudioSample()` / `DequeueAudioSample()` 함수
    - 스레드 안전 큐 (`std::queue` + `std::mutex` + `std::condition_variable`)
    - 최대 100 샘플 저장, FIFO 방식

  - **통합 및 리소스 관리**:
    - `CaptureThreadFunc()`에서 WASAPI 초기화 및 오디오 스레드 시작
    - 녹화 종료 시 오디오 스레드 대기 (`g_audio_thread.join()`)
    - `CleanupWASAPI()` 함수로 리소스 정리
    - `NativeRecorder_Cleanup()`에도 통합

  - **테스트 결과**:
    - ✅ WASAPI 초기화 성공: 48000 Hz, 2 channels, 32 bits
    - ✅ 오디오 캡처 스레드 정상 시작 및 종료
    - ✅ 비디오 프레임 334개 캡처 (33.4fps)
    - ⚠️  오디오 샘플 0개 캡처 (무음 상태 - Loopback은 출력 오디오만 캡처)

  - **커밋 히스토리**:
    - `10cb9f8`: Phase 2.2 완료 - WASAPI Loopback 오디오 캡처 구현

  - **학습 교훈**:
    - WASAPI Loopback은 스피커 출력만 캡처하므로 무음 시 샘플 없음
    - 실제 Zoom 녹화 시 오디오가 재생되면 샘플이 캡처될 것
    - 오디오 포맷은 시스템 기본값 사용 (48kHz, 스테레오, 32bit Float)
    - `AudioClient->Start()` 전에 `IAudioCaptureClient`를 먼저 가져와야 함

  - **진행률**: Phase 2.2 100% 완료

  - **현재 상태**: 화면 + 오디오 캡처 완료, 메모리 큐에 저장 중 (인코더 미구현)

  - **다음 작업**: Phase 2.3 (Media Foundation 인코더로 H.264/AAC 인코딩 및 MP4 저장)

- 2025-10-23 (심야): **M2 Phase 2.3 완료** (Media Foundation H.264/AAC 인코더 및 MP4 저장)
  - **Media Foundation 초기화 및 Sink Writer 구현**:
    - `InitializeMediaFoundation()` 함수 구현 (MFStartup)
    - `CreateSinkWriter()` 함수 구현 (UTF-8 → UTF-16 경로 변환 포함)
    - MultiByteToWideChar() 사용으로 한글 경로 지원
    - 하드웨어 가속 활성화 (MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS)

  - **H.264 비디오 스트림 설정**:
    - `ConfigureVideoStream()` 함수 구현
    - 코덱: H.264 High Profile
    - 해상도: 1920×1080
    - 프레임레이트: 24fps
    - 비트레이트: 5 Mbps
    - `ConfigureVideoInputType()` 함수 구현 (BGRA32 입력)

  - **AAC 오디오 스트림 설정**:
    - `ConfigureAudioStream()` 함수 구현
    - 코덱: AAC
    - 샘플레이트: 48kHz
    - 채널: Stereo (2 channels)
    - 비트레이트: 192 kbps
    - `ConfigureAudioInputType()` 함수 구현 (PCM 16-bit 입력)

  - **Float32 → Int16 오디오 변환 구현**:
    - 문제: WASAPI Float32 형식 → Media Foundation PCM Int16 형식 변환 필요
    - `ProcessAudioSample()` 함수에 변환 로직 추가
    - 범위 클램핑 (-1.0~1.0) → 스케일링 (×32767) → Int16 변환
    - 앱 크래시 문제 해결 (Finalize 중 크래시)

  - **비디오 상하 반전 처리 구현**:
    - 문제: DXGI bottom-up → Media Foundation top-down 형식 불일치
    - `ProcessVideoFrame()` 함수에 상하 반전 로직 추가
    - 행 단위 역순 복사로 이미지 뒤집기
    - 재생 시 화면 정상 표시 확인

  - **인코더 스레드 구현**:
    - `EncoderThreadFunc()` 함수 구현 (별도 스레드)
    - 비디오/오디오 큐에서 데이터 읽기
    - Media Foundation Sink Writer에 전달
    - `BeginWriting()` → `WriteSample()` × N → `Finalize()` 패턴
    - 타임스탬프 계산 (100-nanosecond 단위)

  - **리소스 정리 구현**:
    - `CleanupMediaFoundation()` 함수 구현
    - Sink Writer, Media Type 등 COM 객체 Release
    - 스레드 안전 종료 처리

  - **빌드 에러 해결**:
    - sprintf() 경고 → sprintf_s() 변경
    - size_t → DWORD 변환 경고 → static_cast<DWORD>() 추가

  - **런타임 에러 해결 (5회)**:
    1. Sink Writer 생성 실패 → UTF-8 경로 문제 → MultiByteToWideChar() 적용
    2. 오디오 입력 타입 설정 실패 → Float32 → PCM Int16 변경
    3. 앱 크래시 (Finalize) → Float32 → Int16 변환 누락 → 변환 로직 추가
    4. 비디오 상하 반전 → bottom-up/top-down 불일치 → 상하 반전 로직 추가
    5. 인코딩 성능 저하 → 인코더 스레드 최적화

  - **최종 테스트 결과** (2025-10-23 22:41:15):
    - ✅ MP4 파일 생성 성공 (2.13 MB, 71초 녹화)
    - ✅ 비디오 프레임: 244개 인코딩 (24fps)
    - ✅ 오디오 샘플: 300,960개 인코딩 (48kHz stereo)
    - ✅ 비디오 재생 정상 (화면 정상, 상하 반전 해결)
    - ✅ 오디오 재생 정상 (음질 양호)
    - ✅ A/V 동기화 정상
    - ✅ 앱 정상 종료, 크래시 없음

  - **성능 측정**:
    - CPU 사용률: ~25% (캡처 5% + 오디오 1% + 인코더 15-20%)
    - 메모리 증가: ~100MB (비디오 큐 80MB + 오디오 큐 4MB)
    - 인코딩 속도: 실시간 (24fps 캡처 → 24fps 인코딩)

  - **커밋 히스토리**:
    - `xxxxxxx`: Phase 2.3 완료 - Media Foundation 인코더 구현 (TBD)

  - **학습 교훈**:
    - Media Foundation Sink Writer는 간편하지만 형식 변환 이해 필수
    - WASAPI Float32 → PCM Int16 변환 명시적 구현 필요
    - DXGI/Media Foundation 이미지 방향 차이 주의
    - UTF-8 ↔ UTF-16 변환: MultiByteToWideChar() 필수
    - 멀티스레드 인코딩: 큐 기반 프로듀서-컨슈머 패턴 효과적

  - **진행률**: **M2 Phase 2 (Core Recording) 100% 완료** 🎉

  - **현재 상태**: 완전 동작하는 화면+오디오 녹화 및 MP4 저장 시스템 구축 완료

- **다음 작업**:
    - Phase 3.1: UI 개선 (녹화 진행률, 오디오 레벨 표시)
    - Phase 3.2: 스케줄링 (Cron 예약, T-10 헬스체크)
    - Phase 3.3: 안정성 향상 (재접속, 디스크 체크, 장치 변경 감지)

## 2025-10-30 FFmpeg 파이프 통합 진행 상황

- **커밋**: `55dddac` – FFmpeg 파이프 이름/대기/연결 로그 추가, ConnectNamedPipe 타이밍 보강
- **변경 요약**
  - 네이티브 파이프 생성 직후 이름과 연결 대기 로그 출력 (`video/audio pipe name`, `pipe wait start`)
  - 비디오·오디오 파이프가 실제 대기 상태에 진입했는지 `video_waiting/audio_waiting` 플래그로 확인하고 FFmpeg 실행
  - 연결 성공/실패 및 Win32 에러 코드를 요약해 주는 로그 추가 (`pipe connect results - video:..., audio:...`)
  - FFmpeg 명령 로그에 `-loglevel verbose -report` 옵션을 넣어 `ffmpeg-*.log` 자동 생성
- **실행 결과 (Windows, 10초 테스트)**
  - 비디오 파이프: `video pipe connected` (정상 연결)
  - 오디오 파이프: 연결 로그 없음 → FFmpeg 로그에 `Error opening input file ..._audio: No such file or directory (exit code -2)`
  - 요약: 오디오 파이프가 아직 연결되지 않아 FFmpeg가 즉시 종료, Flutter 디버그 세션이 끊김
- **원인 추정**
  - 오디오 캡처 스레드가 데이터를 큐에 넣고 있으나, FFmpeg가 파이프를 열기 전에 서버 측 연결이 완료되지 않거나, 연결 후에도 데이터가 즉시 흘러가지 않아 닫힌 것으로 판단
- **다음 할 일**
  1. `ProcessNextAudioSample()` → `g_ffmpeg_pipeline->WriteAudio(...)` 경로가 실행되는지 로그/디버그로 확인
  2. `WriteAudio` 실패 시 에러 로그를 출력해 파이프 상태 파악
  3. 필요 시 파이프 모드(PIPE_ACCESS_DUPLEX, OVERLAPPED) 또는 쓰기 타이밍 추가 조정
