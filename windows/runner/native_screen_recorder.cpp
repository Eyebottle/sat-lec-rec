// windows/runner/native_screen_recorder.cpp
// Windows Graphics Capture API + WASAPI를 사용한 화면 + 오디오 녹화 구현
//
// 목적:
//   1. Graphics Capture API로 화면 캡처
//   2. WASAPI Loopback으로 오디오 캡처
//   3. Media Foundation으로 H.264/AAC 인코딩하여 MP4 저장
//
// 작성일: 2025-10-22

#include "native_screen_recorder.h"

#include <windows.h>
#include <string>
#include <atomic>
#include <thread>
#include <mutex>

// 전역 상태
static std::atomic<bool> g_is_recording(false);
static std::string g_last_error;
static std::mutex g_error_mutex;
static std::thread g_capture_thread;

// 에러 메시지 설정 헬퍼
static void SetLastError(const std::string& error) {
    std::lock_guard<std::mutex> lock(g_error_mutex);
    g_last_error = error;
}

// 녹화 스레드 함수 (스텁 - 실제 캡처 로직은 Phase 2에서 구현)
static void CaptureThreadFunc(
    std::string output_path,
    int32_t width,
    int32_t height,
    int32_t fps
) {
    // TODO Phase 2.1: Windows Graphics Capture API 초기화
    // - GraphicsCaptureSession 생성
    // - Direct3D11CaptureFramePool 설정
    // - FrameArrived 이벤트 핸들러 등록

    // TODO Phase 2.2: WASAPI Loopback 초기화
    // - IMMDeviceEnumerator로 기본 오디오 장치 가져오기
    // - IAudioClient 초기화
    // - IAudioCaptureClient로 오디오 데이터 캡처

    // TODO Phase 2.3: Media Foundation 인코더 설정
    // - IMFSinkWriter 생성 (MP4 출력)
    // - H.264 비디오 스트림 추가
    // - AAC 오디오 스트림 추가

    // TODO Phase 2.4: 메인 캡처 루프
    // - 화면 프레임 → H.264 인코딩
    // - 오디오 샘플 → AAC 인코딩
    // - Fragmented MP4로 실시간 저장

    // 현재는 스텁: 단순히 대기만 함
    while (g_is_recording) {
        Sleep(100);  // 100ms 대기
    }
}

// ========== C 인터페이스 구현 (extern "C" 링크) ==========

extern "C" {

// 녹화 초기화
int32_t NativeRecorder_Initialize() {
    try {
        // TODO: COM 초기화 (CoInitializeEx)
        // TODO: Windows Runtime 초기화 (Windows.Graphics.Capture 사용 시)

        SetLastError("");
        return 0;  // 성공
    } catch (const std::exception& e) {
        SetLastError(std::string("Initialize failed: ") + e.what());
        return -1;
    }
}

// 녹화 시작
int32_t NativeRecorder_StartRecording(
    const char* output_path,
    int32_t width,
    int32_t height,
    int32_t fps
) {
    if (g_is_recording) {
        SetLastError("Already recording");
        return -2;
    }

    if (!output_path || strlen(output_path) == 0) {
        SetLastError("Invalid output path");
        return -3;
    }

    try {
        g_is_recording = true;

        // 캡처 스레드 시작
        g_capture_thread = std::thread(
            CaptureThreadFunc,
            std::string(output_path),
            width,
            height,
            fps
        );

        SetLastError("");
        return 0;  // 성공
    } catch (const std::exception& e) {
        g_is_recording = false;
        SetLastError(std::string("StartRecording failed: ") + e.what());
        return -1;
    }
}

// 녹화 중지
int32_t NativeRecorder_StopRecording() {
    if (!g_is_recording) {
        SetLastError("Not recording");
        return -2;
    }

    try {
        g_is_recording = false;

        // 캡처 스레드 종료 대기
        if (g_capture_thread.joinable()) {
            g_capture_thread.join();
        }

        SetLastError("");
        return 0;  // 성공
    } catch (const std::exception& e) {
        SetLastError(std::string("StopRecording failed: ") + e.what());
        return -1;
    }
}

// 녹화 중 여부 확인
int32_t NativeRecorder_IsRecording() {
    return g_is_recording ? 1 : 0;
}

// 리소스 정리
void NativeRecorder_Cleanup() {
    if (g_is_recording) {
        NativeRecorder_StopRecording();
    }

    // TODO: COM 종료 (CoUninitialize)
}

// 마지막 에러 메시지 가져오기
const char* NativeRecorder_GetLastError() {
    std::lock_guard<std::mutex> lock(g_error_mutex);
    return g_last_error.c_str();
}

}  // extern "C"
