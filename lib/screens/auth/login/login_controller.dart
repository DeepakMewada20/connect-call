import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../models/user_model.dart';
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

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Reactive state
  final RxBool isLoading = false.obs;
  final RxBool isGoogleLoading = false.obs;
  final RxBool isPasswordVisible = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  // Email validation rule
  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Password validation rule
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  Future<void> login() async {
    errorMessage.value = '';

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (isLoading.value || isGoogleLoading.value) return;

    isLoading.value = true;

    try {
      await _authService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // Navigate to Home upon successful login
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar(
        'Login Failed',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Google Sign-In logic with Firestore synchronization
  Future<void> signInWithGoogle() async {
    if (isLoading.value || isGoogleLoading.value) return;

    isGoogleLoading.value = true;
    errorMessage.value = '';

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        // User dismissed the Google account picker
        return;
      }

      final user = credential.user;
      if (user != null) {
        // Check if user document already exists in Firestore
        final existingUser = await _userService.getUser(user.uid);
        if (existingUser == null) {
          final newUser = UserModel(
            uid: user.uid,
            name: user.displayName ?? 'Google User',
            email: user.email ?? '',
            profileImage: user.photoURL ?? '',
            isOnline: true,
            createdAt: DateTime.now(),
          );
          await _userService.createUser(newUser);
        } else {
          await _userService.updateOnlineStatus(user.uid, true);
        }

        Get.offAllNamed(AppRoutes.home);
      }
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar(
        'Google Sign-In Failed',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    } finally {
      isGoogleLoading.value = false;
    }
  }

  void goToRegister() {
    Get.toNamed(AppRoutes.register);
  }

  void goToForgotPassword() {
    Get.toNamed(AppRoutes.forgotPassword);
  }
}
