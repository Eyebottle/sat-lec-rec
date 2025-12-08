# Named Pipe + FFmpeg 연동 문제 해결 요청

## 프로젝트 개요
- **목적**: Flutter Windows 앱에서 DXGI/WASAPI로 캡처한 화면/오디오를 FFmpeg로 실시간 인코딩
- **환경**: Windows 11, C++ (Native), FFmpeg 7.1
- **구조**: C++ Named Pipe (Server) ↔ FFmpeg (Client)

## 핵심 문제

### 증상
Named Pipe를 통해 FFmpeg에 비디오/오디오 데이터를 전송하려고 하나, **연결 단계에서 지속적으로 실패**합니다.

### 시도한 모든 접근법과 결과

#### ❌ 시도 1: 동시 ConnectNamedPipe
**코드:**
```cpp
std::thread audio_thread([&]() { ConnectNamedPipe(audio_pipe_, nullptr); });
std::thread video_thread([&]() { ConnectNamedPipe(video_pipe_, nullptr); });
LaunchFFmpeg();
audio_thread.join();
video_thread.join();
```

**결과:**
- Audio 파이프: 성공 ✅
- Video 파이프: `No such file or directory` ❌
- **FFmpeg 로그**: Audio 열림 → Video 찾을 수 없음 → 종료 (exit -2)

---

#### ❌ 시도 2: TestPipeOpenable로 검증 후 재연결
**코드:**
```cpp
// 두 파이프 ConnectNamedPipe 시작
Sleep(2000);
TestPipeOpenable(audio_pipe);  // CreateFileW로 연결 테스트
TestPipeOpenable(video_pipe);
DisconnectNamedPipe(audio_pipe);
DisconnectNamedPipe(video_pipe);
// 재연결 시작
LaunchFFmpeg();
```

**결과:**
- TestPipeOpenable: 두 파이프 모두 성공 ✅
- 재연결 단계에서 앱 **크래시** ❌

---

#### ❌ 시도 3: 순차 연결 (Audio → FFmpeg → Video)
**코드:**
```cpp
std::thread audio_thread([&]() { ConnectNamedPipe(audio_pipe_, nullptr); });
while (!audio_waiting) Sleep(1);
Sleep(200);
LaunchFFmpeg();  // Audio를 먼저 열 것
audio_thread.join();
// Audio 연결 완료 후
std::thread video_thread([&]() { ConnectNamedPipe(video_pipe_, nullptr); });
video_thread.join();
```

**결과:**
- Audio: 성공 ✅
- FFmpeg는 Audio 연결 후 **즉시** Video를 열려고 시도
- Video ConnectNamedPipe는 **아직 시작 안 함** → `No such file or directory` ❌

**FFmpeg 로그 (시도 3):**
```
Line 52: Successfully opened the file.  (Audio)
Line 63: Error opening input: No such file or directory  (Video)
Line 68: Exiting with exit code -2
```

---

#### ❌ 시도 4: 두 파이프 모두 FFmpeg 전에 준비
**코드:**
```cpp
// Audio ConnectNamedPipe 시작
std::thread audio_thread([&]() { ConnectNamedPipe(audio_pipe_, nullptr); });
while (!audio_waiting) Sleep(1);

// Video ConnectNamedPipe 시작 (FFmpeg 전에!)
std::thread video_thread([&]() { ConnectNamedPipe(video_pipe_, nullptr); });
while (!video_waiting) Sleep(1);

Sleep(500);  // 안정화
LaunchFFmpeg();  // 이제 두 파이프 모두 대기 중

audio_thread.join();
video_thread.join();
```

**결과:**
- Audio waiting 플래그: true ✅
- Video waiting 플래그: true ✅
- FFmpeg 시작됨 ✅
- Audio 연결: 성공 ✅
- Video 연결: **여전히 `No such file or directory`** ❌

**FFmpeg 로그 (시도 4):**
```
Line 52: Successfully opened the file.  (Audio)
Line 63: Error opening input: No such file or directory  (Video)
Line 68: Exiting with exit code -2
```

---

#### ❌ 시도 5: ConnectNamedPipe 호출 타이밍 정확화
**문제 발견**: `waiting=true`인데 실제로는 ConnectNamedPipe가 호출 안 된 상태일 수 있음

**코드 수정:**
```cpp
auto connector = [&]() {
    printf("호출 직전...\n");
    ConnectNamedPipe(pipe, nullptr);  // ← 먼저 호출 (블로킹)
    waiting = true;  // ← 블로킹 진입 후 플래그 설정
    printf("호출됨\n");
};
```

**결과:**
- Audio 스레드 시작 → ConnectNamedPipe 호출 직전까지 도달
- **ConnectNamedPipe 호출 시점에 앱 크래시** ❌
- FFmpeg 로그 없음 (FFmpeg 시작 전에 크래시)

---

## 코드 상세

### Named Pipe 생성
```cpp
video_pipe_ = CreateNamedPipeW(
    L"\\\\.\\pipe\\sat_lec_rec_3124_1626265156_video",
    PIPE_ACCESS_OUTBOUND,  // Server writes, Client reads
    PIPE_TYPE_BYTE | PIPE_WAIT,
    1,  // nMaxInstances
    4 * 1024 * 1024,  // Buffer 4MB
    4 * 1024 * 1024,
    0,
    nullptr);

audio_pipe_ = CreateNamedPipeW(
    L"\\\\.\\pipe\\sat_lec_rec_3124_1626265156_audio",
    PIPE_ACCESS_OUTBOUND,
    PIPE_TYPE_BYTE | PIPE_WAIT,
    1,  // nMaxInstances
    512 * 1024,  // Buffer 512KB
    512 * 1024,
    0,
    nullptr);
```

**검증:**
- CreateNamedPipeW 반환값: 유효한 핸들 (INVALID_HANDLE_VALUE 아님) ✅
- 생성 로그: 두 파이프 모두 성공 ✅

### FFmpeg 명령어
```bash
"C:\...\ffmpeg.exe" \
  -hide_banner -loglevel verbose -report -y \
  -thread_queue_size 1024 \
  -f f32le -ar 48000 -ac 2 \
  -i "\\.\pipe\sat_lec_rec_3124_1626265156_audio" \
  -thread_queue_size 1024 \
  -f rawvideo -pix_fmt bgra -s 1920x1080 -r 24 \
  -i "\\.\pipe\sat_lec_rec_3124_1626265156_video" \
  -vf vflip -c:v libx264 -preset veryfast -crf 23 \
  -c:a aac -b:a 192k \
  -movflags +frag_keyframe+empty_moov+separate_moof+omit_tfhd_offset \
  "C:\SatLecRec\recordings\20251103_2017_test.mp4"
```

**검증:**
- FFmpeg 프로세스 시작: 성공 (시도 1-4) ✅
- Audio 입력 파싱: 성공 ✅
- Video 입력 파싱: 실패 (No such file or directory) ❌

### 최신 크래시 로그 (시도 5)
```
[C++] ✅ 비디오 파이프 생성 성공: \\.\pipe\sat_lec_rec_3124_1626265156_video
[C++] ✅ 오디오 파이프 생성 성공: \\.\pipe\sat_lec_rec_3124_1626265156_audio
[C++] Step 1: Audio 스레드 생성 중...
[C++] Step 1: Audio ConnectNamedPipe 호출 대기 중...
[C++] [Audio] 스레드 시작, ConnectNamedPipe 호출 직전...
Lost connection to device.  ← 크래시!
```

---

## 질문

### 1. 왜 Audio는 성공하고 Video는 실패할까요?
- 두 파이프는 완전히 동일한 방식으로 생성됨
- CreateNamedPipeW 파라미터 동일 (버퍼 크기만 다름)
- FFmpeg 명령어에서 순서만 다름 (Audio 먼저, Video 나중)

### 2. FFmpeg가 "파이프를 찾을 수 없다"는 이유?
- C++ 로그: Video ConnectNamedPipe가 **대기 중**임을 확인
- FFmpeg 로그: Video 파이프를 **찾을 수 없음**
- 파이프 이름은 정확히 일치함 (로그 확인됨)

### 3. 시도 5에서 ConnectNamedPipe 호출 시 크래시가 발생하는 이유?
- 이전 시도들에서는 ConnectNamedPipe 호출 자체는 성공했음
- 코드 수정 후 ConnectNamedPipe 호출 순간 크래시
- 변경사항: `waiting=true` 설정 시점을 ConnectNamedPipe **이후**로 이동

### 4. Named Pipe 대신 다른 방법을 써야 할까요?
- stdin/stdout 파이프
- 임시 파일 (성능 문제)
- Media Foundation API 직접 사용 (FFmpeg 없이)
- NUT 컨테이너로 Audio+Video pre-mux 후 단일 파이프 사용

---

## 참고 자료

### 확인된 사실
1. ✅ WASAPI Audio 캡처: 정상 작동 (48kHz stereo Float32)
2. ✅ DXGI Video 캡처: 정상 작동 (1920x1080 @ 24fps BGRA)
3. ✅ CreateNamedPipeW: 두 파이프 모두 생성 성공
4. ✅ FFmpeg 프로세스: 시작 성공 (시도 1-4)
5. ✅ Audio 파이프 연결: 항상 성공
6. ❌ Video 파이프 연결: 항상 실패

### 검색으로 찾은 유사 사례
- [OBS Studio](https://github.com/obsproject/obs-studio): NUT 컨테이너 사용 (단일 파이프)
- [Mathew Sachin 블로그](https://mathewsachin.github.io/blog/2017/09/27/ffmpeg-pipe-multiple-inputs.html): "FFmpeg reads all inputs sequentially"
- [Stack Overflow #50594281](https://stackoverflow.com/questions/50594281/): Named Pipe 타이밍 이슈

---

## 요청사항

**다음 중 어느 방향이 올바른 해결책일까요?**

A. Named Pipe 방식 계속 디버깅 (구체적인 수정 방향 제시 필요)
B. 단일 파이프 + NUT pre-muxing 방식으로 전환
C. stdin/stdout 파이프 방식으로 전환
D. Media Foundation API로 FFmpeg 없이 구현
E. 기타 (구체적인 제안)

특히 **시도 5에서 ConnectNamedPipe 호출 시 크래시가 발생하는 원인**과 **Video 파이프만 실패하는 이유**에 대한 근본적인 원인 분석이 필요합니다.
