// 무엇을 하는 코드인지: Zoom 자동화 기능을 테스트하기 위한 간소화된 화면
import 'package:flutter/material.dart';
import '../../services/zoom_launcher_service.dart';
import '../../services/settings_service.dart';
import '../../services/recorder_service.dart';
import '../../models/zoom_automation_state.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';
import '../style/app_colors.dart';
import '../style/app_typography.dart';
import '../style/app_spacing.dart';

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
  final RecorderService _recorderService = RecorderService();

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

  /// 전체 자동 테스트 실행 (단순화 버전)
  /// 복잡한 대기실 감지 로직 없이, 단순하게 "링크 열기 → 기다리기 → 최대화"
  Future<void> _runFullAutoTest() async {
    // 입력 필드 우선, 비어있으면 저장된 테스트 링크 사용
    final testLink = _zoomLinkController.text.isNotEmpty 
        ? _zoomLinkController.text 
        : (_settingsService.settings.testZoomLink ?? '');

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
      _lastResult = '🚀 전체 자동 테스트 시작 (단순 모드)...\n'
          '링크: $testLink';
    });

    try {
      // 1단계: 기존 Zoom 종료
      setState(() => _lastResult = '1/5 🧹 기존 Zoom 종료 중...');
      await _zoomService.closeZoomMeeting(force: true);
      await Future.delayed(const Duration(seconds: 3));

      // 2단계: Zoom 링크 실행 (개별 테스트 "Zoom 링크 실행"과 동일)
      setState(() => _lastResult = '2/5 🌐 Zoom 링크 실행 중...');
      final launchSuccess = await _zoomService.launchZoomMeeting(
        zoomLink: testLink,
        waitSeconds: 8,  // 8초 대기
      );
      
      if (!launchSuccess) {
        setState(() => _lastResult = '❌ 2/5 단계 실패: Zoom 링크 실행 실패');
        return;
      }

      // 3단계: 충분히 대기 (대기실 입장 + 호스트 승인 대기)
      setState(() => _lastResult = '3/5 ⏳ 대기실/입장 대기 중... (15초)\n'
          '💡 호스트가 승인해주세요!');
      await Future.delayed(const Duration(seconds: 15));

      // 4단계: 창 최대화 시도
      setState(() => _lastResult = '4/5 🖥️ Zoom 창 최대화 시도 중...');
      _zoomService.maximizeZoomWindow();
      await Future.delayed(const Duration(seconds: 2));

      // 5단계: 10초간 유지
      setState(() => _lastResult = '5/5 ✅ 테스트 완료 대기 중... (10초)');
      await Future.delayed(const Duration(seconds: 10));

      // 종료
      setState(() => _lastResult = '🚪 Zoom 종료 중...');
      await _zoomService.closeZoomMeeting(force: true);

      setState(() {
        _lastResult = '✅ 전체 자동 테스트 성공!\n\n'
            '단순 모드로 완료:\n'
            '1. Zoom 종료 ✅\n'
            '2. 링크 실행 ✅\n'
            '3. 15초 대기 ✅\n'
            '4. 창 최대화 ✅\n'
            '5. 10초 유지 ✅';
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

  /// 녹화 포함 전체 테스트 실행 (단순화 버전)
  Future<void> _runFullRecordingTest() async {
    // 입력 필드 우선, 비어있으면 저장된 테스트 링크 사용
    final testLink = _zoomLinkController.text.isNotEmpty 
        ? _zoomLinkController.text 
        : (_settingsService.settings.testZoomLink ?? '');

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
      _lastResult = '🎬 녹화 통합 테스트 시작 (단순 모드)...\n'
          '링크: $testLink';
    });

    try {
      // 1. 기존 프로세스 정리
      setState(() => _lastResult = '1/6 🧹 기존 Zoom 종료 중...');
      await _zoomService.closeZoomMeeting(force: true);
      await Future.delayed(const Duration(seconds: 3));

      // 2. Zoom 링크 실행
      setState(() => _lastResult = '2/6 🌐 Zoom 링크 실행 중...');
      final launchSuccess = await _zoomService.launchZoomMeeting(
        zoomLink: testLink,
        waitSeconds: 8,
      );

      if (!launchSuccess) {
        setState(() => _lastResult = '❌ 2/6 단계 실패: Zoom 링크 실행 실패');
        return;
      }

      // 3. 대기실/입장 대기
      setState(() => _lastResult = '3/6 ⏳ 대기실/입장 대기 중... (15초)\n'
          '💡 호스트가 승인해주세요!');
      await Future.delayed(const Duration(seconds: 15));

      // 4. 창 최대화 및 녹화 시작
      setState(() => _lastResult = '4/6 🖥️ 창 최대화 및 녹화 시작...');
      _zoomService.maximizeZoomWindow();
      await Future.delayed(const Duration(seconds: 2));

      // 녹화 시작
      final filePath = await _recorderService.startRecording(
        durationSeconds: 30,
      );
      if (filePath == null) {
        setState(() => _lastResult = '❌ 4/6 단계 실패: 녹화 시작 실패');
        return;
      }

      // 5. 녹화 진행 중 대기
      for (int i = 30; i > 0; i--) {
        setState(() => _lastResult = '5/6 ⏱️ 녹화 중... (남은 시간: ${i}초)\n파일: $filePath');
        await Future.delayed(const Duration(seconds: 1));
      }

      // 6. 종료
      setState(() => _lastResult = '6/6 🚪 Zoom 종료 중...');
      await Future.delayed(const Duration(seconds: 2));
      await _zoomService.closeZoomMeeting(force: true);

      setState(() {
        _lastResult = '✅ 녹화 통합 테스트 성공!\n\n'
            '단순 모드로 완료:\n'
            '1. Zoom 링크 실행 ✅\n'
            '2. 15초 대기 ✅\n'
            '3. 창 최대화 ✅\n'
            '4. 30초 녹화 ✅\n'
            '5. Zoom 종료 ✅\n\n'
            '📁 녹화 파일: $filePath';
      });
    } catch (e) {
      setState(() {
        _lastResult = '❌ 녹화 통합 테스트 예외 발생: $e';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Zoom 자동화 테스트', style: AppTypography.titleLarge),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 안내 카드
            AppCard.level1(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.info, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        '테스트 방법',
                        style: AppTypography.titleMedium.copyWith(color: AppColors.info),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Zoom 자동화 기능을 테스트합니다. pwd가 포함된 링크 사용을 권장합니다.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Zoom 링크 입력 (pwd 포함)\n'
                    '2. "전체 자동 테스트" 버튼으로 원클릭 테스트\n'
                    '3. 또는 개별 버튼으로 단계별 테스트',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 전체 자동 테스트 버튼 (가장 중요)
            AppCard.level2(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.rocket_launch_rounded, color: AppColors.success, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '원클릭 전체 자동 테스트',
                              style: AppTypography.titleLarge.copyWith(color: AppColors.success),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '저장된 링크로 모든 단계를 자동 실행합니다 (약 20초)',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      onPressed: _isProcessing ? null : _runFullAutoTest,
                      backgroundColor: AppColors.success,
                      icon: Icons.play_arrow_rounded,
                      child: const Text('전체 자동 테스트 시작'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (_settingsService.settings.testZoomLink?.isNotEmpty ?? false)
                        ? '✅ 저장된 테스트 링크 사용 중'
                        : '⚠️ 설정에서 테스트 링크를 저장하거나 아래 필드에 입력하세요',
                    style: AppTypography.labelSmall.copyWith(
                      color: (_settingsService.settings.testZoomLink?.isNotEmpty ?? false)
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // 녹화 통합 테스트 버튼
            AppCard.level2(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.videocam_rounded, color: Color(0xFF9C27B0), size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '녹화 통합 테스트',
                              style: AppTypography.titleLarge.copyWith(color: Color(0xFF9C27B0)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Zoom 참가 + 30초 녹화 + 종료 (약 1분)',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      onPressed: _isProcessing ? null : _runFullRecordingTest,
                      backgroundColor: Color(0xFF9C27B0),
                      icon: Icons.fiber_manual_record_rounded,
                      child: const Text('녹화 통합 테스트 시작'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Zoom 링크 입력
            TextField(
              controller: _zoomLinkController,
              decoration: const InputDecoration(
                labelText: 'Zoom 회의 링크 (pwd 포함)',
                prefixIcon: Icon(Icons.link),
                hintText: 'https://zoom.us/j/xxxxx?pwd=yyyyy',
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 사용자 이름 입력
            TextField(
              controller: _userNameController,
              decoration: const InputDecoration(
                labelText: '참가자 이름',
                prefixIcon: Icon(Icons.person_outline),
                hintText: '녹화 시스템',
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 개별 테스트 버튼들
            _buildSectionTitle('개별 테스트'),

            _buildTestButton(
              icon: Icons.launch_rounded,
              label: 'Zoom 링크 실행',
              color: AppColors.primary,
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
              icon: Icons.login_rounded,
              label: '이름 입력 + 참가 버튼 클릭',
              color: AppColors.secondary,
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
              icon: Icons.exit_to_app_rounded,
              label: 'Zoom 종료',
              color: AppColors.error,
              onPressed: () => _runTest(
                'Zoom 종료',
                () => _zoomService.closeZoomMeeting(),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 결과 표시
            AppCard.level1(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _lastResult.contains('✅')
                            ? Icons.check_circle_rounded
                            : _lastResult.contains('❌')
                                ? Icons.error_rounded
                                : Icons.info_rounded,
                        color: _lastResult.contains('✅')
                            ? AppColors.success
                            : _lastResult.contains('❌')
                                ? AppColors.error
                                : AppColors.neutral500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '테스트 결과',
                        style: AppTypography.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _lastResult,
                      style: AppTypography.bodySmall.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(top: 12.0),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // 자동화 상태 리스너
            ValueListenableBuilder<ZoomAutomationState>(
              valueListenable: _zoomService.automationState,
              builder: (context, state, child) {
                return AppCard.level1(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            state.isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                            color: state.isError ? AppColors.error : AppColors.info,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '자동화 상태',
                            style: AppTypography.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('단계: ${state.stage.toString().split('.').last}'),
                      Text('메시지: ${state.message}'),
                      Text('시간: ${state.updatedAt.toString().substring(11, 19)}'),
                    ],
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
        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTestButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        onPressed: _isProcessing ? null : onPressed,
        backgroundColor: color,
        icon: icon,
        child: Text(label),
      ),
    );
  }
}
