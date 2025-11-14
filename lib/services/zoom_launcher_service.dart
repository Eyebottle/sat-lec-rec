// lib/services/zoom_launcher_service.dart
// Zoom 자동 실행 서비스
//
// 목적: 스케줄된 녹화 시작 전 Zoom 회의 자동 실행
// - Zoom 링크로 기본 브라우저 열기
// - Zoom 앱 자동 실행 대기
// - 회의 참가 확인

import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../ffi/zoom_automation_bindings.dart';
import '../models/zoom_automation_state.dart';
import 'tray_service.dart';

/// Zoom 자동 실행 서비스
class ZoomLauncherService {
  ZoomLauncherService();

  final Logger _logger = Logger();
  final TrayService _trayService = TrayService();

  static final ValueNotifier<ZoomAutomationState> _automationStateNotifier =
      ValueNotifier<ZoomAutomationState>(ZoomAutomationState.idle());

  /// UI가 구독할 수 있는 자동화 상태 노티파이어
  ZoomAutomationListenable get automationState => _automationStateNotifier;

  /// 자동화 상태 초기화 (대기 상태)
  void resetAutomationState() {
    _automationStateNotifier.value = ZoomAutomationState.idle();
  }

  /// 녹화 준비 완료 상태로 업데이트
  void markRecordingReady() {
    _automationStateNotifier.value = ZoomAutomationState(
      stage: ZoomAutomationStage.recordingReady,
      message: '회의 입장을 마쳤습니다. 녹화를 준비하세요.',
      isError: false,
      updatedAt: DateTime.now(),
    );
  }

  /// 외부에서 명시적으로 실패 상태로 표시할 때 사용
  void markAutomationFailure(String message) {
    _updateAutomationState(ZoomAutomationStage.failed, message, isError: true);
  }

  /// 트레이 알림 도우미
  /// 입력: [title], [message]
  /// 출력: 없음
  /// 예외: TrayService 내부에서 처리됨
  Future<void> _notifyTray(String title, String message) async {
    await _trayService.showNotification(title: title, message: message);
  }

  void _updateAutomationState(
    ZoomAutomationStage stage,
    String message, {
    bool isError = false,
  }) {
    _automationStateNotifier.value = ZoomAutomationState(
      stage: stage,
      message: message,
      isError: isError,
      updatedAt: DateTime.now(),
    );
  }

  /// Zoom 링크로 회의 시작
  ///
  /// @param zoomLink Zoom 회의 링크 (예: https://zoom.us/j/123456789)
  /// @param waitSeconds 실행 후 대기 시간 (초, 기본 10초)
  /// @return 성공 여부
  Future<bool> launchZoomMeeting({
    required String zoomLink,
    int waitSeconds = 10,
  }) async {
    try {
      _updateAutomationState(
        ZoomAutomationStage.launching,
        'Zoom 링크를 실행하여 회의 입장을 준비합니다.',
      );
      _logger.i('🚀 Zoom 회의 실행 시작: $zoomLink');

      // 1. URL 유효성 검증
      final uri = Uri.tryParse(zoomLink);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        _logger.e('❌ 잘못된 Zoom 링크: $zoomLink');
        return false;
      }

      // 2. Zoom 링크인지 확인
      if (!uri.host.contains('zoom.us') && !uri.host.contains('zoom.com')) {
        _logger.w('⚠️ Zoom 링크가 아닙니다: $zoomLink');
        // 경고만 하고 계속 진행 (사용자 지정 Zoom 도메인 지원)
      }

      // 3. HTTP(S) 링크를 브라우저로 열기 (암호 자동 전달 보장)
      // 핵심: zoommtg:// 프로토콜은 암호를 자동으로 전달하지 않을 수 있습니다.
      // 브라우저에서 HTTP URL을 열면 Zoom이 내부적으로 암호를 처리하여
      // 암호 입력창 없이 자동 참가가 가능합니다.
      _logger.i('🌐 브라우저를 통해 Zoom 링크 실행 (암호 자동 전달)');
      _logger.i('📞 회의 URL: $zoomLink');

      try {
        // HTTP(S) URL을 브라우저로 열기
        // 브라우저가 Zoom 프로토콜 핸들러를 호출하면서 암호 정보를 자동으로 전달합니다
        final process = await Process.start(
          'rundll32',
          ['url.dll,FileProtocolHandler', zoomLink],
          runInShell: false,
        );

      _logger.i('✅ Zoom 링크 실행 완료: pid=${process.pid}');
      _logger.i('💡 브라우저가 Zoom 앱을 자동으로 실행하며 암호를 전달합니다');

      // 브라우저 다이얼로그 자동 클릭 시도 (최대 5초)
      _logger.i('🖱️ 브라우저 다이얼로그 자동 클릭 시도 중...');
      bool dialogClicked = false;
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (ZoomAutomationBindings.initializeUIAutomation() != 0) {
          if (automationBool(ZoomAutomationBindings.clickBrowserDialog())) {
            _logger.i('✅ 브라우저 다이얼로그 클릭 성공 (${i + 1}회 시도)');
            dialogClicked = true;
            break;
          }
        }
      }
      if (!dialogClicked) {
        _logger.d('ℹ️ 브라우저 다이얼로그를 찾지 못함 (수동 클릭 필요할 수 있음)');
      }
      } catch (e) {
        // rundll32 실패 시 폴백: CMD start 사용
        _logger.w('⚠️ rundll32 실패, CMD 폴백 시도: $e');
        try {
          final process = await Process.start(
            'cmd',
            ['/c', 'start', '', zoomLink],
            runInShell: false,
          );
          _logger.i('✅ Zoom 링크 실행 완료 (CMD 폴백): pid=${process.pid}');
        } catch (e2) {
          _logger.e('❌ Zoom 링크 실행 실패: $e2');
          rethrow;
        }
      }
      await _notifyTray('Zoom 실행', '회의 자동 입장을 준비합니다.');

      // 5. Zoom 앱이 실행될 때까지 대기
      _logger.i('⏳ Zoom 앱 실행 대기 중... ($waitSeconds초)');
      await Future.delayed(Duration(seconds: waitSeconds));

      // 6. Zoom 프로세스가 실행 중인지 확인
      final isZoomRunning = await _isZoomProcessRunning();
      if (isZoomRunning) {
        _logger.i('✅ Zoom 앱 실행 확인됨');
      } else {
        _logger.w('⚠️ Zoom 앱이 실행되지 않은 것 같습니다 (수동 확인 필요)');
        // 경고만 하고 계속 진행 (사용자가 수동으로 참가할 수 있음)
      }

      return true;
    } catch (e, stackTrace) {
      _logger.e('❌ Zoom 회의 실행 실패', error: e, stackTrace: stackTrace);
      _updateAutomationState(
        ZoomAutomationStage.failed,
        'Zoom 실행 중 예기치 못한 오류가 발생했습니다.',
        isError: true,
      );
      return false;
    }
  }

  /// Zoom 프로세스가 실행 중인지 확인
  ///
  /// @return Zoom.exe가 실행 중이면 true
  Future<bool> _isZoomProcessRunning() async {
    try {
      // Windows tasklist 명령어로 Zoom 프로세스 확인
      final result = await Process.run('tasklist', [
        '/FI',
        'IMAGENAME eq Zoom.exe',
        '/NH',
      ], runInShell: true);

      if (result.exitCode != 0) {
        _logger.w('⚠️ tasklist 명령 실패 (exit code: ${result.exitCode})');
        return false;
      }

      final output = result.stdout.toString();

      // "Zoom.exe"가 출력에 포함되어 있으면 실행 중
      final isRunning = output.toLowerCase().contains('zoom.exe');

      if (isRunning) {
        _logger.d('✅ Zoom 프로세스 확인됨');
      } else {
        _logger.d('⚠️ Zoom 프로세스 없음');
      }

      return isRunning;
    } catch (e) {
      _logger.e('❌ Zoom 프로세스 확인 실패', error: e);
      return false;
    }
  }

  /// Zoom 앱이 설치되어 있는지 확인
  ///
  /// @return Zoom이 설치되어 있으면 true
  Future<bool> isZoomInstalled() async {
    try {
      _logger.d('🔍 Zoom 설치 확인 중...');

      // Zoom 기본 설치 경로들
      final possiblePaths = [
        r'C:\Program Files\Zoom\bin\Zoom.exe',
        r'C:\Program Files (x86)\Zoom\bin\Zoom.exe',
        Platform.environment['APPDATA'] != null
            ? '${Platform.environment['APPDATA']}\\Zoom\\bin\\Zoom.exe'
            : null,
      ];

      for (final path in possiblePaths) {
        if (path == null) continue;

        final file = File(path);
        if (await file.exists()) {
          _logger.i('✅ Zoom 설치 확인됨: $path');
          return true;
        }
      }

      _logger.w('⚠️ Zoom 설치를 찾을 수 없습니다 (기본 경로에서)');
      return false;
    } catch (e) {
      _logger.e('❌ Zoom 설치 확인 실패', error: e);
      return false;
    }
  }

  /// Zoom 회의 종료
  ///
  /// 녹화가 끝난 후 Zoom 앱을 종료합니다.
  /// @param force 강제 종료 여부 (기본 false)
  Future<bool> closeZoomMeeting({bool force = false}) async {
    try {
      _logger.i('🚪 Zoom 회의 종료 시작...');

      // Zoom 프로세스 종료
      final result = await Process.run('taskkill', [
        '/IM',
        'Zoom.exe',
        if (force) '/F',
      ], runInShell: true);

      if (result.exitCode == 0) {
        _logger.i('✅ Zoom 앱 종료 완료');
        await _notifyTray('Zoom 종료', '회의 창을 닫았습니다.');
        _updateAutomationState(
          ZoomAutomationStage.idle,
          '대기 중입니다. 다음 예약을 기다립니다.',
        );
        return true;
      } else if (result.exitCode == 128) {
        // 프로세스가 없는 경우
        _logger.d('ℹ️ Zoom 프로세스가 실행 중이지 않음');
        _updateAutomationState(
          ZoomAutomationStage.idle,
          'Zoom 프로세스가 이미 종료된 상태입니다.',
        );
        return true;
      } else {
        _logger.w('⚠️ Zoom 종료 실패 (exit code: ${result.exitCode})');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Zoom 종료 실패', error: e);
      return false;
    }
  }

  /// Zoom UI Automation을 사용해 이름 입력과 참가 버튼 클릭까지 수행한다.
  /// 입력: [zoomLink]는 접속할 회의 주소, [userName]은 참가 시 표시될 이름,
  /// [password]는 회의 암호 (선택 사항), [initialWaitSeconds]는 Zoom 실행 후 UI 자동화까지 기다릴 시간이다.
  /// 출력: 자동 참가에 성공하면 true, 중간 단계에서 막히면 false를 돌려준다.
  /// 예외: Windows UI Automation 초기화 실패나 네이티브 오류가 발생하면 false를 반환하며
  ///       로그에 스택 정보를 남긴다.
  Future<bool> autoJoinZoomMeeting({
    required String zoomLink,
    String userName = '녹화 시스템',
    String? password,
    int initialWaitSeconds = 5,
    int maxAttempts = 30,
  }) async {
    try {
      _logger.i('🤖 Zoom 자동 진입 준비 (사용자 이름: $userName)');
      _updateAutomationState(
        ZoomAutomationStage.autoJoining,
        '자동으로 이름을 입력하고 참가 버튼을 누르고 있습니다.',
      );
      bool skipLaunch = false;
      if (await _isZoomProcessRunning()) {
        skipLaunch = true;
        _logger.i('🔁 Zoom 프로세스가 이미 실행 중입니다. 중복 실행을 건너뜁니다.');
        await Future.delayed(Duration(seconds: initialWaitSeconds));
      }

      if (!skipLaunch) {
        final launched = await launchZoomMeeting(
          zoomLink: zoomLink,
          waitSeconds: initialWaitSeconds,
        );

        if (!launched) {
          _logger.e('❌ Zoom 실행 실패로 자동 진입 중단');
          await _notifyTray('Zoom 실행 실패', '링크 실행에 실패했습니다. 수동 확인이 필요합니다.');
          _updateAutomationState(
            ZoomAutomationStage.failed,
            'Zoom 실행에 실패해 자동 참가를 중단했습니다.',
            isError: true,
          );
          return false;
        }
      }

      // 브라우저를 통해 실행하는 경우 Zoom 창이 완전히 로드될 때까지 추가 대기
      _logger.i('⏳ Zoom 창이 완전히 로드될 때까지 대기 중... (최대 10초)');
      bool zoomWindowReady = false;
      for (int waitAttempt = 0; waitAttempt < 10; waitAttempt++) {
        await Future.delayed(const Duration(seconds: 1));
        // UI Automation 초기화 시도 (성공하면 Zoom 창이 준비된 것)
        if (ZoomAutomationBindings.initializeUIAutomation() != 0) {
          zoomWindowReady = true;
          _logger.i('✅ Zoom 창 준비 완료 (${waitAttempt + 1}초 후)');
          break;
        }
        _logger.d('⏳ Zoom 창 대기 중... (${waitAttempt + 1}/10초)');
      }

      if (!zoomWindowReady) {
        _logger.w('⚠️ Zoom 창을 찾지 못했습니다. UI Automation 재시도...');
        // 마지막 시도
        if (ZoomAutomationBindings.initializeUIAutomation() == 0) {
          _logger.e('❌ UI Automation 초기화 실패');
          await _notifyTray('자동 참가 실패', 'Windows UI Automation 초기화에 실패했습니다.');
          _updateAutomationState(
            ZoomAutomationStage.failed,
            'Windows UI Automation 초기화에 실패했습니다. Zoom 창이 열렸는지 확인하세요.',
            isError: true,
          );
          return false;
        }
      }

      final safeName = userName.trim().isEmpty ? '녹화 시스템' : userName.trim();

      // 암호 입력 시도 (암호가 제공된 경우만)
      // 브라우저를 통해 실행하면 암호가 자동으로 전달되므로, 암호 입력창이 나타나지 않을 수 있습니다.
      // 하지만 수동으로 암호를 제공한 경우(URL에 없고 별도 파라미터로 전달) 시도합니다.
      if (password != null && password.isNotEmpty) {
        _logger.i('🔑 회의 암호 입력 시도 중... (브라우저를 통해 실행했다면 이미 처리되었을 수 있음)');
        const passwordAttempts = 10; // 대기 시간 증가 (5초)
        bool passwordEntered = false;

        for (int i = 1; i <= passwordAttempts; i++) {
          final passwordPointer = password.toNativeUtf16();
          try {
            final passwordResult = ZoomAutomationBindings.enterPassword(passwordPointer);
            if (automationBool(passwordResult)) {
              _logger.i('✅ 암호 입력 성공 ($i회 시도)');
              passwordEntered = true;
              break;
            }
          } finally {
            malloc.free(passwordPointer);
          }

          if (i < passwordAttempts) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        if (!passwordEntered) {
          _logger.d('ℹ️ 암호 필드를 찾지 못함 (브라우저를 통해 이미 처리되었거나 공개 강의일 수 있음)');
        }
      } else {
        _logger.d('ℹ️ 별도 암호가 제공되지 않음 (URL에 포함된 암호가 브라우저를 통해 자동 전달됨)');
      }

      _logger.i('👤 이름 입력 및 참가 버튼 클릭 시도 시작...');
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        final namePointer = safeName.toNativeUtf16();
        try {
          final joinResult = ZoomAutomationBindings.enterNameAndJoin(
            namePointer,
          );
          if (automationBool(joinResult)) {
            _logger.i('✅ Zoom 자동 진입 성공 ($attempt회 시도)');
            await _notifyTray('Zoom 자동 참가 완료', '이름 입력 후 참가 버튼을 눌렀습니다.');
            _updateAutomationState(
              ZoomAutomationStage.waitingRoom,
              '대기실 승인 결과를 확인하는 중입니다.',
            );
            return true;
          } else {
            _logger.d('⏳ 참가 버튼을 찾지 못함. 재시도 중... ($attempt/$maxAttempts)');
            // Zoom 창이 아직 완전히 로드되지 않았을 수 있으므로 짧은 대기
            await Future.delayed(const Duration(milliseconds: 800));
          }
        } catch (e) {
          _logger.w('⚠️ 이름 입력 시도 중 오류: $e');
          await Future.delayed(const Duration(milliseconds: 800));
        } finally {
          malloc.free(namePointer);
        }
      }

      _logger.w('⚠️ Zoom 자동 진입 타임아웃 (30초 경과)');
      await _notifyTray('자동 참가 실패', '30초 동안 참가 버튼을 찾지 못했습니다.');
      _updateAutomationState(
        ZoomAutomationStage.failed,
        '자동 참가 타임아웃: 참가 버튼을 찾지 못했습니다.',
        isError: true,
      );
      return false;
    } catch (e, stackTrace) {
      _logger.e('❌ Zoom 자동 진입 중 예외 발생', error: e, stackTrace: stackTrace);
      _updateAutomationState(
        ZoomAutomationStage.failed,
        '자동 참가 중 예외가 발생했습니다.',
        isError: true,
      );
      return false;
    } finally {
      ZoomAutomationBindings.cleanupUIAutomation();
    }
  }

  /// Zoom 대기실 화면이 사라질 때까지 주기적으로 확인한다.
  /// 입력: [maxAttempts]는 최대 확인 횟수, [interval]은 확인 간격이다.
  /// 출력: 대기실을 통과하면 true, 타임아웃이면 false.
  /// 예외: UI Automation 오류가 나면 false로 처리하고 로그를 남긴다.
  Future<bool> waitForWaitingRoomClear({
    int maxAttempts = 15,
    Duration interval = const Duration(seconds: 20),
  }) async {
    try {
      _logger.i('🔄 대기실 통과 여부 확인 시작');
      await _notifyTray('대기실 대기 중', '호스트 승인까지 조금만 기다려 주세요.');
      _updateAutomationState(
        ZoomAutomationStage.waitingRoom,
        '대기실에서 승인될 때까지 기다리는 중입니다.',
      );
      if (ZoomAutomationBindings.initializeUIAutomation() == 0) {
        _logger.e('❌ UI Automation 초기화 실패 (대기실 확인)');
        _updateAutomationState(
          ZoomAutomationStage.failed,
          '대기실 확인용 UI Automation 초기화에 실패했습니다.',
          isError: true,
        );
        return false;
      }

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        final inWaitingRoom = automationBool(
          ZoomAutomationBindings.checkWaitingRoom(),
        );
        if (!inWaitingRoom) {
          _logger.i('✅ 대기실 통과 감지 (시도 $attempt/$maxAttempts)');
          await _notifyTray('대기실 통과', '회의실로 입장했습니다.');
          _updateAutomationState(
            ZoomAutomationStage.waitingHost,
            '호스트가 회의를 시작할 때까지 기다립니다.',
          );
          return true;
        }

        _logger.d('⏳ 아직 대기실 상태 → ${interval.inSeconds}초 뒤 재확인');
        await Future.delayed(interval);
      }

      _logger.w('⚠️ 대기실 통과 실패 (5분 경과)');
      await _notifyTray('대기실 시간 초과', '5분 동안 승인되지 않았습니다. Zoom 창을 확인해 주세요.');
      _updateAutomationState(
        ZoomAutomationStage.failed,
        '대기실 승인 시간이 5분을 초과했습니다.',
        isError: true,
      );
      return false;
    } catch (e, stackTrace) {
      _logger.e('❌ 대기실 확인 중 예외 발생', error: e, stackTrace: stackTrace);
      _updateAutomationState(
        ZoomAutomationStage.failed,
        '대기실 확인 도중 오류가 발생했습니다.',
        isError: true,
      );
      return false;
    } finally {
      ZoomAutomationBindings.cleanupUIAutomation();
    }
  }

  /// 호스트가 회의를 시작했는지 주기적으로 감시한다.
  /// 입력: [maxAttempts]는 최대 반복 횟수, [interval]은 재확인 간격이다.
  /// 출력: 호스트가 시작하면 true, 제한 시간 초과 시 false.
  /// 예외: UI Automation 접근 실패 시 false 반환.
  Future<bool> waitForHostToStart({
    int maxAttempts = 20,
    Duration interval = const Duration(seconds: 30),
  }) async {
    try {
      _logger.i('🔍 호스트 시작 여부 확인');
      await _notifyTray('호스트 대기 중', '호스트가 회의를 시작할 때까지 기다립니다.');
      _updateAutomationState(
        ZoomAutomationStage.waitingHost,
        '호스트가 회의를 시작할 때까지 대기 중입니다.',
      );
      if (ZoomAutomationBindings.initializeUIAutomation() == 0) {
        _logger.e('❌ UI Automation 초기화 실패 (호스트 확인)');
        _updateAutomationState(
          ZoomAutomationStage.failed,
          '호스트 확인용 UI Automation 초기화에 실패했습니다.',
          isError: true,
        );
        return false;
      }

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        final hostNotReady = automationBool(
          ZoomAutomationBindings.checkHostNotStarted(),
        );
        if (!hostNotReady) {
          _logger.i('✅ 호스트 시작 감지 (시도 $attempt/$maxAttempts)');
          await _notifyTray('호스트 시작', '회의가 시작되었습니다. 녹화를 준비합니다.');
          _updateAutomationState(
            ZoomAutomationStage.recordingReady,
            '회의가 시작되었습니다. 녹화를 곧 시작합니다.',
          );
          return true;
        }

        _logger.d('⏳ 호스트 대기 중… ${interval.inSeconds}초 뒤 다시 확인');
        await Future.delayed(interval);
      }

      _logger.w('⚠️ 호스트 미시작으로 10분 제한 시간 초과');
      await _notifyTray('호스트 대기 시간 초과', '10분 동안 회의가 시작되지 않았습니다.');
      _updateAutomationState(
        ZoomAutomationStage.failed,
        '호스트가 10분 동안 회의를 시작하지 않았습니다.',
        isError: true,
      );
      return false;
    } catch (e, stackTrace) {
      _logger.e('❌ 호스트 확인 중 예외 발생', error: e, stackTrace: stackTrace);
      _updateAutomationState(
        ZoomAutomationStage.failed,
        '호스트 확인 도중 오류가 발생했습니다.',
        isError: true,
      );
      return false;
    } finally {
      ZoomAutomationBindings.cleanupUIAutomation();
    }
  }

  /// "Join with Computer Audio" 버튼을 클릭하여 오디오와 함께 회의에 참가한다.
  /// 입력: 없음
  /// 출력: 성공하면 true, 실패하면 false
  /// 예외: UI Automation 초기화 실패 시 false 반환
  Future<bool> joinWithAudio() async {
    try {
      _logger.i('🔊 오디오와 함께 참가 시도');

      if (ZoomAutomationBindings.initializeUIAutomation() == 0) {
        _logger.e('❌ UI Automation 초기화 실패 (오디오 참가)');
        return false;
      }

      final result = automationBool(ZoomAutomationBindings.joinWithAudio());
      if (result) {
        _logger.i('✅ 오디오 참가 버튼 클릭 완료');
        await _notifyTray('오디오 참가', '컴퓨터 오디오로 회의에 참가했습니다.');
      } else {
        _logger.w('⚠️ 오디오 참가 버튼을 찾을 수 없습니다');
      }

      return result;
    } catch (e, stackTrace) {
      _logger.e('❌ 오디오 참가 실패', error: e, stackTrace: stackTrace);
      return false;
    } finally {
      ZoomAutomationBindings.cleanupUIAutomation();
    }
  }

  /// 비디오를 켜거나 끈다.
  /// 입력: [enable]이 true면 비디오 켜기, false면 비디오 끄기
  /// 출력: 성공하면 true, 실패하면 false
  /// 예외: UI Automation 초기화 실패 시 false 반환
  Future<bool> setVideoEnabled(bool enable) async {
    try {
      _logger.i('📹 비디오 ${enable ? "켜기" : "끄기"} 시도');

      if (ZoomAutomationBindings.initializeUIAutomation() == 0) {
        _logger.e('❌ UI Automation 초기화 실패 (비디오 설정)');
        return false;
      }

      final result = automationBool(
        ZoomAutomationBindings.setVideoEnabled(enable ? 1 : 0),
      );

      if (result) {
        _logger.i('✅ 비디오 ${enable ? "켜기" : "끄기"} 완료');
        await _notifyTray(
          '비디오 설정',
          '비디오를 ${enable ? "켰습니다" : "껐습니다"}.',
        );
      } else {
        _logger.w('⚠️ 비디오 설정 버튼을 찾을 수 없습니다');
      }

      return result;
    } catch (e, stackTrace) {
      _logger.e('❌ 비디오 설정 실패', error: e, stackTrace: stackTrace);
      return false;
    } finally {
      ZoomAutomationBindings.cleanupUIAutomation();
    }
  }

  /// 마이크를 음소거하거나 음소거 해제한다.
  /// 입력: [mute]가 true면 음소거, false면 음소거 해제
  /// 출력: 성공하면 true, 실패하면 false
  /// 예외: UI Automation 초기화 실패 시 false 반환
  Future<bool> setMuted(bool mute) async {
    try {
      _logger.i('🎤 마이크 ${mute ? "음소거" : "음소거 해제"} 시도');

      if (ZoomAutomationBindings.initializeUIAutomation() == 0) {
        _logger.e('❌ UI Automation 초기화 실패 (음소거 설정)');
        return false;
      }

      final result = automationBool(
        ZoomAutomationBindings.setMuted(mute ? 1 : 0),
      );

      if (result) {
        _logger.i('✅ 마이크 ${mute ? "음소거" : "음소거 해제"} 완료');
        await _notifyTray(
          '마이크 설정',
          '마이크를 ${mute ? "음소거했습니다" : "켰습니다"}.',
        );
      } else {
        _logger.w('⚠️ 음소거 버튼을 찾을 수 없습니다');
      }

      return result;
    } catch (e, stackTrace) {
      _logger.e('❌ 음소거 설정 실패', error: e, stackTrace: stackTrace);
      return false;
    } finally {
      ZoomAutomationBindings.cleanupUIAutomation();
    }
  }
}
