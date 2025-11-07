// lib/models/app_settings.dart
// 앱 설정 데이터 모델
//
// 목적: 사용자 설정 저장 및 관리
// - 녹화 품질 설정
// - 저장 경로 설정
// - 기타 앱 동작 설정

/// 앱 설정 데이터 클래스
class AppSettings {
  /// 비디오 해상도 너비
  final int videoWidth;

  /// 비디오 해상도 높이
  final int videoHeight;

  /// 비디오 FPS (Frames Per Second)
  final int videoFps;

  /// H.264 CRF (Constant Rate Factor) - 품질 (18=최고, 28=낮음)
  final int h264Crf;

  /// H.264 프리셋 (ultrafast, veryfast, faster, fast, medium, slow)
  final String h264Preset;

  /// AAC 비트레이트 (bps)
  final int aacBitrate;

  /// 오디오 샘플레이트 (Hz)
  final int audioSampleRate;

  /// 오디오 채널 수
  final int audioChannels;

  /// 저장 경로 (null이면 기본 경로 사용)
  final String? customOutputPath;

  /// 헬스체크 활성화 여부
  final bool enableHealthCheck;

  /// Zoom 자동 실행 활성화 여부
  final bool enableAutoZoomLaunch;

  /// Zoom 실행 후 대기 시간 (초)
  final int zoomLaunchWaitSeconds;

  /// 녹화 종료 후 Zoom 자동 종료 여부
  final bool autoCloseZoomAfterRecording;

  /// 시작 시 자동 실행 여부
  final bool launchAtStartup;

  AppSettings({
    this.videoWidth = 1920,
    this.videoHeight = 1080,
    this.videoFps = 24,
    this.h264Crf = 23,
    this.h264Preset = 'veryfast',
    this.aacBitrate = 192000,
    this.audioSampleRate = 48000,
    this.audioChannels = 2,
    this.customOutputPath,
    this.enableHealthCheck = true,
    this.enableAutoZoomLaunch = true,
    this.zoomLaunchWaitSeconds = 15,
    this.autoCloseZoomAfterRecording = true,
    this.launchAtStartup = false,
  });

  /// 기본 설정
  factory AppSettings.defaults() => AppSettings();

  /// JSON으로 직렬화
  Map<String, dynamic> toJson() {
    return {
      'videoWidth': videoWidth,
      'videoHeight': videoHeight,
      'videoFps': videoFps,
      'h264Crf': h264Crf,
      'h264Preset': h264Preset,
      'aacBitrate': aacBitrate,
      'audioSampleRate': audioSampleRate,
      'audioChannels': audioChannels,
      'customOutputPath': customOutputPath,
      'enableHealthCheck': enableHealthCheck,
      'enableAutoZoomLaunch': enableAutoZoomLaunch,
      'zoomLaunchWaitSeconds': zoomLaunchWaitSeconds,
      'autoCloseZoomAfterRecording': autoCloseZoomAfterRecording,
      'launchAtStartup': launchAtStartup,
    };
  }

  /// JSON에서 역직렬화
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      videoWidth: json['videoWidth'] as int? ?? 1920,
      videoHeight: json['videoHeight'] as int? ?? 1080,
      videoFps: json['videoFps'] as int? ?? 24,
      h264Crf: json['h264Crf'] as int? ?? 23,
      h264Preset: json['h264Preset'] as String? ?? 'veryfast',
      aacBitrate: json['aacBitrate'] as int? ?? 192000,
      audioSampleRate: json['audioSampleRate'] as int? ?? 48000,
      audioChannels: json['audioChannels'] as int? ?? 2,
      customOutputPath: json['customOutputPath'] as String?,
      enableHealthCheck: json['enableHealthCheck'] as bool? ?? true,
      enableAutoZoomLaunch: json['enableAutoZoomLaunch'] as bool? ?? true,
      zoomLaunchWaitSeconds: json['zoomLaunchWaitSeconds'] as int? ?? 15,
      autoCloseZoomAfterRecording: json['autoCloseZoomAfterRecording'] as bool? ?? true,
      launchAtStartup: json['launchAtStartup'] as bool? ?? false,
    );
  }

  /// copyWith 메서드
  AppSettings copyWith({
    int? videoWidth,
    int? videoHeight,
    int? videoFps,
    int? h264Crf,
    String? h264Preset,
    int? aacBitrate,
    int? audioSampleRate,
    int? audioChannels,
    String? customOutputPath,
    bool? enableHealthCheck,
    bool? enableAutoZoomLaunch,
    int? zoomLaunchWaitSeconds,
    bool? autoCloseZoomAfterRecording,
    bool? launchAtStartup,
  }) {
    return AppSettings(
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      videoFps: videoFps ?? this.videoFps,
      h264Crf: h264Crf ?? this.h264Crf,
      h264Preset: h264Preset ?? this.h264Preset,
      aacBitrate: aacBitrate ?? this.aacBitrate,
      audioSampleRate: audioSampleRate ?? this.audioSampleRate,
      audioChannels: audioChannels ?? this.audioChannels,
      customOutputPath: customOutputPath ?? this.customOutputPath,
      enableHealthCheck: enableHealthCheck ?? this.enableHealthCheck,
      enableAutoZoomLaunch: enableAutoZoomLaunch ?? this.enableAutoZoomLaunch,
      zoomLaunchWaitSeconds: zoomLaunchWaitSeconds ?? this.zoomLaunchWaitSeconds,
      autoCloseZoomAfterRecording: autoCloseZoomAfterRecording ?? this.autoCloseZoomAfterRecording,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
    );
  }

  @override
  String toString() {
    return 'AppSettings(video: ${videoWidth}x$videoHeight@${videoFps}fps, '
        'h264: CRF$h264Crf/$h264Preset, audio: ${audioSampleRate}Hz/${aacBitrate}bps)';
  }
}
