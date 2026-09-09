import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore? _injectedFirestore;
  FirebaseFirestore? _firestoreInstance;

  UserService({FirebaseFirestore? firestore}) : _injectedFirestore = firestore;

  FirebaseFirestore get _instance {
    _firestoreInstance ??= _injectedFirestore ?? FirebaseFirestore.instance;
    return _firestoreInstance!;
  }

  // Users collection reference
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _instance.collection('users');

  // Create or save user document in Firestore using Firebase Auth UID as doc ID
  Future<void> createUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(
            user.toMap(),
            SetOptions(merge: true),
          );
      debugPrint('Firestore user document created for UID: ${user.uid}');
    } catch (e) {
      debugPrint('UserService.createUser error: $e');
      throw 'Failed to save user profile to database.';
    }
  }

  // Create or save new user profile with server timestamps (preferred for Phone Auth registration)
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String phoneNumber,
    String? profileImage,
  }) async {
    try {
      final data = <String, dynamic>{
        'uid': uid,
        'name': name.trim(),
        'phoneNumber': phoneNumber.trim(),
        'profileImage': profileImage?.trim() ?? '',
        'isOnline': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _usersCollection.doc(uid).set(
            data,
            SetOptions(merge: true),
          );
      debugPrint('Firestore user profile created for UID: $uid');
    } catch (e) {
      debugPrint('UserService.createUserProfile error: $e');
      throw 'Failed to save user profile to database.';
    }
  }

  // Retrieve user document by UID
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return UserModel.fromMap(doc.data()!, documentId: doc.id);
    } catch (e) {
      debugPrint('UserService.getUser error: $e');
      return null;
    }
  }

  // Retrieve all user documents from the users collection
  Future<List<UserModel>> getUsers() async {
    try {
      final snapshot = await _usersCollection.get();
      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data(), documentId: doc.id);
      }).toList();
    } catch (e) {
      debugPrint('UserService.getUsers error: $e');
      throw mapFirestoreError(e);
    }
  }

  // Update user online status
  Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    try {
      await _usersCollection.doc(uid).update({'isOnline': isOnline});
    } catch (e) {
      debugPrint('UserService.updateOnlineStatus error: $e');
    }
  }

  // Update user profile fields (name and optional profileImage)
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    String? profileImage,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'name': name.trim(),
      };
      if (profileImage != null) {
        data['profileImage'] = profileImage.trim();
      }
      await _usersCollection.doc(uid).update(data);
    } catch (e) {
      debugPrint('UserService.updateUserProfile error: $e');
      throw mapFirestoreError(e);
    }
  }

  // Map Firebase Firestore exceptions to friendly, actionable messages
  static String mapFirestoreError(dynamic error) {
    if (error is FirebaseException) {
      final message = error.message ?? '';
      if (error.code == 'permission-denied') {
        if (message.contains('Cloud Firestore API') ||
            message.contains('disabled') ||
            message.contains('not been used')) {
          return 'Cloud Firestore is disabled in Firebase Console. Please enable Firestore Database in your Firebase project.';
        }
        return 'Access denied. Please check your Firestore security rules.';
      } else if (error.code == 'unavailable') {
        return 'Database temporarily unavailable. Please check your internet connection.';
      }
      return message.isNotEmpty ? message : 'A database error occurred.';
    }
    return error.toString();
  }
}
