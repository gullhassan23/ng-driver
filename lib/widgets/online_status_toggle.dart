import 'package:flutter/material.dart';

import '../responsiveness/responsive_repo.dart';
import '../utilis/app_colors.dart';
import '../utilis/app_text_styles.dart';

class OnlineStatusToggle extends StatelessWidget {
  const OnlineStatusToggle({
    super.key,
    required this.isOnline,
    required this.isBusy,
    required this.onTap,
  });

  final bool isOnline;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: responsive.w(36),
        height: responsive.h(4.2),
        padding: EdgeInsets.all(responsive.w(0.8)),
        decoration: BoxDecoration(
          color: isOnline
              ? AppColors.primaryGreen
              : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(responsive.w(6)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment:
                  isOnline ? Alignment.centerLeft : Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: responsive.w(3)),
                child: Text(
                  isOnline ? 'Online' : 'Offline',
                  style: AppTextStyles.small(context).copyWith(
                    color: isOnline ? AppColors.black : AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Align(
              alignment:
                  isOnline ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: responsive.h(3.2),
                height: responsive.h(3.2),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppColors.black
                      : AppColors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: isBusy
                    ? Padding(
                        padding: EdgeInsets.all(responsive.w(1.2)),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isOnline
                              ? AppColors.primaryGreen
                              : AppColors.black,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
