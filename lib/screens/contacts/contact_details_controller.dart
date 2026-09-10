import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_number_util.dart';
import '../../models/user_model.dart';
import '../../services/block_service.dart';
import '../../services/contact_service.dart';
import '../../services/favorite_service.dart';
import '../../services/zego_call_service.dart';
import 'contacts_controller.dart';

/// Strongly-typed arguments passed to ContactDetailsScreen
class ContactDetailsArgs {
  final UserModel? user;
  final DeviceContact? deviceContact;
  final String? displayName;
  final String? phoneNumber;

  const ContactDetailsArgs({
    this.user,
    this.deviceContact,
    this.displayName,
    this.phoneNumber,
  });
}

class ContactDetailsController extends GetxController {
  final ContactDetailsArgs? initialArgs;
  final ContactService _contactService;
  final FavoriteService _favoriteService;
  final BlockService _blockService;
  final ZegoCallService? _injectedZegoCallService;

  ContactDetailsController({
    this.initialArgs,
    ContactService? contactService,
    FavoriteService? favoriteService,
    BlockService? blockService,
    ZegoCallService? zegoCallService,
  })  : _contactService = contactService ?? ContactService.instance,
        _favoriteService = favoriteService ?? FavoriteService.instance,
        _blockService = blockService ?? BlockService.instance,
        _injectedZegoCallService = zegoCallService;

  ZegoCallService get activeCallService =>
      _injectedZegoCallService ?? ZegoCallService.instance;

  // Observables
  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final Rx<DeviceContact?> deviceContact = Rx<DeviceContact?>(null);
  final RxString displayName = ''.obs;
  final RxString phoneNumber = ''.obs;
  final RxBool isLoading = false.obs;

  bool get isRegistered => user.value != null;
  bool get isFavorite =>
      user.value != null && _favoriteService.isFavoriteSync(user.value!.uid);
  bool get isBlocked =>
      user.value != null && _blockService.isBlockedSync(user.value!.uid);
  bool get isSavedContact {
    if (deviceContact.value != null &&
        deviceContact.value!.displayName.trim().isNotEmpty) {
      return true;
    }
    final phone = phoneNumber.value;
    if (phone.isEmpty) return false;
    final saved = _contactService.getSavedContactName(phone);
    return saved != null && saved.trim().isNotEmpty;
  }

  @override
  void onInit() {
    super.onInit();
    _parseArguments();
    _initDeviceContactAndName();
  }

  void _parseArguments() {
    final args = initialArgs ?? Get.arguments;
    if (args is ContactDetailsArgs) {
      user.value = args.user;
      deviceContact.value = args.deviceContact;
      displayName.value = args.displayName ?? (args.user != null ? args.user!.name : 'Unknown User');
      phoneNumber.value = args.phoneNumber ?? (args.user != null ? args.user!.phoneNumber : '');
    } else if (args is Map<String, dynamic>) {
      user.value = args['user'] as UserModel?;
      deviceContact.value = args['deviceContact'] as DeviceContact?;
      displayName.value = (args['displayName'] as String?) ?? user.value?.name ?? 'Unknown User';
      phoneNumber.value = (args['phoneNumber'] as String?) ?? user.value?.phoneNumber ?? '';
    } else if (args is UserModel) {
      user.value = args;
      displayName.value = args.name;
      phoneNumber.value = args.phoneNumber;
    }
  }

  void _initDeviceContactAndName() {
    final phone = phoneNumber.value;
    final regName = user.value?.name ?? '';

    // Step 1: If device contact is not yet matched, search cached device contacts
    if (deviceContact.value == null && phone.isNotEmpty) {
      final cached = _contactService.cachedContacts;
      final norm = PhoneNumberUtil.normalize(phone);
      final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
      final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : '';

      for (final dc in cached) {
        for (final p in dc.phones) {
          final pNorm = PhoneNumberUtil.normalize(p);
          final pDigits = p.replaceAll(RegExp(r'[^\d]'), '');
          if (pNorm == norm || (last10.isNotEmpty && pDigits.endsWith(last10))) {
            deviceContact.value = dc;
            break;
          }
        }
        if (deviceContact.value != null) break;
      }
    }

    // Step 2: Name Resolution Logic:
    // Condition 1: If contact IS saved in mobile contacts -> show saved name
    if (deviceContact.value != null &&
        deviceContact.value!.displayName.trim().isNotEmpty) {
      displayName.value = deviceContact.value!.displayName.trim();
      return;
    }

    final savedName = _contactService.getSavedContactName(phone);
    if (savedName != null && savedName.trim().isNotEmpty) {
      displayName.value = savedName.trim();
      return;
    }

    // Condition 2: If contact IS NOT saved in mobile contacts -> show registered login name
    if (regName.trim().isNotEmpty) {
      displayName.value = regName.trim();
      return;
    }

    // Fallback: Use passed displayName if valid and not a placeholder
    if (displayName.value.trim().isNotEmpty &&
        displayName.value != 'Unknown User' &&
        displayName.value != 'Unknown Contact') {
      return;
    }

    // Ultimate fallback: Formatted phone number
    displayName.value = phone.isNotEmpty
        ? PhoneNumberUtil.formatForDisplay(phone)
        : 'Unknown Contact';
  }

  void _showSnackbar(
    String title,
    String message, {
    Color? backgroundColor,
    Color? colorText,
    Duration duration = const Duration(seconds: 3),
    Widget? icon,
    EdgeInsets? margin,
    double? borderRadius,
  }) {
    if (Get.context != null) {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: backgroundColor,
        colorText: colorText,
        duration: duration,
        icon: icon,
        margin: margin ?? const EdgeInsets.all(16),
        borderRadius: borderRadius ?? 12,
      );
    }
  }

  // --- Calling Actions (ZEGOCLOUD) ---

  Future<void> makeAudioCall() async {
    final target = user.value;
    if (target == null) {
      _showSnackbar(
        'Calling Unavailable',
        'ConnectCall calling is only available for registered app users.',
      );
      return;
    }

    if (isBlocked) {
      _showSnackbar(
        'Blocked User',
        'You have blocked this contact. Unblock them to make calls.',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return;
    }

    await activeCallService.sendAudioCallInvitation(targetUser: target);
  }

  Future<void> makeVideoCall() async {
    final target = user.value;
    if (target == null) {
      _showSnackbar(
        'Calling Unavailable',
        'ConnectCall calling is only available for registered app users.',
      );
      return;
    }

    if (isBlocked) {
      _showSnackbar(
        'Blocked User',
        'You have blocked this contact. Unblock them to make calls.',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return;
    }

    await activeCallService.sendVideoCallInvitation(targetUser: target);
  }

  // --- Message / SMS Action ---

  Future<void> openSms() async {
    final phone = phoneNumber.value.trim();
    if (phone.isEmpty) {
      _showSnackbar('Error', 'No phone number available to send SMS.');
      return;
    }

    final Uri smsUri = Uri(scheme: 'sms', path: phone);
    try {
      final launched = await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showSnackbar(
          'SMS Unavailable',
          'Could not open default SMS application.',
        );
      }
    } catch (e) {
      _showSnackbar(
        'SMS Unavailable',
        'No suitable messaging application found on this device.',
      );
    }
  }

  // --- WhatsApp Action ---

  Future<void> openWhatsApp() async {
    final phone = phoneNumber.value;
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      _showSnackbar('Error', 'Invalid phone number for WhatsApp.');
      return;
    }

    final Uri whatsappUri = Uri.parse('https://wa.me/$digits');
    try {
      final launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showSnackbar(
          'WhatsApp Not Found',
          'WhatsApp does not appear to be installed on this device.',
        );
      }
    } catch (e) {
      _showSnackbar(
        'WhatsApp Not Found',
        'WhatsApp is not installed or could not be opened.',
      );
    }
  }

  // --- Copy Phone Number ---

  Future<void> copyPhoneNumber() async {
    final phone = phoneNumber.value.trim();
    if (phone.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: phone));
    _showSnackbar(
      'Copied to Clipboard',
      phone,
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF1E293B),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
    );
  }

  // --- Share Contact ---

  Future<void> shareContact() async {
    final name = displayName.value.trim();
    final phone = phoneNumber.value.trim();
    if (name.isEmpty && phone.isEmpty) return;

    final shareText = '$name\n$phone';
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'Contact: $name',
        ),
      );
    } catch (e) {
      _showSnackbar(
        'Share Failed',
        'Could not open system share sheet: $e',
      );
    }
  }

  // --- Favorite / Unfavorite ---

  Future<void> toggleFavorite() async {
    final target = user.value;
    if (target == null) return;

    await _favoriteService.toggleFavoriteUser(target);
    update();
  }

  // --- Block / Unblock ---

  Future<void> confirmToggleBlock(BuildContext context) async {
    final target = user.value;
    if (target == null) return;

    if (isBlocked) {
      // Unblock directly
      await _blockService.unblockUser(blockedUserUid: target.uid);
      update();
      _showSnackbar(
        'User Unblocked',
        '${displayName.value} has been unblocked.',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
      );
    } else {
      // Show confirmation dialog before blocking
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Block ${displayName.value}?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to block this user? You will not be able to call them, and they will be removed from your active contacts.',
            style: TextStyle(color: AppTheme.textSecondaryOf(context), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondaryOf(context)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Block'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _blockService.blockUser(blockedUserUid: target.uid);
        update();
        _showSnackbar(
          'User Blocked',
          '${displayName.value} has been blocked.',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
        );
      }
    }
  }

  // --- Edit Actual Device Contact ---

  Future<void> showEditContactDialog(BuildContext context) async {
    final currentContact = deviceContact.value;
    if (currentContact == null || currentContact.id == null) {
      _showSnackbar(
        'Phone Contact Not Found',
        'This contact is not saved in your phone contacts.',
      );
      return;
    }

    final nameController = TextEditingController(text: currentContact.displayName);
    final phoneController = TextEditingController(
      text: currentContact.phoneNumbers.isNotEmpty ? currentContact.phoneNumbers.first : phoneNumber.value,
    );

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Phone Contact', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Contact Name',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryOf(context))),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                _showSnackbar('Error', 'Name and phone number cannot be empty.');
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == true) {
      final newName = nameController.text.trim();
      final newPhone = phoneController.text.trim();

      isLoading.value = true;
      try {
        final success = await _contactService.updateContact(
          id: currentContact.id!,
          name: newName,
          phoneNumber: newPhone,
        );

        if (success) {
          displayName.value = newName;
          phoneNumber.value = newPhone;
          deviceContact.value = DeviceContact(
            id: currentContact.id,
            displayName: newName,
            phoneNumbers: [newPhone],
          );

          // Refresh Contacts list
          if (Get.isRegistered<ContactsController>()) {
            Get.find<ContactsController>().loadContacts();
          }

          _showSnackbar(
            'Contact Updated',
            'Phone contact updated successfully.',
            backgroundColor: Colors.green.shade600,
            colorText: Colors.white,
          );
        } else {
          _showSnackbar('Update Failed', 'Could not update contact on device.');
        }
      } catch (e) {
        _showSnackbar('Error', 'Failed to update contact: $e');
      } finally {
        isLoading.value = false;
      }
    }
  }

  // --- Add to Phone Contacts (for Unsaved Contacts) ---

  Future<void> showAddContactDialog(BuildContext context) async {
    final nameController = TextEditingController(text: displayName.value);
    final phoneController = TextEditingController(text: phoneNumber.value);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Save to Phone Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Contact Name',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryOf(context))),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                _showSnackbar('Error', 'Name and phone number cannot be empty.');
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final newName = nameController.text.trim();
      final newPhone = phoneController.text.trim();

      isLoading.value = true;
      try {
        final contactId = await _contactService.createContact(
          name: newName,
          phoneNumber: newPhone,
        );

        if (contactId.isNotEmpty) {
          displayName.value = newName;
          phoneNumber.value = newPhone;
          deviceContact.value = DeviceContact(
            id: contactId,
            displayName: newName,
            phoneNumbers: [newPhone],
          );

          if (Get.isRegistered<ContactsController>()) {
            Get.find<ContactsController>().loadContacts();
          }

          _showSnackbar(
            'Contact Saved',
            '$newName saved to your phone contacts.',
            backgroundColor: Colors.green.shade600,
            colorText: Colors.white,
          );
        } else {
          _showSnackbar('Save Failed', 'Could not save contact to phonebook.');
        }
      } catch (e) {
        _showSnackbar('Error', 'Failed to save contact: $e');
      } finally {
        isLoading.value = false;
      }
    }
  }

  // --- Delete Device Contact ---

  Future<void> confirmDeleteContact(BuildContext context) async {
    final currentContact = deviceContact.value;
    if (currentContact == null || currentContact.id == null) {
      _showSnackbar(
        'Phone Contact Not Found',
        'This contact is not saved in your phone contacts.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Contact?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${displayName.value}" from your phone contacts? This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondaryOf(context), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryOf(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      isLoading.value = true;
      try {
        final success = await _contactService.deleteContact(currentContact.id!);
        if (success) {
          // Refresh Contacts Screen list
          if (Get.isRegistered<ContactsController>()) {
            Get.find<ContactsController>().loadContacts();
          }

          // Return to Contacts Screen safely
          Get.back();

          _showSnackbar(
            'Contact Deleted',
            'Contact removed from your phone contacts.',
            backgroundColor: Colors.grey.shade800,
            colorText: Colors.white,
          );
        } else {
          _showSnackbar('Delete Failed', 'Could not delete contact from device.');
        }
      } catch (e) {
        _showSnackbar('Error', 'Failed to delete contact: $e');
      } finally {
        isLoading.value = false;
      }
    }
  }
}
