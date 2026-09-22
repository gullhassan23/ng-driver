import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';

class RiderArrivedBanner extends StatelessWidget {
  const RiderArrivedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF163A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passenger has arrived',
            style: GoogleFonts.inter(
              color: AppColors.primaryGreen,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your passenger has arrived at the pickup location.',
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}