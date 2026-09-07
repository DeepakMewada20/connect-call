import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import 'edit_profile_controller.dart';

class EditProfileScreen extends GetView<EditProfileController> {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Interactive Avatar with Camera Badge
              _buildAvatarPicker(context),

              const SizedBox(height: 12),

              const Text(
                'Tap avatar to choose a photo',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 32),

              // Full Name Input
              _buildNameField(),

              const SizedBox(height: 20),

              // Read-only Email Field
              _buildEmailField(),

              const SizedBox(height: 36),

              // Save Changes Button
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPicker(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: controller.pickImage,
        child: Stack(
          children: [
            Obx(() {
              final selectedFile = controller.selectedImage.value;
              final hasNetworkImage =
                  controller.currentUser.profileImage.trim().isNotEmpty;

              ImageProvider? imageProvider;
              if (selectedFile != null) {
                imageProvider = FileImage(selectedFile);
              } else if (hasNetworkImage) {
                imageProvider =
                    NetworkImage(controller.currentUser.profileImage);
              }

              final initial = controller.currentUser.name.isNotEmpty
                  ? controller.currentUser.name[0].toUpperCase()
                  : 'U';

              return Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.12),
                  backgroundImage: imageProvider,
                  onBackgroundImageError: imageProvider != null
                      ? (error, stackTrace) {}
                      : null,
                  child: imageProvider == null
                      ? Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : null,
                ),
              );
            }),
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Full Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => TextField(
            controller: controller.nameController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                color: AppTheme.textSecondary,
                size: 22,
              ),
              errorText: controller.nameError.value.isNotEmpty
                  ? controller.nameError.value
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Address',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller:
              TextEditingController(text: controller.currentUser.email),
          enabled: false,
          style: TextStyle(color: Colors.grey.shade600),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: AppTheme.textSecondary,
              size: 22,
            ),
            helperText: 'Email cannot be changed directly.',
            helperStyle: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Obx(() {
      final isSaving = controller.isSaving.value;

      return ElevatedButton(
        onPressed: isSaving ? null : controller.saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      );
    });
  }
}
