import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/views/history/history.dart';
import 'package:ngtowncardriver/views/reservations/confirm_reservation.dart';

import '../../controllers/dashboard_controller.dart';
import '../../utilis/app_colors.dart';
import '../../widgets/bottomnav/bottom_nav.dart';
import '../dashboard/dashboard_view.dart';

import '../settings/settings_view.dart';

class MainShellView extends GetView<DashboardController> {
  const MainShellView({super.key});

  @override
  Widget build(BuildContext context) {
    // Built once — Obx only updates IndexedStack.index / bottom nav selection.
    const tabs = <Widget>[
      DashboardView(),
      ConfirmReservation(),
      History(),
      SettingsView(),
    ];

    return Obx(() {
      final index = controller.selectedNavIndex.value;
      return Scaffold(
        backgroundColor: AppColors.dashboardBackground,
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: index,
            children: tabs,
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: DashboardBottomNavWidget(
            selectedIndex: index,
            onItemSelected: controller.selectNav,
          ),
        ),
      );
    });
  }
}
