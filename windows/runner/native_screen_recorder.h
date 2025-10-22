// windows/runner/native_screen_recorder.h
// Windows Graphics Capture API + WASAPI를 사용한 화면 + 오디오 녹화
//
// 목적: Flutter FFI에서 호출 가능한 C 스타일 인터페이스 제공
// 작성일: 2025-10-22

#ifndef NATIVE_SCREEN_RECORDER_H_
#define NATIVE_SCREEN_RECORDER_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 녹화 초기화
/// @return 성공 시 0, 실패 시 에러 코드
int32_t NativeRecorder_Initialize();

/// 녹화 시작
/// @param output_path 저장할 MP4 파일 경로 (UTF-8)
/// @param width 녹화 해상도 너비
/// @param height 녹화 해상도 높이
/// @param fps 프레임률
/// @return 성공 시 0, 실패 시 에러 코드
int32_t NativeRecorder_StartRecording(
    const char* output_path,
    int32_t width,
    int32_t height,
    int32_t fps
);

/// 녹화 중지
/// @return 성공 시 0, 실패 시 에러 코드
int32_t NativeRecorder_StopRecording();

/// 녹화 중 여부 확인
/// @return 녹화 중이면 1, 아니면 0
int32_t NativeRecorder_IsRecording();

/// 리소스 정리
void NativeRecorder_Cleanup();

/// 마지막 에러 메시지 가져오기
/// @return UTF-8 인코딩된 에러 메시지 (수명은 다음 호출까지 유효)
const char* NativeRecorder_GetLastError();

#ifdef __cplusplus
}
#endif

#endif  // NATIVE_SCREEN_RECORDER_H_
