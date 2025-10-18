# Services

녹화, 스케줄링, 트레이, FFmpeg 관리 등 핵심 서비스 레이어입니다.

## 예정된 서비스

- `recorder_service.dart` - 화면/오디오 녹화 제어
- `schedule_service.dart` - 예약 시간 관리 및 자동 실행
- `tray_service.dart` - 시스템 트레이 통합
- `audio_service.dart` - WASAPI 오디오 캡처
- `ffmpeg_service.dart` - FFmpeg 프로세스 관리
- `health_check_service.dart` - 사전 헬스체크 (T-10, T-2)
