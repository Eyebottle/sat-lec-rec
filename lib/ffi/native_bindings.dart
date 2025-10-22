// lib/ffi/native_bindings.dart
// Dart FFI 바인딩: C++ 네이티브 화면 녹화 함수 연결
//
// 목적: RecorderService에서 호출 가능한 Dart 인터페이스 제공
// 작성일: 2025-10-22

import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

/// C++ 함수 시그니처 정의
typedef NativeInitializeFunc = ffi.Int32 Function();
typedef NativeStartRecordingFunc = ffi.Int32 Function(
  ffi.Pointer<Utf8> outputPath,
  ffi.Int32 width,
  ffi.Int32 height,
  ffi.Int32 fps,
);
typedef NativeStopRecordingFunc = ffi.Int32 Function();
typedef NativeIsRecordingFunc = ffi.Int32 Function();
typedef NativeCleanupFunc = ffi.Void Function();
typedef NativeGetLastErrorFunc = ffi.Pointer<Utf8> Function();

/// Dart 함수 시그니처 정의
typedef DartInitializeFunc = int Function();
typedef DartStartRecordingFunc = int Function(
  ffi.Pointer<Utf8> outputPath,
  int width,
  int height,
  int fps,
);
typedef DartStopRecordingFunc = int Function();
typedef DartIsRecordingFunc = int Function();
typedef DartCleanupFunc = void Function();
typedef DartGetLastErrorFunc = ffi.Pointer<Utf8> Function();

/// 네이티브 라이브러리 로드
ffi.DynamicLibrary _loadLibrary() {
  if (Platform.isWindows) {
    // Windows: 실행 파일 자체에 네이티브 함수가 포함됨
    return ffi.DynamicLibrary.executable();
  } else {
    throw UnsupportedError('이 플랫폼은 지원되지 않습니다: ${Platform.operatingSystem}');
  }
}

/// 네이티브 녹화 API 래퍼 클래스
class NativeRecorderBindings {
  static final ffi.DynamicLibrary _lib = _loadLibrary();

  /// 네이티브 함수 바인딩
  static final DartInitializeFunc initialize = _lib
      .lookup<ffi.NativeFunction<NativeInitializeFunc>>('NativeRecorder_Initialize')
      .asFunction();

  static final DartStartRecordingFunc startRecording = _lib
      .lookup<ffi.NativeFunction<NativeStartRecordingFunc>>('NativeRecorder_StartRecording')
      .asFunction();

  static final DartStopRecordingFunc stopRecording = _lib
      .lookup<ffi.NativeFunction<NativeStopRecordingFunc>>('NativeRecorder_StopRecording')
      .asFunction();

  static final DartIsRecordingFunc isRecording = _lib
      .lookup<ffi.NativeFunction<NativeIsRecordingFunc>>('NativeRecorder_IsRecording')
      .asFunction();

  static final DartCleanupFunc cleanup = _lib
      .lookup<ffi.NativeFunction<NativeCleanupFunc>>('NativeRecorder_Cleanup')
      .asFunction();

  static final DartGetLastErrorFunc getLastError = _lib
      .lookup<ffi.NativeFunction<NativeGetLastErrorFunc>>('NativeRecorder_GetLastError')
      .asFunction();
}

/// 편의 함수: 마지막 에러 메시지 가져오기 (Dart String 변환)
String getNativeLastError() {
  final errorPtr = NativeRecorderBindings.getLastError();
  if (errorPtr.address == 0) {
    return '';
  }
  return errorPtr.toDartString();
}
