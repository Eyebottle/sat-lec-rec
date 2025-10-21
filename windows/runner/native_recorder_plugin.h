// windows/runner/native_recorder_plugin.h
// FFI 테스트용 네이티브 레코더 플러그인 헤더 파일
//
// 목적: Dart와 C++ 간 FFI 통신을 위한 기본 구조 제공
// 작성일: 2025-10-21

#ifndef NATIVE_RECORDER_PLUGIN_H_
#define NATIVE_RECORDER_PLUGIN_H_

#ifdef __cplusplus
extern "C" {
#endif

// FFI 테스트용 샘플 함수
// Dart에서 호출하여 C++ 통신이 정상 작동하는지 검증
//
// @return C 스타일 문자열 포인터 (상수)
__declspec(dllexport) const char* NativeHello();

#ifdef __cplusplus
}
#endif

#endif  // NATIVE_RECORDER_PLUGIN_H_
