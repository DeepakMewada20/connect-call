import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/auth/forgot_password/forgot_password_controller.dart';
import 'package:connect_call/screens/auth/login/login_controller.dart';
import 'package:connect_call/screens/auth/register/register_controller.dart';
import 'package:connect_call/services/auth_service.dart';

void main() {
  group('UserModel Tests', () {
    test('toMap and fromMap should correctly serialize and deserialize', () {
      final now = DateTime(2026, 9, 7, 12, 0);
      final user = UserModel(
        uid: 'user_123',
        name: 'Sarah Johnson',
        email: 'sarah@example.com',
        profileImage: 'https://example.com/avatar.png',
        isOnline: true,
        createdAt: now,
      );

      final map = user.toMap();
      expect(map['uid'], 'user_123');
      expect(map['name'], 'Sarah Johnson');
      expect(map['email'], 'sarah@example.com');
      expect(map['profileImage'], 'https://example.com/avatar.png');
      expect(map['isOnline'], true);
      expect(map['createdAt'], isA<Timestamp>());

      final deserialized = UserModel.fromMap(map, documentId: 'user_123');
      expect(deserialized.uid, 'user_123');
      expect(deserialized.name, 'Sarah Johnson');
      expect(deserialized.email, 'sarah@example.com');
      expect(deserialized.profileImage, 'https://example.com/avatar.png');
      expect(deserialized.isOnline, true);
    });
  });

  group('Validation Tests', () {
    final loginController = LoginController();
    final registerController = RegisterController();
    final forgotPasswordController = ForgotPasswordController();

    test('Email validation tests', () {
      expect(loginController.validateEmail(''), 'Email is required');
      expect(loginController.validateEmail('   '), 'Email is required');
      expect(loginController.validateEmail('invalid-email'),
          'Please enter a valid email address');
      expect(loginController.validateEmail('user@domain'),
          'Please enter a valid email address');
      expect(loginController.validateEmail('test@example.com'), isNull);

      expect(forgotPasswordController.validateEmail(''), 'Email is required');
      expect(forgotPasswordController.validateEmail('test@example.com'), isNull);
    });

    test('Password validation tests', () {
      expect(loginController.validatePassword(''), 'Password is required');
      expect(loginController.validatePassword('secret123'), isNull);

      expect(registerController.validatePassword(''), 'Password is required');
      expect(registerController.validatePassword('12345'),
          'Password must be at least 6 characters');
      expect(registerController.validatePassword('123456'), isNull);
    });

    test('Name validation tests', () {
      expect(registerController.validateName(''), 'Please enter your name');
      expect(registerController.validateName('a'),
          'Name must be at least 2 characters');
      expect(registerController.validateName('Sarah'), isNull);
    });

    test('Confirm password validation tests', () {
      registerController.passwordController.text = 'password123';
      expect(registerController.validateConfirmPassword(''),
          'Please confirm your password');
      expect(registerController.validateConfirmPassword('different123'),
          'Passwords do not match');
      expect(registerController.validateConfirmPassword('password123'), isNull);
    });
  });

  group('AuthService Error Mapping Tests', () {
    test('mapFirebaseAuthError returns user-friendly messages', () {
      expect(
        AuthService.mapFirebaseAuthError(
          FirebaseAuthException(code: 'invalid-credential'),
        ),
        'Invalid email or password. Please verify your credentials.',
      );

      expect(
        AuthService.mapFirebaseAuthError(
          FirebaseAuthException(code: 'email-already-in-use'),
        ),
        'This email is already registered. Please login instead.',
      );

      expect(
        AuthService.mapFirebaseAuthError(
          FirebaseAuthException(code: 'weak-password'),
        ),
        'The password is too weak. Please use a stronger password.',
      );

      expect(
        AuthService.mapFirebaseAuthError(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        'Network error. Please check your internet connection.',
      );
    });
  });
}
