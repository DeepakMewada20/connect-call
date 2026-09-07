import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

class EditProfileController extends GetxController {
  final UserService _userService;
  final AuthService _authService;
  final ImagePicker _imagePicker;
  final UserModel? initialUser;

  EditProfileController({
    UserService? userService,
    AuthService? authService,
    ImagePicker? imagePicker,
    this.initialUser,
  })  : _userService = userService ?? UserService(),
        _authService = authService ?? AuthService(),
        _imagePicker = imagePicker ?? ImagePicker();

  // User model being edited
  late final UserModel currentUser;

  // Form controls & state
  final TextEditingController nameController = TextEditingController();
  final Rxn<File> selectedImage = Rxn<File>();
  final RxBool isSaving = false.obs;
  final RxString nameError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final args = initialUser ?? Get.arguments;
    if (args is UserModel) {
      currentUser = args;
    } else {
      // Fallback if accessed directly without arguments
      final authUser = _authService.getCurrentUser();
      currentUser = UserModel(
        uid: _authService.currentUserId ?? '',
        name: authUser?.displayName ?? 'User',
        email: authUser?.email ?? '',
        profileImage: authUser?.photoURL ?? '',
        createdAt: DateTime.now(),
      );
    }
    nameController.text = currentUser.name;
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }

  // Pick an image from gallery
  Future<void> pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        selectedImage.value = File(pickedFile.path);
      }
    } catch (e) {
      Get.snackbar(
        'Image Selection',
        'Unable to select image. Please check permissions.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  // Validate name field
  bool validateName() {
    final trimmedName = nameController.text.trim();
    if (trimmedName.isEmpty) {
      nameError.value = 'Name cannot be empty';
      return false;
    }
    if (trimmedName.length < 2) {
      nameError.value = 'Name must be at least 2 characters';
      return false;
    }
    nameError.value = '';
    return true;
  }

  // Save changes to Firestore and update Firebase Auth display name
  Future<void> saveProfile() async {
    // Prevent multiple triggers while saving
    if (isSaving.value) return;

    if (!validateName()) return;

    isSaving.value = true;

    try {
      final updatedName = nameController.text.trim();

      // Update Firestore user document
      await _userService.updateUserProfile(
        uid: currentUser.uid,
        name: updatedName,
      );

      // Keep Firebase Auth displayName in sync
      await _authService.updateDisplayName(updatedName);

      // Return to Profile screen with refresh signal
      Get.back(result: true);

      // Show success feedback on returning screen
      Get.snackbar(
        'Success',
        'Profile updated successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Update Failed',
        'Unable to update profile. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isSaving.value = false;
    }
  }
}
