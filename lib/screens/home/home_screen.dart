import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      Get.snackbar(
        'Logout Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();
    final String displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@').first ?? 'User');
    final String email = user?.email ?? 'No email';
    final String uid = user?.uid ?? 'Unknown';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _isLoggingOut ? null : _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    size: 44,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Welcome, $displayName!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'UID: $uid',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You are successfully authenticated.\nFull Home UI will be implemented in Phase 3.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),
                ElevatedButton.icon(
                  onPressed: _isLoggingOut ? null : _handleLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  icon: _isLoggingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(_isLoggingOut ? 'Logging out...' : 'Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
