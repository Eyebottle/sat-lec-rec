// 무엇을 하는 코드인지: Zoom 자동화 기능을 테스트하기 위한 화면
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/zoom_launcher_service.dart';
import '../../models/zoom_automation_state.dart';

/// Zoom 자동화 테스트 화면
///
/// 입력: 없음
/// 출력: 각 Zoom 자동화 기능을 테스트할 수 있는 UI
/// 예외: ZoomLauncherService 초기화 실패 시 에러 메시지 표시
class ZoomTestScreen extends StatefulWidget {
  const ZoomTestScreen({super.key});

  @override
  State<ZoomTestScreen> createState() => _ZoomTestScreenState();
}

class _ZoomTestScreenState extends State<ZoomTestScreen> {
  final ZoomLauncherService _zoomService = ZoomLauncherService();
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
                      '💡 가장 안전한 방법: Personal Meeting Room (PMI) 사용\n'
                      '• Zoom 웹사이트(zoom.us/profile)에서 개인 회의 ID 확인\n'
                      '• 링크 형식: https://zoom.us/j/당신의PMI번호\n'
                      '• 언제든 접속 가능한 고정 회의실입니다\n\n'
                      '1. 위 링크를 입력하거나 실제 Zoom 회의 링크 입력\n'
                      '2. "Zoom 링크 실행" 버튼으로 Zoom 앱 실행\n'
                      '3. 각 기능 버튼을 눌러 자동화 테스트\n'
                      '4. Zoom 창에서 실제로 버튼이 클릭되는지 확인',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // PMI 안내 다이얼로그
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('💡 PMI 찾는 방법'),
                            content: const SingleChildScrollView(
                              child: Text(
                                '방법 1: Zoom 웹사이트\n'
                                '1. zoom.us/profile 접속\n'
                                '2. 로그인\n'
                                '3. "개인 회의 ID" 섹션에서 확인\n\n'
                                '방법 2: Zoom 앱\n'
                                '1. Zoom 앱 실행\n'
                                '2. 설정(⚙️) → 프로필\n'
                                '3. "개인 회의 ID (PMI)" 확인\n\n'
                                '예시 링크:\n'
                                'https://zoom.us/j/1234567890',
                                style: TextStyle(height: 1.5),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('닫기'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.help_outline),
                      label: const Text('PMI 찾는 방법 보기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.blue.shade700,
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
                labelText: 'Zoom 회의 링크',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
                hintText: 'https://zoom.us/j/123456789',
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

            // 1단계: Zoom 실행
            _buildSectionTitle('1️⃣ Zoom 실행'),
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

            const SizedBox(height: 24),

            // 2단계: 자동 참가
            _buildSectionTitle('2️⃣ 자동 참가'),
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

            const SizedBox(height: 24),

            // 3단계: 오디오/비디오 설정
            _buildSectionTitle('3️⃣ 오디오/비디오 설정'),

            _buildTestButton(
              icon: Icons.volume_up,
              label: '컴퓨터 오디오로 참가',
              color: Colors.orange,
              onPressed: () => _runTest(
                '오디오 참가',
                _zoomService.joinWithAudio,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTestButton(
                    icon: Icons.videocam,
                    label: '비디오 켜기',
                    color: Colors.purple,
                    onPressed: () => _runTest(
                      '비디오 켜기',
                      () => _zoomService.setVideoEnabled(true),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTestButton(
                    icon: Icons.videocam_off,
                    label: '비디오 끄기',
                    color: Colors.grey,
                    onPressed: () => _runTest(
                      '비디오 끄기',
                      () => _zoomService.setVideoEnabled(false),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTestButton(
                    icon: Icons.mic,
                    label: '음소거 해제',
                    color: Colors.teal,
                    onPressed: () => _runTest(
                      '음소거 해제',
                      () => _zoomService.setMuted(false),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTestButton(
                    icon: Icons.mic_off,
                    label: '음소거',
                    color: Colors.red,
                    onPressed: () => _runTest(
                      '음소거',
                      () => _zoomService.setMuted(true),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 4단계: 상태 확인
            _buildSectionTitle('4️⃣ 상태 확인'),

            Row(
              children: [
                Expanded(
                  child: _buildTestButton(
                    icon: Icons.meeting_room,
                    label: '대기실 확인',
                    color: Colors.amber,
                    onPressed: () => _runTest(
                      '대기실 확인',
                      _zoomService.waitForWaitingRoomClear,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTestButton(
                    icon: Icons.person_search,
                    label: '호스트 대기 확인',
                    color: Colors.indigo,
                    onPressed: () => _runTest(
                      '호스트 대기',
                      _zoomService.waitForHostToStart,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 5단계: Zoom 종료
            _buildSectionTitle('5️⃣ 종료'),
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
