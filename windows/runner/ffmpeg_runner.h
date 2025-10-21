// windows/runner/ffmpeg_runner.h
// FFmpeg 프로세스 관리 클래스
//
// 목적: FFmpeg 바이너리 실행 및 프로세스 생명주기 관리
// 작성일: 2025-10-21

#ifndef FFMPEG_RUNNER_H_
#define FFMPEG_RUNNER_H_

#include <windows.h>
#include <string>

/// FFmpeg 프로세스 관리 클래스
///
/// 책임:
/// - FFmpeg 바이너리 경로 확인
/// - 프로세스 생성 및 종료
/// - Named Pipe 생성 및 관리 (향후 구현)
class FFmpegRunner {
 public:
  FFmpegRunner();
  ~FFmpegRunner();

  /// FFmpeg 바이너리 존재 여부 확인
  ///
  /// @return true if ffmpeg.exe exists
  bool CheckFFmpegExists();

  /// FFmpeg 프로세스 시작 (테스트용)
  ///
  /// @param args 명령줄 인수 (예: L"-version")
  /// @param output_file 출력 파일 경로 (선택)
  /// @return true if process started successfully
  bool StartFFmpeg(const std::wstring& args, const std::wstring& output_file = L"");

  /// FFmpeg 프로세스 종료
  void StopFFmpeg();

  /// FFmpeg 실행 중 여부
  ///
  /// @return true if process is running
  bool IsRunning();

 private:
  PROCESS_INFORMATION process_info_;
  HANDLE pipe_handle_;
  bool is_running_;

  /// FFmpeg 실행 파일 경로 획득
  ///
  /// 개발 환경: {project_root}/third_party/ffmpeg/ffmpeg.exe
  /// 배포 환경: {exe_dir}/data/flutter_assets/assets/ffmpeg/ffmpeg.exe
  ///
  /// @return 절대 경로 (wstring)
  std::wstring GetFFmpegPath();
};

#endif  // FFMPEG_RUNNER_H_
