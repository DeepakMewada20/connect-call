import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/contacts/contact_details_controller.dart';
import 'package:connect_call/screens/contacts/contact_details_screen.dart';
import 'package:connect_call/services/auth_service.dart';
import 'package:connect_call/services/block_service.dart';
import 'package:connect_call/services/contact_service.dart';
import 'package:connect_call/services/favorite_service.dart';
import 'package:connect_call/services/zego_call_service.dart';

class MockAuthService extends AuthService {
  @override
  String? get currentUserId => 'current_user_123';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService authService;
  late BlockService blockService;
  late FavoriteService favoriteService;
  late ContactService contactService;
  late ZegoCallService zegoCallService;

  final Set<String> inMemoryBlocked = {};
  final Set<String> inMemoryFavorites = {};
  final List<DeviceContact> inMemoryContacts = [];

  setUp(() {
    Get.testMode = true;
    inMemoryBlocked.clear();
    inMemoryFavorites.clear();
    inMemoryContacts.clear();

    authService = MockAuthService();

    blockService = BlockService(
      authService: authService,
      blockUserDelegate: (blockedUid, currentUid) async {
        inMemoryBlocked.add(blockedUid);
        return true;
      },
      unblockUserDelegate: (blockedUid, currentUid) async {
        inMemoryBlocked.remove(blockedUid);
        return true;
      },
      isBlockedDelegate: (targetUid, currentUid) async {
        return inMemoryBlocked.contains(targetUid);
      },
      getBlockedListDelegate: (currentUid) async {
        return inMemoryBlocked.toList();
      },
    );
    BlockService.setInstance(blockService);

    favoriteService = FavoriteService(
      authService: authService,
    );
    favoriteService.favoriteUserIds.assignAll(inMemoryFavorites);
    FavoriteService.setInstance(favoriteService);

    contactService = ContactService(
      fetchContactsDelegate: () async => inMemoryContacts,
      updateContactDelegate: (id, name, phone) async => true,
      deleteContactDelegate: (id) async => true,
    );
    contactService.updateCacheFromContacts([
      const DeviceContact(
        id: 'dc_1',
        displayName: 'Rahul Sharma (Mobile)',
        phoneNumbers: ['+919876543210'],
      ),
    ]);

    zegoCallService = ZegoCallService(
      authService: authService,
      blockService: blockService,
    );
  });

  group('ContactDetailsController Tests', () {
    test('Initializes with ContactDetailsArgs and resolves saved device contact name', () {
      final user = UserModel(
        uid: 'user_rahul_1',
        name: 'Rahul AppName',
        phoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      );

      final args = ContactDetailsArgs(
        user: user,
        deviceContact: const DeviceContact(
          id: 'dc_1',
          displayName: 'Rahul Sharma (Mobile)',
          phoneNumbers: ['+919876543210'],
        ),
        displayName: 'Rahul Sharma (Mobile)',
        phoneNumber: '+919876543210',
      );

      final controller = ContactDetailsController(
        initialArgs: args,
        contactService: contactService,
        favoriteService: favoriteService,
        blockService: blockService,
        zegoCallService: zegoCallService,
      );
      controller.onInit();

      expect(controller.isRegistered, isTrue);
      expect(controller.displayName.value, 'Rahul Sharma (Mobile)');
      expect(controller.phoneNumber.value, '+919876543210');
      expect(controller.deviceContact.value?.id, 'dc_1');
    });

    test('Audio Call triggers ZegoCallService when user is not blocked', () async {
      final user = UserModel(
        uid: 'user_rahul_2',
        name: 'Rahul AppName',
        phoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      );

      final controller = ContactDetailsController(
        initialArgs: ContactDetailsArgs(
          user: user,
          displayName: 'Rahul',
          phoneNumber: '+919876543210',
        ),
        contactService: contactService,
        favoriteService: favoriteService,
        blockService: blockService,
        zegoCallService: zegoCallService,
      );
      controller.onInit();

      await controller.makeAudioCall();
      expect(controller.isBlocked, isFalse);
    });

    test('Calling is blocked when user is blocked', () async {
      final user = UserModel(
        uid: 'user_blocked_3',
        name: 'Blocked Person',
        phoneNumber: '+919999999999',
        createdAt: DateTime.now(),
      );

      inMemoryBlocked.add('user_blocked_3');
      blockService.blockedUserIds.add('user_blocked_3');

      final controller = ContactDetailsController(
        initialArgs: ContactDetailsArgs(
          user: user,
          displayName: 'Blocked Person',
          phoneNumber: '+919999999999',
        ),
        contactService: contactService,
        favoriteService: favoriteService,
        blockService: blockService,
        zegoCallService: zegoCallService,
      );
      controller.onInit();

      expect(controller.isBlocked, isTrue);
    });

    test('Copy phone number sets clipboard data', () async {
      String? clipboardContent;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardContent = (methodCall.arguments as Map)['text'] as String?;
          return null;
        } else if (methodCall.method == 'Clipboard.getData') {
          return {'text': clipboardContent};
        }
        return null;
      });

      final user = UserModel(
        uid: 'user_copy_4',
        name: 'Copy Contact',
        phoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      );

      final controller = ContactDetailsController(
        initialArgs: ContactDetailsArgs(
          user: user,
          displayName: 'Copy Contact',
          phoneNumber: '+919876543210',
        ),
        contactService: contactService,
        favoriteService: favoriteService,
        blockService: blockService,
        zegoCallService: zegoCallService,
      );
      controller.onInit();

      await controller.copyPhoneNumber();
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipData?.text, '+919876543210');
    });

    test('Favorite toggles reactive state', () async {
      final user = UserModel(
        uid: 'user_fav_5',
        name: 'Favorite Contact',
        phoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      );

      final controller = ContactDetailsController(
        initialArgs: ContactDetailsArgs(
          user: user,
          displayName: 'Favorite Contact',
          phoneNumber: '+919876543210',
        ),
        contactService: contactService,
        favoriteService: favoriteService,
        blockService: blockService,
        zegoCallService: zegoCallService,
      );
      controller.onInit();

      expect(controller.isFavorite, isFalse);
      favoriteService.favoriteUserIds.add('user_fav_5');
      expect(controller.isFavorite, isTrue);
    });
  });

  tearDown(() {
    Get.reset();
  });

  group('ContactDetailsScreen Widget Tests', () {
    testWidgets('Renders contact photo, name, phone, calling chips, and action cards', (tester) async {
      final user = UserModel(
        uid: 'user_widget_6',
        name: 'Priya Sharma',
        phoneNumber: '+919876543299',
        createdAt: DateTime.now(),
      );

      Get.put(ContactDetailsController(
        initialArgs: ContactDetailsArgs(
          user: user,
          deviceContact: const DeviceContact(
            id: 'dc_6',
            displayName: 'Priya Sharma',
            phoneNumbers: ['+919876543299'],
          ),
          displayName: 'Priya Sharma',
          phoneNumber: '+919876543299',
        ),
        contactService: contactService,
        favoriteService: favoriteService,
        blockService: blockService,
        zegoCallService: zegoCallService,
      ));

      await tester.pumpWidget(const GetMaterialApp(
        home: ContactDetailsScreen(),
      ));
      await tester.pumpAndSettle();

      // Name and phone number rendered
      expect(find.text('Priya Sharma'), findsWidgets);
      expect(find.text('+91 98765 43299'), findsWidgets);

      // Calling chips rendered
      expect(find.text('Audio Call'), findsOneWidget);
      expect(find.text('Video Call'), findsOneWidget);

      // Communication actions rendered
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);

      // Contact actions rendered
      expect(find.text('Copy Phone Number'), findsOneWidget);
      expect(find.text('Share Contact'), findsOneWidget);
      expect(find.text('Edit Contact'), findsOneWidget);

      // Privacy actions rendered
      expect(find.text('Block Contact'), findsOneWidget);
      expect(find.text('Delete Contact'), findsOneWidget);
    });

    testWidgets('Blocked user displays blocked banner and unblock button', (tester) async {
      final user = UserModel(
        uid: 'user_blocked_7',
        name: 'Blocked User',
        phoneNumber: '+919123456789',
        createdAt: DateTime.now(),
      );

      inMemoryBlocked.add('user_blocked_7');
      blockService.blockedUserIds.add('user_blocked_7');

      Get.put(ContactDetailsController(
        initialArgs: ContactDetailsArgs(
          user: user,
          displayName: 'Blocked User',
          phoneNumber: '+919123456789',
        ),
        contactService: contactService,
        favoriteService: favoriteService,
        blockService: blockService,
        zegoCallService: zegoCallService,
      ));

      await tester.pumpWidget(const GetMaterialApp(
        home: ContactDetailsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Contact is currently Blocked'), findsOneWidget);
      expect(find.text('Unblock Contact'), findsOneWidget);
    });
  });
}
