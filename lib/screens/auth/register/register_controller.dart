import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_service.dart';

class RegisterController extends GetxController {
  final AuthService _authService;
  final UserService _userService;

  RegisterController({
    AuthService? authService,
    UserService? userService,
  })  : _authService = authService ?? AuthService(),
        _userService = userService ?? UserService();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  // Reactive states
  final RxBool isLoading = false.obs;
  final RxBool isPasswordVisible = false.obs;
  final RxBool isConfirmPasswordVisible = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  // Name validation
  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  // Email validation
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

  // Password validation
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Confirm password validation
  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> register() async {
    errorMessage.value = '';

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (isLoading.value) return;

    isLoading.value = true;

    try {
      final name = nameController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text;

      // 1. Create Firebase Auth user
      final credential = await _authService.register(
        email: email,
        password: password,
        name: name,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw 'User registration failed. No UID returned.';
      }

      // 2. Create Firestore user document
      final newUser = UserModel(
        uid: uid,
        name: name,
        email: email,
        profileImage: '',
        isOnline: true,
        createdAt: DateTime.now(),
      );

      await _userService.createUser(newUser);

      // 3. Navigate to Home
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar(
        'Registration Failed',
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

  void goToLogin() {
    Get.back();
  }
}
