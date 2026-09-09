import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_service.dart';

class LoginController extends GetxController {
  final AuthService _authService;
  final UserService _userService;

  LoginController({
    AuthService? authService,
    UserService? userService,
  })  : _authService = authService ?? AuthService(),
        _userService = userService ?? UserService();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();

  // Selected country code (default India +91)
  final RxString selectedCountryCode = '+91'.obs;

  // Reactive UI state
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }

  // Phone number validation rule
  String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    final cleanNumber = value.trim().replaceAll(RegExp(r'\s+|-'), '');

    // Digits only
    if (!RegExp(r'^\d+$').hasMatch(cleanNumber)) {
      return 'Phone number must contain only digits';
    }

    // Validation for India (+91)
    if (selectedCountryCode.value == '+91') {
      if (cleanNumber.length != 10) {
        return 'Please enter a valid 10-digit mobile number';
      }
      if (!RegExp(r'^[6-9]').hasMatch(cleanNumber)) {
        return 'Indian mobile numbers start with 6, 7, 8, or 9';
      }
    } else {
      if (cleanNumber.length < 7 || cleanNumber.length > 15) {
        return 'Please enter a valid phone number (7-15 digits)';
      }
    }

    return null;
  }

  // Trigger Send OTP
  Future<void> sendOtp() async {
    errorMessage.value = '';

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (isLoading.value) return;

    final cleanNumber =
        phoneController.text.trim().replaceAll(RegExp(r'\s+|-'), '');
    final fullPhoneNumber = '${selectedCountryCode.value}$cleanNumber';

    isLoading.value = true;

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('LoginController: Auto-verification completed by Firebase');
          try {
            final userCredential =
                await _authService.signInWithCredential(credential);
            await handlePostAuthNavigation(userCredential.user, fullPhoneNumber);
          } catch (e) {
            isLoading.value = false;
            errorMessage.value = e.toString();
            Get.snackbar(
              'Verification Error',
              errorMessage.value,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red.shade600,
              colorText: Colors.white,
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('LoginController: verificationFailed: ${e.code} - ${e.message}');
          isLoading.value = false;
          errorMessage.value = AuthService.mapFirebaseAuthError(e);
          Get.snackbar(
            'Verification Failed',
            errorMessage.value,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade600,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('LoginController: codeSent received verificationId');
          isLoading.value = false;
          Get.toNamed(
            AppRoutes.otp,
            arguments: {
              'verificationId': verificationId,
              'phoneNumber': fullPhoneNumber,
              'resendToken': resendToken,
            },
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('LoginController: codeAutoRetrievalTimeout');
        },
      );
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = e.toString();
      Get.snackbar(
        'Request Failed',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    }
  }

  // Handle post-authentication navigation:
  // Check Firestore user profile; if existing user -> Home; if new user -> Name screen
  Future<void> handlePostAuthNavigation(User? user, String fallbackPhone) async {
    if (user == null) {
      isLoading.value = false;
      return;
    }

    try {
      final existingProfile = await _userService.getUser(user.uid);
      isLoading.value = false;

      if (existingProfile != null && existingProfile.name.trim().isNotEmpty) {
        // Existing User: Navigate directly to Home
        Get.offAllNamed(AppRoutes.home);
      } else {
        // New User: Navigate to Name Screen
        Get.offAllNamed(
          AppRoutes.name,
          arguments: {
            'uid': user.uid,
            'phoneNumber': user.phoneNumber ?? fallbackPhone,
          },
        );
      }
    } catch (e) {
      isLoading.value = false;
      debugPrint('LoginController.handlePostAuthNavigation error: $e');
      // If Firestore query fails, fallback safely to Name screen so profile can be ensured
      Get.offAllNamed(
        AppRoutes.name,
        arguments: {
          'uid': user.uid,
          'phoneNumber': user.phoneNumber ?? fallbackPhone,
        },
      );
    }
  }
}
