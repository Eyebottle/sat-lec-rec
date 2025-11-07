import 'package:flutter/material.dart';
import '../style/app_colors.dart';
import '../style/app_typography.dart';
import '../style/app_spacing.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';

/// UI 컴포넌트 테스트 화면
///
/// 새로운 디자인 시스템의 버튼과 카드 컴포넌트를 시각적으로 확인할 수 있는 화면입니다.
/// 이 파일은 개발 중 테스트 용도로만 사용되며, 실제 배포 시에는 제거할 수 있습니다.
///
/// 사용 방법:
/// MaterialApp의 home을 ComponentTestScreen()으로 임시 변경하여 확인
class ComponentTestScreen extends StatelessWidget {
  const ComponentTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '디자인 시스템 테스트',
          style: AppTypography.titleLarge,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 버튼 섹션
            _buildSection(
              title: '버튼 컴포넌트',
              child: Column(
                children: [
                  // Primary 버튼
                  AppButton(
                    onPressed: () => _showMessage(context, 'Primary 버튼 클릭'),
                    child: const Text('Primary 버튼'),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Tonal 버튼 (새로 추가!)
                  AppButton.tonal(
                    onPressed: () => _showMessage(context, 'Tonal 버튼 클릭'),
                    child: const Text('Tonal 버튼 (새로운 스타일)'),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Secondary 버튼
                  AppButton.secondary(
                    onPressed: () => _showMessage(context, 'Secondary 버튼 클릭'),
                    child: const Text('Secondary 버튼'),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 아이콘 버튼
                  AppButton.primary(
                    onPressed: () => _showMessage(context, '녹화 시작'),
                    icon: Icons.fiber_manual_record,
                    child: const Text('녹화 시작'),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Success 버튼
                  AppButton.success(
                    onPressed: () => _showMessage(context, '성공!'),
                    icon: Icons.check_circle,
                    child: const Text('저장'),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Error 버튼
                  AppButton.error(
                    onPressed: () => _showMessage(context, '삭제'),
                    icon: Icons.delete,
                    child: const Text('삭제'),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 크기 변형
                  Row(
                    children: [
                      Expanded(
                        child: AppButtonSize.small(
                          onPressed: () =>
                              _showMessage(context, '작은 버튼 클릭'),
                          child: const Text('작은 버튼'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButtonSize.large(
                          onPressed: () => _showMessage(context, '큰 버튼 클릭'),
                          icon: Icons.star,
                          child: const Text('큰 버튼'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 카드 섹션
            _buildSection(
              title: '카드 컴포넌트',
              child: Column(
                children: [
                  // Level 1 카드
                  AppCard.level1(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level 1 카드',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '일반적인 정보 표시에 사용됩니다.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Level 2 카드 (강조)
                  AppCard.level2(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level 2 카드',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '중요한 정보나 입력 폼에 사용됩니다.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 클릭 가능한 카드
                  AppCard.level1(
                    onTap: () => _showMessage(context, '카드 클릭됨!'),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            '클릭 가능한 카드 (호버 효과 확인)',
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 설정 카드
                  SettingsCard(
                    icon: Icons.video_settings,
                    title: '비디오 설정',
                    description: '해상도, FPS, CRF 조정',
                    onTap: () => _showMessage(context, '비디오 설정 열기'),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 통계 카드 (2개를 나란히)
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.video_library,
                          label: '총 녹화 수',
                          value: '24',
                          trend: '+5',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: StatCard(
                          icon: Icons.schedule,
                          label: '다음 예약',
                          value: '토 11:42',
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 색상 팔레트
            _buildSection(
              title: '색상 시스템',
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _buildColorChip('Primary', AppColors.primary),
                  _buildColorChip('Primary Light', AppColors.primaryLight),
                  _buildColorChip('Primary Dark', AppColors.primaryDark),
                  _buildColorChip('Success', AppColors.success),
                  _buildColorChip('Error', AppColors.error),
                  _buildColorChip('Warning', AppColors.warning),
                  _buildColorChip('Info', AppColors.info),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 섹션 제목과 내용을 감싸는 위젯
  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }

  /// 색상 칩 위젯
  Widget _buildColorChip(String label, Color color) {
    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide(color: color),
    );
  }

  /// 메시지 표시
  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
