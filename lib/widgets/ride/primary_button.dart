import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';

class PrimaryCtaButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool showProgressTint;
  final VoidCallback onTap;
  const PrimaryCtaButton({
    super.key,
    required this.label,
    required this.loading,
    required this.showProgressTint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isStartRide = showProgressTint;
    final background = isStartRide
        ? AppColors.primaryGreen
        : const Color(0xFF2F6FED);
    final foreground = isStartRide ? AppColors.black : AppColors.white;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: GestureDetector(
        onTap: loading ? null : onTap,
        // borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: foreground,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.inter(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
