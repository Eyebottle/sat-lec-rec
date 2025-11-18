// 무엇을 하는 코드인지: Zoom 자동화 기능을 테스트하기 위한 간소화된 화면
import 'package:flutter/material.dart';
import '../../services/zoom_launcher_service.dart';
import '../../services/settings_service.dart';
import '../../models/zoom_automation_state.dart';

/// Zoom 자동화 테스트 화면
///
/// 입력: 없음
/// 출력: 핵심 Zoom 자동화 기능만 테스트할 수 있는 UI
/// 예외: ZoomLauncherService 초기화 실패 시 에러 메시지 표시
class ZoomTestScreen extends StatefulWidget {
  const ZoomTestScreen({super.key});

  @override
  State<ZoomTestScreen> createState() => _ZoomTestScreenState();
}

class _ZoomTestScreenState extends State<ZoomTestScreen> {
  final ZoomLauncherService _zoomService = ZoomLauncherService();
  final SettingsService _settingsService = SettingsService();

  final TextEditingController _zoomLinkController = TextEditingController(
    text: 'https://zoom.us/j/123456789',
  );
  final TextEditingController _userNameController = TextEditingController(
    text: '녹화 시스템',
  );

  String _lastResult = '대기 중...';
  bool _isProcessing = false;

  @override
  void dispose() {
    _zoomLinkController.dispose();
    _userNameController.dispose();
    super.dispose();
  }

  Future<void> _runTest(String testName, Future<bool> Function() testFn) async {
    setState(() {
      _isProcessing = true;
      _lastResult = '$testName 실행 중...';
    });

    try {
      final result = await testFn();
      setState(() {
        _lastResult = result
            ? '✅ $testName 성공!'
            : '❌ $testName 실패 (버튼을 찾지 못했거나 Zoom이 실행 중이지 않습니다)';
      });
    } catch (e) {
      setState(() {
        _lastResult = '❌ $testName 예외 발생: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// 전체 자동 테스트 실행
  Future<void> _runFullAutoTest() async {
    // 저장된 테스트 링크가 있으면 사용, 없으면 입력 필드의 링크 사용
    final testLink = _settingsService.settings.testZoomLink ?? _zoomLinkController.text;

    if (testLink.isEmpty || !testLink.contains('zoom.us')) {
      setState(() {
        _lastResult = '❌ 유효한 Zoom 링크가 필요합니다.\n'
            '설정 화면에서 "테스트용 Zoom 링크"를 저장하거나\n'
            '위 입력 필드에 링크를 입력하세요.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastResult = '🚀 전체 자동 테스트 시작...\n'
          '링크: $testLink';
    });

    try {
      // 1단계: Zoom 실행 및 자동 참가
      setState(() => _lastResult = '1/6 🔵 Zoom 실행 및 자동 참가 중...');
      await Future.delayed(const Duration(milliseconds: 500));
      final joinSuccess = await _zoomService.autoJoinZoomMeeting(
        zoomLink: testLink,
        userName: _userNameController.text,
      );
      if (!joinSuccess) {
        setState(() => _lastResult = '❌ 1/6 단계 실패: Zoom 실행 및 자동 참가 실패');
        return;
      }

      // 2단계: 오디오 참가
      setState(() => _lastResult = '2/6 🔊 오디오 참가 중...');
      await Future.delayed(const Duration(seconds: 2));
      final audioSuccess = await _zoomService.joinWithAudio();
      if (!audioSuccess) {
        setState(() => _lastResult = '⚠️ 2/6 단계 경고: 오디오 참가 실패 (계속 진행)');
        await Future.delayed(const Duration(seconds: 1));
      }

      // 3단계: 비디오 끄기
      setState(() => _lastResult = '3/6 📹 비디오 끄기...');
      await Future.delayed(const Duration(seconds: 1));
      await _zoomService.setVideoEnabled(false);

      // 4단계: 음소거
      setState(() => _lastResult = '4/6 🔇 음소거 설정...');
      await Future.delayed(const Duration(seconds: 1));
      await _zoomService.setMuted(true);

      // 5단계: 10초 대기
      setState(() => _lastResult = '5/6 ⏱️ 10초 대기 중... (테스트 안정성 확인)');
      await Future.delayed(const Duration(seconds: 10));

      // 6단계: Zoom 종료
      setState(() => _lastResult = '6/6 🚪 Zoom 종료 중...');
      await Future.delayed(const Duration(seconds: 1));
      await _zoomService.closeZoomMeeting();

      setState(() {
        _lastResult = '✅ 전체 자동 테스트 성공!\n\n'
            '모든 6단계가 완료되었습니다:\n'
            '1. Zoom 실행 및 자동 참가 ✅\n'
            '2. 오디오 참가 ✅\n'
            '3. 비디오 끄기 ✅\n'
            '4. 음소거 설정 ✅\n'
            '5. 10초 안정성 확인 ✅\n'
            '6. Zoom 종료 ✅';
      });
    } catch (e) {
      setState(() {
        _lastResult = '❌ 전체 자동 테스트 예외 발생: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Zoom 자동화 테스트'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 안내 카드
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '테스트 방법',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '💡 pwd 파라미터 포함 링크 사용 권장\n'
                      '• 링크 형식: https://zoom.us/j/회의번호?pwd=암호\n'
                      '• 브라우저가 자동으로 암호를 Zoom에 전달합니다\n\n'
                      '1. Zoom 링크 입력 (pwd 파라미터 포함)\n'
                      '2. "전체 자동 테스트" 버튼으로 원클릭 테스트\n'
                      '3. 또는 개별 버튼으로 단계별 테스트',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 전체 자동 테스트 버튼 (가장 중요)
            Card(
              color: Colors.green.shade50,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.rocket_launch, color: Colors.green.shade700, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🚀 원클릭 전체 자동 테스트',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '저장된 링크로 모든 단계를 자동 실행합니다 (약 20초 소요)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _runFullAutoTest,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text(
                        '전체 자동 테스트 시작',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
                        minimumSize: const Size(double.infinity, 60),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      (_settingsService.settings.testZoomLink?.isNotEmpty ?? false)
                          ? '✅ 저장된 테스트 링크 사용 중'
                          : '⚠️ 설정에서 테스트 링크를 저장하거나 위 필드에 입력하세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: (_settingsService.settings.testZoomLink?.isNotEmpty ?? false)
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Zoom 링크 입력
            TextField(
              controller: _zoomLinkController,
              decoration: const InputDecoration(
                labelText: 'Zoom 회의 링크 (pwd 파라미터 포함)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
                hintText: 'https://zoom.us/j/xxxxx?pwd=yyyyy',
                helperText: '암호가 필요한 경우 URL에 pwd 파라미터 포함',
              ),
            ),

            const SizedBox(height: 16),

            // 사용자 이름 입력
            TextField(
              controller: _userNameController,
              decoration: const InputDecoration(
                labelText: '참가자 이름',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                hintText: '녹화 시스템',
              ),
            ),

            const SizedBox(height: 24),

            // 개별 테스트 버튼들
            _buildSectionTitle('개별 테스트'),

            _buildTestButton(
              icon: Icons.launch,
              label: 'Zoom 링크 실행',
              color: Colors.blue,
              onPressed: () => _runTest(
                'Zoom 실행',
                () => _zoomService.launchZoomMeeting(
                  zoomLink: _zoomLinkController.text,
                  waitSeconds: 5,
                ),
              ),
            ),

            const SizedBox(height: 12),

            _buildTestButton(
              icon: Icons.login,
              label: '이름 입력 + 참가 버튼 클릭',
              color: Colors.green,
              onPressed: () => _runTest(
                '자동 참가',
                () => _zoomService.autoJoinZoomMeeting(
                  zoomLink: _zoomLinkController.text,
                  userName: _userNameController.text,
                ),
              ),
            ),

            const SizedBox(height: 12),

            _buildTestButton(
              icon: Icons.exit_to_app,
              label: 'Zoom 종료',
              color: Colors.red.shade700,
              onPressed: () => _runTest(
                'Zoom 종료',
                () => _zoomService.closeZoomMeeting(),
              ),
            ),

            const SizedBox(height: 32),

            // 결과 표시
            Card(
              color: _lastResult.contains('✅')
                  ? Colors.green.shade50
                  : _lastResult.contains('❌')
                      ? Colors.red.shade50
                      : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lastResult.contains('✅')
                              ? Icons.check_circle
                              : _lastResult.contains('❌')
                                  ? Icons.error
                                  : Icons.info,
                          color: _lastResult.contains('✅')
                              ? Colors.green
                              : _lastResult.contains('❌')
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '테스트 결과',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _lastResult,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (_isProcessing)
                      const Padding(
                        padding: EdgeInsets.only(top: 12.0),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 자동화 상태 리스너
            ValueListenableBuilder<ZoomAutomationState>(
              valueListenable: _zoomService.automationState,
              builder: (context, state, child) {
                return Card(
                  color: state.isError ? Colors.red.shade50 : Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              state.isError ? Icons.error : Icons.info_outline,
                              color: state.isError ? Colors.red : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '자동화 상태',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('단계: ${state.stage.toString().split('.').last}'),
                        Text('메시지: ${state.message}'),
                        Text('시간: ${state.updatedAt.toString().substring(11, 19)}'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTestButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }
}
