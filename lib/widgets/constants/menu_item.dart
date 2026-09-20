import 'package:flutter/material.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

class MenuItem extends StatelessWidget {
  final BuildContext context;
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const MenuItem({
    super.key,
    required this.context,
    required this.title,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
   return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: GestureDetector(
        onTap: onTap,
        // borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? AppColors.primaryGreen, size: 23),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.whiteMedium(
                    context,
                  ).copyWith(color: textColor ?? AppColors.white),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.white.withValues(alpha: 0.65),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

 

 
}
