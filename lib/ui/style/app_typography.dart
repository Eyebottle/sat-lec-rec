import 'package:flutter/material.dart';

/// sat-lec-rec 강의녹화 앱의 디자인 토큰 - 타이포그래피
///
/// Material Design 3 Typography 기반으로 한글에 최적화된 텍스트 스타일을 제공합니다.
class AppTypography {
  AppTypography._();

  // ============================================================================
  // Font Families
  // ============================================================================

  /// 기본 폰트 (한글 최적화)
  static const String defaultFontFamily = 'Noto Sans KR';

  /// 영문 폰트 (숫자, 라틴 문자)
  static const String latinFontFamily = 'Inter';

  // ============================================================================
  // Display Styles (큰 제목)
  // ============================================================================

  /// Display Large - 가장 큰 제목 (57px)
  static const TextStyle displayLarge = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.25,
  );

  /// Display Medium - 큰 제목 (45px)
  static const TextStyle displayMedium = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
  );

  /// Display Small - 중간 큰 제목 (36px)
  static const TextStyle displaySmall = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0,
  );

  // ============================================================================
  // Headline Styles (헤드라인)
  // ============================================================================

  /// Headline Large - 큰 헤드라인 (32px)
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0,
  );

  /// Headline Medium - 중간 헤드라인 (28px)
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
  );

  /// Headline Small - 작은 헤드라인 (24px)
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
  );

  // ============================================================================
  // Title Styles (제목)
  // ============================================================================

  /// Title Large - 큰 제목 (22px) - 다이얼로그 제목 등
  static const TextStyle titleLarge = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: 0,
  );

  /// Title Medium - 중간 제목 (16px) - 카드 제목, 섹션 제목
  static const TextStyle titleMedium = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.15,
  );

  /// Title Small - 작은 제목 (14px) - 작은 카드 제목
  static const TextStyle titleSmall = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
  );

  // ============================================================================
  // Body Styles (본문)
  // ============================================================================

  /// Body Large - 큰 본문 (16px)
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.5,
  );

  /// Body Medium - 중간 본문 (14px) - 가장 일반적인 텍스트
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.25,
  );

  /// Body Small - 작은 본문 (12px) - 보조 설명
  static const TextStyle bodySmall = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.4,
  );

  // ============================================================================
  // Label Styles (라벨)
  // ============================================================================

  /// Label Large - 큰 라벨 (14px) - 버튼 텍스트
  static const TextStyle labelLarge = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
  );

  /// Label Medium - 중간 라벨 (12px) - 탭, 칩
  static const TextStyle labelMedium = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
  );

  /// Label Small - 작은 라벨 (11px) - 매우 작은 힌트, 캡션
  static const TextStyle labelSmall = TextStyle(
    fontFamily: defaultFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
  );

  // ============================================================================
  // Custom Styles (커스텀 스타일)
  // ============================================================================

  /// 숫자 표시용 스타일 (타이머, 통계 등)
  static const TextStyle numberLarge = TextStyle(
    fontFamily: latinFontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 중간 크기 숫자 표시
  static const TextStyle numberMedium = TextStyle(
    fontFamily: latinFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 작은 숫자 표시 (시간 등)
  static const TextStyle numberSmall = TextStyle(
    fontFamily: latinFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// TextTheme 생성 (Material 3)
  static TextTheme createTextTheme(Color baseColor) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: baseColor),
      displayMedium: displayMedium.copyWith(color: baseColor),
      displaySmall: displaySmall.copyWith(color: baseColor),
      headlineLarge: headlineLarge.copyWith(color: baseColor),
      headlineMedium: headlineMedium.copyWith(color: baseColor),
      headlineSmall: headlineSmall.copyWith(color: baseColor),
      titleLarge: titleLarge.copyWith(color: baseColor),
      titleMedium: titleMedium.copyWith(color: baseColor),
      titleSmall: titleSmall.copyWith(color: baseColor),
      bodyLarge: bodyLarge.copyWith(color: baseColor),
      bodyMedium: bodyMedium.copyWith(color: baseColor),
      bodySmall: bodySmall.copyWith(color: baseColor),
      labelLarge: labelLarge.copyWith(color: baseColor),
      labelMedium: labelMedium.copyWith(color: baseColor),
      labelSmall: labelSmall.copyWith(color: baseColor),
    );
  }
}
