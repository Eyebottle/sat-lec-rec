// 무엇을 하는 코드인지: Zoom API 인증 설정을 저장하는 모델
//
// Zoom Server-to-Server OAuth 인증 정보를 관리합니다.
// 입력: accountId, clientId, clientSecret
// 출력: API 요청에 필요한 인증 정보
// 예외: 필수 값이 없으면 isConfigured가 false

class ZoomApiConfig {
  final String accountId;
  final String clientId;
  final String clientSecret;

  ZoomApiConfig({
    required this.accountId,
    required this.clientId,
    required this.clientSecret,
  });

  /// API가 설정되어 있는지 확인
  bool get isConfigured =>
      accountId.isNotEmpty &&
      clientId.isNotEmpty &&
      clientSecret.isNotEmpty;

  /// JSON으로 변환
  Map<String, String> toJson() => {
        'accountId': accountId,
        'clientId': clientId,
        'clientSecret': clientSecret,
      };

  /// JSON에서 생성
  factory ZoomApiConfig.fromJson(Map<String, dynamic> json) {
    return ZoomApiConfig(
      accountId: json['accountId'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      clientSecret: json['clientSecret'] as String? ?? '',
    );
  }

  /// 빈 설정 생성
  factory ZoomApiConfig.empty() {
    return ZoomApiConfig(
      accountId: '',
      clientId: '',
      clientSecret: '',
    );
  }

  @override
  String toString() {
    return 'ZoomApiConfig(accountId: ${accountId.isEmpty ? "미설정" : "***"}, '
        'clientId: ${clientId.isEmpty ? "미설정" : "***"}, '
        'clientSecret: ${clientSecret.isEmpty ? "미설정" : "***"})';
  }
}
