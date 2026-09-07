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
      throw 'Unable to load contacts. Please check your connection and try again.';
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
}
