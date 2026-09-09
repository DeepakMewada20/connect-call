import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/phone_number_util.dart';

class UserModel {
  final String uid;
  final String name;
  final String phoneNumber;
  final String? normalizedPhoneNumber;
  final String profileImage;
  final bool isOnline;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.name,
    this.phoneNumber = '',
    this.normalizedPhoneNumber,
    this.profileImage = '',
    this.isOnline = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Returns the normalized phone number, falling back to normalizing [phoneNumber].
  String get effectiveNormalizedPhone =>
      normalizedPhoneNumber ?? PhoneNumberUtil.normalize(phoneNumber) ?? phoneNumber;

  // Convert UserModel to a Map for Firestore storage
  Map<String, dynamic> toMap() {
    final normalized = normalizedPhoneNumber ?? PhoneNumberUtil.normalize(phoneNumber);
    return {
      'uid': uid,
      'name': name,
      'phoneNumber': phoneNumber,
      if (normalized != null && normalized.isNotEmpty) 'normalizedPhoneNumber': normalized,
      'profileImage': profileImage,
      'isOnline': isOnline,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
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

    DateTime? parsedUpdatedAt;
    final rawUpdatedAt = map['updatedAt'];
    if (rawUpdatedAt is Timestamp) {
      parsedUpdatedAt = rawUpdatedAt.toDate();
    } else if (rawUpdatedAt is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    }

    final rawPhone = map['phoneNumber'] as String? ?? '';
    final rawNormalized = map['normalizedPhoneNumber'] as String?;

    return UserModel(
      uid: documentId ?? map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phoneNumber: rawPhone,
      normalizedPhoneNumber: rawNormalized ?? PhoneNumberUtil.normalize(rawPhone),
      profileImage: map['profileImage'] as String? ?? '',
      isOnline: map['isOnline'] as bool? ?? false,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  // Helper copyWith
  UserModel copyWith({
    String? uid,
    String? name,
    String? phoneNumber,
    String? normalizedPhoneNumber,
    String? profileImage,
    bool? isOnline,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      normalizedPhoneNumber: normalizedPhoneNumber ?? this.normalizedPhoneNumber,
      profileImage: profileImage ?? this.profileImage,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
