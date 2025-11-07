import 'package:flutter/material.dart';
import 'app_colors.dart';

/// sat-lec-rec 강의녹화 앱의 디자인 토큰 - Elevation (고도/그림자)
///
/// Material Design 3 Elevation System을 기반으로 합니다.
/// 각 레벨은 UI 요소의 계층 구조와 중요도를 시각적으로 표현합니다.
class AppElevation {
  AppElevation._();

  // ============================================================================
  // Elevation Levels (고도 레벨)
  // ============================================================================

  /// Level 0 - 그림자 없음 (평면)
  /// 사용처: 배경, 기본 컨테이너
  static const double level0 = 0;

  /// Level 1 - 매우 약한 그림자 (1dp)
  /// 사용처: 카드, 칩, 정보 표시 요소
  static const double level1 = 1;

  /// Level 2 - 약한 그림자 (3dp)
  /// 사용처: 부상한 버튼, 중요한 카드, 활성 요소
  static const double level2 = 3;

  /// Level 3 - 중간 그림자 (6dp)
  /// 사용처: 다이얼로그, 모달, 드롭다운
  static const double level3 = 6;

  /// Level 4 - 강한 그림자 (8dp)
  /// 사용처: 내비게이션 드로어, 플로팅 요소
  static const double level4 = 8;

  /// Level 5 - 매우 강한 그림자 (12dp)
  /// 사용처: 최상위 오버레이, 알림
  static const double level5 = 12;

  // ============================================================================
  // Shadow Definitions (그림자 정의)
  // ============================================================================

  /// Level 1 Shadow - 미세한 그림자
  static List<BoxShadow> get shadow1 => [
        BoxShadow(
          color: AppColors.neutral900.withOpacity(0.05),
          offset: const Offset(0, 1),
          blurRadius: 2,
          spreadRadius: 0,
        ),
      ];

  /// Level 2 Shadow - 표준 카드 그림자
  static List<BoxShadow> get shadow2 => [
        BoxShadow(
          color: AppColors.neutral900.withOpacity(0.08),
          offset: const Offset(0, 2),
          blurRadius: 4,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: AppColors.neutral900.withOpacity(0.04),
          offset: const Offset(0, 1),
          blurRadius: 2,
          spreadRadius: 0,
        ),
      ];

  /// Level 3 Shadow - 부상한 요소 그림자
  static List<BoxShadow> get shadow3 => [
        BoxShadow(
          color: AppColors.neutral900.withOpacity(0.1),
          offset: const Offset(0, 4),
          blurRadius: 8,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: AppColors.neutral900.withOpacity(0.06),
          offset: const Offset(0, 2),
          blurRadius: 4,
          spreadRadius: 0,
        ),
      ];

  /// Level 4 Shadow - 모달/다이얼로그 그림자
  static List<BoxShadow> get shadow4 => [
        BoxShadow(
          color: AppColors.neutral900.withOpacity(0.12),
          offset: const Offset(0, 6),
          blurRadius: 12,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: AppColors.neutral900.withOpacity(0.08),
          offset: const Offset(0, 3),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ];

  /// Level 5 Shadow - 최상위 오버레이 그림자
  static List<BoxShadow> get shadow5 => [
        BoxShadow(
          color: AppColors.neutral900.withOpacity(0.15),
          offset: const Offset(0, 8),
          blurRadius: 16,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: AppColors.neutral900.withOpacity(0.1),
          offset: const Offset(0, 4),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ];

  // ============================================================================
  // Primary Color Shadows (Primary 색상 그림자)
  // ============================================================================

  /// Primary 색상의 부드러운 그림자 (강조 효과)
  static List<BoxShadow> get primaryShadow => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.15),
          offset: const Offset(0, 4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: AppColors.primary.withOpacity(0.1),
          offset: const Offset(0, 2),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ];

  /// Primary 색상의 강한 그림자 (호버/활성 상태)
  static List<BoxShadow> get primaryShadowStrong => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.25),
          offset: const Offset(0, 6),
          blurRadius: 16,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: AppColors.primary.withOpacity(0.15),
          offset: const Offset(0, 3),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ];

  // ============================================================================
  // Semantic Shadows (의미론적 그림자)
  // ============================================================================

  /// Success 상태 그림자 (녹색)
  static List<BoxShadow> get successShadow => [
        BoxShadow(
          color: AppColors.success.withOpacity(0.15),
          offset: const Offset(0, 4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ];

  /// Warning 상태 그림자 (노란색)
  static List<BoxShadow> get warningShadow => [
        BoxShadow(
          color: AppColors.warning.withOpacity(0.15),
          offset: const Offset(0, 4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ];

  /// Error 상태 그림자 (빨간색)
  static List<BoxShadow> get errorShadow => [
        BoxShadow(
          color: AppColors.error.withOpacity(0.15),
          offset: const Offset(0, 4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ];

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Elevation 레벨에 따른 그림자 반환
  static List<BoxShadow> getShadow(int level) {
    switch (level) {
      case 1:
        return shadow1;
      case 2:
        return shadow2;
      case 3:
        return shadow3;
      case 4:
        return shadow4;
      case 5:
        return shadow5;
      default:
        return [];
    }
  }

  /// 커스텀 색상의 그림자 생성
  static List<BoxShadow> createCustomShadow({
    required Color color,
    double opacity = 0.15,
    Offset offset = const Offset(0, 4),
    double blurRadius = 12,
    double spreadRadius = 0,
  }) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        offset: offset,
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
      ),
    ];
  }
}
