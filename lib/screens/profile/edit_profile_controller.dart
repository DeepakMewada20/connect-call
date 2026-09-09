import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

class EditProfileController extends GetxController {
  final UserService _userService;
  final AuthService _authService;
  final ImagePicker _imagePicker;
  final ImageCropper _imageCropper;
  final UserModel? initialUser;

  EditProfileController({
    UserService? userService,
    AuthService? authService,
    ImagePicker? imagePicker,
    ImageCropper? imageCropper,
    this.initialUser,
  })  : _userService = userService ?? UserService(),
        _authService = authService ?? AuthService(),
        _imagePicker = imagePicker ?? ImagePicker(),
        _imageCropper = imageCropper ?? ImageCropper();

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
        phoneNumber: authUser?.phoneNumber ?? '',
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

  // Show BottomSheet to choose Camera or Gallery
  void showImageSourceSelector() {
    final context = Get.context;
    final isDark = context != null ? AppTheme.isDarkMode(context) : false;
    final surfaceColor =
        context != null ? AppTheme.surfaceColorOf(context) : Colors.white;
    final textPrimary =
        context != null ? AppTheme.textPrimaryOf(context) : AppTheme.textPrimary;
    final textSecondary = context != null
        ? AppTheme.textSecondaryOf(context)
        : AppTheme.textSecondary;
    final dividerColor = context != null
        ? AppTheme.dividerColorOf(context)
        : AppTheme.dividerColor;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how you would like to select your photo',
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            // Camera option
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor
                      .withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: Text(
                'Take Photo',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
              subtitle: Text(
                'Use camera to take a new picture',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              onTap: () {
                Get.back();
                pickAndCropImage(ImageSource.camera);
              },
            ),
            Divider(height: 16, color: dividerColor),
            // Gallery option
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.purple,
                ),
              ),
              title: Text(
                'Choose from Gallery',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
              subtitle: Text(
                'Select an existing image from gallery',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              onTap: () {
                Get.back();
                pickAndCropImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  // Pick an image from the given source and open the cropper
  Future<void> pickAndCropImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (pickedFile == null) return;

      // Launch cropper
      final CroppedFile? croppedFile = await _imageCropper.cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust & Crop Photo',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          IOSUiSettings(
            title: 'Adjust & Crop Photo',
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        selectedImage.value = File(croppedFile.path);
      } else {
        // User cancelled cropping - fallback to selected original image
        selectedImage.value = File(pickedFile.path);
      }
    } catch (e) {
      Get.snackbar(
        'Image Selection',
        'Unable to access camera or gallery. Please restart the app if newly installed.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    }
  }

  // Backward-compatible alias for existing tests
  Future<void> pickImage() async {
    await pickAndCropImage(ImageSource.gallery);
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
