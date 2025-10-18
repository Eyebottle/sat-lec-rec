토요 컨퍼런스 ZOOM 자동 녹화 앱 — PRD v1.1

Executive Summary

본 제품은 토요일 Zoom 강의를 무인 자동 녹화하여, 사용자가 링크·시작 시각·녹화 시간만 입력하면 정시에 입장하고 안정적으로 저장하도록 돕는다.

핵심 가치: 주말 작업 최소화, 95% 이상 예약 성공률, Fragmented MP4 기반 파일 복구 안정성.
타깃 사용자: 토요일 강의를 운영·수강하는 1인 사용자.
타임라인: M1~M4, 약 12주 예상.
성공 기준: 4주 연속 95% 성공률, T0±3초 내 녹화 시작, 드롭률 < 1%.

0. 배경 & 목표

매주 토요일 강의(ZOOM)를 정시에 자동 입장하고 로컬(화면+소리)로 자동 녹화한다.

사용자는 회의 링크·시작 시각·녹화 시간만 직접 입력한다.

oCam 수준의 단순함을 유지하되, 정시성·안정성·기록관리(파일명/로그)만 강화한다.

1. 범위(Scope)

In-Scope (MVP)

링크/시간 수동 입력 → 정시 입장

로컬 녹화: 화면(Zoom 창 우선) + 시스템 소리(스피커), 마이크 믹스 옵션

녹화 시간 제한: 만료 시 동작 선택(아무 작업 없음 / 새 녹화 / 앱 종료 / 시스템 종료 / 최대 절전)

세그먼트 저장(옵션): 장시간 대비 30/45/60분 단위 파일 분할(기본 45분)

파일 관리: 규칙형 파일명, 저장 폴더 지정, 디스크 여유 공간 체크

사전 헬스체크: T-10분 링크·네트워크·디스크·오디오 장치·인코더·Zoom 클라이언트 확인 / T-2분 예열

간단 UI: 예약 카드 1개, 10초 테스트, 트레이 아이콘, 글로벌 핫키(시작/중지)

Out-of-Scope (v1.0 제외)

클라우드 녹화 API/자막/요약/편집 스튜디오

다자 공유/권한 관리, iOS/웹 클라이언트

2. 사용자 및 사용 시나리오

User Story

As a 토요일 강의 운영자, I want to 미리 링크·시간·녹화시간을 입력하면 앱이 자동으로 입장·녹화해서, 토요일 오전에 기기 앞에 있지 않아도 강의를 복습용으로 보관하고 싶다.

Acceptance Criteria

- 금요일 23시에 예약 저장 시 토요일 08시에 자동 입장·녹화 시작
- 80분 녹화 후 파일 및 메타 자동 저장
- 파일명에 날짜·강의명 포함, 최소 72분 이상 영상 보존
- 크래시가 있어도 기록된 부분은 Fragmented MP4로 복구 가능

주요 시나리오

공지 수령 → 앱에 회의 링크·시작시각·녹화시간 입력 → 저장

토요일 자동으로 T-10 준비/T-2 예열 → T0 입장·녹화 시작

시간 만료 시 설정한 동작 수행 → 파일/메타 저장 → 완료 알림

3. 성공 기준 (측정 방법 포함)

정시성: T0±3초 내 녹화 시작(환경에 따라 허용 오차 최대 ±5초)
- 측정: 메타 JSON에 scheduled_start_time, actual_start_time 기록 → 오차(ms) 계산 → 평균·최대 오차 및 ±3초 달성률 산출

완성률: 4주 연속 토요일 예약 성공률 ≥ 95%
- 측정: 성공 = 메타 파일 존재 & duration ≥ 예약 시간의 90%; 실패 = 크래시, 0바이트, 무음 파일 → 성공률 = (성공 건수 / 전체 예약) × 100

품질: 드롭·끊김 없이 720p/24fps 안정 녹화(기본 프로파일)
- 측정: ffprobe로 해상도/FPS/비트레이트 확인, dropped_frames 필드로 드롭률(<1%) 검증

신뢰성 지표 추가
- CPU 평균/최대 점유율(목표 50% 미만)
- 메모리 증가량(120분 녹화 후 500MB 미만)
- 세그먼트 전환 시 프레임 연속성(전환 시점 ±1초)

3.1 성공 기준 자동 측정 구현

**목적:** 주간/월간 성공률 자동 집계, 실패 파일 자동 감지, 대시보드 시각화

**측정 스크립트 구조 (Python/C++):**

```python
# validate_recordings.py
import json
import subprocess
import datetime
from pathlib import Path

class RecordingValidator:
    def __init__(self, recordings_dir: Path):
        self.recordings_dir = recordings_dir
        self.results = []

    def validate_all(self, days: int = 28):
        """최근 N일 녹화 파일 검증"""
        cutoff = datetime.datetime.now() - datetime.timedelta(days=days)

        for meta_path in self.recordings_dir.glob("*.json"):
            if meta_path.stat().st_mtime < cutoff.timestamp():
                continue

            result = self.validate_recording(meta_path)
            self.results.append(result)

        return self.calculate_metrics()

    def validate_recording(self, meta_path: Path):
        """단일 녹화 검증"""
        with open(meta_path) as f:
            meta = json.load(f)

        video_path = meta_path.with_suffix(".mp4")

        # 1. 파일 존재 여부
        if not video_path.exists():
            return {"status": "FAIL", "reason": "File not found"}

        # 2. 파일 크기 (0바이트 체크)
        if video_path.stat().st_size < 1024 * 1024:  # 1MB 미만
            return {"status": "FAIL", "reason": "File too small"}

        # 3. ffprobe 검증 (해상도/FPS/길이)
        probe = self.run_ffprobe(video_path)

        # 4. 길이 검증 (예약 시간의 90% 이상)
        scheduled_duration = meta.get("scheduled_duration_sec", 0)
        actual_duration = probe.get("duration", 0)

        if actual_duration < scheduled_duration * 0.9:
            return {
                "status": "FAIL",
                "reason": f"Short recording: {actual_duration}/{scheduled_duration}s"
            }

        # 5. 무음 검증 (RMS < -50dB 경고)
        silence_ratio = self.detect_silence(video_path)
        if silence_ratio > 0.5:  # 50% 이상 무음
            return {
                "status": "WARN",
                "reason": f"High silence ratio: {silence_ratio:.1%}"
            }

        # 6. 드롭 프레임 검증
        dropped = probe.get("dropped_frames", 0)
        total_frames = probe.get("total_frames", 1)
        drop_rate = dropped / total_frames

        if drop_rate > 0.01:  # 1% 이상
            return {
                "status": "WARN",
                "reason": f"High drop rate: {drop_rate:.2%}"
            }

        # 7. 정시성 검증
        scheduled_start = meta.get("scheduled_start_time")
        actual_start = meta.get("actual_start_time")

        if scheduled_start and actual_start:
            delay_ms = abs(actual_start - scheduled_start)
            if delay_ms > 5000:  # ±5초 초과
                return {
                    "status": "WARN",
                    "reason": f"Late start: {delay_ms}ms"
                }

        return {"status": "PASS", "meta": meta, "probe": probe}

    def run_ffprobe(self, video_path: Path):
        """FFprobe로 비디오 메타데이터 추출"""
        cmd = [
            "ffprobe",
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=width,height,r_frame_rate,nb_frames",
            "-show_entries", "format=duration",
            "-of", "json",
            str(video_path)
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)
        data = json.loads(result.stdout)

        stream = data["streams"][0] if data["streams"] else {}
        format_info = data["format"]

        return {
            "width": stream.get("width"),
            "height": stream.get("height"),
            "fps": eval(stream.get("r_frame_rate", "0/1")),  # "24/1" → 24.0
            "total_frames": int(stream.get("nb_frames", 0)),
            "duration": float(format_info.get("duration", 0))
        }

    def detect_silence(self, video_path: Path):
        """무음 구간 비율 측정 (RMS < -50dB)"""
        cmd = [
            "ffmpeg",
            "-i", str(video_path),
            "-af", "silencedetect=n=-50dB:d=2",  # 2초 이상 무음
            "-f", "null",
            "-"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, stderr=subprocess.STDOUT)

        # 출력에서 silence_start/silence_end 파싱
        import re
        silence_durations = []

        for line in result.stdout.split("\n"):
            if "silence_duration" in line:
                match = re.search(r"silence_duration: ([\d.]+)", line)
                if match:
                    silence_durations.append(float(match.group(1)))

        total_silence = sum(silence_durations)
        total_duration = self.run_ffprobe(video_path)["duration"]

        return total_silence / total_duration if total_duration > 0 else 0

    def calculate_metrics(self):
        """성공률 집계"""
        total = len(self.results)
        passed = sum(1 for r in self.results if r["status"] == "PASS")
        warned = sum(1 for r in self.results if r["status"] == "WARN")
        failed = sum(1 for r in self.results if r["status"] == "FAIL")

        return {
            "total": total,
            "passed": passed,
            "warned": warned,
            "failed": failed,
            "success_rate": (passed / total * 100) if total > 0 else 0,
            "details": self.results
        }

# 실행 예시
if __name__ == "__main__":
    validator = RecordingValidator(Path("D:/SaturdayZoomRec/2025/10"))
    metrics = validator.validate_all(days=28)

    print(f"최근 4주 성공률: {metrics['success_rate']:.1f}% ({metrics['passed']}/{metrics['total']})")
    print(f"경고: {metrics['warned']}건, 실패: {metrics['failed']}건")

    # JSON 저장
    with open("validation_report.json", "w") as f:
        json.dump(metrics, f, indent=2)
```

**UI 대시보드 연동:**

```dart
// lib/widgets/metrics_dashboard.dart
class MetricsDashboard extends StatelessWidget {
  final ValidationMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(
            "최근 4주 성공률: ${metrics.successRate.toStringAsFixed(1)}%",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text("${metrics.passed}/${metrics.total}건 성공"),

          if (metrics.warned > 0)
            Text("⚠️ ${metrics.warned}건 경고", style: TextStyle(color: Colors.orange)),

          if (metrics.failed > 0)
            Text("❌ ${metrics.failed}건 실패", style: TextStyle(color: Colors.red)),

          ElevatedButton(
            onPressed: () => _showDetailedReport(context),
            child: Text("상세 보고서 보기"),
          ),
        ],
      ),
    );
  }
}
```

**자동 실행 설정:**

1. **주간 스케줄 작업 (Windows Task Scheduler):**
   ```xml
   <Task>
     <Triggers>
       <CalendarTrigger>
         <StartBoundary>2025-01-01T09:00:00</StartBoundary>
         <ScheduleByWeek>
           <DaysOfWeek><Monday /></DaysOfWeek>
           <WeeksInterval>1</WeeksInterval>
         </ScheduleByWeek>
       </CalendarTrigger>
     </Triggers>
     <Actions>
       <Exec>
         <Command>python</Command>
         <Arguments>C:\sat-lec-rec\validate_recordings.py</Arguments>
       </Exec>
     </Actions>
   </Task>
   ```

2. **앱 시작 시 자동 로드:**
   ```dart
   // lib/main.dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();

     // 메트릭 로드
     final metrics = await loadValidationMetrics();

     runApp(MyApp(metrics: metrics));
   }
   ```

**출력 예시:**

```
최근 4주 성공률: 96% (23/24)
경고: 1건 (무음 비율 높음), 실패: 0건

상세:
- 2025-10-05: PASS (78분, 720p, 드롭률 0.3%)
- 2025-10-12: PASS (82분, 720p, 드롭률 0.5%)
- 2025-10-19: WARN (80분, 720p, 무음 60%, 드롭률 0.2%)
- 2025-10-26: PASS (79분, 720p, 드롭률 0.4%)
```

4. 환경 & 제약

Windows 우선: 실제 녹화 본 환경은 Windows 데스크톱/노트북

WSL↔Windows 동기화 운영: 실개발은 WSL 경로, 빌드는 NTFS 경로에서 수행(기존 동기화 스크립트/훅 재사용)

그래픽/오디오 드라이버 다양성: 하드웨어 인코더 유무가 다름 → 자동 감지·폴백 필요

절전/보안 정책: 병원/사내망 전제 시 절전·방화벽·AV 영향 가능

Windows 업데이트·재부팅: 예약 시간대 강제 업데이트 방지 정책 필요

Zoom 버전 변동: UI/인증 흐름 변경에 대비한 모니터링 필요

5. 기능 요구사항(FR)

5.1 예약 & 스케줄러

FR-1: 회의 링크(URL/zoommtg 스킴)·시작 시간·녹화 시간(분/초) 입력/저장

FR-2: T-10 준비 체크(네트워크/디스크/오디오 장치/인코더/Zoom 클라이언트) & T-2 예열

FR-2-1: Pre-flight 체크리스트

**M1~M2 (필수 항목):**

1. 네트워크 연결성
   - zoom.us ping (ICMP 응답 확인)
   - DNS 해석 (gethostbyname 성공 여부)
   - 결과: PASS/FAIL

2. 디스크 상태
   - 저장 경로 쓰기 권한 (CreateFile 테스트)
   - 남은 용량 > 예상 용량 + 5GB (GetDiskFreeSpaceEx)
   - 결과: PASS/FAIL

3. 오디오 장치
   - WASAPI 기본 재생 장치 존재 (IMMDeviceEnumerator::GetDefaultAudioEndpoint)
   - 결과: PASS/FAIL

4. 비디오 인코더
   - NVENC/QSV/AMF 존재 여부 (`ffmpeg -encoders | grep h264_nvenc`)
   - 결과: HW_AVAILABLE / SW_FALLBACK

5. Zoom 클라이언트
   - 설치 경로 존재 (레지스트리 확인: HKLM\SOFTWARE\Zoom)
   - 결과: PASS/FAIL

**평가 로직:**
- FAIL ≥ 1개 → 녹화 시작 차단, 오류 다이얼로그
- 모두 PASS → T-2분 Warm-up 진행

**M3~M4 (선택 항목 - 복잡도 높음):**
- 대역폭 테스트 (외부 API 통합 필요)
- 100MB 쓰기 성능 테스트 (3초 이상 소요 가능)
- CPU 부하 예측 (벤치마크 데이터 필요)
- Zoom 로그인 상태 (버전별 파싱 필요)
- 오디오 샘플레이트/독점 모드 확인

FR-2-2: Warm-up 절차 (T-2분)

**목적:** FFmpeg/캡처 API 콜드 스타트 지연 제거, T0 시점 500ms 이내 녹화 시작 보장

**단계별 절차:**

1. **FFmpeg 프로세스 테스트 (15초)**
   ```cpp
   // 검은 화면 720p@24fps, 무음 48kHz, 5초 인코딩
   std::string testCmd =
       "ffmpeg -f lavfi -i testsrc=size=1280x720:rate=24:duration=5 "
       "-f lavfi -i anullsrc=r=48000:cl=stereo "
       "-c:v h264_nvenc -preset fast -c:a aac "
       "-movflags +frag_keyframe+empty_moov "
       "test_warmup.mp4";

   DWORD exitCode = executeAndWait(testCmd, 15000);  // 15초 타임아웃

   if (exitCode != 0) {
       // NVENC 실패 시 x264 폴백으로 재시도
       testCmd = replace(testCmd, "h264_nvenc", "libx264 -preset veryfast");
       executeAndWait(testCmd, 15000);
   }

   deleteFile("test_warmup.mp4");  // 테스트 파일 삭제
   ```
   - 검증: FFmpeg 정상 실행, 하드웨어 인코더 초기화
   - 실패 시: WARN 상태로 전환, 소프트웨어 인코더 대비

2. **Windows Graphics Capture 초기화 (2초)**
   ```cpp
   // 데스크톱 1프레임 캡처
   auto item = CreateCaptureItemForMonitor(primaryMonitor);
   auto framePool = Direct3D11CaptureFramePool::Create(...);
   auto session = framePool.CreateCaptureSession(item);

   session.StartCapture();
   auto frame = framePool.TryGetNextFrame();  // 첫 프레임 획득
   auto startTime = GetTickCount64();
   session.Close();

   DWORD captureLatency = GetTickCount64() - startTime;
   if (captureLatency > 200) {
       logWarning("Graphics Capture slow: " + captureLatency + "ms");
   }
   ```
   - 검증: API 응답 시간 측정 (200ms 기준)
   - 실패 시: WARN 상태, GDI 폴백 준비

3. **WASAPI Loopback 초기화 (2초)**
   ```cpp
   // 기본 재생 장치에서 1초 오디오 캡처
   IMMDevice* device = enumerator->GetDefaultAudioEndpoint(eRender, eConsole);
   IAudioClient* audioClient = device->Activate(...);

   audioClient->Initialize(
       AUDCLNT_SHAREMODE_SHARED,
       AUDCLNT_STREAMFLAGS_LOOPBACK,
       10000000,  // 1초 버퍼
       0, waveFormat, NULL
   );

   IAudioCaptureClient* captureClient = audioClient->GetService(...);
   audioClient->Start();
   Sleep(1000);  // 1초 수집

   UINT32 packetLength = 0;
   captureClient->GetNextPacketSize(&packetLength);
   audioClient->Stop();

   if (packetLength == 0) {
       logInfo("Audio silent (normal if no sound playing)");
   }
   ```
   - 검증: 버퍼 정상 수집 (무음이어도 PASS)
   - 실패 시: FAIL, 장치 변경 알림

4. **시스템 리소스 스냅샷 (1초)**
   ```cpp
   MEMORYSTATUSEX memInfo;
   GlobalMemoryStatusEx(&memInfo);

   PDH_FMT_COUNTERVALUE counterVal;
   PdhGetFormattedCounterValue(cpuQuery, PDH_FMT_DOUBLE, NULL, &counterVal);

   baselineCPU = counterVal.doubleValue;
   baselineMemory = memInfo.ullAvailPhys;
   ```
   - 목적: 녹화 중 증가량 비교 베이스라인

5. **Zoom 클라이언트 Pre-launch (T-30초)**
   ```cpp
   // Zoom.exe 프로세스만 백그라운드 실행 (링크는 T0에 전달)
   STARTUPINFO si = {0};
   si.dwFlags = STARTF_USESHOWWINDOW;
   si.wShowWindow = SW_HIDE;  // 숨김 상태

   CreateProcess("C:\\Program Files\\Zoom\\bin\\Zoom.exe", "", ...);
   Sleep(500);  // 프로세스 안정화
   ```
   - 목적: 클라이언트 초기화 시간 제거
   - 주의: 링크는 T0±1초에 실제 전달하여 입장 타이밍 유지

**전체 소요 시간:** 약 20초 (T-2분 ~ T-100초)

FR-3: 정확 시각(T0) 자동 실행(입장 & 녹화 시작), 실패 시 재시도 정책 적용

FR-4: Windows 절전 방지/깨우기(전원 프로필 변경, 화면 꺼짐 방지, Task Scheduler 깨우기 옵션)

5.2 입장(런처)

FR-5: 링크 실행으로 Zoom 자동 호출(대기실 시 재시도)

FR-5-1: 상황별 재시도 정책
- 호스트 미시작 메시지: 30초 간격 최대 20회(10분)
- 대기실 메시지: 20초 간격 최대 15회(5분) 후 사용자 알림
- 잘못된 ID/권한 제한: 즉시 실패 → 알림
- 호스트 종료: 녹화 종료 후 정상 저장

FR-6: SSO/재로그인 필요 시 사전 알림(전날/당일 확인용 배지)

5.3 녹화(로컬 화면+소리)

FR-7: 화면: Zoom 창(윈도우 핸들) 우선 캡처, 실패 시 전체 모니터 폴백

FR-8: 오디오: 시스템 소리(WASAPI Loopback) 기본, 마이크 믹스 옵션

FR-8-1: 장치 변경 대응

**Windows IMMNotificationClient 구현:**
```cpp
// IMMNotificationClient 인터페이스 구현
class DeviceNotificationClient : public IMMNotificationClient {
public:
    HRESULT OnDefaultDeviceChanged(
        EDataFlow flow,
        ERole role,
        LPCWSTR pwstrDeviceId
    ) override {
        if (flow == eRender && isRecording) {
            // 기본 재생 장치 변경 감지
            PostMessage(hwndMain, WM_AUDIO_DEVICE_CHANGED, 0, 0);
        }
        return S_OK;
    }
};
```

**기본 동작 (M1~M2):**
1. 감지: IMMNotificationClient::OnDefaultDeviceChanged 이벤트
2. 일시 중지: 녹화 즉시 일시 중지 (FFmpeg SIGSTOP)
3. 모달 표시:
   ```
   오디오 장치가 변경되었습니다.

   [이전 장치로 복구] [새 장치로 계속] [녹화 중지]

   30초 후 자동으로 녹화 중지됩니다.
   ```
4. 타임아웃: 30초 무응답 시 자동 중지 + 기존 파일 저장

**설정 옵션 (M3~M4):**
- 옵션A: 자동 전환 (새 기본 장치로 즉시 전환, 로그만 기록)
- 옵션B: 경고만 표시 (녹화 계속, 무음 위험 로그 기록)
- 옵션C: 즉시 중지 (파일 저장 후 종료)

FR-9: 품질 프로파일: 기본 720p/24fps/~3.5Mbps, 고급에서 1080p/30fps 선택 가능

FR-10: 세그먼트 저장 옵션: 30/45/60분 간격, _part001 형식 파일명 (기본 45분, 3자리 0 패딩)

FR-10-1: Fragmented MP4 사용(-movflags +frag_keyframe+empty_moov)으로 크래시 시에도 재생 가능하도록 저장

FR-11: 시간 제한 동작: 아무 작업 없음(기본)/새 녹화/앱 종료/시스템 종료/최대 절전

FR-12: 파일명 규칙: YYYYMMDD_HHMM_[연제]_[연자]_zoom_partNNN.mp4

**파일명 생성 로직:**
- 기본 형식: `YYYYMMDD_HHMM_[연제]_[연자]_zoom.mp4`
- 세그먼트 사용 시: `YYYYMMDD_HHMM_[연제]_[연자]_zoom_part001.mp4`
- 빈값 생략 예시:
  - 모두 입력: `20251018_0800_술후안내염_이승민_zoom.mp4`
  - 연자만 생략: `20251018_0800_술후안내염_zoom.mp4`
  - 모두 생략: `20251018_0800_zoom.mp4`

FR-13: 메타(JSON 동명 파일): 해상도/FPS/인코더/길이/해시/시작·종료/오디오 소스/드롭 프레임/CPU·메모리 스냅샷

FR-14: 저장 폴더 지정, 남은 용량 임계치(기본 5GB) 미만 시 시작 차단

FR-15: 완료/실패 알림, 썸네일(선택), 트레이 아이콘 상태 표시, 글로벌 핫키(Start/Stop)

5.4 크래시 복구

FR-16: 녹화 중 임시 확장자(.recording) 사용, 정상 종료 시 .mp4로 rename

FR-17: 앱 재시작 시 .recording 파일 감지 → 복구 다이얼로그 노출(재시작/무시 선택)

FR-18: 프로세스 크래시 감지 시 최대 2회 자동 재기동, 새 세그먼트로 재개 및 로그 기록

6. 비기능 요구사항(NFR)

NFR-1 성능: CPU 점유 50% 미만(하드웨어 인코더 시), 드롭률 < 1%

NFR-2 안정성: 장시간(≥120분) 녹화 시 메모리 누수/프리즈 없이 세그먼트 안전 저장

NFR-3 사용성: “링크·시간·녹화시간” 3가지 핵심만 입력해도 동작

NFR-4 보안/프라이버시: 개인 복습용 전제, 녹화 중 상시 배지 옵션 제공, 감사 로그(시작/중지/실패) 저장

NFR-5 배포 신뢰성: 코드 서명(가능 시), 안티바이러스 오탐 최소화 가이드

NFR-6 관찰성: JSON 구조화 로그, 1초 단위 메트릭(CPU/메모리/디스크 I/O), 녹화 타임라인 트레이싱, 30일/1GB 순환 보존

NFR-7 복구 가능성: 크래시 후 5초 이내 복구 프롬프트, 부분 녹화 복구율 90% 이상, 세그먼트 독립 재생 가능

NFR-8 유지보수성: 캡처/인코딩/스케줄링 모듈 분리, 설정 JSON/YAML 외부화, 버전 마이그레이션 스크립트, 핵심 함수 DartDoc/JSDoc

7. UX 개요

홈: 예약 카드(링크·시각·시간), [10초 테스트], [저장 폴더 열기], 헬스체크 배지, 상태 표시

설정: 캡처 대상(창/모니터), 오디오(스피커 기본/마이크 믹스 옵션), 품질(기본/고급), 세그먼트 on/off, 제한 만료 시 동작, 디스크 임계치, Fragmented MP4 고정 안내

트레이: 녹화 시작/중지, 최근 파일 열기, 상태(준비/대기/녹화/경고/오류), 장치 변경 알림 표시

8. 구현 전략(비개발자 설명 버전)

화면 캡처: Windows의 공식 화면 가져오기 기능으로 줌 창만 잡는다. 안 되면 전체 화면으로 자동 전환한다.

소리 캡처: 컴퓨터 소리를 그대로 받는 표준 루프백 경로를 쓰고, 필요 시 마이크를 섞을 수 있게 한다.

저장: FFmpeg을 함께 넣어 H.264/AAC(mp4)로 저장한다. 그래픽카드가 있으면 자동으로 가속하고, 없으면 일반 방식으로 바꾼다.

정시성: 예약시간 전에 미리 기기를 깨우고 점검 후 예열을 해서 정확히 시작한다.

안전장치: 45분마다 파일을 나눠 저장(원하면 30/60분 선택), 디스크 부족이나 장치 미인식이면 시작 전 막는다.

9. 기술 스택 & 아키텍처

9.1 Flutter 네이티브 통합 전략

**아키텍처 패턴:**
- Flutter(Dart) UI ↔ dart:ffi ↔ C++ 녹화 엔진 (네이티브)
- 프레임 데이터는 C++ 메모리에서 FFmpeg로 직접 전달 (Zero-Copy)
- Dart는 제어 명령만 전달 (시작/중지/설정)

**기술적 근거:**
1. Platform Channel 성능 한계:
   - 720p@24fps = 약 88MB/초 프레임 데이터
   - EventChannel은 여러 복사 단계 포함 → CPU 과부하 발생
   - 참조: Flutter 공식 블로그 "Improving Platform Channel Performance"

2. FFI Zero-Copy 전략:
   - Uint8List.address를 통한 네이티브 포인터 직접 전달
   - Pointer.asTypedList로 네이티브 메모리 뷰 생성
   - 복사 없이 메모리 주소만 전달 (~100ns 오버헤드)

**구현 방식 (코드 스케치):**
```cpp
// C++ 네이티브 플러그인 (windows/recorder_plugin.cpp)
class RecorderEngine {
  CaptureThread captureThread;    // Windows Graphics Capture
  AudioThread audioThread;         // WASAPI Loopback
  FFmpegPipeline ffmpegPipeline;   // Named Pipe → FFmpeg
};

// Dart FFI 바인딩 (lib/native_recorder.dart)
@Native<Void Function()>(isLeaf: true)
external void nativeStartRecording();
```

**참고 프로젝트:**
- github.com/ffiirree/ffmpeg-tutorials (Windows Graphics Capture + WASAPI)
- github.com/clowd/screen-recorder (WASAPI 동기화 muxing)
- github.com/robmikh/Win32CaptureSample (공식 Windows Graphics Capture 예시)

9.2 FFmpeg 통합 전략

**Windows Named Pipe 사용 (검증된 방법):**

C++ Named Pipe 생성 및 FFmpeg 연동:
```cpp
// 1. Named Pipe 생성 (비동기, 별도 스레드)
HANDLE hVideoPipe = CreateNamedPipeA(
    "\\\\.\\pipe\\video",
    PIPE_ACCESS_OUTBOUND,          // 단방향 (쓰기 전용)
    PIPE_TYPE_BYTE | PIPE_WAIT,
    1,                              // 인스턴스 1개
    1024 * 1024,                   // 출력 버퍼 1MB
    0, 0, NULL
);

HANDLE hAudioPipe = CreateNamedPipeA("\\\\.\\pipe\\audio", ...);

// 2. 스레드 분리: Video 프레임 쓰기
std::thread videoWriter([&]() {
    ConnectNamedPipe(hVideoPipe, NULL);  // FFmpeg 연결 대기
    while (recording) {
        FrameData frame = captureFrame();
        DWORD written;
        WriteFile(hVideoPipe, frame.data, frame.size, &written, NULL);
    }
    CloseHandle(hVideoPipe);
});

// 3. 스레드 분리: Audio 샘플 쓰기
std::thread audioWriter([&]() {
    ConnectNamedPipe(hAudioPipe, NULL);
    while (recording) {
        AudioBuffer buffer = captureAudio();
        DWORD written;
        WriteFile(hAudioPipe, buffer.data, buffer.size, &written, NULL);
    }
    CloseHandle(hAudioPipe);
});

// 4. FFmpeg 프로세스 실행
std::string cmd =
    "ffmpeg "
    "-f rawvideo -pix_fmt bgra -s 1280x720 -r 24 -i \\\\.\\pipe\\video "
    "-f s16le -ar 48000 -ac 2 -i \\\\.\\pipe\\audio "
    "-c:v h264_nvenc -preset fast -b:v 3.5M "
    "-c:a aac -b:a 192k "
    "-f segment -segment_time 2700 "
    "-segment_format_options movflags=frag_keyframe+empty_moov:flush_packets=1 "
    "-reset_timestamps 1 "
    "output_%03d.mp4";

CreateProcess(cmd, ...);
```

**핵심 포인트:**
1. Named Pipe 2개 분리: 비디오/오디오 독립적으로 블로킹 방지
2. 비동기 쓰기: 각 파이프는 별도 스레드에서 WriteFile 호출
3. segment_format_options: 세그먼트마다 Fragmented MP4 적용

**검증된 FFmpeg 명령어:**
```bash
# 단일 파일 (Fragmented MP4)
ffmpeg -i ... -movflags +frag_keyframe+empty_moov output.mp4

# 세그먼트 파일 (각각 Fragmented, 45분=2700초)
ffmpeg -i video -i audio \
  -c:v h264_nvenc -c:a aac \
  -f segment -segment_time 2700 \
  -segment_format_options movflags=frag_keyframe+empty_moov:flush_packets=1 \
  -reset_timestamps 1 \
  output_%03d.mp4
```

**하드웨어 인코더 감지:**
```bash
# NVENC/QSV/AMF 존재 여부 확인
ffmpeg -encoders | grep h264_nvenc  # NVIDIA
ffmpeg -encoders | grep h264_qsv    # Intel Quick Sync
ffmpeg -encoders | grep h264_amf    # AMD

# 미지원 시 자동 폴백
-c:v libx264 -preset veryfast
```

**참조:**
- stackoverflow.com/questions/28473238 (Windows Named Pipe with FFmpeg)
- superuser.com/questions/1868660 (segment + fragmented MP4)

9.3 스케줄링 & 전원 관리
- Windows Task Scheduler에서 Wake the computer 옵션 사용
- 앱 내부 타이머로 T-10/T-2 루틴 수행
- 절전 모드 방지: 전원 프로필 전환 + 화면 꺼짐 차단

9.4 트레이 & 핫키
- Flutter `tray_manager`, `hotkey_manager` 활용
- 상태 변화 이벤트는 FFI 콜백을 통해 Dart로 전달 (제어 명령만)

9.5 로깅 & 관찰성
- JSON 로그(레벨, 타임스탬프, 컨텍스트)
- 성능 메트릭 수집 후 주기적 플러시
- 실패 시 마지막 영상 10초/스크린샷 덤프 옵션

10. 파일/폴더 규격(예시)

기본 폴더: 사용자 지정(예: D:\SaturdayZoomRec\2025\10\)

파일명: 20251018_0800_술후안내염_이승민_zoom.mp4

메타: 동명 …mp4.json(프로파일·길이·해시·세그먼트 정보·드롭 프레임·CPU/메모리)

세그먼트: …_part001.mp4, …_part002.mp4, …_part003.mp4
  예시: 20251018_0800_술후안내염_이승민_zoom_part001.mp4
  FFmpeg segment 형식: %03d (000부터, 3자리 0 패딩)
  각각 Fragmented MP4

임시 파일: …_partN.recording (정상 종료 시 rename)

11. 오류 처리·복구

입장 실패: 30초 간격 최대 3회 재시도, 실패 시 팝업 알림(상세 정책은 FR-5-1 적용)

캡처 실패: 창 타겟 불가 → 전체 모니터 폴백(로그 남김)

오디오 장치 변경:
  기본 동작(M1~M2): 녹화 일시 중지 → 모달 사용자 선택 → 30초 타임아웃
  설정 옵션(M3~M4): 자동 전환 / 경고만 / 즉시 중지

디스크 부족: 시작 차단(경고), 자동 순환 삭제(옵션)

프로세스 크래시: 자동 재기동 최대 2회(세그먼트 단위 보존)

11.1 크래시 복구 세부 전략

- 임시 확장자(.recording) 유지 → 정상 종료 시 rename
- Fragmented MP4로 헤더 미작성 위험 최소화
- 앱 재시작 시 미완료 파일 목록 → 복구 안내 및 메타 업데이트
- 자동 재기동 시 새 세그먼트에서 이어서 녹화, 이전 세그먼트 보존

12. 테스트 계획

12.1 체크리스트(단위)

 10초 테스트: 화면+소리 녹화 확인

 정시 시작: T0±3초 이내 자동 시작

 시간제한: 80분 후 설정 동작 정확 수행

 세그먼트: 120분 연속 시 _part 파일 정확 생성 및 Fragmented MP4 확인

 디스크: 5GB 임계치 이하 차단 동작

 창/모니터 전환: 창 캡처 실패 시 모니터 폴백

 장치 변경: 오디오 장치 변경 시 경고/중단 처리

 절전/깨우기: 예약 전 절전 해제, 대기 중 강제 절전 없이 유지

12.2 통합 테스트 시나리오

시나리오 1 End-to-End
- 테스트 Zoom 계정으로 예약 → 헬스체크 → 60분 녹화 → 종료
- 검증: 파일 크기, ffprobe 결과, 메타 JSON 비교, 알림 로그 검토

시나리오 2 장애 시뮬레이션
- 네트워크 단절(20초 후 복구)
- 녹화 중 디스크 용량 임계 도달
- 헤드셋 분리(장치 변경)
- 기대 결과: 경고/일시정지/재개 동작, 크래시 복구 동작 확인

시나리오 3 성능 로드
- 120분 녹화, CPU/메모리 1초 단위 기록
- 세그먼트 전환 시 프레임 드롭 측정
- 결과: CPU 50% 이하, 메모리 증가 500MB 이하, 드롭률 <1%

12.3 자동화 테스트 환경
- CI(예: GitHub Actions)에서 Windows 에이전트로 실행
- 산출물: 녹화 샘플, 로그, 메트릭 CSV, 스크린샷
- 실패 시: 마지막 10초 영상, 에러 로그 첨부

13. 릴리스 범위 & 마일스톤

M1 (녹화 코어): 화면+소리 녹화, 10초 테스트, 파일 저장/메타, Fragmented MP4 적용

M2 (정시 자동화): 예약/헬스체크/예열/정시 시작, 절전 방지, 재시도 정책

M3 (안정성): 세그먼트, 크래시 복구, 재시작/폴백, 디스크·장치 가드, 관찰성 지표

M4 (UX/배포): 트레이/핫키, 설정 저장, 코드 서명(가능 시), 로그/메트릭 뷰어

14. 리스크 & 대응

리스크 | 영향 | 확률 | 대응 | 완화 전략
-------|------|------|------|----------
대기실/승인 | 시작 지연 | 중 | 재시도·알림 | 사전 대기실 해제 요청, 호스트 협의
오디오 장치 변경 | 무음 파일 | 고 | 실시간 감지 | IMMNotificationClient 구독, 자동 알림/일시정지
드라이버 부재 | 고부하 | 중 | HW 감지→폴백 | T-10 헬스체크에서 사전 경고 및 품질 조정
디스크 부족 | 녹화 실패 | 저 | 사전 체크 | 5GB 임계치 + 실시간 모니터링, 순환 삭제 옵션
절전/보안 정책 | 시작 지연 | 중 | 전원 프로필 | 작업 스케줄러, DND 설정, IT와 협업
FFmpeg 크래시 | 파일 손실 | 중 | Fragmented MP4 | 세그먼트 저장 + 임시 확장자 복구
네트워크 단절 | Zoom 퇴출 | 중 | 재연결 시도 | 대역폭 여유 확인, 경고 후 사용자 개입
Windows 업데이트 | 강제 재시작 | 저 | 업데이트 연기 | 녹화 시간대 자동 업데이트 차단 정책
Zoom UI 변경 | 자동화 실패 | 저 | 버전 감지 | 메이저 버전별 UI 프로파일, 모니터링

15. WSL↔Windows 동기화 유의(현행 구조 반영)

실개발 경로: WSL(예: /home/…/projects/…)

윈도 빌드 경로: NTFS(예: C:\ws-workspace\…)

운영 원칙: 커밋/훅 또는 수동 명령으로 WSL→NTFS 동기화 후, NTFS 경로에서 빌드·실행

제외 항목: 빌드 산출물/캐시 폴더는 동기화 제외(엔지니어링 표준 준수)

16. 전달물(Deliverables)

PRD v1.1(본 문서)

UI 와이어프레임 3장(홈/설정/트레이 상태) — 텍스트 명세 기반

실행/테스트 시나리오 표(체크리스트 + 통합 테스트)

설치/배포 가이드(코드 서명/AV 예외 안내 포함)

관찰성 구성 안내(JSON 로그, 메트릭 수집 템플릿)

17. 결정 사항 요약

오디오 기본값: 시스템 소리만(Loopback), 마이크 믹스는 옵션.

기본 품질: 720p/24fps, 고급 설정에서 1080p/30fps 선택 가능.

시간제한 만료 기본 동작: 아무 작업 없음.

 Fragmented MP4 + .recording 임시 파일 전략 채택.

 헬스체크/워밍업 절차 T-10/T-2 구조로 확정.

 장치 변경 실시간 감지 및 경고/일시정지 플로우 적용.

 성공 기준 측정 메트릭(정시성, 완성률, 품질, 신뢰성) 정의 완료.

18. 모듈별 구현 체크리스트

**의존성 레벨 표기:**
- **L0 (Foundation)**: 다른 모든 기능의 기반이 되는 핵심 인프라, 가장 먼저 구현 필요
- **L1 (Core)**: L0에 의존, 주요 기능의 핵심 구현 (M1~M2 필수)
- **L2 (Enhancement)**: L1에 의존, 안정성 및 품질 향상 (M2~M3 권장)
- **L3 (Polish)**: L2에 의존, UX 개선 및 운영 편의성 (M3~M4 선택)

**마일스톤 매핑:**
- M1 = L0 + L1 (녹화 코어)
- M2 = L1 + L2 (정시 자동화 + 안정성 기초)
- M3 = L2 (안정성 강화)
- M4 = L3 (UX/배포)

- **기본 환경 & 프로젝트 설정**
  - [ ] **[L0]** Flutter Windows 데스크톱 타깃 활성화 및 기본 빌드 확인 (`flutter config --enable-windows-desktop`) (FR 전반)
  - [ ] **[L0]** dart:ffi 스캐폴딩 구성, Dart↔C++ 메시지 샘플 교신 확인 (섹션 9.1)
  - [ ] **[L0]** FFmpeg 런타임(64bit) 번들 구조 설계, 실행 권한/경로 확인 (섹션 9.2)

- **예약 & 헬스체크 모듈**
  - [ ] **[L1]** 예약 저장 로컬 DB/파일 구조 설계(단일 예약 우선) (FR-1)
  - [ ] **[L2]** T-10 Pre-flight 점검 루틴 구현(네트워크/디스크/오디오/인코더/Zoom) (FR-2-1)
  - [ ] **[L2]** 헬스체크 결과 PASS/WARN/FAIL UI 및 알림 처리 (FR-2-1)
  - [ ] **[L2]** T-2 Warm-up 루틴과 성능 스냅샷 로깅 (FR-2-2)
  - [ ] **[L2]** Task Scheduler XML 템플릿 생성 및 Wake 옵션 세팅 (FR-4, 섹션 9.3)

- **Zoom 런처 & 재시도**
  - [ ] **[L1]** zoommtg 링크 실행 및 프로세스 핸들 확보 (FR-5)
  - [ ] **[L2]** 상태별 메시지 파싱(호스트 미시작/대기실/권한 오류) 로직 구현 (FR-5-1)
  - [ ] **[L2]** 재시도 카운터 및 사용자 알림 경로 연결 (FR-5-1)

- **화면 캡처 파이프라인** *(의존: L0 FFI + FFmpeg 기초)*
  - [ ] **[L1]** Windows Graphics Capture로 창 핸들 타깃 캡처 (FR-7)
  - [ ] **[L2]** 전체 모니터 폴백 경로 구현 및 로그 남김 (FR-7)
  - [ ] **[L1]** 프레임 버퍼를 Named Pipe로 FFmpeg에 전달하는 큐 구성 (섹션 9.2)

- **오디오 캡처 파이프라인** *(의존: L0 FFI + FFmpeg 기초)*
  - [ ] **[L1]** WASAPI Loopback 초기화 및 스트림 파이프 구성 (FR-8)
  - [ ] **[L2]** 마이크 믹스 옵션 토글 및 혼합 비율 로직 (FR-8)
  - [ ] **[L2]** IMMNotificationClient 기반 장치 변경 이벤트 구독 (FR-8-1)
  - [ ] **[L3]** 장치 변경 시 경고/일시정지/자동 전환 플로우 구현 (FR-8-1)

- **인코딩 & 세그먼트 처리** *(의존: L1 화면/오디오 캡처)*
  - [ ] **[L1]** 하드웨어 인코더 감지(NVENC/QSV/AMF) 및 FFmpeg 명령 동적 생성 (FR-9, 섹션 9.2)
  - [ ] **[L1]** Fragmented MP4 옵션(-movflags +frag_keyframe+empty_moov) 기본 적용 (FR-10-1)
  - [ ] **[L2]** 세그먼트 롤오버 스케줄러(기본 45분) 및 파일명 생성기 (FR-10)

- **크래시 복구 & 관찰성** *(의존: L1 녹화 파이프라인)*
  - [ ] **[L2]** 임시 확장자(.recording) 파일 생성/정상 종료 시 rename (FR-16)
  - [ ] **[L2]** 앱 재시작 시 미완료 파일 스캔 및 복구 다이얼로그 (FR-17)
  - [ ] **[L2]** 프로세스 모니터링 및 자동 재기동 시퀀스(최대 2회) (FR-18)
  - [ ] **[L2]** JSON 로그/메트릭 수집기 및 보존 정책 구현 (NFR-6)

- **UI/UX & 상호작용** *(의존: L1 예약/녹화 기능)*
  - [ ] **[L1]** 예약 카드 UI(링크/시각/시간 입력 + 검증) (섹션 7)
  - [ ] **[L1]** 10초 테스트 버튼 화면/오디오 미리보기 구현 (FR 체크리스트, 섹션 7)
  - [ ] **[L3]** 트레이 아이콘 및 글로벌 핫키 연동(`tray_manager`, `hotkey_manager`) (FR-15, 섹션 9.4)
  - [ ] **[L2]** 상태 배지/알림(준비/대기/녹화/경고/오류) 표현 (섹션 7)

- **설정 & 파일 관리** *(의존: L1 녹화 기능)*
  - [ ] **[L2]** 설정 JSON 저장/로드 및 버전 관리(유지보수성) (NFR-8)
  - [ ] **[L1]** 파일명 규칙/저장 폴더 선택/용량 체크 구현 (FR-12, FR-14)
  - [ ] **[L2]** 메타 JSON 기록(해상도/FPS/드롭 프레임/CPU·메모리) (FR-13)

- **배포 & 운영 준비** *(의존: L2 모든 기능 완성)*
  - [ ] **[L3]** Windows 패키징 스크립트(msix 또는 zip + 런처) (NFR-5)
  - [ ] **[L3]** 코드 서명/AV 예외 가이드 문서 초안 작성 (섹션 16)
  - [ ] **[L3]** 운영 로그/백업 정책 정의 및 전달물 포함 (NFR-6, NFR-7)

19. 모듈별 수용 테스트

- **기본 환경 & 프로젝트 설정**
  - [ ] Windows에서 `flutter run -d windows` 실행 성공, 로그에 MethodChannel 초기 메시지 표시
  - [ ] FFmpeg 실행 테스트(`ffmpeg -version`) 및 런타임 경로 접근성 검증

- **예약 & 헬스체크 모듈**
  - [ ] 테스트 예약 생성 후 JSON/DB에 저장된 값 검증
  - [ ] 네트워크/디스크/오디오/인코더/Zoom 각각 FAIL 조건을 시뮬레이션하고 UI에 WARN/FAIL 표시 확인
  - [ ] Warm-up 실행 시 FFmpeg 더미 녹화 5초 완료 및 로그에 성능 스냅샷 기록 확인
  - [ ] Task Scheduler 등록 후 PC 절전 상태에서 예약 시간 도달 시 자동 깨움 확인

- **Zoom 런처 & 재시도**
  - [ ] 정상 링크 → Zoom 자동 입장 후 녹화 시작까지 T0±3초 유지
  - [ ] 호스트 미시작/대기실/권한 오류/잘못된 ID 각각 유도, 재시도 횟수 및 알림 동작 검증

- **화면 캡처 파이프라인**
  - [ ] Zoom 창 포커스 상태에서 창만 캡처되는지 영상 확인
  - [ ] 창 닫힘/미표시 시 전체 모니터 폴백 영상 생성 여부 확인
  - [ ] 720p/24fps 해상도 및 프레임 기록이 메타 JSON에 올바르게 표기되는지 검증

- **오디오 캡처 파이프라인**
  - [ ] 시스템 소리만 녹음 시 스펙트럼 확인(마이크 음성 미포함)
  - [ ] 마이크 믹스 옵션 활성화 후 스피커+마이크가 동시에 녹음되는지 확인
  - [ ] 녹화 중 기본 장치 변경 시 경고 다이얼로그/일시정지 동작 확인

- **인코딩 & 세그먼트 처리**
  - [ ] NVENC 지원 GPU에서 하드웨어 인코딩 선택됨을 로그에서 확인
  - [ ] NVENC 미지원 장치에서 x264 폴백 및 CPU 점유율 50% 미만 유지 확인
  - [ ] 90분 녹화 시 _part1.mp4, _part2.mp4 생성 및 Fragmented MP4로 재생 가능 여부 확인

- **크래시 복구 & 관찰성**
  - [ ] 녹화 중 강제 프로세스 종료 → 재실행 시 .recording 복구 다이얼로그 노출
  - [ ] 정상 종료 후 .mp4와 동일 이름 .json 생성 및 로그에 종료 이벤트 기록 확인
  - [ ] 2시간 녹화 중 CPU/메모리 메트릭이 1초 간격으로 수집·보존되는지 확인

- **UI/UX & 상호작용**
  - [ ] 예약 카드 입력 검증(필수 값 누락 시 오류 표시), 저장 후 홈 화면 반영
  - [ ] 10초 테스트 버튼 클릭 시 미리보기 영상·오디오 재생 확인
  - [ ] 트레이 아이콘 상태 변경(대기→녹화→완료) 및 글로벌 핫키(Start/Stop) 동작 검증

- **설정 & 파일 관리**
  - [ ] 설정 변경 후 재실행 시 기존 값 유지
  - [ ] 파일명 생성기가 빈값 누락 처리 후 규칙대로 저장되는지 확인
  - [ ] 디스크 용량 5GB 이하 시 녹화 시작 차단 및 경고 메시지 출력 검증

- **배포 & 운영 준비**
  - [ ] 패키징 산출물 설치 후 바로 실행 가능, 로그 및 저장 경로 정상 생성
  - [ ] 코드 서명된 실행 파일에서 Windows SmartScreen 경고 최소화 확인
  - [ ] AV 예외 가이드 문서 검토 후 적용 여부 체크
