class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
  });

  factory AuthTokens.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Token payload must be a JSON object.');
    }

    final Object? accessToken = json['access_token'];
    final Object? refreshToken = json['refresh_token'];
    final Object? tokenType = json['token_type'] ?? 'bearer';
    if (accessToken is! String || accessToken.trim().isEmpty) {
      throw const FormatException('access_token is missing.');
    }
    if (refreshToken is! String || refreshToken.trim().isEmpty) {
      throw const FormatException('refresh_token is missing.');
    }
    if (tokenType is! String || tokenType.trim().isEmpty) {
      throw const FormatException('token_type is invalid.');
    }

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
    };
  }
}
