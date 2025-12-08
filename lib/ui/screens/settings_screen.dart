// lib/ui/screens/settings_screen.dart
// 설정 화면
//
// 목적: 앱 설정 관리 UI 제공
// - 녹화 품질 설정
// - Zoom 자동 실행 설정
// - 저장 경로 설정

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../models/app_settings.dart';
import '../../services/settings_service.dart';
import '../../utils/file_size_estimator.dart';
import '../widgets/common/slider_with_input.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';
import '../style/app_colors.dart';
import '../style/app_typography.dart';

/// 설정 화면
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Logger _logger = Logger();
  final SettingsService _settingsService = SettingsService();

  late AppSettings _settings;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.settings;
  }

  void _markChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  Future<void> _saveSettings() async {
    try {
      await _settingsService.updateSettings(_settings);
      setState(() {
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 설정이 저장되었습니다')),
        );
      }
    } catch (e) {
      _logger.e('설정 저장 실패', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 설정 저장 실패: $e')),
        );
      }
    }
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정 초기화'),
        content: const Text('모든 설정을 기본값으로 되돌리시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('초기화'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _settingsService.resetSettings();
      setState(() {
        _settings = _settingsService.settings;
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 설정이 초기화되었습니다')),
        );
      }
    }
  }

  Future<void> _applyRecommendedSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📚 강의 녹화 추천 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '강의 녹화에 최적화된 설정입니다.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // 해상도
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.high_quality, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('해상도: 1920x1080 (Full HD)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('→ PPT 슬라이드의 작은 글씨도 선명하게 보입니다',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // FPS
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.speed, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FPS: 30 (부드러운 화면)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('→ 화면 전환과 커서 움직임이 자연스럽습니다',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // CRF
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.video_settings, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('비디오 품질: CRF 20 (고품질)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('→ 슬라이드 텍스트가 뭉개지지 않고 깨끗합니다',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 오디오
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.graphic_eq, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('오디오: 192 kbps (명확한 음성)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('→ 강사님 목소리가 또렷하게 들립니다',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 자동화 설정
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.settings_suggest, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Zoom 자동 실행 & 헬스체크 ON',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('→ 수동 조작 없이 자동으로 녹화를 시작합니다',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '2시간 강의 기준 약 2-3GB 파일 크기 예상',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('적용'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _settings = _settings.copyWith(
          videoWidth: 1920,
          videoHeight: 1080,
          videoFps: 30,
          h264Crf: 20,
          aacBitrate: 192000,
          enableAutoZoomLaunch: true,
          enableHealthCheck: true,
        );
        _markChanged();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 강의 녹화 추천 설정이 적용되었습니다. 저장 버튼을 눌러주세요.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // 4개 탭: 비디오, 오디오, Zoom, 고급
      child: Scaffold(
        appBar: AppBar(
          title: const Text('설정'),
          actions: [
            // 강의 녹화 추천 설정 버튼
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _applyRecommendedSettings,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.school, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '강의 추천',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: '기본값으로 초기화',
              onPressed: _resetSettings,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.videocam), text: '비디오'),
              Tab(icon: Icon(Icons.audiotrack), text: '오디오'),
              Tab(icon: Icon(Icons.video_call), text: 'Zoom'),
              Tab(icon: Icon(Icons.settings_applications), text: '고급'),
            ],
          ),
        ),
        body: Column(
          children: [
            // TabBarView 영역
            Expanded(
              child: TabBarView(
                children: [
                  // 비디오 탭
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildVideoSettingsCard(),
                  ),
                  // 오디오 탭
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildAudioSettingsCard(),
                  ),
                  // Zoom 탭
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildZoomSettingsCard(),
                  ),
                  // 고급 탭
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildZoomApiSettingsCard(),
                        const SizedBox(height: 16),
                        _buildOtherSettingsCard(),
                        const SizedBox(height: 80), // 하단 버튼 공간 확보
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 하단 고정 버튼 영역
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 변경사항 표시
                if (_hasChanges)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '저장되지 않은 변경사항이 있습니다',
                              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Expanded(
                    child: Text(
                      '모든 설정이 저장되었습니다',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                const SizedBox(width: 16),

                // 취소 버튼
                if (_hasChanges)
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _settings = _settingsService.settings;
                        _hasChanges = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('변경사항을 취소했습니다')),
                      );
                    },
                    child: const Text('취소'),
                  ),
                if (_hasChanges) const SizedBox(width: 8),

                // 저장 버튼
                Container(
                  decoration: BoxDecoration(
                    color: _hasChanges ? Colors.blue : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _hasChanges ? _saveSettings : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.save, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '저장',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildVideoSettingsCard() {
    return AppCard.level1(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.videocam_outlined,
            title: '비디오 품질',
            description: '해상도, 프레임 레이트, 화질을 설정합니다.',
          ),
          const SizedBox(height: 24),

          // 해상도
          Text('해상도', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          _buildInfoTip(
            'Full HD는 작은 글씨도 선명하게 보이지만 파일 용량이 큽니다.',
            icon: Icons.info_outline,
            color: AppColors.info,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 1920,
                  label: Text('1080p (FHD)'),
                  icon: Icon(Icons.hd_outlined),
                ),
                ButtonSegment(
                  value: 1280,
                  label: Text('720p (HD)'),
                  icon: Icon(Icons.sd_outlined),
                ),
              ],
              selected: {_settings.videoWidth},
              onSelectionChanged: (Set<int> newSelection) {
                final width = newSelection.first;
                final height = width == 1920 ? 1080 : 720;
                setState(() {
                  _settings = _settings.copyWith(videoWidth: width, videoHeight: height);
                  _markChanged();
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.comfortable,
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // FPS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('프레임 레이트 (FPS)', style: AppTypography.labelLarge),
              Text(
                '${_settings.videoFps} fps',
                style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _settings.videoFps.toDouble(),
            min: 15,
            max: 60,
            divisions: 3, // 15, 30, 45, 60 roughly or 9
            label: '${_settings.videoFps} fps',
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(videoFps: value.toInt());
                _markChanged();
              });
            },
          ),
          const Text(
            '30fps가 강의 녹화에 가장 적합합니다.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 32),

          // CRF (품질)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('화질 (CRF)', style: AppTypography.labelLarge),
              Text(
                '값: ${_settings.h264Crf}',
                style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoTip(
            '숫자가 낮을수록 고화질/대용량입니다. (권장: 20-23)',
            icon: Icons.tips_and_updates_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(height: 12),
          Slider(
            value: _settings.h264Crf.toDouble(),
            min: 18,
            max: 35,
            divisions: 17,
            label: '${_settings.h264Crf}',
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(h264Crf: value.toInt());
                _markChanged();
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('고화질 (18)', style: AppTypography.labelSmall),
              Text('저용량 (35)', style: AppTypography.labelSmall),
            ],
          ),
          const SizedBox(height: 32),

          // 예상 파일 크기
          const Divider(),
          const SizedBox(height: 24),
          _buildFileSizeEstimate(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTip(String text, {IconData icon = Icons.info_outline, Color color = AppColors.neutral500}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// 예상 파일 크기 표시
  Widget _buildFileSizeEstimate() {
    // 1시간 기준 파일 크기 계산
    final sizePerHour = FileSizeEstimator.estimatePerHour(
      videoWidth: _settings.videoWidth,
      videoHeight: _settings.videoHeight,
      fps: _settings.videoFps,
      crf: _settings.h264Crf,
      audioBitrate: _settings.aacBitrate,
    );

    // 2시간 기준 계산 (일반적인 강의 시간)
    final sizePer2Hours = FileSizeEstimator.estimateFileSize(
      videoWidth: _settings.videoWidth,
      videoHeight: _settings.videoHeight,
      fps: _settings.videoFps,
      crf: _settings.h264Crf,
      audioBitrate: _settings.aacBitrate,
      durationMinutes: 120,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '예상 파일 크기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1시간 녹화 시:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                FileSizeEstimator.formatFileSize(sizePerHour),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '2시간 녹화 시:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                FileSizeEstimator.formatFileSize(sizePer2Hours),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '💡 CRF 값을 높이면 파일 크기가 줄어듭니다',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSettingsCard() {
    return AppCard.level1(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.audiotrack_outlined,
            title: '오디오 설정',
            description: '녹음 음질과 비트레이트를 설정합니다.',
          ),
          const SizedBox(height: 24),

          // 비트레이트
          Text('오디오 비트레이트', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          _buildInfoTip(
            '192kbps가 강의 녹음에 가장 적합하며, 256kbps는 음악이 포함된 경우 권장됩니다.',
            icon: Icons.headphones_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 128000,
                  label: Text('128k'),
                  tooltip: '저용량',
                ),
                ButtonSegment(
                  value: 192000,
                  label: Text('192k (Standard)'),
                  tooltip: '권장',
                ),
                ButtonSegment(
                  value: 256000,
                  label: Text('256k (High)'),
                  tooltip: '고음질',
                ),
              ],
              selected: {_settings.aacBitrate},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _settings = _settings.copyWith(aacBitrate: newSelection.first);
                  _markChanged();
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.comfortable,
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomSettingsCard() {
    return AppCard.level1(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.video_call_outlined,
            title: 'Zoom 자동화 설정',
            description: 'Zoom 실행 및 자동 접속 관련 설정을 관리합니다.',
          ),
          const SizedBox(height: 24),

          // Zoom 자동 실행 스위치
          _buildSwitchTile(
            title: 'Zoom 자동 실행',
            description: '예약 녹화 시각에 맞춰 Zoom을 자동으로 실행합니다.',
            value: _settings.enableAutoZoomLaunch,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(enableAutoZoomLaunch: value);
                _markChanged();
              });
            },
          ),

          if (_settings.enableAutoZoomLaunch) ...[
            const SizedBox(height: 24),
            _buildInfoTip(
              'Zoom이 실행된 후, 회의에 완전히 접속할 때까지 기다리는 시간을 설정하세요.',
              icon: Icons.timer_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('실행 대기 시간', style: AppTypography.labelLarge),
                Text(
                  '${_settings.zoomLaunchWaitSeconds}초',
                  style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            Slider(
              value: _settings.zoomLaunchWaitSeconds.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              label: '${_settings.zoomLaunchWaitSeconds}초',
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(zoomLaunchWaitSeconds: value.toInt());
                  _markChanged();
                });
              },
            ),
            const SizedBox(height: 24),

            _buildSwitchTile(
              title: '녹화 종료 후 Zoom 종료',
              description: '녹화가 끝나면 Zoom 애플리케이션을 자동으로 닫습니다.',
              value: _settings.autoCloseZoomAfterRecording,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(autoCloseZoomAfterRecording: value);
                  _markChanged();
                });
              },
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(),
          ),

          // 테스트용 Zoom 링크 입력
          Text('테스트용 Zoom 링크', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _settings.testZoomLink ?? '',
            decoration: const InputDecoration(
              hintText: 'https://zoom.us/j/1234567890',
              prefixIcon: Icon(Icons.link),
              helperText: 'Zoom 실행 테스트 버튼을 누를 때 사용될 링크입니다.',
            ),
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(testZoomLink: value);
                _markChanged();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildZoomApiSettingsCard() {
    // Note: Controllers created here for stateless simplicity in this refactor, 
    // ideally should be in State but keeping original logic structure for now.
    final TextEditingController accountIdController = TextEditingController(
      text: _settings.zoomApiAccountId ?? '',
    );
    final TextEditingController clientIdController = TextEditingController(
      text: _settings.zoomApiClientId ?? '',
    );
    final TextEditingController clientSecretController = TextEditingController(
      text: _settings.zoomApiClientSecret ?? '',
    );

    return AppCard.level1(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.api_outlined,
            title: 'Zoom API 설정 (고급)',
            description: '자동 회의 생성 등 고급 기능을 위해 설정합니다.',
          ),
          const SizedBox(height: 24),
          _buildInfoTip(
            'Server-to-Server OAuth 앱 설정이 필요합니다.',
            icon: Icons.vpn_key_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(height: 24),

          // Account ID
          Text('Account ID', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: accountIdController,
            decoration: const InputDecoration(
              hintText: 'Zoom Account ID',
              prefixIcon: Icon(Icons.account_circle_outlined),
            ),
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(zoomApiAccountId: value);
                _markChanged();
              });
            },
          ),
          const SizedBox(height: 16),

          // Client ID
          Text('Client ID', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: clientIdController,
            decoration: const InputDecoration(
              hintText: 'OAuth Client ID',
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(zoomApiClientId: value);
                _markChanged();
              });
            },
          ),
          const SizedBox(height: 16),

          // Client Secret
          Text('Client Secret', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: clientSecretController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'OAuth Client Secret',
              prefixIcon: Icon(Icons.lock_outlined),
            ),
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(zoomApiClientSecret: value);
                _markChanged();
              });
            },
          ),
          const SizedBox(height: 24),

          // 도움말 링크
          SizedBox(
            width: double.infinity,
            child: AppButton.secondary(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Zoom API 설정 방법'),
                    content: const Text(
                      '1. Zoom App Marketplace (marketplace.zoom.us) 접속\n'
                      '2. Develop > Build App > Server-to-Server OAuth 선택\n'
                      '3. App Credentials에서 정보 복사\n'
                      '4. Scopes에 meeting:write:admin, user:read:admin 추가',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
                    ],
                  ),
                );
              },
              icon: Icons.help_outline,
              child: const Text('설정 가이드 보기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherSettingsCard() {
    return AppCard.level1(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.tune_outlined,
            title: '기타 설정',
            description: '시스템 동작 및 기타 옵션입니다.',
          ),
          const SizedBox(height: 24),

          _buildSwitchTile(
            title: '헬스체크 활성화',
            description: '녹화 10분 전 시스템 상태(디스크, 인터넷)를 확인합니다.',
            value: _settings.enableHealthCheck,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(enableHealthCheck: value);
                _markChanged();
              });
            },
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            title: '윈도우 시작 시 자동 실행',
            description: 'PC가 켜질 때 앱을 백그라운드로 실행합니다.',
            value: _settings.launchAtStartup,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(launchAtStartup: value);
                _markChanged();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return AppCard.level2(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
