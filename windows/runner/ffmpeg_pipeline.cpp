// FFmpeg 프로세스를 Named Pipe로 연결해 화면·오디오 데이터를 파일로 저장하는 헬퍼 클래스 정의부

#include "ffmpeg_pipeline.h"

#include <algorithm>
#include <filesystem>
#include <sstream>
#include <vector>

namespace {
constexpr DWORD kPipeBufferSizeVideo = 4 * 1024 * 1024;   // 비디오 파이프 버퍼 4MB
constexpr DWORD kPipeBufferSizeAudio = 512 * 1024;        // 오디오 파이프 버퍼 512KB
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
    return false;
  }

  if (!LaunchProcess()) {
    CloseHandles();
    return false;
  }

  if (!ConnectPipes()) {
    Stop(true);
    return false;
  }

  is_running_ = true;
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
  if (!is_running_ || audio_pipe_ == INVALID_HANDLE_VALUE) {
    SetLastError("오디오 파이프가 준비되지 않았습니다.");
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
  }

  CloseHandles();
  is_running_ = false;
}

// 입력: 없음 (내부 상태 이용)
// 출력: Named Pipe 생성 성공 여부
// 예외: 실패 시 last_error_에 메시지 기록
bool FFmpegPipeline::CreateNamedPipes() {
  video_pipe_name_ = GeneratePipeName(L"video");
  audio_pipe_name_ = GeneratePipeName(L"audio");

  video_pipe_ = CreateNamedPipeW(
      video_pipe_name_.c_str(),
      PIPE_ACCESS_OUTBOUND,
      PIPE_TYPE_BYTE | PIPE_WAIT,
      1,
      kPipeBufferSizeVideo,
      kPipeBufferSizeVideo,
      0,
      nullptr);

  if (video_pipe_ == INVALID_HANDLE_VALUE) {
    SetLastError("비디오 파이프 생성에 실패했습니다.");
    return false;
  }

  audio_pipe_ = CreateNamedPipeW(
      audio_pipe_name_.c_str(),
      PIPE_ACCESS_OUTBOUND,
      PIPE_TYPE_BYTE | PIPE_WAIT,
      1,
      kPipeBufferSizeAudio,
      kPipeBufferSizeAudio,
      0,
      nullptr);

  if (audio_pipe_ == INVALID_HANDLE_VALUE) {
    SetLastError("오디오 파이프 생성에 실패했습니다.");
    if (video_pipe_ != INVALID_HANDLE_VALUE) {
      CloseHandle(video_pipe_);
      video_pipe_ = INVALID_HANDLE_VALUE;
    }
    return false;
  }

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
    SetLastError("FFmpeg 프로세스를 시작하지 못했습니다.");
    return false;
  }

  return true;
}

// 입력: 없음 (파이프 핸들 사용)
// 출력: FFmpeg가 파이프에 연결되었는지 여부
// 예외: 실패 시 last_error_에 메시지 기록
bool FFmpegPipeline::ConnectPipes() {
  auto wait_for_pipe = [](HANDLE pipe) {
    BOOL connected = ConnectNamedPipe(pipe, nullptr);
    if (!connected) {
      DWORD err = GetLastError();
      if (err == ERROR_PIPE_CONNECTED) {
        return TRUE;
      }
      return FALSE;
    }
    return TRUE;
  };

  if (!wait_for_pipe(video_pipe_)) {
    SetLastError("FFmpeg가 비디오 파이프에 연결하지 못했습니다.");
    return false;
  }
  if (!wait_for_pipe(audio_pipe_)) {
    SetLastError("FFmpeg가 오디오 파이프에 연결하지 못했습니다.");
    return false;
  }
  return true;
}

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
  oss << L'"' << ffmpeg_path << L""";
  oss << L" -hide_banner -loglevel warning -y";
  oss << L" -f rawvideo -pix_fmt bgra -vf vflip";
  oss << L" -s " << config_.video_width << L"x" << config_.video_height;
  oss << L" -r " << config_.video_fps;
  oss << L" -i \"" << video_pipe_name_ << L"\"";
  oss << L" -f f32le -ar " << config_.audio_sample_rate;
  oss << L" -ac " << config_.audio_channels;
  oss << L" -i \"" << audio_pipe_name_ << L"\"";
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

  oss << L" " << L'"' << config_.output_path << L'"';

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
      if (error == ERROR_NO_DATA) {
        SetLastError(std::string(label) + " 파이프가 닫혔습니다.");
      } else {
        SetLastError(std::string(label) + " 파이프에 데이터를 쓰지 못했습니다.");
      }
      return false;
    }
    total_written += chunk;
  }
  return true;
}
