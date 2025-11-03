// FFmpeg 프로세스를 Named Pipe로 연결해 화면·오디오 데이터를 파일로 저장하는 헬퍼 클래스 정의부

#include "ffmpeg_pipeline.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <filesystem>
#include <sstream>
#include <thread>
#include <vector>
#include <windows.h>

namespace {
constexpr DWORD kPipeBufferSizeVideo = 4 * 1024 * 1024;   // 비디오 파이프 버퍼 4MB
constexpr DWORD kPipeBufferSizeAudio = 512 * 1024;        // 오디오 파이프 버퍼 512KB

std::string WideToUtf8(const std::wstring& src) {
  if (src.empty()) {
    return {};
  }

  int utf8_length = WideCharToMultiByte(
      CP_UTF8,
      0,
      src.c_str(),
      static_cast<int>(src.size()),
      nullptr,
      0,
      nullptr,
      nullptr);

  if (utf8_length <= 0) {
    return {};
  }

  std::string result(utf8_length, '\0');
  WideCharToMultiByte(
      CP_UTF8,
      0,
      src.c_str(),
      static_cast<int>(src.size()),
      result.data(),
      utf8_length,
      nullptr,
      nullptr);
  return result;
}
}  // namespace

// 입력: 없음
// 출력: 파이프 핸들을 초기화한 객체
// 예외: 없음
FFmpegPipeline::FFmpegPipeline() {
  ZeroMemory(&process_info_, sizeof(process_info_));
}

// 입력: 없음
// 출력: 자원 정리 수행
// 예외: 없음
FFmpegPipeline::~FFmpegPipeline() {
  Stop(true);
}

// 입력: config - FFmpeg 실행 옵션 묶음
// 출력: 실행 성공 여부(true/false)
// 예외: Windows API 실패 시 false, last_error_에 메시지 저장
bool FFmpegPipeline::Start(const FFmpegLaunchConfig& config) {
  Stop();  // 이전 실행이 남아있다면 정리

  config_ = config;
  if (config_.video_width <= 0 || config_.video_height <= 0 || config_.video_fps <= 0) {
    SetLastError("잘못된 비디오 설정입니다.");
    return false;
  }

  if (!CreateNamedPipes()) {
    printf("[C++] ❌ Named pipe creation failed: %s\n", last_error_.c_str());
    fflush(stdout);
    return false;
  }

  printf("[C++] video pipe name: %s\n", WideToUtf8(video_pipe_name_).c_str());
  printf("[C++] audio pipe name: %s\n", WideToUtf8(audio_pipe_name_).c_str());
  fflush(stdout);

  // ============================================
  // 검증된 패턴: 별도 스레드에서 동기 ConnectNamedPipe 사용
  // ============================================
  printf("[C++] =================================\n");
  printf("[C++] 스레드 기반 파이프 연결 시작 (검증된 패턴)\n");
  printf("[C++] =================================\n");
  fflush(stdout);

  // 연결 상태 변수
  std::atomic<bool> audio_connected{false};
  std::atomic<bool> video_connected{false};
  std::atomic<bool> audio_failed{false};
  std::atomic<bool> video_failed{false};
  std::atomic<bool> audio_waiting{false};  // ConnectNamedPipe 호출 완료 플래그
  std::atomic<bool> video_waiting{false};  // ConnectNamedPipe 호출 완료 플래그
  DWORD audio_error = ERROR_SUCCESS;
  DWORD video_error = ERROR_SUCCESS;

  // Audio 연결 스레드 (동기 ConnectNamedPipe - 블로킹)
  std::thread audio_thread([&]() {
    printf("[C++] [Audio] ConnectNamedPipe 스레드 시작...\n");
    fflush(stdout);
    printf("[C++] [Audio] ConnectNamedPipe 호출 직전...\n");
    fflush(stdout);
    audio_waiting.store(true, std::memory_order_release);  // 호출 직전 알림
    printf("[C++] [Audio] ConnectNamedPipe 호출 (블로킹 대기)...\n");
    fflush(stdout);
    BOOL connected = ConnectNamedPipe(audio_pipe_, nullptr);  // 동기 모드 - 블로킹
    DWORD err = GetLastError();
    printf("[C++] [Audio] ConnectNamedPipe 반환: connected=%d, err=%lu\n", connected, err);
    fflush(stdout);
    if (connected || err == ERROR_PIPE_CONNECTED) {
      audio_connected.store(true, std::memory_order_release);
      audio_error = ERROR_SUCCESS;
      printf("[C++] ✅ [Audio] 파이프 연결 성공\n");
    } else {
      audio_failed.store(true, std::memory_order_release);
      audio_error = err;
      printf("[C++] ❌ [Audio] 파이프 연결 실패: err=%lu\n", err);
    }
    fflush(stdout);
  });

  // Video 연결 스레드 (동기 ConnectNamedPipe - 블로킹)
  std::thread video_thread([&]() {
    printf("[C++] [Video] ConnectNamedPipe 스레드 시작...\n");
    fflush(stdout);
    printf("[C++] [Video] ConnectNamedPipe 호출 직전...\n");
    fflush(stdout);
    video_waiting.store(true, std::memory_order_release);  // 호출 직전 알림
    printf("[C++] [Video] ConnectNamedPipe 호출 (블로킹 대기)...\n");
    fflush(stdout);
    BOOL connected = ConnectNamedPipe(video_pipe_, nullptr);  // 동기 모드 - 블로킹
    DWORD err = GetLastError();
    printf("[C++] [Video] ConnectNamedPipe 반환: connected=%d, err=%lu\n", connected, err);
    fflush(stdout);
    if (connected || err == ERROR_PIPE_CONNECTED) {
      video_connected.store(true, std::memory_order_release);
      video_error = ERROR_SUCCESS;
      printf("[C++] ✅ [Video] 파이프 연결 성공\n");
    } else {
      video_failed.store(true, std::memory_order_release);
      video_error = err;
      printf("[C++] ❌ [Video] 파이프 연결 실패: err=%lu\n", err);
    }
    fflush(stdout);
  });

  // 두 스레드가 ConnectNamedPipe를 호출할 때까지 대기 (블로킹 상태 확인)
  printf("[C++] 두 ConnectNamedPipe 호출 완료 대기...\n");
  fflush(stdout);
  while (!audio_waiting.load(std::memory_order_acquire) || !video_waiting.load(std::memory_order_acquire)) {
    Sleep(1);
  }
  printf("[C++] ✅ 두 ConnectNamedPipe 모두 호출 완료 (블로킹 상태)\n");
  fflush(stdout);
  
  // 안정화 대기
  Sleep(200);

  // Step 3: FFmpeg 프로세스 시작 (두 파이프 모두 ConnectNamedPipe 대기 중)
  printf("[C++] Step 3: FFmpeg 프로세스 시작 (파이프 연결 대기 중)...\n");
  fflush(stdout);

  if (!LaunchProcess()) {
    printf("[C++] ❌ FFmpeg 프로세스 실행 실패: %s\n", last_error_.c_str());
    fflush(stdout);
    DisconnectNamedPipe(audio_pipe_);
    DisconnectNamedPipe(video_pipe_);
    if (audio_thread.joinable()) audio_thread.join();
    if (video_thread.joinable()) video_thread.join();
    CloseHandles();
    return false;
  }

  // Step 4: FFmpeg 프로세스 시작 검증
  printf("[C++] Step 4: FFmpeg 프로세스 시작 검증...\n");
  fflush(stdout);

  if (process_info_.hProcess == nullptr) {
    printf("[C++] ❌ FFmpeg 프로세스 핸들이 유효하지 않음\n");
    fflush(stdout);
    SetLastError("FFmpeg 프로세스 핸들 유효성 검사 실패");
    DisconnectNamedPipe(audio_pipe_);
    DisconnectNamedPipe(video_pipe_);
    if (audio_thread.joinable()) audio_thread.join();
    if (video_thread.joinable()) video_thread.join();
    CloseHandles();
    return false;
  }

  // Step 5: 두 파이프 모두 연결 완료 대기
  printf("[C++] Step 5: 두 파이프 연결 완료 대기 (타임아웃 10초)...\n");
  fflush(stdout);

  // Audio 연결 완료 대기
  auto audio_start = std::chrono::steady_clock::now();
  while (!audio_connected.load(std::memory_order_acquire) && 
         !audio_failed.load(std::memory_order_acquire)) {
    auto elapsed = std::chrono::steady_clock::now() - audio_start;
    if (std::chrono::duration_cast<std::chrono::seconds>(elapsed).count() >= 10) {
      printf("[C++] ❌ [Audio] 파이프 연결 타임아웃 (10초)\n");
      fflush(stdout);
      DisconnectNamedPipe(audio_pipe_);
      DisconnectNamedPipe(video_pipe_);
      if (audio_thread.joinable()) audio_thread.join();
      if (video_thread.joinable()) video_thread.join();
      CloseHandles();
      SetLastError("오디오 파이프 연결 타임아웃");
      return false;
    }
    
    // FFmpeg 프로세스 상태 확인
    DWORD exit_code = 0;
    if (GetExitCodeProcess(process_info_.hProcess, &exit_code) && exit_code != STILL_ACTIVE) {
      printf("[C++] ❌ FFmpeg 프로세스가 Audio 파이프 연결 대기 중 종료됨 (exit_code=%lu)\n", exit_code);
      printf("[C++] 💡 FFmpeg 로그 파일을 확인하세요: C:\\ws-workspace\\sat-lec-rec\\ffmpeg-*.log\n");
      fflush(stdout);
      DisconnectNamedPipe(audio_pipe_);
      DisconnectNamedPipe(video_pipe_);
      if (audio_thread.joinable()) audio_thread.join();
      if (video_thread.joinable()) video_thread.join();
      CloseHandles();
      SetLastError("FFmpeg 프로세스가 Audio 파이프 연결 대기 중 종료됨. 코드: " + std::to_string(exit_code));
      return false;
    }
    
    Sleep(10);
  }

  // Video 연결 완료 대기
  auto video_start = std::chrono::steady_clock::now();
  while (!video_connected.load(std::memory_order_acquire) && 
         !video_failed.load(std::memory_order_acquire)) {
    auto elapsed = std::chrono::steady_clock::now() - video_start;
    if (std::chrono::duration_cast<std::chrono::seconds>(elapsed).count() >= 10) {
      printf("[C++] ❌ [Video] 파이프 연결 타임아웃 (10초)\n");
      printf("[C++] 💡 FFmpeg 로그 파일을 확인하세요: C:\\ws-workspace\\sat-lec-rec\\ffmpeg-*.log\n");
      fflush(stdout);
      DisconnectNamedPipe(video_pipe_);
      if (audio_thread.joinable()) audio_thread.join();
      if (video_thread.joinable()) video_thread.join();
      CloseHandles();
      SetLastError("비디오 파이프 연결 타임아웃");
      return false;
    }
    
    // FFmpeg 프로세스 상태 확인
    DWORD exit_code = 0;
    if (GetExitCodeProcess(process_info_.hProcess, &exit_code) && exit_code != STILL_ACTIVE) {
      printf("[C++] ❌ FFmpeg 프로세스가 Video 파이프 연결 대기 중 종료됨 (exit_code=%lu)\n", exit_code);
      printf("[C++] 💡 FFmpeg 로그 파일을 확인하세요: C:\\ws-workspace\\sat-lec-rec\\ffmpeg-*.log\n");
      fflush(stdout);
      DisconnectNamedPipe(video_pipe_);
      if (audio_thread.joinable()) audio_thread.join();
      if (video_thread.joinable()) video_thread.join();
      CloseHandles();
      SetLastError("FFmpeg 프로세스가 Video 파이프 연결 대기 중 종료됨. 코드: " + std::to_string(exit_code));
      return false;
    }
    
    Sleep(10);
  }

  // 스레드 종료 대기
  if (audio_thread.joinable()) audio_thread.join();
  if (video_thread.joinable()) video_thread.join();

  // 연결 결과 확인
  if (audio_failed.load(std::memory_order_acquire)) {
    printf("[C++] ❌ [Audio] 파이프 연결 실패: err=%lu\n", audio_error);
    fflush(stdout);
    SetLastError("오디오 파이프 연결 실패. 코드: " + std::to_string(audio_error));
    DisconnectNamedPipe(video_pipe_);
    CloseHandles();
    return false;
  }

  if (video_failed.load(std::memory_order_acquire)) {
    printf("[C++] ❌ [Video] 파이프 연결 실패: err=%lu\n", video_error);
    fflush(stdout);
    SetLastError("비디오 파이프 연결 실패. 코드: " + std::to_string(video_error));
    DisconnectNamedPipe(audio_pipe_);
    CloseHandles();
    return false;
  }

  printf("[C++] ✅ 두 파이프 모두 연결 완료\n");
  fflush(stdout);
  printf("[C++] =================================\n");
  fflush(stdout);

  is_running_ = true;
  printf("[C++] ✅ FFmpeg 파이프라인 시작 (video pipe: %s, audio pipe: %s)\n",
         WideToUtf8(video_pipe_name_).c_str(),
         WideToUtf8(audio_pipe_name_).c_str());
  fflush(stdout);
  return true;
}

// 입력: data - 비디오 프레임 바이트 배열, length - 배열 크기
// 출력: 쓰기 성공 여부(true/false)
// 예외: 파이프 오류 시 false 반환
bool FFmpegPipeline::WriteVideo(const uint8_t* data, size_t length) {
  if (!is_running_ || video_pipe_ == INVALID_HANDLE_VALUE) {
    SetLastError("비디오 파이프가 준비되지 않았습니다.");
    return false;
  }
  return WriteToPipe(video_pipe_, data, length, "video");
}

// 입력: data - 오디오 샘플 바이트 배열, length - 배열 크기
// 출력: 쓰기 성공 여부(true/false)
// 예외: 파이프 오류 시 false 반환
bool FFmpegPipeline::WriteAudio(const uint8_t* data, size_t length) {
  if (!is_running_) {
    SetLastError("FFmpeg 파이프라인이 실행 중이 아닙니다.");
    printf("[C++] ❌ WriteAudio 실패: 파이프라인 미실행\n");
    fflush(stdout);
    return false;
  }
  if (audio_pipe_ == INVALID_HANDLE_VALUE) {
    SetLastError("오디오 파이프 핸들이 유효하지 않습니다.");
    printf("[C++] ❌ WriteAudio 실패: audio_pipe_ = INVALID_HANDLE_VALUE\n");
    fflush(stdout);
    return false;
  }
  return WriteToPipe(audio_pipe_, data, length, "audio");
}

// 입력: force_kill - FFmpeg 종료가 늦어질 때 강제로 종료할지 여부
// 출력: 없음
// 예외: 없음 (오류 시 내부적으로 로그 문자열만 기록)
void FFmpegPipeline::Stop(bool force_kill) {
  if (video_pipe_ != INVALID_HANDLE_VALUE) {
    FlushFileBuffers(video_pipe_);
    DisconnectNamedPipe(video_pipe_);
  }
  if (audio_pipe_ != INVALID_HANDLE_VALUE) {
    FlushFileBuffers(audio_pipe_);
    DisconnectNamedPipe(audio_pipe_);
  }

  if (process_info_.hProcess != nullptr) {
    DWORD wait_result = WaitForSingleObject(process_info_.hProcess, 5000);
    if (wait_result != WAIT_OBJECT_0 && force_kill) {
      TerminateProcess(process_info_.hProcess, 1);
      WaitForSingleObject(process_info_.hProcess, 2000);
    }

    DWORD exit_code = 0;
    if (GetExitCodeProcess(process_info_.hProcess, &exit_code)) {
      printf("[C++] FFmpeg 프로세스 종료 코드: %lu\n", exit_code);
      fflush(stdout);
    }
  }

  CloseHandles();
  is_running_ = false;
}

// 입력: 없음 (내부 상태 이용)
// 출력: Named Pipe 생성 성공 여부
// 예외: 실패 시 last_error_에 메시지 기록
bool FFmpegPipeline::CreateNamedPipes() {
  // 파이프 이름을 동일한 tick 값으로 생성 (타이밍 이슈 방지)
  DWORD pid = GetCurrentProcessId();
  ULONGLONG tick = GetTickCount64();

  std::wostringstream video_oss;
  video_oss << L"\\\\.\\pipe\\sat_lec_rec_" << pid << L"_" << tick << L"_video";
  video_pipe_name_ = video_oss.str();

  std::wostringstream audio_oss;
  audio_oss << L"\\\\.\\pipe\\sat_lec_rec_" << pid << L"_" << tick << L"_audio";
  audio_pipe_name_ = audio_oss.str();

  video_pipe_ = CreateNamedPipeW(
      video_pipe_name_.c_str(),
      PIPE_ACCESS_OUTBOUND,  // 동기 모드
      PIPE_TYPE_BYTE | PIPE_WAIT,
      1,  // nMaxInstances = 1 (순차 연결 방식)
      kPipeBufferSizeVideo,
      kPipeBufferSizeVideo,
      0,
      nullptr);

  if (video_pipe_ == INVALID_HANDLE_VALUE) {
    DWORD err = GetLastError();
    printf("[C++] ❌ 비디오 파이프 생성 실패: %s (err=%lu)\n", WideToUtf8(video_pipe_name_).c_str(), err);
    fflush(stdout);
    SetLastError("비디오 파이프 생성에 실패했습니다. 코드: " + std::to_string(err));
    return false;
  }
  printf("[C++] ✅ 비디오 파이프 생성 성공: %s\n", WideToUtf8(video_pipe_name_).c_str());
  fflush(stdout);

  audio_pipe_ = CreateNamedPipeW(
      audio_pipe_name_.c_str(),
      PIPE_ACCESS_OUTBOUND,  // 동기 모드
      PIPE_TYPE_BYTE | PIPE_WAIT,
      1,  // nMaxInstances = 1 (순차 연결 방식)
      kPipeBufferSizeAudio,
      kPipeBufferSizeAudio,
      0,
      nullptr);

  if (audio_pipe_ == INVALID_HANDLE_VALUE) {
    DWORD err = GetLastError();
    printf("[C++] ❌ 오디오 파이프 생성 실패: %s (err=%lu)\n", WideToUtf8(audio_pipe_name_).c_str(), err);
    fflush(stdout);
    SetLastError("오디오 파이프 생성에 실패했습니다. 코드: " + std::to_string(err));
    if (video_pipe_ != INVALID_HANDLE_VALUE) {
      CloseHandle(video_pipe_);
      video_pipe_ = INVALID_HANDLE_VALUE;
    }
    return false;
  }
  printf("[C++] ✅ 오디오 파이프 생성 성공: %s\n", WideToUtf8(audio_pipe_name_).c_str());
  fflush(stdout);

  // CreateNamedPipeW 성공 = 파이프 유효함
  // GetNamedPipeInfo는 OVERLAPPED 파이프에서 ERROR_ACCESS_DENIED를 반환할 수 있으므로
  // 불필요한 검증을 제거하고 바로 ConnectNamedPipe 단계로 진행
  printf("[C++] ✅ 두 파이프 모두 생성 완료, ConnectNamedPipe 대기 시작\n");
  fflush(stdout);

  return true;
}

// 입력: 없음 (config_와 파이프 이름 사용)
// 출력: FFmpeg 프로세스 실행 성공 여부
// 예외: 실패 시 last_error_에 메시지 기록
bool FFmpegPipeline::LaunchProcess() {
  std::wstring ffmpeg_path = config_.ffmpeg_path.empty() ? ResolveFFmpegPath() : config_.ffmpeg_path;
  if (ffmpeg_path.empty()) {
    SetLastError("ffmpeg.exe 경로를 찾을 수 없습니다.");
    return false;
  }

  std::wstring command_line = BuildCommandLine(ffmpeg_path);
  if (command_line.empty()) {
    SetLastError("FFmpeg 명령어 구성이 잘못되었습니다.");
    return false;
  }

  printf("[C++] ========================================\n");
  printf("[C++] FFmpeg 설정 정보:\n");
  printf("[C++] FFmpeg 경로: %s\n", WideToUtf8(ffmpeg_path).c_str());
  printf("[C++] 비디오 파이프: %s\n", WideToUtf8(video_pipe_name_).c_str());
  printf("[C++] 오디오 파이프: %s\n", WideToUtf8(audio_pipe_name_).c_str());
  printf("[C++] 출력 경로: %s\n", WideToUtf8(config_.output_path).c_str());
  printf("[C++] 비디오: %dx%d @ %dfps\n", config_.video_width, config_.video_height, config_.video_fps);
  printf("[C++] 오디오: %dHz, %dch\n", config_.audio_sample_rate, config_.audio_channels);
  printf("[C++] ========================================\n");
  printf("[C++] FFmpeg 전체 명령:\n%s\n", WideToUtf8(command_line).c_str());
  printf("[C++] ========================================\n");
  fflush(stdout);

  STARTUPINFOW startup_info;
  ZeroMemory(&startup_info, sizeof(startup_info));
  startup_info.cb = sizeof(startup_info);

  std::vector<wchar_t> command_buffer(command_line.begin(), command_line.end());
  command_buffer.push_back(L'\0');

  BOOL created = CreateProcessW(
      nullptr,
      command_buffer.data(),
      nullptr,
      nullptr,
      FALSE,
      CREATE_NO_WINDOW,
      nullptr,
      nullptr,
      &startup_info,
      &process_info_);

  if (!created) {
    DWORD err = GetLastError();
    SetLastError("FFmpeg 프로세스를 시작하지 못했습니다. 코드: " + std::to_string(err));
    return false;
  }

  return true;
}

// 입력: 없음 (파이프 핸들 사용)
// 출력: FFmpeg가 파이프에 연결되었는지 여부
// 예외: 실패 시 last_error_에 메시지 기록
// 입력: 없음 (현재 프로세스 위치 기반)
// 출력: 탐색된 ffmpeg.exe 절대 경로
// 예외: 없음 (찾지 못하면 빈 문자열 반환)
std::wstring FFmpegPipeline::ResolveFFmpegPath() const {
  wchar_t module_path[MAX_PATH];
  DWORD length = GetModuleFileNameW(nullptr, module_path, MAX_PATH);
  if (length == 0) {
    return L"";
  }

  std::filesystem::path current_path(module_path);
  std::filesystem::path search_path = current_path.parent_path();

  for (int i = 0; i < 6; ++i) {
    std::filesystem::path candidate = search_path / L"third_party" / L"ffmpeg" / L"ffmpeg.exe";
    if (std::filesystem::exists(candidate)) {
      return candidate.wstring();
    }
    if (search_path.has_parent_path()) {
      search_path = search_path.parent_path();
    }
  }

  return L"";
}

// 입력: ffmpeg_path - 실행 파일 경로
// 출력: FFmpeg 실행을 위한 전체 명령줄 문자열
// 예외: 없음 (구성 실패 시 빈 문자열 반환)
std::wstring FFmpegPipeline::BuildCommandLine(const std::wstring& ffmpeg_path) const {
  std::wostringstream oss;
  oss << L"\"" << ffmpeg_path << L"\"";
  oss << L" -hide_banner -loglevel verbose -report -y";

  // Audio 입력 먼저 (순차 처리 문제 우회)
  oss << L" -thread_queue_size 1024";
  oss << L" -f f32le -ar " << config_.audio_sample_rate;
  oss << L" -ac " << config_.audio_channels;
  oss << L" -i " << audio_pipe_name_;  // 따옴표 제거

  // Video 입력 나중에
  oss << L" -thread_queue_size 1024";
  oss << L" -f rawvideo -pix_fmt bgra";
  oss << L" -s " << config_.video_width << L"x" << config_.video_height;
  oss << L" -r " << config_.video_fps;
  oss << L" -i " << video_pipe_name_;  // 따옴표 제거

  oss << L" -vf vflip";
  oss << L" -c:v libx264 -preset veryfast -crf 23";
  oss << L" -c:a aac -b:a 192k";

  if (config_.enable_fragmented_mp4) {
    oss << L" -movflags +frag_keyframe+empty_moov+separate_moof+omit_tfhd_offset";
  }

  if (config_.enable_segment) {
    oss << L" -f segment -segment_time " << config_.segment_seconds;
    oss << L" -segment_format_options movflags=frag_keyframe+empty_moov";
    oss << L" -reset_timestamps 1";
  }

  oss << L" \"" << config_.output_path << L"\"";

  return oss.str();
}

// 입력: 없음
// 출력: 내부 핸들 모두 해제
// 예외: 없음
void FFmpegPipeline::CloseHandles() {
  if (video_pipe_ != INVALID_HANDLE_VALUE) {
    CloseHandle(video_pipe_);
    video_pipe_ = INVALID_HANDLE_VALUE;
  }
  if (audio_pipe_ != INVALID_HANDLE_VALUE) {
    CloseHandle(audio_pipe_);
    audio_pipe_ = INVALID_HANDLE_VALUE;
  }
  if (process_info_.hThread != nullptr) {
    CloseHandle(process_info_.hThread);
    process_info_.hThread = nullptr;
  }
  if (process_info_.hProcess != nullptr) {
    CloseHandle(process_info_.hProcess);
    process_info_.hProcess = nullptr;
  }
}

// 입력: message - 에러 설명 문자열
// 출력: 없음 (last_error_ 업데이트)
// 예외: 없음
void FFmpegPipeline::SetLastError(const std::string& message) {
  last_error_ = message;
}

// 입력: suffix - 파이프 이름 뒤에 붙일 식별자
// 출력: 고유한 Named Pipe 이름 문자열
// 예외: 없음
std::wstring FFmpegPipeline::GeneratePipeName(const wchar_t* suffix) const {
  DWORD pid = GetCurrentProcessId();
  ULONGLONG tick = GetTickCount64();
  std::wostringstream oss;
  oss << L"\\\\.\\pipe\\sat_lec_rec_" << pid << L"_" << tick << L"_" << suffix;
  return oss.str();
}

// 입력: pipe - 쓰기 대상 파이프 핸들, data - 전송할 바이트 배열, length - 배열 크기, label - 로그용 라벨
// 출력: 쓰기 성공 여부(true/false)
// 예외: WriteFile 실패 시 false 반환
bool FFmpegPipeline::WriteToPipe(HANDLE pipe, const uint8_t* data, size_t length, const char* label) {
  size_t total_written = 0;
  while (total_written < length) {
    DWORD chunk = 0;
    DWORD to_write = static_cast<DWORD>(
        std::min<size_t>(length - total_written, static_cast<size_t>(64 * 1024)));
    BOOL success = WriteFile(pipe, data + total_written, to_write, &chunk, nullptr);
    if (!success || chunk == 0) {
      DWORD error = GetLastError();
      std::string message = std::string(label) + " 파이프에 데이터를 쓰지 못했습니다. 코드: " + std::to_string(error);
      if (error == ERROR_NO_DATA) {
        message += " (파이프가 닫혔습니다)";
      }
      SetLastError(message);
      printf("[C++] ❌ %s\n", message.c_str());
      fflush(stdout);
      return false;
    }
    total_written += chunk;
  }
  return true;
}

