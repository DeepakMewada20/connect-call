import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth? _injectedAuth;
  FirebaseAuth? _authInstance;

  AuthService({
    FirebaseAuth? auth,
  }) : _injectedAuth = auth;

  FirebaseAuth get _instance {
    _authInstance ??= _injectedAuth ?? FirebaseAuth.instance;
    return _authInstance!;
  }

  // Stream of auth state changes for persistence and listeners
  Stream<User?> get authStateChanges {
    try {
      return _instance.authStateChanges();
    } catch (e) {
      debugPrint('AuthService.authStateChanges error: $e');
      return const Stream.empty();
    }
  }

  // Get currently authenticated Firebase user
  User? getCurrentUser() {
    try {
      return _instance.currentUser;
    } catch (e) {
      debugPrint('AuthService.getCurrentUser error: $e');
      return null;
    }
  }

  // Convenience getter for current Firebase User
  User? get currentUser => getCurrentUser();

  // Get current user UID safely
  String? get currentUserId {
    try {
      return _instance.currentUser?.uid;
    } catch (e) {
      debugPrint('AuthService.currentUserId error: $e');
      return null;
    }
  }

  // Update Firebase Auth display name
  Future<void> updateDisplayName(String name) async {
    try {
      await _instance.currentUser?.updateDisplayName(name.trim());
      await _instance.currentUser?.reload();
    } catch (e) {
      debugPrint('AuthService.updateDisplayName error: $e');
    }
  }

  // Trigger Firebase Phone Number verification
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    int? resendToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      await _instance.verifyPhoneNumber(
        phoneNumber: phoneNumber.trim(),
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        forceResendingToken: resendToken,
        timeout: timeout,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.verifyPhoneNumber error: ${e.code} - ${e.message}');
      throw mapFirebaseAuthError(e);
    } catch (e) {
      debugPrint('AuthService.verifyPhoneNumber unexpected error: $e');
      throw 'Failed to send verification code. Please try again.';
    }
  }

  // Sign in using manual verificationId + SMS code
  Future<UserCredential> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      return await _instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.signInWithPhoneCredential error: ${e.code} - ${e.message}');
      throw mapFirebaseAuthError(e);
    } catch (e) {
      debugPrint('AuthService.signInWithPhoneCredential unexpected error: $e');
      throw 'Authentication failed. Please check the code and try again.';
    }
  }

  // Sign in using an existing AuthCredential (e.g. from automatic verificationCompleted)
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    try {
      return await _instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.signInWithCredential error: ${e.code} - ${e.message}');
      throw mapFirebaseAuthError(e);
    } catch (e) {
      debugPrint('AuthService.signInWithCredential unexpected error: $e');
      throw 'Failed to sign in with credential. Please try again.';
    }
  }

  // Logout from Firebase
  Future<void> logout() async {
    try {
      await _instance.signOut();
    } catch (e) {
      debugPrint('AuthService.logout error: $e');
      throw 'Failed to log out. Please try again.';
    }
  }

  // Map Firebase exception codes to human-friendly messages
  static String mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The phone number entered is invalid. Please check and try again.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please check and try again.';
      case 'invalid-verification-id':
        return 'The verification session is invalid. Please request a new OTP.';
      case 'session-expired':
        return 'The verification code has expired. Please request a new code.';
      case 'quota-exceeded':
        return 'SMS quota exceeded for today. Please try again later.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'credential-already-in-use':
        return 'This phone credential is already linked to another account.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled in Firebase Console. Please enable Phone provider.';
      case 'app-not-authorized':
        return 'App not authorized for Firebase Phone Auth. Please verify SHA-1/SHA-256 fingerprints in Firebase Console.';
      case 'missing-client-identifier':
        return 'Device verification failed. Please try again.';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'An authentication error occurred. Please try again.';
    }
  }
}
