// windows/runner/native_recorder_plugin.cpp
// FFI 테스트용 네이티브 레코더 플러그인 구현 파일
//
// 목적: Dart FFI를 통해 호출 가능한 C++ 함수 제공
// 작성일: 2025-10-21

#include "native_recorder_plugin.h"

extern "C" {

/// Dart FFI 테스트용 함수
///
/// Dart 코드에서 이 함수를 호출하여 C++ 통신이 정상 작동하는지 검증합니다.
///
/// @return 상수 문자열 "Hello from C++ Native Plugin!"
__declspec(dllexport) const char* NativeHello() {
    return "Hello from C++ Native Plugin!";
}

}  // extern "C"
