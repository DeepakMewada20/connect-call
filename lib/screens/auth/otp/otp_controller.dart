import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_service.dart';

class OtpController extends GetxController {
  final AuthService _authService;
  final UserService _userService;

  OtpController({
    AuthService? authService,
    UserService? userService,
  })  : _authService = authService ?? AuthService(),
        _userService = userService ?? UserService();

  // Arguments passed from login
  final RxString verificationId = ''.obs;
  final RxString phoneNumber = ''.obs;
  int? resendToken;

  // OTP text controller
  final TextEditingController otpController = TextEditingController();

  // UI state
  final RxBool isLoading = false.obs;
  final RxBool isResending = false.obs;
  final RxString errorMessage = ''.obs;

  // Resend cooldown timer
  static const int resendCooldownSeconds = 60;
  final RxInt secondsRemaining = resendCooldownSeconds.obs;
  final RxBool canResend = false.obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map) {
      verificationId.value = args['verificationId'] as String? ?? '';
      phoneNumber.value = args['phoneNumber'] as String? ?? '';
      resendToken = args['resendToken'] as int?;
    }
    startResendTimer();
  }

  @override
  void onClose() {
    _timer?.cancel();
    otpController.dispose();
    super.onClose();
  }

  // Starts or resets 60s countdown timer
  void startResendTimer() {
    _timer?.cancel();
    canResend.value = false;
    secondsRemaining.value = resendCooldownSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining.value > 1) {
        secondsRemaining.value--;
      } else {
        secondsRemaining.value = 0;
        canResend.value = true;
        timer.cancel();
      }
    });
  }

  // OTP validation rule
  String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the 6-digit OTP';
    }
    final cleanCode = value.trim();
    if (cleanCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
      return 'OTP must be exactly 6 digits';
    }
    return null;
  }

  // Manual OTP verification
  Future<void> verifyOtp() async {
    errorMessage.value = '';

    final otp = otpController.text.trim();
    final validationError = validateOtp(otp);
    if (validationError != null) {
      errorMessage.value = validationError;
      Get.snackbar(
        'Invalid OTP',
        validationError,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    if (verificationId.value.isEmpty) {
      errorMessage.value = 'Verification session not found. Please resend OTP.';
      Get.snackbar(
        'Session Expired',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    try {
      final userCredential = await _authService.signInWithPhoneCredential(
        verificationId: verificationId.value,
        smsCode: otp,
      );

      await handlePostAuthNavigation(userCredential.user);
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = e.toString();
      Get.snackbar(
        'Verification Failed',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    }
  }

  // Resend OTP via SMS
  Future<void> resendOtp() async {
    if (!canResend.value || isResending.value || phoneNumber.value.isEmpty) {
      return;
    }

    isResending.value = true;
    errorMessage.value = '';

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber.value,
        resendToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('OtpController: Auto-verification completed on resend');
          try {
            final userCredential =
                await _authService.signInWithCredential(credential);
            await handlePostAuthNavigation(userCredential.user);
          } catch (e) {
            isResending.value = false;
            errorMessage.value = e.toString();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          isResending.value = false;
          errorMessage.value = AuthService.mapFirebaseAuthError(e);
          Get.snackbar(
            'Resend Failed',
            errorMessage.value,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade600,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
          );
        },
        codeSent: (String newVerificationId, int? newResendToken) {
          debugPrint('OtpController: New OTP sent');
          isResending.value = false;
          verificationId.value = newVerificationId;
          resendToken = newResendToken;
          startResendTimer();
          Get.snackbar(
            'OTP Sent',
            'A new verification code has been sent to ${phoneNumber.value}',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF10B981),
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
          );
        },
        codeAutoRetrievalTimeout: (String newVerificationId) {
          verificationId.value = newVerificationId;
        },
      );
    } catch (e) {
      isResending.value = false;
      errorMessage.value = e.toString();
      Get.snackbar(
        'Resend Failed',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }

  // Navigate after successful phone auth:
  // Existing profile with name -> Home
  // New user / missing profile -> Name Screen
  Future<void> handlePostAuthNavigation(User? user) async {
    if (user == null) {
      isLoading.value = false;
      return;
    }

    try {
      final existingProfile = await _userService.getUser(user.uid);
      isLoading.value = false;

      if (existingProfile != null && existingProfile.name.trim().isNotEmpty) {
        // Existing User: Navigate to Home
        Get.offAllNamed(AppRoutes.home);
      } else {
        // New User: Navigate to Name Screen
        Get.offAllNamed(
          AppRoutes.name,
          arguments: {
            'uid': user.uid,
            'phoneNumber': user.phoneNumber ?? phoneNumber.value,
          },
        );
      }
    } catch (e) {
      isLoading.value = false;
      debugPrint('OtpController.handlePostAuthNavigation error: $e');
      // If Firestore read fails, navigate to Name Screen so profile is initialized
      Get.offAllNamed(
        AppRoutes.name,
        arguments: {
          'uid': user.uid,
          'phoneNumber': user.phoneNumber ?? phoneNumber.value,
        },
      );
    }
  }

  void goBack() {
    Get.back();
  }
}
