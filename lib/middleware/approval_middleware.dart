import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../routes/app_routes.dart';

/// Blocks dashboard and ride details until Firestore has confirmed
/// `isApproved == true`. GetX `redirect` is synchronous, so this reads
/// [AuthController.hasConfirmedApproval] set by the last fetch.
class ApprovalMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<AuthController>()) {
      return const RouteSettings(name: AppRoutes.signIn);
    }

    final auth = Get.find<AuthController>();

    if (auth.uid == null) {
      return const RouteSettings(name: AppRoutes.signIn);
    }

    if (!auth.hasConfirmedApproval.value) {
      return const RouteSettings(name: AppRoutes.waitingApproval);
    }

    return null;
  }
}
