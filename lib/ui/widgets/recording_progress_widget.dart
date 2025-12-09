// lib/ui/widgets/recording_progress_widget.dart
// 녹화 진행률 표시 위젯
//
// 목적: 녹화 중 실시간 진행 상황(경과 시간, 프레임 수, 오디오 샘플 등)을 표시
// Phase 3.1.1 작업
// Phase 3.1.2: 오디오 레벨 미터 추가

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../ffi/native_bindings.dart';
import '../widgets/common/app_card.dart';
import '../style/app_colors.dart';
import '../style/app_typography.dart';

/// 녹화 진행 상태를 나타내는 데이터 클래스
class RecordingProgress {
  /// 녹화 경과 시간 (밀리초)
  final int elapsedMs;

  /// 인코딩된 비디오 프레임 수
  final int videoFrameCount;

  /// 인코딩된 오디오 샘플 수
  final int audioSampleCount;

  /// 오디오 RMS 레벨 (0.0 ~ 1.0) - Phase 3.1.2
  final double audioLevel;

  /// 오디오 Peak 레벨 (0.0 ~ 1.0) - Phase 3.1.2
  final double audioPeakLevel;

  RecordingProgress({
    required this.elapsedMs,
    required this.videoFrameCount,
    required this.audioSampleCount,
    required this.audioLevel,
    required this.audioPeakLevel,
  });

  /// 경과 시간을 MM:SS 형식 문자열로 변환
  String get formattedTime {
    final seconds = elapsedMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// 예상 파일 크기 (MB) - 대략적 계산
  /// H.264 5Mbps + AAC 192kbps = 약 0.65 MB/초
  double get estimatedFileSizeMB {
    final seconds = elapsedMs / 1000.0;
    return seconds * 0.65; // 5 Mbps ≈ 0.625 MB/s + 오버헤드
  }
}

/// 녹화 진행률 표시 위젯
///
/// 녹화 중일 때 1초마다 FFI를 통해 네이티브 레이어에서
/// 진행 상황을 가져와 UI를 업데이트합니다.
class RecordingProgressWidget extends StatefulWidget {
  const RecordingProgressWidget({super.key});

  @override
  State<RecordingProgressWidget> createState() => _RecordingProgressWidgetState();
}

class _RecordingProgressWidgetState extends State<RecordingProgressWidget> {
  Timer? _updateTimer;
  RecordingProgress? _progress;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _startUpdateTimer();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  /// 1초마다 FFI를 통해 진행 상황 업데이트
  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateProgress();
    });
  }

  /// 네이티브 레이어에서 진행 상황 가져오기
  void _updateProgress() {
    try {
      // FFI 호출
      final isRecording = NativeRecorderBindings.isRecording() == 1;

      if (!isRecording) {
        // 녹화 중이 아니면 상태 초기화
        if (_isRecording) {
          setState(() {
            _isRecording = false;
            _progress = null;
          });
        }
        return;
      }

      // 녹화 중이면 진행 상황 업데이트
      final elapsedMs = NativeRecorderBindings.getElapsedTimeMs();
      final videoFrameCount = NativeRecorderBindings.getVideoFrameCount();
      final audioSampleCount = NativeRecorderBindings.getAudioSampleCount();

      // Phase 3.1.2: 오디오 레벨 조회
      final audioLevel = NativeRecorderBindings.getAudioLevel();
      final audioPeakLevel = NativeRecorderBindings.getAudioPeakLevel();

      setState(() {
        _isRecording = true;
        _progress = RecordingProgress(
          elapsedMs: elapsedMs,
          videoFrameCount: videoFrameCount,
          audioSampleCount: audioSampleCount,
          audioLevel: audioLevel,
          audioPeakLevel: audioPeakLevel,
        );
      });
    } catch (e) {
      // FFI 호출 실패 시 로그만 출력하고 계속 진행
      debugPrint('❌ RecordingProgress 업데이트 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 녹화 중이 아니면 아무것도 표시하지 않음
    if (!_isRecording || _progress == null) {
      return const SizedBox.shrink();
    }

    final progress = _progress!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더: 녹화 중 표시 (상위 위젯에서 처리할 수도 있으나, 여기서는 타이머/상태 정보가 있으므로 유지하되 간소화)
        Row(
          children: [
            // 빨간 점 애니메이션
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.recordingActive,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.recordingActive.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              progress.formattedTime,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAudioLevelMeter(context, progress),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 진행 상황 상세 정보 (한 줄로 컴팩트하게)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompactStat(Icons.video_camera_back_outlined, '${progress.videoFrameCount} frames'),
              _buildVerticalDivider(),
              _buildCompactStat(Icons.audiotrack_outlined, _formatLargeNumber(progress.audioSampleCount)),
              _buildVerticalDivider(),
              _buildCompactStat(Icons.save_outlined, '${progress.estimatedFileSizeMB.toStringAsFixed(1)} MB'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 12,
      color: AppColors.neutral300,
    );
  }

  Widget _buildCompactStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 큰 숫자를 K, M 단위로 포맷팅
  /// 예: 1,234,567 → "1.2M"
  String _formatLargeNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  /// Phase 3.1.2: 오디오 레벨 미터 위젯 빌더 (Compact)
  Widget _buildAudioLevelMeter(BuildContext context, RecordingProgress progress) {
    // RMS 레벨을 dB로 변환 (UI 표시용)
    final rmsDb = progress.audioLevel > 0.0
        ? (20 * (progress.audioLevel.clamp(0.0001, 1.0)).log10())
        : -60.0;

    // -60dB ~ 0dB를 0.0 ~ 1.0으로 정규화
    final normalizedLevel = ((rmsDb + 60) / 60).clamp(0.0, 1.0);

    // 레벨에 따라 색상 결정
    Color levelColor;
    if (normalizedLevel > 0.9) {
      levelColor = Colors.red;
    } else if (normalizedLevel > 0.7) {
      levelColor = Colors.orange;
    } else if (normalizedLevel > 0.3) {
      levelColor = Colors.green;
    } else {
      levelColor = Colors.blue;
    }

    return Row(
      children: [
        Icon(
          Icons.graphic_eq,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6, // 높이 축소
              decoration: BoxDecoration(
                color: AppColors.neutral200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: normalizedLevel,
                child: Container(
                  decoration: BoxDecoration(
                    color: levelColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32, // 고정 폭으로 흔들림 방지
          child: Text(
            '${(normalizedLevel * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.end,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

// log10 확장 함수
extension DoubleExtension on double {
  double log10() {
    return log(this) / ln10;
  }
}
