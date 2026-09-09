class PendingCallModel {
  final String callId;
  final String callerUid;
  final String callerName;
  final String callerZegoUserId;
  final String? callerPhoto;
  final String callType; // 'audio' or 'video'
  final DateTime timestamp;
  final DateTime expiresAt;

  const PendingCallModel({
    required this.callId,
    required this.callerUid,
    required this.callerName,
    required this.callerZegoUserId,
    this.callerPhoto,
    required this.callType,
    required this.timestamp,
    required this.expiresAt,
  });

  bool get isVideo => callType.toLowerCase() == 'video';

  /// A call is considered expired if current time is past expiresAt,
  /// or if more than 60 seconds have elapsed since creation.
  bool get isExpired {
    final now = DateTime.now();
    return now.isAfter(expiresAt) || now.difference(timestamp).inSeconds > 60;
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerUid': callerUid,
      'callerName': callerName,
      'callerZegoUserId': callerZegoUserId,
      'callerPhoto': callerPhoto,
      'callType': callType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    };
  }

  factory PendingCallModel.fromMap(Map<String, dynamic> map) {
    final rawTimestamp = map['timestamp'];
    final DateTime parsedTimestamp = rawTimestamp is int
        ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp)
        : (rawTimestamp is String
            ? (int.tryParse(rawTimestamp) != null
                ? DateTime.fromMillisecondsSinceEpoch(int.parse(rawTimestamp))
                : (DateTime.tryParse(rawTimestamp) ?? DateTime.now()))
            : DateTime.now());

    final rawExpiresAt = map['expiresAt'];
    final DateTime parsedExpiresAt = rawExpiresAt is int
        ? DateTime.fromMillisecondsSinceEpoch(rawExpiresAt)
        : (rawExpiresAt is String
            ? (int.tryParse(rawExpiresAt) != null
                ? DateTime.fromMillisecondsSinceEpoch(int.parse(rawExpiresAt))
                : (DateTime.tryParse(rawExpiresAt) ??
                    parsedTimestamp.add(const Duration(seconds: 60))))
            : parsedTimestamp.add(const Duration(seconds: 60)));

    return PendingCallModel(
      callId: map['callId'] as String? ?? '',
      callerUid: map['callerUid'] as String? ?? '',
      callerName: map['callerName'] as String? ?? 'User',
      callerZegoUserId: map['callerZegoUserId'] as String? ?? (map['callerUid'] as String? ?? ''),
      callerPhoto: map['callerPhoto'] as String?,
      callType: (map['callType'] as String? ?? 'audio').toLowerCase(),
      timestamp: parsedTimestamp,
      expiresAt: parsedExpiresAt,
    );
  }

  factory PendingCallModel.fromFcmPayload(Map<String, dynamic> data) {
    return PendingCallModel.fromMap(data);
  }
}
