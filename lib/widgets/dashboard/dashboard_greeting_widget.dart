import 'package:flutter/material.dart';
import 'package:ngtowncardriver/routes/app_routes.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

import '../../responsiveness/responsive_repo.dart';

class DashboardGreetingWidget extends StatelessWidget {
  final String name;

  const DashboardGreetingWidget({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // GREETING TEXT
        // ==========================================
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _gradientText(context: context, text: 'Good', height: 0.81),

              _gradientText(
                context: context,
                text: _greetingPeriod(),
                height: 1.22,
              ),

              _gradientText(context: context, text: name, height: 0.9),
            ],
          ),
        ),

        // ==========================================
        // PROFILE IMAGE - CLICKABLE
        // ==========================================
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.profile);
          },

          child: Container(
            width: responsive.w(12),
            height: responsive.w(12),

            margin: EdgeInsets.only(top: responsive.h(0.5)),

            padding: EdgeInsets.all(responsive.w(0.8)),

            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryGreen,
            ),

            child: ClipOval(
              child: Image.asset(
                'assets/images/profile.png',
                fit: BoxFit.cover,

                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.person,
                    color: Colors.black,
                    size: responsive.w(8),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _greetingPeriod() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'morning,';
    if (hour >= 12 && hour < 17) return 'afternoon,';
    if (hour >= 17 && hour < 21) return 'evening,';
    return 'night,';
  }

  // ==========================================
  // GRADIENT TEXT
  // ==========================================
  Widget _gradientText({
    required BuildContext context,
    required String text,
    required double height,
  }) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return AppColors.gradientOrange.createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        );
      },

      blendMode: BlendMode.srcIn,

      child: Text(
        text,
        style: AppTextStyles.extraLarge(context).copyWith(height: height),
      ),
    );
  }
}
