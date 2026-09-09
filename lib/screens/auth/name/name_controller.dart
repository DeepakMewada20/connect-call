import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_service.dart';

class NameController extends GetxController {
  final UserService _userService;
  final AuthService _authService;

  NameController({
    UserService? userService,
    AuthService? authService,
  })  : _userService = userService ?? UserService(),
        _authService = authService ?? AuthService();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  String? passedUid;
  String? passedPhone;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map) {
      passedUid = args['uid'] as String?;
      passedPhone = args['phoneNumber'] as String?;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }

  // Name validation: cannot be empty or only whitespace, 2-50 chars
  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (trimmed.length > 50) {
      return 'Name must be at most 50 characters';
    }
    return null;
  }

  // Save profile and proceed to Home
  Future<void> submitName() async {
    errorMessage.value = '';

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (isLoading.value) return;

    final trimmedName = nameController.text.trim();
    final currentUser = _authService.getCurrentUser();
    final uid = currentUser?.uid ?? passedUid;
    final phoneNumber = currentUser?.phoneNumber ?? passedPhone ?? '';

    if (uid == null || uid.isEmpty) {
      errorMessage.value = 'User session expired. Please sign in again.';
      Get.snackbar(
        'Authentication Error',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    isLoading.value = true;

    try {
      // 1. Save user profile in Firestore
      await _userService.createUserProfile(
        uid: uid,
        name: trimmedName,
        phoneNumber: phoneNumber,
      );

      // 2. Update Firebase Auth display name
      await _authService.updateDisplayName(trimmedName);

      // 3. Navigate directly to Home
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = e.toString();
      Get.snackbar(
        'Error Saving Profile',
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
}
