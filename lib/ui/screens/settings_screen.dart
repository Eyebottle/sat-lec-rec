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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.videocam, size: 24),
                const SizedBox(width: 12),
                Text(
                  '비디오 설정',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 해상도
            Text('해상도', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.help_outline, size: 16, color: Colors.green),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Full HD: PPT 슬라이드 선명 (권장) | HD: 저용량/빠른 인코딩',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('1920x1080 (Full HD)'),
                  selected: _settings.videoWidth == 1920,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _settings = _settings.copyWith(videoWidth: 1920, videoHeight: 1080);
                        _markChanged();
                      });
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('1280x720 (HD)'),
                  selected: _settings.videoWidth == 1280,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _settings = _settings.copyWith(videoWidth: 1280, videoHeight: 720);
                        _markChanged();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // FPS
            Text('FPS (프레임 레이트)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.help_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '15fps: 저용량 | 24-30fps: 강의 권장 | 60fps: 게임/매끄러운 영상',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SliderWithInput(
              value: _settings.videoFps.toDouble(),
              min: 15,
              max: 60,
              divisions: 9,
              suffix: 'fps',
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(videoFps: value.toInt());
                  _markChanged();
                });
              },
            ),
            const SizedBox(height: 16),

            // CRF (품질)
            Text('비디오 품질 (CRF)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, size: 16, color: Colors.orange),
                      SizedBox(width: 6),
                      Text(
                        '낮을수록 고품질 (파일 크기 증가)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '18-20: 최고화질 (큰 파일) | 23: 기본값 | 28-30: 저용량',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SliderWithInput(
              value: _settings.h264Crf.toDouble(),
              min: 18,
              max: 35,
              divisions: 17,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(h264Crf: value.toInt());
                  _markChanged();
                });
              },
            ),
            const SizedBox(height: 20),

            // 예상 파일 크기
            const Divider(),
            const SizedBox(height: 12),
            _buildFileSizeEstimate(),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.audiotrack, size: 24),
                const SizedBox(width: 12),
                Text(
                  '오디오 설정',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 비트레이트
            Text('오디오 비트레이트', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.help_outline, size: 16, color: Colors.purple),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '128: 저용량 | 192: 강의 권장 (명확한 음성) | 256: 음악 포함 시',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('128 kbps'),
                  selected: _settings.aacBitrate == 128000,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _settings = _settings.copyWith(aacBitrate: 128000);
                        _markChanged();
                      });
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('192 kbps'),
                  selected: _settings.aacBitrate == 192000,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _settings = _settings.copyWith(aacBitrate: 192000);
                        _markChanged();
                      });
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('256 kbps'),
                  selected: _settings.aacBitrate == 256000,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _settings = _settings.copyWith(aacBitrate: 256000);
                        _markChanged();
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.video_call, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Zoom 설정',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Zoom 자동 실행'),
              subtitle: const Text('예약 녹화 시 Zoom을 자동으로 실행합니다'),
              value: _settings.enableAutoZoomLaunch,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(enableAutoZoomLaunch: value);
                  _markChanged();
                });
              },
            ),

            const Divider(),

            // 테스트용 Zoom 링크 입력
            Text('테스트용 Zoom 링크 (선택사항)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _settings.testZoomLink ?? '',
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'https://zoom.us/j/당신의PMI번호',
                prefixIcon: Icon(Icons.link),
                helperText: 'PMI 링크를 입력하면 테스트 버튼으로 빠르게 테스트할 수 있습니다',
                helperMaxLines: 2,
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return null; // 선택사항이므로 빈 값 허용
                }
                if (!value.contains('zoom.us')) {
                  return 'Zoom 링크는 "zoom.us"를 포함해야 합니다';
                }
                if (!value.startsWith('http')) {
                  return 'https:// 또는 http://로 시작해야 합니다';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(testZoomLink: value);
                  _markChanged();
                });
              },
            ),

            if (_settings.enableAutoZoomLaunch) ...[
              const Divider(),
              Text('Zoom 실행 후 대기 시간', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.help_outline, size: 16, color: Colors.teal),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Zoom이 완전히 실행될 때까지 기다리는 시간 (느린 PC는 길게 설정)',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SliderWithInput(
                value: _settings.zoomLaunchWaitSeconds.toDouble(),
                min: 5,
                max: 30,
                divisions: 5,
                suffix: '초',
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(zoomLaunchWaitSeconds: value.toInt());
                    _markChanged();
                  });
                },
              ),

              const Divider(),
              SwitchListTile(
                title: const Text('녹화 종료 후 Zoom 자동 종료'),
                subtitle: const Text('녹화가 끝나면 Zoom 앱을 자동으로 닫습니다'),
                value: _settings.autoCloseZoomAfterRecording,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(autoCloseZoomAfterRecording: value);
                    _markChanged();
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildZoomApiSettingsCard() {
    final TextEditingController accountIdController = TextEditingController(
      text: _settings.zoomApiAccountId ?? '',
    );
    final TextEditingController clientIdController = TextEditingController(
      text: _settings.zoomApiClientId ?? '',
    );
    final TextEditingController clientSecretController = TextEditingController(
      text: _settings.zoomApiClientSecret ?? '',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.api, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Zoom API 설정',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '테스트용 Zoom 회의를 자동 생성하려면 Server-to-Server OAuth 앱이 필요합니다',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account ID
            Text('Account ID', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: accountIdController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Zoom 계정 ID 입력',
                prefixIcon: Icon(Icons.account_circle),
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
            Text('Client ID', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: clientIdController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'OAuth 앱 Client ID 입력',
                prefixIcon: Icon(Icons.vpn_key),
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
            Text('Client Secret', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: clientSecretController,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'OAuth 앱 Client Secret 입력',
                prefixIcon: Icon(Icons.lock),
              ),
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(zoomApiClientSecret: value);
                  _markChanged();
                });
              },
            ),
            const SizedBox(height: 16),

            // 도움말 링크
            OutlinedButton.icon(
              onPressed: () {
                // 도움말 다이얼로그 표시
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('📚 Zoom API 설정 방법'),
                    content: const SingleChildScrollView(
                      child: Text(
                        '1. Zoom App Marketplace 접속\n'
                        '   https://marketplace.zoom.us/\n\n'
                        '2. "Develop" → "Build App" 클릭\n\n'
                        '3. "Server-to-Server OAuth" 선택\n\n'
                        '4. 앱 생성 후 다음 정보 복사:\n'
                        '   • Account ID\n'
                        '   • Client ID\n'
                        '   • Client Secret\n\n'
                        '5. Scopes 권한 추가:\n'
                        '   • meeting:write:admin\n'
                        '   • user:read:admin\n\n'
                        '6. 활성화 후 위 정보를 입력하세요',
                        style: TextStyle(height: 1.5),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.help_outline),
              label: const Text('설정 방법 보기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 24),
                const SizedBox(width: 12),
                Text(
                  '기타 설정',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('헬스체크 활성화'),
              subtitle: const Text('녹화 10분 전 시스템 상태를 확인합니다'),
              value: _settings.enableHealthCheck,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(enableHealthCheck: value);
                  _markChanged();
                });
              },
            ),

            const Divider(),

            SwitchListTile(
              title: const Text('시작 시 자동 실행'),
              subtitle: const Text('Windows 시작 시 앱을 자동으로 실행합니다'),
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
      ),
    );
  }
}
