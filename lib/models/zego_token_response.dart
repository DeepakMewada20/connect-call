class ZegoTokenResponse {
  final int appId;
  final String userId;
  final String token;
  final int expiresIn;

  const ZegoTokenResponse({
    required this.appId,
    required this.userId,
    required this.token,
    required this.expiresIn,
  });

  factory ZegoTokenResponse.fromMap(Map<String, dynamic> map) {
    return ZegoTokenResponse(
      appId: (map['appId'] as num?)?.toInt() ?? 0,
      userId: (map['userId'] as String?)?.trim() ?? '',
      token: (map['token'] as String?)?.trim() ?? '',
      expiresIn: (map['expiresIn'] as num?)?.toInt() ?? 3600,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appId': appId,
      'userId': userId,
      'token': token,
      'expiresIn': expiresIn,
    };
  }

  bool get isValid => appId > 0 && userId.isNotEmpty && token.isNotEmpty;
}
