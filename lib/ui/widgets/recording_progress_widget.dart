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

    return AppCard.level2(
      color: AppColors.recordingActive.withOpacity(0.1),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: 녹화 중 표시
            Row(
              children: [
                // 빨간 점 애니메이션
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.recordingActive,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.recordingActive.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '녹화 중',
                  style: AppTypography.titleMedium,
                ),
                const Spacer(),
                // 경과 시간 (크게 표시)
                Text(
                  progress.formattedTime,
                  style: AppTypography.numberMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 진행 상황 상세 정보
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  icon: Icons.video_library,
                  label: '비디오 프레임',
                  value: progress.videoFrameCount.toString(),
                ),
                _buildStatItem(
                  context,
                  icon: Icons.audiotrack,
                  label: '오디오 샘플',
                  value: _formatLargeNumber(progress.audioSampleCount),
                ),
                _buildStatItem(
                  context,
                  icon: Icons.storage,
                  label: '예상 크기',
                  value: '${progress.estimatedFileSizeMB.toStringAsFixed(1)} MB',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Phase 3.1.2: 오디오 레벨 미터
            _buildAudioLevelMeter(context, progress),
          ],
        ),
      ),
    );
  }

  /// 통계 항목 위젯 빌더
  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.7),
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
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

  /// Phase 3.1.2: 오디오 레벨 미터 위젯 빌더
  Widget _buildAudioLevelMeter(BuildContext context, RecordingProgress progress) {
    // RMS 레벨을 dB로 변환 (UI 표시용)
    // -60dB ~ 0dB 범위로 매핑
    final rmsDb = progress.audioLevel > 0.0
        ? (20 * (progress.audioLevel.clamp(0.0001, 1.0)).log10())
        : -60.0;

    // -60dB ~ 0dB를 0.0 ~ 1.0으로 정규화
    final normalizedLevel = ((rmsDb + 60) / 60).clamp(0.0, 1.0);

    // 레벨에 따라 색상 결정
    Color levelColor;
    if (normalizedLevel > 0.9) {
      levelColor = Colors.red; // 클리핑 위험
    } else if (normalizedLevel > 0.7) {
      levelColor = Colors.orange; // 높음
    } else if (normalizedLevel > 0.3) {
      levelColor = Colors.green; // 적정
    } else {
      levelColor = Colors.blue; // 낮음
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.graphic_eq,
              size: 16,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              '오디오 레벨',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.7),
                  ),
            ),
            const Spacer(),
            Text(
              '${(normalizedLevel * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 레벨 바
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: normalizedLevel,
              child: Container(
                decoration: BoxDecoration(
                  color: levelColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: levelColor.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
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
