// windows/runner/ffmpeg_runner.cpp
// FFmpeg 프로세스 관리 클래스 구현
//
// 목적: FFmpeg 바이너리 실행 및 프로세스 생명주기 관리
// 작성일: 2025-10-21

#include "ffmpeg_runner.h"
#include <shlwapi.h>
#include <filesystem>

#pragma comment(lib, "shlwapi.lib")

namespace fs = std::filesystem;

FFmpegRunner::FFmpegRunner()
    : process_info_{}, pipe_handle_(INVALID_HANDLE_VALUE), is_running_(false) {
  // 프로세스 정보 초기화
  ZeroMemory(&process_info_, sizeof(process_info_));
}

FFmpegRunner::~FFmpegRunner() {
  StopFFmpeg();
}

std::wstring FFmpegRunner::GetFFmpegPath() {
  // 현재 실행 파일의 디렉토리 획득
  wchar_t exe_path[MAX_PATH];
  GetModuleFileNameW(NULL, exe_path, MAX_PATH);

  fs::path exe_dir = fs::path(exe_path).parent_path();

  // 개발 환경: {project_root}/third_party/ffmpeg/ffmpeg.exe
  // exe_dir = {project_root}/build/windows/x64/runner/Debug (또는 Release)
  // 상대 경로로 4단계 상위 이동
  fs::path dev_path = exe_dir / ".." / ".." / ".." / ".." / "third_party" / "ffmpeg" / "ffmpeg.exe";

  // 경로 정규화 (.. 제거)
  dev_path = dev_path.lexically_normal();

  // 개발 환경 경로가 존재하면 사용
  if (fs::exists(dev_path)) {
    return fs::absolute(dev_path).wstring();
  }

  // 배포 환경 폴백: {exe_dir}/data/flutter_assets/assets/ffmpeg/ffmpeg.exe
  fs::path deploy_path = exe_dir / "data" / "flutter_assets" / "assets" / "ffmpeg" / "ffmpeg.exe";
  return fs::absolute(deploy_path).wstring();
}

bool FFmpegRunner::CheckFFmpegExists() {
  std::wstring path = GetFFmpegPath();

  // 디버그 로깅
  OutputDebugStringW(L"[FFmpeg] Checking path: ");
  OutputDebugStringW(path.c_str());
  OutputDebugStringW(L"\n");

  bool exists = fs::exists(path);

  if (exists) {
    OutputDebugStringW(L"[FFmpeg] ✓ File EXISTS\n");
  } else {
    OutputDebugStringW(L"[FFmpeg] ✗ File NOT FOUND\n");
  }

  return exists;
}

bool FFmpegRunner::StartFFmpeg(const std::wstring& args, const std::wstring& output_file) {
  if (is_running_) {
    return false;  // 이미 실행 중
  }

  std::wstring ffmpeg_path = GetFFmpegPath();
  if (!fs::exists(ffmpeg_path)) {
    return false;  // FFmpeg 바이너리 없음
  }

  // 명령줄 구성: "경로" 인수 "출력파일"
  std::wstring cmdline = L"\"" + ffmpeg_path + L"\" " + args;
  if (!output_file.empty()) {
    cmdline += L" \"" + output_file + L"\"";
  }

  // 프로세스 시작 정보 설정
  STARTUPINFOW si = {};
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESTDHANDLES;
  si.hStdInput = NULL;
  si.hStdOutput = NULL;
  si.hStdError = NULL;

  // CreateProcess는 cmdline을 수정할 수 있으므로 복사본 사용
  std::wstring cmdline_copy = cmdline;

  BOOL success = CreateProcessW(
    NULL,                              // lpApplicationName
    const_cast<LPWSTR>(cmdline_copy.c_str()),  // lpCommandLine
    NULL,                              // lpProcessAttributes
    NULL,                              // lpThreadAttributes
    FALSE,                             // bInheritHandles
    CREATE_NO_WINDOW,                  // dwCreationFlags (콘솔 창 숨김)
    NULL,                              // lpEnvironment
    NULL,                              // lpCurrentDirectory
    &si,                               // lpStartupInfo
    &process_info_                     // lpProcessInformation
  );

  if (success) {
    is_running_ = true;
    return true;
  }

  return false;
}

void FFmpegRunner::StopFFmpeg() {
  if (!is_running_) {
    return;
  }

  // 프로세스 종료
  TerminateProcess(process_info_.hProcess, 0);

  // 핸들 정리
  if (process_info_.hProcess != NULL) {
    CloseHandle(process_info_.hProcess);
  }
  if (process_info_.hThread != NULL) {
    CloseHandle(process_info_.hThread);
  }

  ZeroMemory(&process_info_, sizeof(process_info_));
  is_running_ = false;
}

bool FFmpegRunner::IsRunning() {
  if (!is_running_) {
    return false;
  }

  // 프로세스 종료 코드 확인
  DWORD exit_code;
  if (GetExitCodeProcess(process_info_.hProcess, &exit_code)) {
    if (exit_code != STILL_ACTIVE) {
      is_running_ = false;
      return false;
    }
  }

  return true;
}
