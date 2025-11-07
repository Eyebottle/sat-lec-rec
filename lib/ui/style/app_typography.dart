import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// sat-lec-rec 강의녹화 앱의 디자인 토큰 - 타이포그래피
///
/// Material Design 3 Typography 기반으로 한글에 최적화된 텍스트 스타일을 제공합니다.
/// Google Fonts를 사용하여 자동으로 폰트를 다운로드하고 적용합니다.
class AppTypography {
  AppTypography._();

  // ============================================================================
  // Font Families (Google Fonts 사용)
  // ============================================================================

  /// 기본 폰트 (한글 최적화) - Noto Sans KR
  /// Google Fonts에서 자동 다운로드
  static String get defaultFontFamily => GoogleFonts.notoSansKr().fontFamily!;

  /// 영문 폰트 (숫자, 라틴 문자) - Inter
  /// Google Fonts에서 자동 다운로드
  static String get latinFontFamily => GoogleFonts.inter().fontFamily!;

  // ============================================================================
  // Display Styles (큰 제목)
  // ============================================================================

  /// Display Large - 가장 큰 제목 (57px)
  static TextStyle get displayLarge => GoogleFonts.notoSansKr(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.25,
      );

  /// Display Medium - 큰 제목 (45px)
  static TextStyle get displayMedium => GoogleFonts.notoSansKr(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      );

  /// Display Small - 중간 큰 제목 (36px)
  static TextStyle get displaySmall => GoogleFonts.notoSansKr(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: 0,
      );

  // ============================================================================
  // Headline Styles (헤드라인)
  // ============================================================================

  /// Headline Large - 큰 헤드라인 (32px)
  static TextStyle get headlineLarge => GoogleFonts.notoSansKr(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: 0,
      );

  /// Headline Medium - 중간 헤드라인 (28px)
  static TextStyle get headlineMedium => GoogleFonts.notoSansKr(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0,
      );

  /// Headline Small - 작은 헤드라인 (24px)
  static TextStyle get headlineSmall => GoogleFonts.notoSansKr(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0,
      );

  // ============================================================================
  // Title Styles (제목)
  // ============================================================================

  /// Title Large - 큰 제목 (22px) - 다이얼로그 제목 등
  static TextStyle get titleLarge => GoogleFonts.notoSansKr(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.4,
        letterSpacing: 0,
      );

  /// Title Medium - 중간 제목 (16px) - 카드 제목, 섹션 제목
  static TextStyle get titleMedium => GoogleFonts.notoSansKr(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.15,
      );

  /// Title Small - 작은 제목 (14px) - 작은 카드 제목
  static TextStyle get titleSmall => GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.1,
      );

  // ============================================================================
  // Body Styles (본문)
  // ============================================================================

  /// Body Large - 큰 본문 (16px)
  static TextStyle get bodyLarge => GoogleFonts.notoSansKr(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.5,
      );

  /// Body Medium - 중간 본문 (14px) - 가장 일반적인 텍스트
  static TextStyle get bodyMedium => GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.25,
      );

  /// Body Small - 작은 본문 (12px) - 보조 설명
  static TextStyle get bodySmall => GoogleFonts.notoSansKr(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.4,
      );

  // ============================================================================
  // Label Styles (라벨)
  // ============================================================================

  /// Label Large - 큰 라벨 (14px) - 버튼 텍스트
  static TextStyle get labelLarge => GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.1,
      );

  /// Label Medium - 중간 라벨 (12px) - 탭, 칩
  static TextStyle get labelMedium => GoogleFonts.notoSansKr(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.5,
      );

  /// Label Small - 작은 라벨 (11px) - 매우 작은 힌트, 캡션
  static TextStyle get labelSmall => GoogleFonts.notoSansKr(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.5,
      );

  // ============================================================================
  // Custom Styles (커스텀 스타일)
  // ============================================================================

  /// 숫자 표시용 스타일 (타이머, 통계 등)
  static TextStyle get numberLarge => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
        fontFeatures: [const FontFeature.tabularFigures()],
      );

  /// 중간 크기 숫자 표시
  static TextStyle get numberMedium => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
        fontFeatures: [const FontFeature.tabularFigures()],
      );

  /// 작은 숫자 표시 (시간 등)
  static TextStyle get numberSmall => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
        fontFeatures: [const FontFeature.tabularFigures()],
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
