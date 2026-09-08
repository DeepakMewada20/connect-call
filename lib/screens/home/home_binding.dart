import 'package:get/get.dart';
import '../calls/calls_controller.dart';
import '../contacts/contacts_controller.dart';
import '../profile/profile_controller.dart';
import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController(), fenix: true);
    Get.lazyPut<ContactsController>(() => ContactsController(), fenix: true);
    Get.lazyPut<CallsController>(() => CallsController(), fenix: true);
    Get.lazyPut<ProfileController>(() => ProfileController(), fenix: true);
  }
}
