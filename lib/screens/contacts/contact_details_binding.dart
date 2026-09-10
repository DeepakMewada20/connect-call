import 'package:get/get.dart';
import 'contact_details_controller.dart';

class ContactDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ContactDetailsController>(() => ContactDetailsController());
  }
}
