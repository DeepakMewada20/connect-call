import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/contacts/contacts_controller.dart';
import 'package:connect_call/services/contact_service.dart';
import 'package:connect_call/widgets/user_tile.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('ContactService Name Resolution', () {
    late ContactService contactService;

    setUp(() {
      contactService = ContactService();
      contactService.updateCacheFromContacts([
        const DeviceContact(
          id: '1',
          displayName: 'Papa Mobile',
          phoneNumbers: ['+919876543210', '09876543210'],
        ),
        const DeviceContact(
          id: '2',
          displayName: 'Bhaiya Work',
          phoneNumbers: ['+91 91234 56789'],
        ),
      ]);
    });

    test('Condition 1: Returns saved device contact name when number is saved in mobile contacts', () {
      final resolved = contactService.resolveDisplayName(
        phoneNumber: '+919876543210',
        registeredName: 'Deepak Mewada',
      );
      expect(resolved, equals('Papa Mobile'));
    });

    test('Condition 1: Matches even with formatting differences like spaces or domestic 0 prefix', () {
      final resolvedWithSpaces = contactService.resolveDisplayName(
        phoneNumber: '+919123456789',
        registeredName: 'Rahul Mewada',
      );
      expect(resolvedWithSpaces, equals('Bhaiya Work'));

      final resolvedWith10Digits = contactService.resolveDisplayName(
        phoneNumber: '9876543210',
        registeredName: 'Deepak Mewada',
      );
      expect(resolvedWith10Digits, equals('Papa Mobile'));
    });

    test('Condition 2: Returns registered profile name when number is NOT saved in mobile contacts', () {
      final resolved = contactService.resolveDisplayName(
        phoneNumber: '+919999988888',
        registeredName: 'Amit Sharma',
      );
      expect(resolved, equals('Amit Sharma'));
    });

    test('Fallback to formatted phone number if registered name is empty and number unsaved', () {
      final resolved = contactService.resolveDisplayName(
        phoneNumber: '+919999988888',
        registeredName: '',
      );
      expect(resolved, equals('+91 99999 88888'));
    });
  });

  group('ContactsController Display Name Resolution and Search', () {
    test('getDisplayNameForUser prioritizes device contact saved name over registered name', () {
      final controller = ContactsController(
        currentUserIdOverride: 'self_uid',
        currentUserPhoneOverride: '+911111122222',
      );

      controller.deviceContacts.assignAll([
        const DeviceContact(
          id: 'c1',
          displayName: 'Best Friend',
          phoneNumbers: ['+919876543210'],
        ),
      ]);

      final savedUser = UserModel(
        uid: 'user_1',
        name: 'Gaurav Kumar',
        phoneNumber: '+919876543210',
        normalizedPhoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      );

      final unsavedUser = UserModel(
        uid: 'user_2',
        name: 'Stranger Danger',
        phoneNumber: '+919999900000',
        normalizedPhoneNumber: '+919999900000',
        createdAt: DateTime.now(),
      );

      // Condition 1: Saved in mobile contacts -> Saved Name
      expect(controller.getDisplayNameForUser(savedUser), equals('Best Friend'));

      // Condition 2: Not saved in mobile contacts -> Registered Profile Name
      expect(controller.getDisplayNameForUser(unsavedUser), equals('Stranger Danger'));
    });

    test('filteredUsers search matches by saved device name in addition to registered name', () {
      final controller = ContactsController(
        currentUserIdOverride: 'self_uid',
        currentUserPhoneOverride: '+911111122222',
      );

      controller.deviceContacts.assignAll([
        const DeviceContact(
          id: 'c1',
          displayName: 'Papa',
          phoneNumbers: ['+919876543210'],
        ),
      ]);

      final user = UserModel(
        uid: 'user_1',
        name: 'Deepak Mewada',
        phoneNumber: '+919876543210',
        normalizedPhoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      );

      controller.users.assignAll([user]);

      // Searching by saved name 'Papa' finds the user
      controller.onSearchChanged('Papa');
      expect(controller.filteredUsers.length, equals(1));
      expect(controller.filteredUsers.first.uid, equals('user_1'));

      // Searching by registered profile name 'Deepak' also finds the user
      controller.onSearchChanged('Deepak');
      expect(controller.filteredUsers.length, equals(1));
      expect(controller.filteredUsers.first.uid, equals('user_1'));
    });
  });

  group('UserTile Widget Display Name Test', () {
    testWidgets('renders displayName as primary title when provided', (tester) async {
      final user = UserModel(
        uid: 'user_1',
        name: 'Deepak Mewada',
        phoneNumber: '+919876543210',
        normalizedPhoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserTile(
              user: user,
              displayName: 'Papa',
            ),
          ),
        ),
      );

      // Primary title is the saved contact name 'Papa'
      expect(find.text('Papa'), findsOneWidget);
      // Secondary subtitle shows phone and registered profile name '(~Deepak Mewada)'
      expect(find.textContaining('~Deepak Mewada'), findsOneWidget);
      // Avatar initial is 'P'
      expect(find.text('P'), findsOneWidget);
    });

    testWidgets('renders user.name when displayName is not provided (unsaved user)', (tester) async {
      final user = UserModel(
        uid: 'user_2',
        name: 'Anjali Sharma',
        phoneNumber: '+919888877777',
        normalizedPhoneNumber: '+919888877777',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserTile(
              user: user,
            ),
          ),
        ),
      );

      // Primary title is user.name
      expect(find.text('Anjali Sharma'), findsOneWidget);
      // Avatar initial is 'A'
      expect(find.text('A'), findsOneWidget);
    });
  });
}
