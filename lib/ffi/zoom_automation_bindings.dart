// 무엇을 하는 코드인지: Zoom UI 자동화 네이티브 모듈을 Dart에서 호출하는 FFI 래퍼를 제공한다
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart' show Utf16;

/// 네이티브 함수 시그니처 정의
typedef NativeNoParamBool = ffi.Int32 Function();
typedef NativeEnterNameAndJoin = ffi.Int32 Function(ffi.Pointer<Utf16>);
typedef NativeBoolParamBool = ffi.Int32 Function(ffi.Int32);
typedef NativeCleanup = ffi.Void Function();

typedef DartNoParamBool = int Function();
typedef DartEnterNameAndJoin = int Function(ffi.Pointer<Utf16>);
typedef DartBoolParamBool = int Function(int);
typedef DartCleanup = void Function();

ffi.DynamicLibrary _loadAutomationLibrary() {
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.executable();
  }
  throw UnsupportedError('Zoom UI 자동화는 Windows에서만 사용할 수 있습니다.');
}

/// Zoom UI Automation 네이티브 모듈과 통신하는 정적 헬퍼
class ZoomAutomationBindings {
  ZoomAutomationBindings._();

  static final ffi.DynamicLibrary _lib = _loadAutomationLibrary();

  /// UI Automation 초기화 (성공 시 1, 실패 시 0 반환)
  static final DartNoParamBool initializeUIAutomation = _lib
      .lookup<ffi.NativeFunction<NativeNoParamBool>>('ZoomAutomation_Initialize')
      .asFunction();

  /// Zoom 창에서 이름 입력 후 참가 버튼 클릭
  static final DartEnterNameAndJoin enterNameAndJoin = _lib
      .lookup<ffi.NativeFunction<NativeEnterNameAndJoin>>(
          'ZoomAutomation_EnterNameAndJoin')
      .asFunction();

  /// Zoom 창에서 암호 입력 후 확인 버튼 클릭
  /// 입력: password 문자열 (Pointer<Utf16>)
  /// 출력: 성공 시 1, 실패 시 0
  /// 예외: 암호 필드나 확인 버튼을 찾을 수 없으면 0
  static final DartEnterNameAndJoin enterPassword = _lib
      .lookup<ffi.NativeFunction<NativeEnterNameAndJoin>>(
          'ZoomAutomation_EnterPassword')
      .asFunction();

  /// Zoom 창이 대기실 화면인지 확인 (대기실이면 1)
  static final DartNoParamBool checkWaitingRoom = _lib
      .lookup<ffi.NativeFunction<NativeNoParamBool>>(
          'ZoomAutomation_CheckWaitingRoom')
      .asFunction();

  /// "호스트가 시작하지 않음" 화면인지 확인 (해당 메시지면 1)
  static final DartNoParamBool checkHostNotStarted = _lib
      .lookup<ffi.NativeFunction<NativeNoParamBool>>(
          'ZoomAutomation_CheckHostNotStarted')
      .asFunction();

  /// "Join with Computer Audio" 버튼 클릭
  /// 입력: 없음
  /// 출력: 성공 시 1, 실패 시 0
  /// 예외: 버튼을 찾을 수 없으면 0
  static final DartNoParamBool joinWithAudio = _lib
      .lookup<ffi.NativeFunction<NativeNoParamBool>>(
          'ZoomAutomation_JoinWithAudio')
      .asFunction();

  /// 비디오 활성화/비활성화
  /// 입력: enable (1=비디오 켜기, 0=비디오 끄기)
  /// 출력: 성공 시 1, 실패 시 0
  /// 예외: 비디오 설정을 찾을 수 없으면 0
  static final DartBoolParamBool setVideoEnabled = _lib
      .lookup<ffi.NativeFunction<NativeBoolParamBool>>(
          'ZoomAutomation_SetVideoEnabled')
      .asFunction();

  /// 음소거 설정/해제
  /// 입력: mute (1=음소거, 0=음소거 해제)
  /// 출력: 성공 시 1, 실패 시 0
  /// 예외: 음소거 버튼을 찾을 수 없으면 0
  static final DartBoolParamBool setMuted = _lib
      .lookup<ffi.NativeFunction<NativeBoolParamBool>>(
          'ZoomAutomation_SetMuted')
      .asFunction();

  /// UI Automation 세션 정리
  static final DartCleanup cleanupUIAutomation = _lib
      .lookup<ffi.NativeFunction<NativeCleanup>>('ZoomAutomation_Cleanup')
      .asFunction();
}

/// 네이티브 BOOL → Dart bool 변환 헬퍼
bool automationBool(int value) => value == 1;
