// lib/ffi/native_bindings.dart
// Dart FFI를 통한 C++ 네이티브 함수 바인딩
//
// 목적: C++ NativeHello() 함수를 Dart에서 호출 가능하도록 바인딩
// 작성일: 2025-10-21

import 'dart:ffi';
import 'dart:io';

/// C++ NativeHello 함수 시그니처 (C 측)
typedef NativeHelloNative = Pointer<Utf8> Function();

/// C++ NativeHello 함수 시그니처 (Dart 측)
typedef NativeHelloDart = Pointer<Utf8> Function();

/// 네이티브 레코더 FFI 바인딩 클래스
///
/// C++ 플러그인과 Dart 간 통신을 담당합니다.
/// 초기화 후 C++ 함수를 Dart에서 호출할 수 있습니다.
class NativeRecorder {
  static late DynamicLibrary _dylib;
  static late NativeHelloDart _nativeHello;
  static bool _initialized = false;

  /// FFI 초기화
  ///
  /// 앱 시작 시 한 번만 호출해야 합니다.
  /// Windows 실행 파일에서 C++ 함수를 로드합니다.
  ///
  /// @throws UnsupportedError 플랫폼이 Windows가 아닌 경우
  /// @throws ArgumentError 함수 심볼을 찾을 수 없는 경우
  static void initialize() {
    if (_initialized) {
      return;
    }

    // Windows 플랫폼만 지원
    if (!Platform.isWindows) {
      throw UnsupportedError('This platform is not supported. Windows only.');
    }

    // 현재 실행 파일(sat_lec_rec.exe)에서 DLL 로드
    _dylib = DynamicLibrary.executable();

    // NativeHello 함수 바인딩
    try {
      _nativeHello = _dylib
          .lookup<NativeFunction<NativeHelloNative>>('NativeHello')
          .asFunction();
    } catch (e) {
      throw ArgumentError(
        'Failed to lookup NativeHello function. '
        'Ensure native_recorder_plugin.cpp is included in CMakeLists.txt. '
        'Error: $e',
      );
    }

    _initialized = true;
  }

  /// C++에서 문자열 가져오기 (테스트용)
  ///
  /// NativeHello() C++ 함수를 호출하여 문자열을 반환합니다.
  ///
  /// @return "Hello from C++ Native Plugin!"
  /// @throws StateError FFI가 초기화되지 않은 경우
  static String hello() {
    if (!_initialized) {
      throw StateError(
        'NativeRecorder not initialized. Call initialize() first.',
      );
    }

    final ptr = _nativeHello();

    // C 문자열을 Dart String으로 변환
    // Pointer<Utf8>을 String으로 변환
    final result = ptr.cast<Utf8>().toDartString();

    return result;
  }

  /// 초기화 여부 확인
  static bool get isInitialized => _initialized;
}
