import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/contact_service.dart';
import '../../widgets/user_tile.dart';
import 'contacts_controller.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure controller is registered
    final ContactsController controller = Get.isRegistered<ContactsController>()
        ? Get.find<ContactsController>()
        : Get.put(ContactsController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColorOf(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeader(context, controller),

            // Search Bar
            _buildSearchBar(controller, context),

            const SizedBox(height: 8),

            // Main Content Area
            Expanded(
              child: Obx(() {
                // 1. Permission Permanently Denied
                if (controller.permissionState.value ==
                    ContactsPermissionState.permanentlyDenied) {
                  return _buildPermanentlyDeniedState(controller);
                }

                // 2. Permission Denied
                if (controller.permissionState.value == ContactsPermissionState.denied) {
                  return _buildPermissionDeniedState(controller);
                }

                // 3. Loading State
                if (controller.isLoading.value) {
                  return _buildLoadingState();
                }

                // 4. Error State (Network or Generic)
                if (controller.errorMessage.isNotEmpty) {
                  return _buildErrorState(controller);
                }

                // 5. Smart Search States
                // 5a. Remote Search In Progress
                if (controller.isSearchingRemote.value) {
                  return _buildRemoteSearchingState();
                }

                // 5b. Remote Search Error
                if (controller.remoteSearchError.isNotEmpty) {
                  return _buildRemoteSearchErrorState(controller);
                }

                // 5c. Remote Searched User Found
                if (controller.remoteSearchedUser.value != null) {
                  return _buildRemoteUserResult(
                    context,
                    controller,
                    controller.remoteSearchedUser.value!,
                  );
                }

                // 5d. Remote Search Not Found
                if (controller.remoteSearchNotFound.value) {
                  return _buildRemoteNotFoundState(controller);
                }

                // 6. Local Filtered Contacts / Standard Empty State
                final usersList = controller.filteredUsers;
                if (usersList.isEmpty) {
                  return _buildEmptyState(controller);
                }

                return _buildUsersList(controller, usersList);
              }),
            ),
          ],
        ),
      ),
    );
  }

  // Header displaying title, subtitle and Add Contact action
  Widget _buildHeader(BuildContext context, ContactsController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contacts',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Connect with people',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
          IconButton.filledTonal(
            onPressed: () => _showAddContactDialog(context, controller),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Add Contact',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // Search input with real-time reactive filtering and clear action
  Widget _buildSearchBar(ContactsController controller, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColorOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerColorOf(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppTheme.isDarkMode(context) ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: controller.searchController,
          onChanged: controller.onSearchChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(
            color: AppTheme.textPrimaryOf(context),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Search contacts or phone number',
            hintStyle: TextStyle(
              color: AppTheme.textSecondaryOf(context),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppTheme.textSecondaryOf(context),
              size: 22,
            ),
            suffixIcon: Obx(() {
              if (controller.searchQuery.value.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppTheme.textSecondaryOf(context),
                ),
                onPressed: controller.clearSearch,
              );
            }),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  // Permission Denied State
  Widget _buildPermissionDeniedState(ContactsController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.contacts_outlined,
                size: 38,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Permission Required',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Contacts permission is required to find your friends on ConnectCall.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: controller.requestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Grant Permission',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Permission Permanently Denied State
  Widget _buildPermanentlyDeniedState(ContactsController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.settings_suggest_rounded,
                size: 38,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Permission Needed',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Contacts permission is permanently denied. Please enable it from Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: controller.openSettings,
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text(
                'Open Settings',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Loading state indicator
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Finding contacts...',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Error state with retry button
  Widget _buildErrorState(ContactsController controller) {
    final bool isNet = controller.isNetworkError.value;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNet ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 34,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isNet ? 'Network Error' : 'Unable to load contacts',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.errorMessage.value.isNotEmpty
                  ? controller.errorMessage.value
                  : 'Something went wrong while fetching contacts.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: controller.refreshContacts,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Empty state differentiated between search and total users
  Widget _buildEmptyState(ContactsController controller) {
    final bool isSearching = controller.searchQuery.value.trim().isNotEmpty;

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      onRefresh: controller.refreshContacts,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(32.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSearching
                          ? Icons.search_off_rounded
                          : Icons.people_outline_rounded,
                      size: 36,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isSearching ? 'No contacts found' : 'No registered contacts found.',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSearching
                        ? 'Try a different name or phone number.'
                        : 'None of your phone contacts are registered on ConnectCall yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isSearching)
                    TextButton.icon(
                      onPressed: controller.clearSearch,
                      icon: const Icon(Icons.clear_all_rounded, size: 18),
                      label: const Text('Clear search'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: controller.refreshContacts,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh Contacts'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Users list with Pull-to-Refresh
  Widget _buildUsersList(ContactsController controller, List usersList) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      onRefresh: controller.refreshContacts,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        itemCount: usersList.length,
        itemBuilder: (context, index) {
          final user = usersList[index];
          final isFav = controller.isFavorite(user.uid);
          final isBlk = controller.isBlocked(user.uid);
          final deviceContact = controller.findDeviceContactForUser(user);
          final displayName = controller.getDisplayNameForUser(user);

          return UserTile(
            user: user,
            displayName: displayName,
            isFavorite: isFav,
            isBlocked: isBlk,
            onTap: () => controller.navigateToContactDetails(user, deviceContact),
            onAvatarTap: () => controller.navigateToContactDetails(user, deviceContact),
            onAudioCall: () => controller.onAudioCallTap(user),
            onVideoCall: () => controller.onVideoCallTap(user),
            onToggleFavorite: () => controller.toggleFavorite(user),
            onToggleBlock: () => _handleBlockToggle(context, controller, user, isBlk),
            onEditContact: deviceContact != null
                ? () => _showEditContactDialog(context, controller, deviceContact)
                : null,
            onDeleteContact: deviceContact != null
                ? () => _showDeleteContactDialog(context, controller, deviceContact)
                : null,
          );
        },
      ),
    );
  }

  // Smart Search: In-flight remote lookup loading indicator
  Widget _buildRemoteSearchingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Checking registered users...',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Looking up phone number on ConnectCall',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Smart Search: Remote lookup network or service error
  Widget _buildRemoteSearchErrorState(ContactsController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 34,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Search Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.remoteSearchError.value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: controller.retryRemoteSearch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Smart Search: Number not registered empty state
  Widget _buildRemoteNotFoundState(ContactsController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_off_rounded,
                size: 36,
                color: Colors.orange.shade600,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No registered user found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This number is not registered in the app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: controller.clearSearch,
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Clear search'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Smart Search: Registered user result display
  Widget _buildRemoteUserResult(BuildContext context, ContactsController controller, UserModel user) {
    final isFav = controller.isFavorite(user.uid);
    final isBlk = controller.isBlocked(user.uid);
    final deviceContact = controller.findDeviceContactForUser(user);
    final displayName = controller.getDisplayNameForUser(user);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Registered User',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        UserTile(
          user: user,
          displayName: displayName,
          isSelf: controller.isSelfNumberSearched.value,
          badgeText: controller.isSelfNumberSearched.value ? null : 'Registered User',
          isFavorite: isFav,
          isBlocked: isBlk,
          onTap: () => controller.navigateToContactDetails(user, deviceContact),
          onAvatarTap: () => controller.navigateToContactDetails(user, deviceContact),
          onAudioCall: () => controller.onAudioCallTap(user),
          onVideoCall: () => controller.onVideoCallTap(user),
          onToggleFavorite: () => controller.toggleFavorite(user),
          onToggleBlock: () => _handleBlockToggle(context, controller, user, isBlk),
          onEditContact: deviceContact != null
              ? () => _showEditContactDialog(context, controller, deviceContact)
              : null,
          onDeleteContact: deviceContact != null
              ? () => _showDeleteContactDialog(context, controller, deviceContact)
              : null,
        ),
      ],
    );
  }

  // --- Dialogs for Contact & Block Management ---

  void _showAddContactDialog(BuildContext context, ContactsController controller) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter contact name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. +91 9876543210',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter both name and phone number')),
                );
                return;
              }
              Navigator.of(dialogCtx).pop();
              final success = await controller.addContact(name: name, phoneNumber: phone);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Contact saved to phone contacts.' : 'Failed to save contact.',
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditContactDialog(
    BuildContext context,
    ContactsController controller,
    DeviceContact contact,
  ) {
    final nameController = TextEditingController(text: contact.name);
    final initialPhone = contact.phones.isNotEmpty ? contact.phones.first : '';
    final phoneController = TextEditingController(text: initialPhone);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Phone Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Edits will be saved to your device contacts and will not alter the user\'s registered profile.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter both name and phone number')),
                );
                return;
              }
              if (contact.id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot edit contact without an ID.')),
                );
                return;
              }
              Navigator.of(dialogCtx).pop();
              final success = await controller.updateContact(
                contactId: contact.id!,
                newName: name,
                newPhoneNumber: phone,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Device contact updated.' : 'Failed to update contact.',
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteContactDialog(
    BuildContext context,
    ContactsController controller,
    DeviceContact contact,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'Are you sure you want to delete ${contact.name} from your device contacts?',
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (contact.id == null) return;
              Navigator.of(dialogCtx).pop();
              final success = await controller.deleteContact(contact.id!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Contact deleted from device.' : 'Failed to delete contact.',
                    ),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleBlockToggle(
    BuildContext context,
    ContactsController controller,
    UserModel user,
    bool isBlocked,
  ) {
    if (isBlocked) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Unblock User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Text(
            'Are you sure you want to unblock ${user.name}?',
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await controller.unblockUser(user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${user.name} has been unblocked.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Unblock'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Block User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Text(
            'Are you sure you want to block ${user.name}? They will not be able to call you and you will not be able to call them.',
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await controller.blockUser(user);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${user.name} has been blocked.')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Block'),
            ),
          ],
        ),
      );
    }
  }
}
