import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profileImage;
  final bool isOnline;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.profileImage = '',
    this.isOnline = false,
    required this.createdAt,
  });

  // Convert UserModel to a Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'isOnline': isOnline,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create UserModel from Firestore Map
  factory UserModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime parsedCreatedAt;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return UserModel(
      uid: documentId ?? map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      profileImage: map['profileImage'] as String? ?? '',
      isOnline: map['isOnline'] as bool? ?? false,
      createdAt: parsedCreatedAt,
    );
  }

  // Helper copyWith
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? profileImage,
    bool? isOnline,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
