# Phase 3.3 구현 필요성 검증
**Media Foundation → FFmpeg 마이그레이션 타당성 분석**

## 검증 질문

### 1. 현재 Media Foundation 구현이 작동하는가?

**현재 상태:**
- ✅ Media Foundation 초기화 완료
- ✅ DXGI Desktop Duplication (화면 캡처) 구현
- ✅ WASAPI Loopback (오디오 캡처) 구현
- ✅ H.264/AAC 인코딩 구현
- ✅ IMFSinkWriter로 MP4 저장
- ✅ 10초 테스트 녹화 성공

**검증 결과: 현재 구현은 작동하고 있음**

### 2. Fragmented MP4가 정말 필요한가?

**PRD 요구사항 재검토:**

> **FR-10-1**: Fragmented MP4 사용(`-movflags +frag_keyframe+empty_moov`)으로 **크래시 시에도 재생 가능하도록 저장**

> **핵심 가치**: 주말 작업 최소화, 95% 이상 예약 성공률, **Fragmented MP4 기반 파일 복구 안정성**

> **성공 기준**: **크래시가 있어도 기록된 부분은 Fragmented MP4로 복구 가능**

**PRD에서 Fragmented MP4는 필수 요구사항임**

### 3. 왜 Fragmented MP4가 중요한가?

**일반 MP4 구조의 문제점:**

```
일반 MP4 파일 구조:
[ftyp] [moov - 메타데이터] [mdat - 실제 데이터]
       ↑
       정상 종료 시에만 작성됨
```

**크래시 시나리오:**
1. 120분 녹화 중
2. 90분 시점에 정전/크래시 발생
3. IMFSinkWriter->Finalize() 호출 안 됨
4. **moov atom 미작성 → 파일 재생 불가**
5. **90분 녹화분 전체 손실** 💥

**Fragmented MP4 구조:**

```
Fragmented MP4 구조:
[ftyp] [moov - 비어있음] [moof][mdat] [moof][mdat] [moof][mdat] ...
                          ↑     ↑      ↑     ↑      ↑     ↑
                          각 세그먼트가 독립적으로 재생 가능
```

**크래시 시나리오:**
1. 120분 녹화 중
2. 90분 시점에 정전/크래시 발생
3. **마지막 fragment까지 재생 가능**
4. **~89분 녹화분 복구 가능** ✅

### 4. Media Foundation으로 Fragmented MP4 구현 가능한가?

**Microsoft 공식 문서 조사:**

검색 결과, Media Foundation에서 Fragmented MP4를 만드는 방법:

1. **MF_TRANSCODE_CONTAINERTYPE = MFTranscodeContainerType_FMPEG4**
   - Windows 8+ 전용
   - IMFSinkWriter가 아닌 IMFTranscodeProfile 사용
   - 현재 코드 전면 리팩토링 필요

2. **MFCreateFMPEG4MediaSink** (Windows 10+)
   - Media Foundation의 MPEG4 Fragment Sink
   - 복잡한 설정 필요
   - 문서화 부족

**조사 결과:**
- ⚠️ 구현 가능하지만 복잡함
- ⚠️ Windows 버전 의존성 높음
- ⚠️ Stack Overflow에서 신뢰성 문제 다수 보고
- ⚠️ 현재 코드 대폭 수정 필요

### 5. 크래시 복구가 실제로 얼마나 중요한가?

**예상 사용 시나리오:**

| 시나리오 | 빈도 | 영향 | Fragmented MP4 필요성 |
|---------|------|------|---------------------|
| **정상 녹화** | 95% | 없음 | 불필요 |
| **일시적 네트워크 끊김** | 3% | 낮음 | 불필요 (재연결) |
| **정전/시스템 크래시** | 1% | 🔴 치명적 | **필수** |
| **앱 크래시** | 1% | 🔴 치명적 | **필수** |

**크래시 시나리오 상세:**

사용자는 **토요일 강의를 녹화**하는데, 강의는 **주 1회**만 열림:

1. 토요일 08:00 강의 시작
2. 09:30 시점에 Windows 자동 업데이트 재부팅 💥
3. 일반 MP4: **90분 녹화분 전체 손실** → 다시 녹화 불가능
4. Fragmented MP4: **~89분 녹화분 복구** → 부분이라도 보존

**결론: 1% 확률이지만, 발생 시 영향이 치명적임**

## 대안 검토

### 대안 1: Media Foundation 현재 구현 유지 + 주기적 파일 쓰기

**방법:**
- IMFSinkWriter->Finalize() 주기적 호출 (5분마다)
- 새 세그먼트 파일로 시작

**문제점:**
- ❌ Finalize()는 파일을 닫음 → 연속 녹화 불가
- ❌ 5분마다 녹화 중단 → 프레임 드롭 위험
- ❌ 세그먼트 간 시간 불일치 가능성

### 대안 2: Media Foundation + Fragmented MP4 구현

**장점:**
- ✅ 현재 DXGI/WASAPI 코드 재사용 가능
- ✅ Windows 네이티브 API 사용

**단점:**
- ⚠️ 구현 복잡도 높음 (IMFTranscodeProfile)
- ⚠️ Windows 8+ 요구
- ⚠️ Stack Overflow에서 신뢰성 문제 보고 다수
- ⚠️ 개발 시간 증가 (추정 3-5일)
- ⚠️ 테스트 시간 증가 (크래시 시나리오 검증)

### 대안 3: FFmpeg + Named Pipe (PRD 계획)

**장점:**
- ✅ Fragmented MP4 검증된 구현 (`-movflags`)
- ✅ 세그먼트 저장 내장 (`-f segment`)
- ✅ 하드웨어 인코더 자동 감지
- ✅ PRD 설계와 일치
- ✅ Stack Overflow 다수 검증 사례

**단점:**
- ⚠️ 전면 리팩토링 필요 (추정 5-7일)
- ⚠️ FFmpeg 바이너리 포함 (~100MB)
- ⚠️ Named Pipe 오버헤드

## 비용-편익 분석

### 옵션 A: Media Foundation 유지 (Fragmented MP4 없음)

| 항목 | 값 |
|------|-----|
| **개발 시간** | 0일 (현재 상태 유지) |
| **크래시 복구** | ❌ 불가능 |
| **PRD 충족** | ❌ FR-10-1 미달 |
| **리스크** | 🔴 **1% 확률로 전체 녹화분 손실** |

### 옵션 B: Media Foundation + Fragmented MP4 구현

| 항목 | 값 |
|------|-----|
| **개발 시간** | 3-5일 |
| **크래시 복구** | ⚠️ 가능 (신뢰성 불확실) |
| **PRD 충족** | ⚠️ FR-10-1 부분 충족 |
| **리스크** | 🟡 IMFSinkWriter Finalize() 행 위험 |

### 옵션 C: FFmpeg + Named Pipe (PRD 계획)

| 항목 | 값 |
|------|-----|
| **개발 시간** | 5-7일 |
| **크래시 복구** | ✅ 검증된 구현 |
| **PRD 충족** | ✅ 모든 요구사항 충족 |
| **리스크** | 🟢 검증된 기술 스택 |

## 최종 권장사항

### 단계별 접근 (절충안)

**Phase 3.3.1: 최소 크래시 복구 (현재 구조 유지)**

1. ✅ `.recording` 임시 파일 구현 (1일)
   - 녹화 중: `output.recording`
   - 정상 종료: `output.mp4`로 rename

2. ✅ 크래시 복구 다이얼로그 (1일)
   - 앱 시작 시 `.recording` 파일 스캔
   - "이 파일은 완료되지 않았습니다. 복구하시겠습니까?"
   - 복구 시도 (IMFSinkWriter->Finalize() 호출 불가하므로 제한적)

3. ⚠️ **제한사항 명시**:
   - "크래시 복구는 제한적입니다. 정상 종료를 권장합니다."
   - 헬스체크로 사전 예방 강화

**개발 시간: 2일**
**PRD 충족: 부분적 (FR-16, FR-17)**

---

**Phase 3.3.2: 완전한 크래시 복구 (FFmpeg 마이그레이션)** *(선택적)*

조건: Phase 3.3.1 완료 후, 실제 크래시 사례 발생 시 재평가

**개발 시간: 5-7일**
**PRD 충족: 완전 (FR-10-1, FR-16, FR-17)**

## 결정 기준

### Fragmented MP4 구현 여부 결정:

**Q1. 크래시 복구가 프로젝트의 핵심 가치인가?**
- PRD: "Fragmented MP4 기반 파일 복구 안정성"
- → **YES, 핵심 가치임**

**Q2. Media Foundation으로 신뢰성 있게 구현 가능한가?**
- Stack Overflow: Finalize() 행, 호환성 문제 다수
- → **NO, 신뢰성 불확실**

**Q3. FFmpeg 마이그레이션 시간이 허용되는가?**
- 추정: 5-7일
- → **프로젝트 일정에 따라 결정**

**Q4. 현재 단계에서 꼭 필요한가?**
- Phase 3.3은 "안정성" 단계
- 사용자 강조: "녹화용량 최적화 같은 안정성 3.3 부분 특히 잘해줘"
- → **Phase 3.3의 핵심 목표임**

## 최종 추천

### 추천 A: 점진적 접근 (현실적)

1. **Phase 3.3.1 먼저 구현** (2일)
   - `.recording` 임시 파일
   - 크래시 복구 다이얼로그 (제한적)
   - 사용자에게 현재 한계 명시

2. **실제 사용 후 평가**
   - 4주 사용 후 크래시 사례 수집
   - 크래시 발생 빈도가 높으면 FFmpeg 마이그레이션

3. **필요 시 Phase 3.3.2 진행**
   - FFmpeg + Named Pipe
   - 완전한 Fragmented MP4

### 추천 B: PRD 완전 충족 (이상적)

1. **FFmpeg 마이그레이션 즉시 진행**
   - PRD 요구사항 완전 충족
   - 검증된 크래시 복구
   - 장기적 안정성 확보

---

**다음 단계 제안:**

1. 현재 Media Foundation 구현 테스트 (10초 → 120분 녹화)
2. 크래시 시나리오 검증 (강제 종료 후 파일 상태 확인)
3. 결과에 따라 A 또는 B 선택

**사용자께 확인 필요:**
- 개발 일정이 얼마나 여유 있는가?
- 크래시 복구가 MVP(Minimum Viable Product)에 필수인가?
- 점진적 접근 vs 완전 구현 중 선호는?
