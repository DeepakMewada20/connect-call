import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import 'register_controller.dart';

class RegisterScreen extends GetView<RegisterController> {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: controller.goToLogin,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Center(
                    child: Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Join ConnectCall to start calling anyone.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Full Name
                  const Text(
                    'Full Name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: controller.nameController,
                    textCapitalization: TextCapitalization.words,
                    validator: controller.validateName,
                    decoration: InputDecoration(
                      hintText: 'John Doe',
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Email
                  const Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: controller.emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    validator: controller.validateEmail,
                    decoration: InputDecoration(
                      hintText: 'name@example.com',
                      prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Password
                  const Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Obx(
                    () => TextFormField(
                      controller: controller.passwordController,
                      obscureText: !controller.isPasswordVisible.value,
                      validator: controller.validatePassword,
                      decoration: InputDecoration(
                        hintText: 'At least 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            controller.isPasswordVisible.value
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: controller.togglePasswordVisibility,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Confirm Password
                  const Text(
                    'Confirm Password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Obx(
                    () => TextFormField(
                      controller: controller.confirmPasswordController,
                      obscureText: !controller.isConfirmPasswordVisible.value,
                      validator: controller.validateConfirmPassword,
                      decoration: InputDecoration(
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            controller.isConfirmPasswordVisible.value
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: controller.toggleConfirmPasswordVisibility,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Create Account Button
                  Obx(
                    () => ElevatedButton(
                      onPressed: controller.isLoading.value ? null : controller.register,
                      child: controller.isLoading.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Navigation back to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account?',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: controller.goToLogin,
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
