import 'package:flutter/material.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

class DashboardBottomNavWidget extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int>? onItemSelected;

  const DashboardBottomNavWidget({
    super.key,
    this.selectedIndex = 0,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: responsive.w(5),
        right: responsive.w(5),
        top: responsive.h(1.2),
        bottom: responsive.h(1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            isSelected: selectedIndex == 0,
            onTap: () {
              onItemSelected?.call(0);
            },
            responsive: responsive,
          ),
          _NavItem(
            icon: Icons.directions_car_rounded,
            label: 'Reservations',
            isSelected: selectedIndex == 1,
            onTap: () {
              onItemSelected?.call(1);
            },
            responsive: responsive,
          ),
          _NavItem(
            icon: Icons.access_time_filled_rounded,
            label: 'History',
            isSelected: selectedIndex == 2,
            onTap: () {
              onItemSelected?.call(2);
            },
            responsive: responsive,
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            isSelected: selectedIndex == 3,
            onTap: () {
              onItemSelected?.call(3);
            },
            responsive: responsive,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ResponsiveRepo responsive;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onTap,
        // borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: responsive.w(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: responsive.w(12),
                height: responsive.w(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.primaryGreen
                      : const Color(0xFFEDEDED),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: responsive.h(2.5),
                    color: AppColors.black,
                  ),
                ),
              ),
              SizedBox(height: responsive.h(0.4)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                // style: TextStyle(
                //   fontSize: responsive.h(1.3),
                //   fontWeight:
                //       isSelected ? FontWeight.w600 : FontWeight.w400,
                //   color: isSelected
                //       ? AppColors.primaryGreen
                //       : const Color(0xFF8A8A8A),
                // ),
                style: AppTextStyles.small(context).copyWith(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : const Color(0xFF8A8A8A),
                  fontSize: responsive.h(1.3),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
