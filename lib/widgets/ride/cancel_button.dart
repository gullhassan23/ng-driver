import 'package:flutter/material.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';

class CancelSquareButton extends StatelessWidget {
  const CancelSquareButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2C2C2E),
      borderRadius: BorderRadius.circular(10),
      child: GestureDetector(
        onTap: onTap,
        // borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            Icons.close_rounded,
            color: AppColors.primaryRed,
            size: 26,
          ),
        ),
      ),
    );
  }
}