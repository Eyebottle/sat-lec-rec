import 'package:flutter/material.dart';
import '../../style/app_colors.dart';
import '../../style/app_elevation.dart';

/// sat-lec-rec 앱의 표준 카드 위젯
///
/// Material 3 디자인 시스템을 따르는 재사용 가능한 카드 컴포넌트입니다.
/// 3가지 elevation 레벨을 제공하여 UI 계층 구조를 명확히 합니다.
///
/// 사용 예시:
/// ```dart
/// // 기본 카드
/// AppCard(
///   child: Text('내용'),
/// )
///
/// // 강조 카드
/// AppCard.level2(
///   child: Text('중요한 내용'),
/// )
///
/// // 클릭 가능한 카드
/// AppCard.level1(
///   onTap: () => print('탭됨'),
///   child: Text('클릭 가능'),
/// )
/// ```
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.elevation = 1,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.onTap,
    this.shadows,
  });

  /// Elevation Level 1 카드 (기본)
  /// 사용처: 정보 표시, 일반 카드
  const AppCard.level1({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.onTap,
  })  : elevation = 1,
        shadows = null;

  /// Elevation Level 2 카드 (강조)
  /// 사용처: 주요 카드, 활성 요소, 입력 폼
  const AppCard.level2({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.onTap,
  })  : elevation = 2,
        shadows = null;

  /// Elevation Level 3 카드 (부상)
  /// 사용처: 다이얼로그 내부 카드, 중요한 요소
  const AppCard.level3({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.onTap,
  })  : elevation = 3,
        shadows = null;

  /// Primary 색상 강조 카드
  const AppCard.primary({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
  })  : elevation = 2,
        color = null,
        border = null,
        shadows = null;

  /// 카드 내용
  final Widget child;

  /// Elevation 레벨 (1-3)
  /// 숫자가 높을수록 카드가 더 위로 떠 있는 느낌을 줍니다.
  final int elevation;

  /// 카드 내부 여백
  /// 기본값: 20px (모든 방향)
  final EdgeInsetsGeometry? padding;

  /// 카드 외부 여백
  final EdgeInsetsGeometry? margin;

  /// 카드 모서리 둥글기
  /// 기본값: 20px
  final BorderRadius? borderRadius;

  /// 카드 배경색
  /// 기본값: AppColors.surface (흰색)
  final Color? color;

  /// 카드 테두리
  final BoxBorder? border;

  /// 탭 이벤트 핸들러
  /// null이 아니면 카드를 클릭할 수 있게 됩니다.
  final VoidCallback? onTap;

  /// 커스텀 그림자 (null이면 elevation 기반 자동 설정)
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(20);
    final effectiveColor = color ?? AppColors.surface;
    final effectivePadding = padding ?? const EdgeInsets.all(20);
    final effectiveShadows = shadows ?? AppElevation.getShadow(elevation);

    Widget content = Container(
      padding: effectivePadding,
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: effectiveBorderRadius,
        border: border ??
            Border.all(
              color: AppColors.surfaceBorder,
              width: 1,
            ),
        boxShadow: effectiveShadows,
      ),
      child: child,
    );

    // 클릭 가능한 카드인 경우 InkWell로 감싸기 (호버 효과 포함)
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          // Windows Desktop 호버 효과 강화
          hoverColor: AppColors.surfaceHover,
          splashColor: AppColors.primaryContainer,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// 설정 항목용 카드
///
/// 아이콘, 제목, 설명, 오른쪽 위젯을 포함하는 설정 항목 카드입니다.
///
/// 사용 예시:
/// ```dart
/// SettingsCard(
///   icon: Icons.volume_up,
///   title: '오디오 설정',
///   description: '마이크 및 오디오 장치 설정',
///   onTap: () => _showAudioSettings(),
/// )
/// ```
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.trailing,
    this.onTap,
  });

  /// 설정 아이콘
  final IconData icon;

  /// 설정 제목
  final String title;

  /// 설정 설명
  final String description;

  /// 오른쪽에 표시할 위젯 (예: Switch, Badge 등)
  final Widget? trailing;

  /// 탭 이벤트 핸들러
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard.level1(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          // 아이콘 컨테이너
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          // 제목 및 설명
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 오른쪽 위젯 또는 화살표 아이콘
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ] else if (onTap != null)
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
  }
}

/// 통계 표시용 카드
///
/// 아이콘, 라벨, 값, 추세를 포함하는 통계 표시 카드입니다.
///
/// 사용 예시:
/// ```dart
/// StatCard(
///   icon: Icons.video_library,
///   label: '총 녹화 수',
///   value: '24',
///   trend: '+5',
/// )
/// ```
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.trend,
    this.color,
  });

  /// 통계 아이콘
  final IconData icon;

  /// 통계 라벨 (예: "총 녹화 수")
  final String label;

  /// 통계 값 (예: "24")
  final String value;

  /// 추세 표시 (예: "+5", "-2") - 선택사항
  final String? trend;

  /// 아이콘 및 강조 색상 - 선택사항
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? AppColors.primary;

    return AppCard.level1(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 아이콘 컨테이너
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: effectiveColor, size: 20),
              ),
              const Spacer(),
              // 추세 배지
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trend!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 라벨
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          // 값
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
