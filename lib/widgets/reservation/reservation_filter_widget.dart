import 'package:flutter/material.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

class AppReservationFilterWidget extends StatelessWidget {
  final int? selectedIndex;
  final ValueChanged<int>? onChanged;

  const AppReservationFilterWidget({
    super.key,
    this.selectedIndex,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    final List<_FilterItem> filters = [
      const _FilterItem(
        title: AppText.all,
        icon: Icons.calendar_month_outlined,
      ),
      const _FilterItem(
        title: AppText.completed,
        icon: Icons.check_circle_outline,
      ),
      const _FilterItem(title: AppText.cancelled, icon: Icons.cancel_outlined),
    ];

    return SizedBox(
      height: responsive.h(6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: responsive.w(3)),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final bool isSelected = (selectedIndex ?? 0) == index;

          final _FilterItem filter = filters[index];

          return GestureDetector(
            onTap: () {
              onChanged?.call(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: responsive.w(2)),
              padding: EdgeInsets.symmetric(
                horizontal: responsive.w(4),
                vertical: responsive.h(2),
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryGreen
                    : AppColors.inputBackground,
                borderRadius: BorderRadius.circular(responsive.w(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    filter.icon,
                    size: responsive.w(4.2),
                    color: isSelected
                        ? AppColors.black
                        : AppColors.white.withValues(alpha: 0.70),
                  ),

                  SizedBox(width: responsive.w(1.7)),

                  Text(
                    filter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.small(context).copyWith(
                      color: isSelected
                          ? AppColors.black
                          : AppColors.white.withValues(alpha: 0.70),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterItem {
  final String title;
  final IconData icon;

  const _FilterItem({required this.title, required this.icon});
}
