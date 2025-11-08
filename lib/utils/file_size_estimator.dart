// 무엇을 하는 코드인지: 녹화 설정값을 기반으로 예상 파일 크기를 계산하는 유틸리티
//
// FPS, 해상도, CRF, 오디오 비트레이트, 녹화 시간을 입력하면
// 예상 파일 크기를 계산합니다 (MB 단위).
//
// 입력: videoWidth, videoHeight, fps, crf, audioBitrate, durationMinutes
// 출력: 예상 파일 크기 (MB)
// 예외: 비정상적인 값 입력 시 0 반환

/// 녹화 파일 크기 추정 유틸리티
class FileSizeEstimator {
  /// 예상 파일 크기 계산 (MB 단위)
  ///
  /// 입력:
  /// - [videoWidth]: 비디오 가로 해상도 (예: 1920)
  /// - [videoHeight]: 비디오 세로 해상도 (예: 1080)
  /// - [fps]: 프레임 레이트 (예: 30)
  /// - [crf]: CRF 값 (18~35, 낮을수록 고품질)
  /// - [audioBitrate]: 오디오 비트레이트 (bps, 예: 192000)
  /// - [durationMinutes]: 녹화 시간 (분)
  ///
  /// 출력: 예상 파일 크기 (MB, 소수점 1자리)
  ///
  /// 계산 방식:
  /// 1. 픽셀 수 = 가로 × 세로
  /// 2. CRF 계수 계산 (낮을수록 비트레이트 높음)
  /// 3. 비디오 비트레이트 = 픽셀 수 × FPS × CRF 계수
  /// 4. 총 비트레이트 = 비디오 + 오디오
  /// 5. 파일 크기 = 총 비트레이트 × 시간 / 8 / 1024 / 1024
  static double estimateFileSize({
    required int videoWidth,
    required int videoHeight,
    required int fps,
    required int crf,
    required int audioBitrate,
    required int durationMinutes,
  }) {
    // 입력 검증
    if (videoWidth <= 0 ||
        videoHeight <= 0 ||
        fps <= 0 ||
        crf < 0 ||
        audioBitrate < 0 ||
        durationMinutes <= 0) {
      return 0.0;
    }

    // 1. 픽셀 수
    final pixels = videoWidth * videoHeight;

    // 2. CRF 계수 (경험적 공식)
    // CRF 18 → 1.2 bpp (bits per pixel)
    // CRF 23 → 0.8 bpp
    // CRF 28 → 0.4 bpp
    // CRF 35 → 0.15 bpp
    final crfFactor = _getCrfFactor(crf);

    // 3. 비디오 비트레이트 (bps)
    final videoBitrate = pixels * fps * crfFactor;

    // 4. 총 비트레이트 (bps)
    final totalBitrate = videoBitrate + audioBitrate;

    // 5. 파일 크기 (MB)
    final durationSeconds = durationMinutes * 60;
    final fileSizeBytes = totalBitrate * durationSeconds / 8;
    final fileSizeMB = fileSizeBytes / 1024 / 1024;

    return double.parse(fileSizeMB.toStringAsFixed(1));
  }

  /// CRF 값에 따른 bits-per-pixel 계수 계산
  ///
  /// CRF는 로그 스케일이므로 지수 함수로 근사:
  /// bpp = 2.0 × exp(-0.12 × CRF)
  ///
  /// 예시:
  /// - CRF 18 → 1.32 bpp (고품질)
  /// - CRF 23 → 0.82 bpp (권장)
  /// - CRF 28 → 0.51 bpp (중간)
  /// - CRF 35 → 0.24 bpp (저품질)
  static double _getCrfFactor(int crf) {
    // H.264 CRF 경험적 공식
    return 2.0 * (0.94 - (crf / 100)); // 간소화된 선형 근사
  }

  /// 파일 크기를 사람이 읽기 쉬운 형식으로 변환
  ///
  /// 입력: [sizeInMB] - 파일 크기 (MB)
  /// 출력: "X.X GB" 또는 "X.X MB" 형식 문자열
  static String formatFileSize(double sizeInMB) {
    if (sizeInMB >= 1024) {
      final sizeInGB = sizeInMB / 1024;
      return '${sizeInGB.toStringAsFixed(1)} GB';
    } else {
      return '${sizeInMB.toStringAsFixed(1)} MB';
    }
  }

  /// 시간당 파일 크기 계산 (MB/시간)
  ///
  /// 설정 비교 시 유용합니다.
  /// 예: "이 설정으로 1시간 녹화 시 2.5 GB"
  static double estimatePerHour({
    required int videoWidth,
    required int videoHeight,
    required int fps,
    required int crf,
    required int audioBitrate,
  }) {
    return estimateFileSize(
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      fps: fps,
      crf: crf,
      audioBitrate: audioBitrate,
      durationMinutes: 60, // 1시간
    );
  }
}
