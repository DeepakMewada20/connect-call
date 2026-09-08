import 'package:cloud_firestore/cloud_firestore.dart';

/// CallModel represents a single call history record in ConnectCall.
///
/// Persistent location: `users/{userId}/call_history/{callId}`
class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String calleeId;
  final String calleeName;
  final String? calleePhoto;
  final String callType; // 'audio' | 'video'
  final String direction; // 'incoming' | 'outgoing'
  final String status; // 'calling' | 'connected' | 'ended' | 'rejected' | 'missed' | 'failed' | 'busy' | 'disconnected'
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.calleeId,
    required this.calleeName,
    this.calleePhoto,
    required this.callType,
    required this.direction,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
  });

  // Convert to Map for Firestore persistence
  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
    };
  }

  // Create from Firestore document snapshot map
  factory CallModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    final dynamic rawEndedAt = map['endedAt'];
    final DateTime? parsedEndedAt =
        rawEndedAt != null ? parseDate(rawEndedAt) : null;

    return CallModel(
      id: documentId ?? (map['id'] as String? ?? ''),
      callerId: map['callerId'] as String? ?? '',
      callerName: map['callerName'] as String? ?? '',
      callerPhoto: map['callerPhoto'] as String?,
      calleeId: map['calleeId'] as String? ?? '',
      calleeName: map['calleeName'] as String? ?? '',
      calleePhoto: map['calleePhoto'] as String?,
      callType: map['callType'] as String? ?? 'audio',
      direction: map['direction'] as String? ?? 'outgoing',
      status: map['status'] as String? ?? 'ended',
      startedAt: parseDate(map['startedAt']),
      endedAt: parsedEndedAt,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  CallModel copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? callerPhoto,
    String? calleeId,
    String? calleeName,
    String? calleePhoto,
    String? callType,
    String? direction,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhoto: callerPhoto ?? this.callerPhoto,
      calleeId: calleeId ?? this.calleeId,
      calleeName: calleeName ?? this.calleeName,
      calleePhoto: calleePhoto ?? this.calleePhoto,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
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
    if (currentUid != null && currentUid == callerId) {
      return calleeName.isNotEmpty ? calleeName : 'User';
    }
    return callerName.isNotEmpty ? callerName : 'User';
  }

  // Get UID of other participant relative to logged-in user
  String getOtherUserId(String? currentUid) {
    if (currentUid != null && currentUid == callerId) {
      return calleeId;
    }
    return callerId;
  }

  // Get photo of other participant relative to logged-in user
  String? getOtherUserPhoto(String? currentUid) {
    if (currentUid != null && currentUid == callerId) {
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
