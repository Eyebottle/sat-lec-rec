# 다음 세션 프롬프트

아래 내용을 복사하여 새 세션에 붙여넣으세요:

---

SatLecRec 프로젝트 (Flutter Windows Desktop - Zoom 강의 자동 녹화 앱) 작업 계속

## 현재 상태
- Git: master 브랜치, origin과 동기화됨
- 최근 커밋: `913a4a6` - 녹화 중단 버그 수정 및 대시보드 컴팩트화

## 긴급 해결 필요: A/V 싱크 버그

### 증상
- 영상이 소리보다 앞서감 (비디오가 빠름)
- 15분 녹화 테스트에서 확인됨

### 근본 원인
1. **PTS 계산이 실제 시간과 무관**: 비디오는 프레임 카운터, 오디오는 샘플 카운터로 독립 증가
2. **DXGI 타임아웃 시 프레임 반복**: 정적 화면에서 과도한 프레임 추가 → 비디오 가속

### 해결 방향
캡처 시점의 QPC 타임스탬프를 인코더까지 전달하여 실제 시간 기반 PTS 계산

### 상세 분석 문서
`AV-SYNC-BUG-HANDOVER.md` 파일 참조 (구현 단계 포함)

## 수정 대상 파일
1. `windows/runner/libav_encoder.h` - EncodeVideo/EncodeAudio 시그니처 변경
2. `windows/runner/libav_encoder.cpp` - 타임스탬프 기반 PTS 계산 구현
3. `windows/runner/native_screen_recorder.cpp` - 타임스탬프 전달

## 오늘 완료한 작업 (2025-12-08~09)
1. 대시보드 컴팩트화 (시스템 테스트 섹션 제거, 카드 레이아웃 개선)
2. 무음 구간 오디오 전송 수정 (AUDCLNT_BUFFERFLAGS_SILENT 처리)
3. DXGI 타임아웃 시 마지막 프레임 재사용 (이 수정이 싱크 문제 악화시킴)

## 요청 사항
`AV-SYNC-BUG-HANDOVER.md`의 "방안 1: 실제 타임스탬프 기반 PTS 계산" 구현해 주세요.

---
