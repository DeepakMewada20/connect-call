import 'package:get/get.dart';
import 'splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SplashController>()) {
      Get.put<SplashController>(SplashController());
    }
  }
}
