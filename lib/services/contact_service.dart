import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../core/utils/phone_number_util.dart';
import '../core/utils/string_utils.dart';

/// Lightweight representation of a device contact.
class DeviceContact {
  final String? id;
  final String displayName;
  final List<String> phoneNumbers;

  const DeviceContact({
    this.id,
    required this.displayName,
    this.phoneNumbers = const [],
  });

  String get name => displayName;
  List<String> get phones => phoneNumbers;
}

/// Service responsible for accessing device contacts and managing contacts permissions.
class ContactService {
  final Future<ph.PermissionStatus> Function()? checkPermissionDelegate;
  final Future<ph.PermissionStatus> Function()? requestPermissionDelegate;
  final Future<List<DeviceContact>> Function()? fetchContactsDelegate;
  final Future<String> Function(String name, String phoneNumber)? createContactDelegate;
  final Future<bool> Function(String id, String name, String phoneNumber)? updateContactDelegate;
  final Future<bool> Function(String id)? deleteContactDelegate;

  ContactService({
    this.checkPermissionDelegate,
    this.requestPermissionDelegate,
    this.fetchContactsDelegate,
    this.createContactDelegate,
    this.updateContactDelegate,
    this.deleteContactDelegate,
  });

  /// Checks current contacts permission status.
  Future<ph.PermissionStatus> checkPermission() async {
    final delegate = checkPermissionDelegate;
    if (delegate != null) {
      return await delegate();
    }
    return await ph.Permission.contacts.status;
  }

  /// Requests contacts permission from the user.
  Future<ph.PermissionStatus> requestPermission() async {
    final delegate = requestPermissionDelegate;
    if (delegate != null) {
      return await delegate();
    }
    return await ph.Permission.contacts.request();
  }

  /// Opens the device app settings screen when permission is permanently denied.
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  static ContactService? _instance;
  static ContactService get instance => _instance ??= ContactService();

  final Map<String, String> _phoneToNameCache = {};
  List<DeviceContact> _cachedContacts = [];

  List<DeviceContact> get cachedContacts => List.unmodifiable(_cachedContacts);
  Map<String, String> get phoneToNameCache => Map.unmodifiable(_phoneToNameCache);

  /// Updates internal cache with the provided contacts.
  void updateCacheFromContacts(List<DeviceContact> contacts) {
    _cachedContacts = List.from(contacts);
    _phoneToNameCache.clear();
    for (final contact in contacts) {
      for (final rawPhone in contact.phoneNumbers) {
        final normalized = PhoneNumberUtil.normalize(rawPhone);
        if (normalized != null && normalized.isNotEmpty) {
          _phoneToNameCache[normalized] = contact.displayName;
        }
      }
    }
  }

  /// Looks up a saved contact name by phone number.
  /// Returns null if not found in device contacts.
  String? getSavedContactName(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) return null;
    final normalized = PhoneNumberUtil.normalize(phoneNumber);
    if (normalized != null && _phoneToNameCache.containsKey(normalized)) {
      return _phoneToNameCache[normalized];
    }
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length >= 10) {
      final last10 = digits.substring(digits.length - 10);
      for (final entry in _phoneToNameCache.entries) {
        final entryDigits = entry.key.replaceAll(RegExp(r'[^\d]'), '');
        if (entryDigits.endsWith(last10)) {
          return entry.value;
        }
      }
    }
    return null;
  }

  /// Resolves display name according to the two requirements:
  /// 1. If saved in mobile contacts -> return saved name
  /// 2. If not saved in mobile contacts -> return registered/login name
  String resolveDisplayName({
    required String? phoneNumber,
    required String registeredName,
    String fallback = 'Unknown User',
  }) {
    final savedName = getSavedContactName(phoneNumber);
    if (savedName != null && savedName.trim().isNotEmpty) {
      return StringUtils.sanitize(savedName.trim());
    }
    if (registeredName.trim().isNotEmpty) {
      return StringUtils.sanitize(registeredName.trim());
    }
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      return PhoneNumberUtil.formatForDisplay(phoneNumber);
    }
    return StringUtils.sanitize(fallback);
  }

  /// Fetches raw device contacts with phone numbers and populates cache.
  Future<List<DeviceContact>> getContacts() async {
    final delegate = fetchContactsDelegate;
    List<DeviceContact> result;
    if (delegate != null) {
      result = await delegate();
    } else {
      // Use flutter_contacts to get contacts with phone properties
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      result = contacts.map((c) {
        final rawName = (c.displayName != null && c.displayName!.isNotEmpty)
            ? c.displayName!
            : '${c.name?.first ?? ''} ${c.name?.last ?? ''}'.trim();
        final name = StringUtils.sanitize(rawName);
        final phones = c.phones.map((p) => p.number).where((p) => p.isNotEmpty).toList();
        return DeviceContact(
          id: c.id,
          displayName: name.isNotEmpty ? name : 'Unknown',
          phoneNumbers: phones,
        );
      }).toList();
    }

    updateCacheFromContacts(result);
    return result;
  }

  /// Creates a new contact in the device's actual Contacts database.
  Future<String> createContact({
    required String name,
    required String phoneNumber,
  }) async {
    final delegate = createContactDelegate;
    if (delegate != null) {
      return await delegate(name, phoneNumber);
    }

    final trimmedName = name.trim();
    final parts = trimmedName.split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final contact = Contact(
      name: Name(first: firstName, last: lastName),
      phones: [Phone(number: phoneNumber.trim())],
    );

    return await FlutterContacts.create(contact);
  }

  /// Updates an existing contact in the device's actual Contacts database.
  Future<bool> updateContact({
    required String id,
    required String name,
    required String phoneNumber,
  }) async {
    final delegate = updateContactDelegate;
    if (delegate != null) {
      return await delegate(id, name, phoneNumber);
    }

    final existing = await FlutterContacts.get(id);
    if (existing == null) return false;

    final trimmedName = name.trim();
    final parts = trimmedName.split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final updated = Contact(
      id: existing.id,
      name: Name(first: firstName, last: lastName),
      phones: [Phone(number: phoneNumber.trim())],
    );

    await FlutterContacts.update(updated);
    return true;
  }

  /// Deletes a contact from the device's actual Contacts database.
  Future<bool> deleteContact(String id) async {
    final delegate = deleteContactDelegate;
    if (delegate != null) {
      return await delegate(id);
    }

    await FlutterContacts.delete(id);
    return true;
  }

  /// Extracts all phone numbers from device contacts, normalizes them, and returns
  /// a deduplicated list of valid standard phone numbers.
  Future<List<String>> getNormalizedPhoneNumbers() async {
    final contacts = await getContacts();
    final Set<String> uniqueNumbers = {};

    for (final contact in contacts) {
      for (final rawPhone in contact.phoneNumbers) {
        final normalized = PhoneNumberUtil.normalize(rawPhone);
        if (normalized != null && normalized.isNotEmpty) {
          uniqueNumbers.add(normalized);
        }
      }
    }

    return uniqueNumbers.toList();
  }
}
