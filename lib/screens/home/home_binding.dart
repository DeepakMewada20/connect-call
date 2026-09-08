import 'package:get/get.dart';
import '../calls/calls_controller.dart';
import '../contacts/contacts_controller.dart';
import '../profile/profile_controller.dart';
import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<ContactsController>(() => ContactsController());
    Get.lazyPut<CallsController>(() => CallsController());
    Get.lazyPut<ProfileController>(() => ProfileController());
  }
}
