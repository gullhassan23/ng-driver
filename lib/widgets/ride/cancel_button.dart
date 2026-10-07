import 'package:flutter/material.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';

class CancelSquareButton extends StatelessWidget {
  const CancelSquareButton({super.key, this.onTap, this.loading = false});

  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: loading ? 0.4 : 1.0,
      child: Material(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(10),
        child: GestureDetector(
          onTap: loading ? null : onTap,
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
      ),
    );
  }
}
