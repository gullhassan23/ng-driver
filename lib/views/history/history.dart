import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/routes/app_routes.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

class History extends StatelessWidget {
  const History({super.key});

  static const Color _mutedGrey = Color(0xFFB8B8B8);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Text(
                AppText.history,
                style: AppTextStyles.large(
                  context,
                ).copyWith(color: AppColors.primaryGreen),
              ),
            ),
            const SizedBox(height: 28),
            _card(
              children: [
                _tile(
                  context: context,
                  icon: Icons.directions_car_outlined,
                  title: AppText.rideHistory,
                  onTap: () => Get.toNamed(AppRoutes.rideCompleted),
                ),
                _tile(
                  context: context,
                  icon: Icons.event_note_outlined,
                  title: 'Reservation History',
                  onTap: () => Get.toNamed(AppRoutes.reservation),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _tile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.white, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.whiteSmall(
                  context,
                ).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
              ),
            ),
            const Icon(Icons.chevron_right, color: _mutedGrey, size: 22),
          ],
        ),
      ),
    );
  }
}
