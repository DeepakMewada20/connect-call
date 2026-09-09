/// Model representing a locally favorited contact in SQLite.
class FavoriteContactModel {
  final int? id;
  final String firebaseUid;
  final String remoteUserId;
  final String contactName;
  final String phoneNumber;
  final DateTime createdAt;

  const FavoriteContactModel({
    this.id,
    required this.firebaseUid,
    required this.remoteUserId,
    this.contactName = '',
    this.phoneNumber = '',
    required this.createdAt,
  });

  String get userId => remoteUserId;
  String get name => contactName;
  String get avatarUrl => '';

  Map<String, dynamic> toSqliteMap() {
    return {
      if (id != null) 'id': id,
      'firebaseUid': firebaseUid,
      'remoteUserId': remoteUserId,
      'contactName': contactName,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory FavoriteContactModel.fromSqliteMap(Map<String, dynamic> map) {
    return FavoriteContactModel(
      id: map['id'] as int?,
      firebaseUid: map['firebaseUid'] as String? ?? '',
      remoteUserId: map['remoteUserId'] as String? ?? '',
      contactName: map['contactName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  FavoriteContactModel copyWith({
    int? id,
    String? firebaseUid,
    String? remoteUserId,
    String? contactName,
    String? phoneNumber,
    DateTime? createdAt,
  }) {
    return FavoriteContactModel(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      contactName: contactName ?? this.contactName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
