import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth? _injectedAuth;
  final GoogleSignIn? _injectedGoogleSignIn;
  FirebaseAuth? _authInstance;
  GoogleSignIn? _googleSignInInstance;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _injectedAuth = auth,
        _injectedGoogleSignIn = googleSignIn;

  FirebaseAuth get _instance {
    _authInstance ??= _injectedAuth ?? FirebaseAuth.instance;
    return _authInstance!;
  }

  GoogleSignIn get _googleSignIn {
    _googleSignInInstance ??= _injectedGoogleSignIn ?? GoogleSignIn();
    return _googleSignInInstance!;
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

  // Register with email and password
  Future<UserCredential> register({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final credential = await _instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update Firebase Auth display name if provided
      if (name != null && name.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(name.trim());
        await credential.user?.reload();
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.register error: ${e.code} - ${e.message}');
      throw mapFirebaseAuthError(e);
    } catch (e) {
      debugPrint('AuthService.register unexpected error: $e');
      throw 'Registration failed. Please try again.';
    }
  }

  // Login with email and password
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.login error: ${e.code} - ${e.message}');
      throw mapFirebaseAuthError(e);
    } catch (e) {
      debugPrint('AuthService.login unexpected error: $e');
      throw 'Login failed. Please try again.';
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the picker
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.signInWithGoogle error: ${e.code} - ${e.message}');
      throw mapFirebaseAuthError(e);
    } catch (e) {
      debugPrint('AuthService.signInWithGoogle unexpected error: $e');
      throw 'Google Sign-In failed. Please try again.';
    }
  }

  // Logout from Firebase and Google
  Future<void> logout() async {
    try {
      await _instance.signOut();
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Google sign out error ignored if not signed in via Google
      }
    } catch (e) {
      debugPrint('AuthService.logout error: $e');
      throw 'Failed to log out. Please try again.';
    }
  }

  // Map Firebase exception codes to human-friendly messages
  static String mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'Invalid email or password. Please verify your credentials.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'weak-password':
        return 'The password is too weak. Please use a stronger password.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase Console.';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'An authentication error occurred. Please try again.';
    }
  }
}
