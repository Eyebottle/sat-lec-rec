// 무엇을 하는 코드인지: Zoom 회의 창을 UI Automation으로 제어하는 FFI용 선언부
#pragma once

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

__declspec(dllexport) BOOL ZoomAutomation_Initialize();
__declspec(dllexport) BOOL ZoomAutomation_FindZoomWindow(HWND* out_window_handle);
__declspec(dllexport) BOOL ZoomAutomation_EnterPassword(const wchar_t* password);
__declspec(dllexport) BOOL ZoomAutomation_EnterNameAndJoin(const wchar_t* user_name);
__declspec(dllexport) BOOL ZoomAutomation_CheckWaitingRoom();
__declspec(dllexport) BOOL ZoomAutomation_CheckHostNotStarted();
__declspec(dllexport) BOOL ZoomAutomation_JoinWithAudio();
__declspec(dllexport) BOOL ZoomAutomation_SetVideoEnabled(BOOL enable);
__declspec(dllexport) BOOL ZoomAutomation_SetMuted(BOOL mute);
__declspec(dllexport) void ZoomAutomation_Cleanup();

#ifdef __cplusplus
}
#endif
