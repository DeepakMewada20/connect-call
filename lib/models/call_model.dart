import 'package:cloud_firestore/cloud_firestore.dart';

/// CallModel represents a single call history record in ConnectCall.
///
/// Persistent location: SQLite local database table `call_history`.
class CallModel {
  final String id;
  final String? firebaseUid;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String calleeId;
  final String calleeName;
  final String? calleePhoto;
  final String? phoneNumber;
  final String? zegoUserId;
  final String callType; // 'audio' | 'video'
  final String direction; // 'incoming' | 'outgoing'
  final String status; // 'calling' | 'connected' | 'ended' | 'rejected' | 'missed' | 'failed' | 'busy' | 'disconnected'
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final DateTime createdAt;

  CallModel({
    required this.id,
    this.firebaseUid,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.calleeId,
    required this.calleeName,
    this.calleePhoto,
    this.phoneNumber,
    this.zegoUserId,
    required this.callType,
    required this.direction,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? startedAt;

  /// Effective owner UID for multi-user device scoping
  String get effectiveFirebaseUid {
    if (firebaseUid != null && firebaseUid!.isNotEmpty) {
      return firebaseUid!;
    }
    return direction == 'outgoing' ? callerId : calleeId;
  }

  /// Remote user's ID
  String get remoteUserId => direction == 'outgoing' ? calleeId : callerId;

  /// Remote user's display / contact name
  String get contactName => direction == 'outgoing' ? calleeName : callerName;

  /// Convert to Map for SQLite persistence
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'firebaseUid': effectiveFirebaseUid,
      'remoteUserId': remoteUserId,
      'contactName': contactName,
      'phoneNumber': phoneNumber ?? '',
      'zegoUserId': zegoUserId ?? '',
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoto': callerPhoto ?? '',
      'calleeId': calleeId,
      'calleeName': calleeName,
      'calleePhoto': calleePhoto ?? '',
      'callType': callType,
      'direction': direction,
      'status': status,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'endedAt': endedAt?.millisecondsSinceEpoch,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Factory constructor to restore CallModel from SQLite Map
  factory CallModel.fromSqliteMap(Map<String, dynamic> map) {
    DateTime parseEpoch(dynamic val) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) {
        final parsed = int.tryParse(val);
        if (parsed != null) return DateTime.fromMillisecondsSinceEpoch(parsed);
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final rawEndedAt = map['endedAt'];

    return CallModel(
      id: map['id'] as String? ?? '',
      firebaseUid: map['firebaseUid'] as String?,
      callerId: map['callerId'] as String? ?? '',
      callerName: map['callerName'] as String? ?? '',
      callerPhoto: (map['callerPhoto'] as String?)?.isNotEmpty == true
          ? map['callerPhoto'] as String
          : null,
      calleeId: map['calleeId'] as String? ?? '',
      calleeName: map['calleeName'] as String? ?? '',
      calleePhoto: (map['calleePhoto'] as String?)?.isNotEmpty == true
          ? map['calleePhoto'] as String
          : null,
      phoneNumber: (map['phoneNumber'] as String?)?.isNotEmpty == true
          ? map['phoneNumber'] as String
          : null,
      zegoUserId: (map['zegoUserId'] as String?)?.isNotEmpty == true
          ? map['zegoUserId'] as String
          : null,
      callType: map['callType'] as String? ?? 'audio',
      direction: map['direction'] as String? ?? 'outgoing',
      status: map['status'] as String? ?? 'ended',
      startedAt: parseEpoch(map['startedAt']),
      endedAt: rawEndedAt != null ? parseEpoch(rawEndedAt) : null,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null
          ? parseEpoch(map['createdAt'])
          : parseEpoch(map['startedAt']),
    );
  }

  // Convert to Map for Firestore backwards-compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firebaseUid': effectiveFirebaseUid,
      'remoteUserId': remoteUserId,
      'contactName': contactName,
      'phoneNumber': phoneNumber ?? '',
      'zegoUserId': zegoUserId ?? '',
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoto': callerPhoto ?? '',
      'calleeId': calleeId,
      'calleeName': calleeName,
      'calleePhoto': calleePhoto ?? '',
      'callType': callType,
      'direction': direction,
      'status': status,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'durationSeconds': durationSeconds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Map (handles Timestamp, int epoch millis, or ISO8601 strings)
  factory CallModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return DateTime.fromMillisecondsSinceEpoch(parsed);
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final dynamic rawEndedAt = map['endedAt'];
    final DateTime? parsedEndedAt =
        rawEndedAt != null ? parseDate(rawEndedAt) : null;

    return CallModel(
      id: documentId ?? (map['id'] as String? ?? ''),
      firebaseUid: map['firebaseUid'] as String?,
      callerId: map['callerId'] as String? ?? '',
      callerName: map['callerName'] as String? ?? '',
      callerPhoto: map['callerPhoto'] as String?,
      calleeId: map['calleeId'] as String? ?? '',
      calleeName: map['calleeName'] as String? ?? '',
      calleePhoto: map['calleePhoto'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      zegoUserId: map['zegoUserId'] as String?,
      callType: map['callType'] as String? ?? 'audio',
      direction: map['direction'] as String? ?? 'outgoing',
      status: map['status'] as String? ?? 'ended',
      startedAt: parseDate(map['startedAt']),
      endedAt: parsedEndedAt,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null ? parseDate(map['createdAt']) : parseDate(map['startedAt']),
    );
  }

  CallModel copyWith({
    String? id,
    String? firebaseUid,
    String? callerId,
    String? callerName,
    String? callerPhoto,
    String? calleeId,
    String? calleeName,
    String? calleePhoto,
    String? phoneNumber,
    String? zegoUserId,
    String? callType,
    String? direction,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    DateTime? createdAt,
  }) {
    return CallModel(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhoto: callerPhoto ?? this.callerPhoto,
      calleeId: calleeId ?? this.calleeId,
      calleeName: calleeName ?? this.calleeName,
      calleePhoto: calleePhoto ?? this.calleePhoto,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      zegoUserId: zegoUserId ?? this.zegoUserId,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helpers
  bool get isAudio => callType.toLowerCase() == 'audio';
  bool get isVideo => callType.toLowerCase() == 'video';
  bool get isOutgoing => direction.toLowerCase() == 'outgoing';
  bool get isIncoming => direction.toLowerCase() == 'incoming';
  bool get isMissed => status.toLowerCase() == 'missed';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isFailed => status.toLowerCase() == 'failed';
  bool get isBusy => status.toLowerCase() == 'busy';
  bool get isConnected => status.toLowerCase() == 'connected';
  bool get isEnded => status.toLowerCase() == 'ended';
  bool get isDisconnected => status.toLowerCase() == 'disconnected';

  // Get name of other participant relative to logged-in user
  String getOtherUserName(String? currentUid) {
    if (currentUid != null && currentUid.isNotEmpty) {
      if (currentUid == callerId) {
        return calleeName.isNotEmpty ? calleeName : 'User';
      } else {
        return callerName.isNotEmpty ? callerName : 'User';
      }
    }
    // Direction-based fallback if currentUid is not provided
    if (isOutgoing) {
      return calleeName.isNotEmpty ? calleeName : 'User';
    }
    return callerName.isNotEmpty ? callerName : 'User';
  }

  // Get UID of other participant relative to logged-in user
  String getOtherUserId(String? currentUid) {
    if (currentUid != null && currentUid.isNotEmpty) {
      if (currentUid == callerId) {
        return calleeId;
      } else {
        return callerId;
      }
    }
    // Direction-based fallback if currentUid is not provided
    if (isOutgoing) {
      return calleeId;
    }
    return callerId;
  }

  // Get photo of other participant relative to logged-in user
  String? getOtherUserPhoto(String? currentUid) {
    if (currentUid != null && currentUid.isNotEmpty) {
      if (currentUid == callerId) {
        return calleePhoto;
      } else {
        return callerPhoto;
      }
    }
    // Direction-based fallback if currentUid is not provided
    if (isOutgoing) {
      return calleePhoto;
    }
    return callerPhoto;
  }

  // Formatted duration: '00:00', '01:05', '01:00:00'
  String get formattedDuration {
    if (durationSeconds <= 0) return '00:00';
    final int hours = durationSeconds ~/ 3600;
    final int minutes = (durationSeconds % 3600) ~/ 60;
    final int seconds = durationSeconds % 60;

    final String minStr = minutes.toString().padLeft(2, '0');
    final String secStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final String hourStr = hours.toString().padLeft(2, '0');
      return '$hourStr:$minStr:$secStr';
    }
    return '$minStr:$secStr';
  }

  // Human readable date formatting: 'Today, 11:45 AM', 'Yesterday, 6:20 PM', 'Sep 8, 2026, 7:30 PM'
  String get formattedDate {
    final now = DateTime.now();
    final localStartedAt = startedAt.toLocal();

    final String hour = (localStartedAt.hour % 12 == 0 ? 12 : localStartedAt.hour % 12)
        .toString();
    final String minute = localStartedAt.minute.toString().padLeft(2, '0');
    final String period = localStartedAt.hour >= 12 ? 'PM' : 'AM';
    final String timeStr = '$hour:$minute $period';

    final isToday = now.year == localStartedAt.year &&
        now.month == localStartedAt.month &&
        now.day == localStartedAt.day;

    if (isToday) {
      return 'Today, $timeStr';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == localStartedAt.year &&
        yesterday.month == localStartedAt.month &&
        yesterday.day == localStartedAt.day;

    if (isYesterday) {
      return 'Yesterday, $timeStr';
    }

    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final String monthStr = months[localStartedAt.month - 1];

    if (now.year == localStartedAt.year) {
      return '$monthStr ${localStartedAt.day}, $timeStr';
    } else {
      return '$monthStr ${localStartedAt.day}, ${localStartedAt.year}, $timeStr';
    }
  }
}
