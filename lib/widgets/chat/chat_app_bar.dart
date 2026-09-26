import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../app_icon_button_widget.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key, required this.riderName, this.onBack});

  final String riderName;
  final VoidCallback? onBack;

  static const Color _muted = Color(0xFF9CA3AF);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    final name = riderName.trim().isEmpty ? 'Passenger' : riderName.trim();
    final responsive = ResponsiveRepo(context);

    return AppBar(
      backgroundColor: AppColors.dashboardBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: AppIconButtonWidget(
        icon: Icons.arrow_back,
        onPressed: () => Get.back(),
        backgroundColor: AppColors.primaryGreen,
        iconColor: AppColors.black,
        width: responsive.w(10),
        height: responsive.h(5),
        top: responsive.h(2),
        left: responsive.w(4),
        borderRadius: responsive.w(3),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chat',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppColors.primaryGreen.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
