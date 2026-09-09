import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a blocked user record in Firestore under
/// `users/{currentUserUid}/blockedUsers/{blockedUserUid}`.
class BlockedUserModel {
  final String blockedUserUid;
  final DateTime createdAt;

  const BlockedUserModel({
    required this.blockedUserUid,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'blockedUserUid': blockedUserUid,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BlockedUserModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime parsedCreatedAt;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      parsedCreatedAt = raw.toDate();
    } else if (raw is String) {
      parsedCreatedAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return BlockedUserModel(
      blockedUserUid: documentId ?? map['blockedUserUid'] as String? ?? '',
      createdAt: parsedCreatedAt,
    );
  }
}
