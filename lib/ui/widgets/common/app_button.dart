import 'package:flutter/material.dart';
import '../../style/app_colors.dart';
import '../../style/app_typography.dart';

/// sat-lec-rec 앱의 표준 버튼 위젯
///
/// Material 3 디자인 시스템을 따르는 일관된 버튼 스타일을 제공합니다.
///
/// 사용 예시:
/// ```dart
/// AppButton(
///   onPressed: () {},
///   child: Text('저장'),
/// )
///
/// AppButton.secondary(
///   onPressed: () {},
///   icon: Icons.test_tube,
///   child: Text('테스트'),
/// )
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
    this.backgroundColor,
  }) : _type = _ButtonType.filled;

  const AppButton.primary({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
    this.backgroundColor,
  }) : _type = _ButtonType.filled;

  /// 부드러운 톤의 버튼 (Material 3 FilledButton.tonal)
  /// 중요하지만 Primary보다 덜 강조되는 액션에 사용
  const AppButton.tonal({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
    this.backgroundColor,
  }) : _type = _ButtonType.tonal;

  const AppButton.secondary({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
    this.backgroundColor,
  }) : _type = _ButtonType.outlined;

  const AppButton.text({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
    this.backgroundColor,
  }) : _type = _ButtonType.text;

  const AppButton.success({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
    this.backgroundColor,
  }) : _type = _ButtonType.success;

  const AppButton.error({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
    this.backgroundColor,
  }) : _type = _ButtonType.error;

  /// 외곽선 버튼 (outlined style)
  /// secondary와 동일하지만 명시적인 이름 제공
  const AppButton.outline({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
    this.backgroundColor,
  }) : _type = _ButtonType.outlined;

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final IconData? icon;
  final Color? backgroundColor;
  final _ButtonType _type;

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return _buildIconButton(context);
    }
    return _buildButton(context);
  }

  Widget _buildButton(BuildContext context) {
    switch (_type) {
      case _ButtonType.filled:
        return FilledButton(
          onPressed: onPressed,
          style: style ?? _getDefaultFilledStyle(backgroundColor ?? AppColors.primary),
          child: child,
        );

      case _ButtonType.tonal:
        return FilledButton.tonal(
          onPressed: onPressed,
          style: style ?? _getDefaultTonalStyle(),
          child: child,
        );

      case _ButtonType.outlined:
        return OutlinedButton(
          onPressed: onPressed,
          style: style ?? _getDefaultOutlinedStyle(AppColors.primary),
          child: child,
        );

      case _ButtonType.text:
        return TextButton(
          onPressed: onPressed,
          style: style ?? _getDefaultTextStyle(AppColors.primary),
          child: child,
        );

      case _ButtonType.success:
        return FilledButton(
          onPressed: onPressed,
          style: style ?? _getDefaultFilledStyle(AppColors.success),
          child: child,
        );

      case _ButtonType.error:
        return FilledButton(
          onPressed: onPressed,
          style: style ?? _getDefaultFilledStyle(AppColors.error),
          child: child,
        );
    }
  }

  Widget _buildIconButton(BuildContext context) {
    switch (_type) {
      case _ButtonType.filled:
        return FilledButton.icon(
          onPressed: onPressed,
          style: style ?? _getDefaultFilledStyle(backgroundColor ?? AppColors.primary),
          icon: Icon(icon),
          label: child,
        );

      case _ButtonType.tonal:
        return FilledButton.tonalIcon(
          onPressed: onPressed,
          style: style ?? _getDefaultTonalStyle(),
          icon: Icon(icon),
          label: child,
        );

      case _ButtonType.outlined:
        return OutlinedButton.icon(
          onPressed: onPressed,
          style: style ?? _getDefaultOutlinedStyle(AppColors.primary),
          icon: Icon(icon),
          label: child,
        );

      case _ButtonType.text:
        return TextButton.icon(
          onPressed: onPressed,
          style: style ?? _getDefaultTextStyle(AppColors.primary),
          icon: Icon(icon),
          label: child,
        );

      case _ButtonType.success:
        return FilledButton.icon(
          onPressed: onPressed,
          style: style ?? _getDefaultFilledStyle(AppColors.success),
          icon: Icon(icon),
          label: child,
        );

      case _ButtonType.error:
        return FilledButton.icon(
          onPressed: onPressed,
          style: style ?? _getDefaultFilledStyle(AppColors.error),
          icon: Icon(icon),
          label: child,
        );
    }
  }

  static ButtonStyle _getDefaultFilledStyle(Color color) {
    return FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: AppColors.textOnPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: AppTypography.labelLarge,
      elevation: 0,
    );
  }

  static ButtonStyle _getDefaultTonalStyle() {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.primaryContainer,
      foregroundColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: AppTypography.labelLarge,
      elevation: 0,
    );
  }

  static ButtonStyle _getDefaultOutlinedStyle(Color color) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: BorderSide(color: color, width: 1.5),
      textStyle: AppTypography.labelLarge,
    );
  }

  static ButtonStyle _getDefaultTextStyle(Color color) {
    return TextButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: AppTypography.labelLarge,
    );
  }
}

enum _ButtonType {
  filled,
  tonal,
  outlined,
  text,
  success,
  error,
}

/// 크기별 버튼 확장
extension AppButtonSize on AppButton {
  /// 작은 버튼 (Windows Desktop에서도 충분한 클릭 영역 제공)
  static Widget small({
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
    bool outlined = false,
  }) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            side: BorderSide(color: AppColors.primary, width: 1.5),
            textStyle: AppTypography.labelMedium,
          )
        : FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: AppTypography.labelMedium,
          );

    if (icon != null) {
      return outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 18),
              label: child,
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 18),
              label: child,
            );
    }

    return outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: style,
            child: child,
          )
        : FilledButton(
            onPressed: onPressed,
            style: style,
            child: child,
          );
  }

  /// 큰 버튼 (Desktop에 최적화된 큰 터치 영역)
  static Widget large({
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
    bool outlined = false,
  }) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(color: AppColors.primary, width: 2),
            textStyle: AppTypography.titleMedium,
          )
        : FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: AppTypography.titleMedium,
          );

    if (icon != null) {
      return outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 24),
              label: child,
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 24),
              label: child,
            );
    }

    return outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: style,
            child: child,
          )
        : FilledButton(
            onPressed: onPressed,
            style: style,
            child: child,
          );
  }
}
