// 무엇을 하는 코드인지: Zoom API와 통신하여 테스트 회의를 생성/삭제하는 서비스
//
// 입력: ZoomApiConfig (인증 정보)
// 출력: 회의 링크, 회의 ID
// 예외: 인증 실패, 네트워크 오류, API 제한

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/zoom_api_config.dart';

/// Zoom 회의 정보
class ZoomMeeting {
  final String id;
  final String joinUrl;
  final String password;
  final DateTime createdAt;

  ZoomMeeting({
    required this.id,
    required this.joinUrl,
    required this.password,
    required this.createdAt,
  });

  factory ZoomMeeting.fromJson(Map<String, dynamic> json) {
    return ZoomMeeting(
      id: json['id'].toString(),
      joinUrl: json['join_url'] as String,
      password: json['password'] as String? ?? '',
      createdAt: DateTime.now(),
    );
  }
}

/// Zoom API 서비스
///
/// Server-to-Server OAuth를 사용하여 Zoom API와 통신합니다.
/// 입력: ZoomApiConfig
/// 출력: 테스트 회의 생성/삭제 성공 여부
/// 예외: 인증 실패 시 false 반환
class ZoomApiService {
  final Logger _logger = Logger();
  ZoomApiConfig? _config;
  String? _accessToken;
  DateTime? _tokenExpiry;

  static const String _baseUrl = 'https://api.zoom.us/v2';
  static const String _oauthUrl = 'https://zoom.us/oauth/token';

  /// API 설정
  void configure(ZoomApiConfig config) {
    _config = config;
    _accessToken = null;
    _tokenExpiry = null;
    _logger.i('Zoom API 설정 완료: ${config.isConfigured ? "유효" : "미설정"}');
  }

  /// 설정되어 있는지 확인
  bool get isConfigured => _config?.isConfigured ?? false;

  /// Access Token 발급
  ///
  /// Server-to-Server OAuth를 사용하여 액세스 토큰을 발급합니다.
  /// 입력: 없음 (config 사용)
  /// 출력: Access Token 문자열
  /// 예외: 인증 실패 시 null 반환
  Future<String?> _getAccessToken() async {
    if (_config == null || !_config!.isConfigured) {
      _logger.e('Zoom API 설정이 필요합니다');
      return null;
    }

    // 기존 토큰이 유효하면 재사용
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      _logger.d('기존 Access Token 재사용');
      return _accessToken;
    }

    try {
      _logger.i('Access Token 발급 요청...');

      final credentials = base64Encode(
        utf8.encode('${_config!.clientId}:${_config!.clientSecret}'),
      );

      final response = await http.post(
        Uri.parse('$_oauthUrl?grant_type=account_credentials&account_id=${_config!.accountId}'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'] as String;
        final expiresIn = data['expires_in'] as int; // 초 단위
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60)); // 1분 여유

        _logger.i('✅ Access Token 발급 성공 (유효기간: $expiresIn초)');
        return _accessToken;
      } else {
        _logger.e('❌ Access Token 발급 실패: ${response.statusCode}');
        _logger.e('응답: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Access Token 발급 예외', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// 테스트 회의 생성
  ///
  /// 즉시 시작 가능한 임시 회의를 생성합니다.
  /// 입력: [topic] 회의 주제 (선택, 기본값: "sat-lec-rec 테스트")
  /// 출력: ZoomMeeting 객체
  /// 예외: 생성 실패 시 null 반환
  Future<ZoomMeeting?> createTestMeeting({
    String topic = 'sat-lec-rec 자동화 테스트',
  }) async {
    try {
      _logger.i('🔧 테스트 회의 생성 시작...');

      final token = await _getAccessToken();
      if (token == null) {
        _logger.e('❌ Access Token이 없어 회의를 생성할 수 없습니다');
        return null;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/users/me/meetings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'topic': topic,
          'type': 1, // Instant meeting (즉시 회의)
          'settings': {
            'host_video': false,
            'participant_video': false,
            'join_before_host': true,
            'mute_upon_entry': true,
            'waiting_room': false, // 대기실 끄기 (테스트 편의)
            'audio': 'both',
          },
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final meeting = ZoomMeeting.fromJson(data);

        _logger.i('✅ 테스트 회의 생성 성공!');
        _logger.i('  회의 ID: ${meeting.id}');
        _logger.i('  참가 링크: ${meeting.joinUrl}');
        _logger.i('  비밀번호: ${meeting.password.isEmpty ? "없음" : meeting.password}');

        return meeting;
      } else {
        _logger.e('❌ 회의 생성 실패: ${response.statusCode}');
        _logger.e('응답: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('❌ 회의 생성 예외', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// 회의 삭제
  ///
  /// 테스트 후 생성된 회의를 삭제합니다.
  /// 입력: [meetingId] 삭제할 회의 ID
  /// 출력: 성공 여부
  /// 예외: 삭제 실패 시 false 반환
  Future<bool> deleteMeeting(String meetingId) async {
    try {
      _logger.i('🗑️ 회의 삭제 시작: $meetingId');

      final token = await _getAccessToken();
      if (token == null) {
        _logger.e('❌ Access Token이 없어 회의를 삭제할 수 없습니다');
        return false;
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/meetings/$meetingId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        _logger.i('✅ 회의 삭제 성공: $meetingId');
        return true;
      } else {
        _logger.w('⚠️ 회의 삭제 실패: ${response.statusCode}');
        _logger.w('응답: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('❌ 회의 삭제 예외', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 사용자 정보 조회 (API 테스트용)
  ///
  /// API 인증이 올바른지 테스트합니다.
  /// 입력: 없음
  /// 출력: 사용자 이메일 (성공 시)
  /// 예외: 실패 시 null 반환
  Future<String?> getUserInfo() async {
    try {
      _logger.i('👤 사용자 정보 조회...');

      final token = await _getAccessToken();
      if (token == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final email = data['email'] as String;
        _logger.i('✅ 사용자 확인: $email');
        return email;
      } else {
        _logger.e('❌ 사용자 정보 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('❌ 사용자 정보 조회 예외', error: e);
      return null;
    }
  }
}
