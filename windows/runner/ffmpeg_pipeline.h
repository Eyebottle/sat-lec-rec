// FFmpeg 프로세스를 Named Pipe로 연결해 화면·오디오 데이터를 파일로 저장하는 헬퍼 클래스 선언부

#ifndef SAT_LEC_REC_FFMPEG_PIPELINE_H_
#define SAT_LEC_REC_FFMPEG_PIPELINE_H_

#include <windows.h>

#include <cstddef>
#include <cstdint>
#include <string>

// 입력: FFmpeg 실행 옵션(출력 경로, 해상도, 프레임레이트 등)
// 출력: FFmpeg 프로세스를 켜고 끄는 제어 함수 제공
// 예외: 내부적으로 std::bad_alloc 같은 예외가 날 수 있으므로 호출부에서 bool 반환값을 확인해야 한다.
struct FFmpegLaunchConfig {
  std::wstring output_path;   // 최종 출력 파일 경로 (.recording 포함 가능)
  std::wstring ffmpeg_path;   // FFmpeg 실행 파일 경로 (비워두면 자동 탐색)
  int video_width = 1920;     // 비디오 가로 해상도
  int video_height = 1080;    // 비디오 세로 해상도
  int video_fps = 24;         // 비디오 프레임레이트
  int audio_sample_rate = 48000;  // 오디오 샘플레이트 (video_only일 때는 미사용)
  int audio_channels = 2;         // 오디오 채널 수 (video_only일 때는 미사용)
  bool enable_fragmented_mp4 = true;  // movflags 설정 여부
  bool enable_segment = false;        // 세그먼트 저장 여부
  int segment_seconds = 2700;         // 세그먼트 길이 (초)
  bool video_only = true;             // true: Video만 인코딩, false: Audio+Video
};

// 입력: FFmpegLaunchConfig, WriteVideo/WriteAudio의 바이트 배열
// 출력: FFmpeg 프로세스 실행 및 Named Pipe 쓰기 성공 여부(bool)
// 예외: Windows API 호출 실패 시 false, last_error()로 원인 메시지 확인
class FFmpegPipeline {
 public:
  FFmpegPipeline();
  ~FFmpegPipeline();

  bool Start(const FFmpegLaunchConfig& config);
  bool WriteVideo(const uint8_t* data, size_t length);
  bool WriteAudio(const uint8_t* data, size_t length);
  void Stop(bool force_kill = false);
  bool IsRunning() const { return is_running_; }
  std::string last_error() const { return last_error_; }

 private:
  bool CreateNamedPipes();
  bool LaunchProcess();
  std::wstring ResolveFFmpegPath() const;
  std::wstring BuildCommandLine(const std::wstring& ffmpeg_path) const;
  void CloseHandles();
  void SetLastError(const std::string& message);
  std::wstring GeneratePipeName(const wchar_t* suffix) const;
  bool WriteToPipe(HANDLE pipe, const uint8_t* data, size_t length, const char* label);

  FFmpegLaunchConfig config_{};
  HANDLE video_pipe_ = INVALID_HANDLE_VALUE;
  HANDLE audio_pipe_ = INVALID_HANDLE_VALUE;
  PROCESS_INFORMATION process_info_{};
  std::wstring video_pipe_name_;
  std::wstring audio_pipe_name_;
  bool is_running_ = false;
  std::string last_error_;
};

#endif  // SAT_LEC_REC_FFMPEG_PIPELINE_H_
