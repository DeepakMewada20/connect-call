import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../core/utils/phone_number_util.dart';

/// Lightweight representation of a device contact.
class DeviceContact {
  final String displayName;
  final List<String> phoneNumbers;

  const DeviceContact({
    required this.displayName,
    this.phoneNumbers = const [],
  });
}

/// Service responsible for accessing device contacts and managing contacts permissions.
class ContactService {
  final Future<ph.PermissionStatus> Function()? checkPermissionDelegate;
  final Future<ph.PermissionStatus> Function()? requestPermissionDelegate;
  final Future<List<DeviceContact>> Function()? fetchContactsDelegate;

  ContactService({
    this.checkPermissionDelegate,
    this.requestPermissionDelegate,
    this.fetchContactsDelegate,
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

  /// Fetches raw device contacts with phone numbers.
  Future<List<DeviceContact>> getContacts() async {
    final delegate = fetchContactsDelegate;
    if (delegate != null) {
      return await delegate();
    }

    // Use flutter_contacts to get contacts with phone properties
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.phone},
    );

    return contacts.map((c) {
      final name = (c.displayName != null && c.displayName!.isNotEmpty)
          ? c.displayName!
          : '${c.name?.first ?? ''} ${c.name?.last ?? ''}'.trim();
      final phones = c.phones.map((p) => p.number).where((p) => p.isNotEmpty).toList();
      return DeviceContact(
        displayName: name.isNotEmpty ? name : 'Unknown',
        phoneNumbers: phones,
      );
    }).toList();
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
