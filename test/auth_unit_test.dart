import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/auth/login/login_controller.dart';
import 'package:connect_call/screens/auth/name/name_controller.dart';
import 'package:connect_call/screens/auth/otp/otp_controller.dart';
import 'package:connect_call/services/auth_service.dart';

void main() {
  group('UserModel Tests', () {
    test('toMap and fromMap should correctly serialize and deserialize phone auth fields', () {
      final now = DateTime(2026, 9, 7, 12, 0);
      final updated = DateTime(2026, 9, 7, 12, 30);
      final user = UserModel(
        uid: 'user_123',
        name: 'Deepak Mewada',
        phoneNumber: '+919876543210',
        profileImage: 'https://example.com/avatar.png',
        isOnline: true,
        createdAt: now,
        updatedAt: updated,
      );

      final map = user.toMap();
      expect(map['uid'], 'user_123');
      expect(map['name'], 'Deepak Mewada');
      expect(map['phoneNumber'], '+919876543210');
      expect(map['profileImage'], 'https://example.com/avatar.png');
      expect(map['isOnline'], true);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());

      final deserialized = UserModel.fromMap(map, documentId: 'user_123');
      expect(deserialized.uid, 'user_123');
      expect(deserialized.name, 'Deepak Mewada');
      expect(deserialized.phoneNumber, '+919876543210');
      expect(deserialized.profileImage, 'https://example.com/avatar.png');
      expect(deserialized.isOnline, true);
      expect(deserialized.updatedAt, isNotNull);
    });
  });

  group('Phone Authentication Validation Tests', () {
    final loginController = LoginController();
    final otpController = OtpController();
    final nameController = NameController();

    test('Phone number validation for India (+91)', () {
      loginController.selectedCountryCode.value = '+91';

      expect(loginController.validatePhoneNumber(''), 'Phone number is required');
      expect(loginController.validatePhoneNumber('   '), 'Phone number is required');
      expect(loginController.validatePhoneNumber('abc1234567'),
          'Phone number must contain only digits');
      expect(loginController.validatePhoneNumber('12345'),
          'Please enter a valid 10-digit mobile number');
      expect(loginController.validatePhoneNumber('123456789012'),
          'Please enter a valid 10-digit mobile number');
      expect(loginController.validatePhoneNumber('1234567890'),
          'Indian mobile numbers start with 6, 7, 8, or 9');
      expect(loginController.validatePhoneNumber('9876543210'), isNull);
      expect(loginController.validatePhoneNumber('8123456789'), isNull);
      expect(loginController.validatePhoneNumber('7000000000'), isNull);
      expect(loginController.validatePhoneNumber('6999999999'), isNull);
    });

    test('OTP validation tests', () {
      expect(otpController.validateOtp(''), 'Please enter the 6-digit OTP');
      expect(otpController.validateOtp('   '), 'Please enter the 6-digit OTP');
      expect(otpController.validateOtp('12345'), 'OTP must be exactly 6 digits');
      expect(otpController.validateOtp('1234567'), 'OTP must be exactly 6 digits');
      expect(otpController.validateOtp('12345a'), 'OTP must be exactly 6 digits');
      expect(otpController.validateOtp('123456'), isNull);
    });

    test('New user name validation tests', () {
      expect(nameController.validateName(''), 'Please enter your name');
      expect(nameController.validateName('   '), 'Please enter your name');
      expect(nameController.validateName('a'), 'Name must be at least 2 characters');
      expect(nameController.validateName('Deepak'), isNull);
      expect(nameController.validateName('Deepak Mewada'), isNull);
      expect(nameController.validateName('a' * 51),
          'Name must be at most 50 characters');
    });
  });

  group('AuthService Phone Auth Error Mapping Tests', () {
    test('mapFirebaseAuthError returns user-friendly messages for phone auth codes', () {
      expect(
        AuthService.mapFirebaseAuthError(
          FirebaseAuthException(code: 'invalid-phone-number'),
        ),
        'The phone number entered is invalid. Please check and try again.',
      );

      expect(
        AuthService.mapFirebaseAuthError(
          FirebaseAuthException(code: 'invalid-verification-code'),
        ),
        'Invalid verification code. Please check and try again.',
      );

      expect(
        AuthService.mapFirebaseAuthError(
          FirebaseAuthException(code: 'session-expired'),
        ),
        'The verification code has expired. Please request a new code.',
      );

      expect(
        AuthService.mapFirebaseAuthError(
          FirebaseAuthException(code: 'quota-exceeded'),
        ),
        'SMS quota exceeded for today. Please try again later.',
      );

      expect(
        AuthService.mapFirebaseAuthError(
          FirebaseAuthException(code: 'too-many-requests'),
        ),
        'Too many attempts. Please wait a few minutes and try again.',
      );

      expect(
        AuthService.mapFirebaseAuthError(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        'Network error. Please check your internet connection.',
      );

      expect(
        AuthService.mapFirebaseAuthError(
          FirebaseAuthException(code: 'operation-not-allowed'),
        ),
        'Phone authentication is not enabled in Firebase Console. Please enable Phone provider.',
      );
    });
  });
}
