# sat-lec-rec 문서 인덱스

프로젝트 개발 진행 상황 및 기술 문서 모음

**최종 업데이트**: 2025-10-24

---

## 📚 문서 구조

### 프로젝트 개요
- **[PRD (제품 요구사항 정의서)](sat-lec-rec-prd.md)** - 프로젝트 목표, 요구사항, 체크리스트
- **[개발 로드맵](development-roadmap.md)** - 전체 개발 단계 및 일정
- **[개발 진행 메모](developing.md)** - 실시간 개발 로그 및 학습 내용

### 개발 환경 설정
- **[M0: 환경 설정](m0-environment-setup.md)** - WSL/Windows 개발 환경 구축
- **[동기화 워크플로우](setting-sync-workflow.md)** - WSL ↔ Windows 코드 동기화
- **[M0 완료 상태](m0-completion-status.md)** - 환경 설정 체크리스트

---

## 🎯 마일스톤별 문서

### M1: FFI 인프라 (완료 ✅)
- **[Phase 1.2: FFmpeg 통합](m1-phase-1.2-ffmpeg-integration.md)** - C++ FFI 기초 구조

**진행률**: 100% 완료
**주요 성과**: FFI 심볼 export, C++ ↔ Dart 통신 구축

---

### M2: Core Recording (완료 ✅)

#### Phase 2.1: DXGI 화면 캡처
- **[가이드 문서](m2-phase-2.1-graphics-capture.md)** - DXGI Desktop Duplication 구현 가이드
- **[진행 상황](m2-phase-2.1-progress.md)** - 완료 보고서

**주요 성과**:
- 1920×1080 @ 40fps 화면 캡처
- GPU → CPU 프레임 전송 파이프라인
- 스레드 안전 프레임 큐

---

#### Phase 2.2: WASAPI 오디오 캡처
- **[가이드 문서](m2-phase-2.2-wasapi-audio.md)** - WASAPI Loopback 구현 가이드
- **[진행 상황](m2-phase-2.2-progress.md)** - 완료 보고서

**주요 성과**:
- 48kHz Stereo Loopback 캡처
- Float32 PCM 오디오 데이터
- 별도 오디오 캡처 스레드

---

#### Phase 2.3: Media Foundation 인코더
- **[가이드 문서](m2-phase-2.3-media-foundation.md)** - H.264/AAC 인코딩 구현 가이드
- **[진행 상황](m2-phase-2.3-progress.md)** - 완료 보고서

**주요 성과**:
- H.264 High Profile (5 Mbps, 24fps)
- AAC 오디오 (192 kbps, 48kHz stereo)
- Float32 → Int16 변환
- 비디오 상하 반전 처리
- MP4 파일 생성 및 재생 검증

**진행률**: 100% 완료 🎉

---

### M3: 프로덕션 준비 (진행 중 🚀)

- **[Phase 3 로드맵](m3-phase-3-roadmap.md)** - UI 개선, 스케줄링, 안정성 향상

**계획된 작업**:
- Phase 3.1: UI 개선 (녹화 진행률, 오디오 레벨 표시)
- Phase 3.2: 스케줄링 (Cron 예약, T-10 헬스체크)
- Phase 3.3: 안정성 (네트워크 단절, 디스크 체크, Fragmented MP4)
- Phase 3.4: 최적화 (하드웨어 가속, 적응형 비트레이트)

**진행률**: 0% (계획 단계)

---

## 📊 전체 진행 상황

### 완료된 마일스톤
- ✅ **M0**: 환경 설정 (2025-10-17 ~ 10-18)
- ✅ **M1**: FFI 인프라 (2025-10-21 ~ 10-23)
- ✅ **M2**: Core Recording (2025-10-23)
  - ✅ Phase 2.1: DXGI 화면 캡처
  - ✅ Phase 2.2: WASAPI 오디오 캡처
  - ✅ Phase 2.3: Media Foundation 인코더

### 진행 중
- 🚀 **M3**: 프로덕션 준비 (2025-10-24 ~ )

### 예정
- ⏳ **M4**: 테스트 및 배포 (TBD)

---

## 🔍 빠른 참조

### 핵심 기술 스택
- **언어**: Dart 3.9.2, C++ 17
- **프레임워크**: Flutter 3.35.6 (Windows Desktop)
- **화면 캡처**: DXGI Desktop Duplication API
- **오디오 캡처**: WASAPI (Loopback 모드)
- **인코딩**: Media Foundation (H.264/AAC)
- **FFI**: Dart `ffi` 패키지

### 주요 파일 위치
- **C++ 네이티브**: `windows/runner/native_screen_recorder.cpp`
- **FFI 바인딩**: `lib/ffi/native_bindings.dart`
- **녹화 서비스**: `lib/services/recorder_service.dart`
- **메인 UI**: `lib/ui/screens/main_screen.dart`

### 개발 워크플로우
1. WSL에서 코드 작성
2. `git commit` (자동으로 Windows 동기화)
3. Windows에서 `flutter build windows`
4. 테스트 및 검증

---

## 📝 문서 작성 가이드

### 새 Phase 시작 시
1. `doc/mX-phase-Y.Z-{name}.md` - 구현 가이드 작성
2. 개발 진행 중 `developing.md`에 로그 기록
3. 완료 후 `doc/mX-phase-Y.Z-progress.md` - 완료 보고서 작성

### 문서 네이밍 규칙
- **가이드**: `mX-phase-Y.Z-{name}.md` (예: `m2-phase-2.3-media-foundation.md`)
- **진행 상황**: `mX-phase-Y.Z-progress.md` (예: `m2-phase-2.3-progress.md`)
- **로드맵**: `mX-phase-Y-roadmap.md` (예: `m3-phase-3-roadmap.md`)

---

## 🚀 다음 작업

### 즉시 시작 가능
1. **Phase 3.1.1**: 녹화 진행률 표시 구현
   - C++ FFI: `GetFrameCount()`, `GetElapsedTimeMs()` 추가
   - Dart UI: `RecordingProgressWidget` 작성

2. **Phase 3.1.2**: 실시간 오디오 레벨 미터
   - C++ FFI: `GetAudioLevel()` 추가
   - Dart UI: `AudioLevelMeter` 위젯 작성

### 우선순위
1. **높음**: Phase 3.1 (UI 개선) - 사용성 향상
2. **높음**: Phase 3.3 (안정성) - 프로덕션 필수
3. **중간**: Phase 3.2 (스케줄링) - 자동화
4. **낮음**: Phase 3.4 (최적화) - 성능 향상

---

**작성자**: Claude Code
**관리**: 프로젝트 진행에 따라 지속적으로 업데이트
**문의**: 각 문서의 "참고 자료" 섹션 참조
