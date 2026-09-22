import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';

class RouteMetaChip extends StatelessWidget {
    final String eta;
  final String distance;
  const RouteMetaChip({super.key, required this.eta, required this.distance});



  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (eta.isNotEmpty) eta,
      if (distance.isNotEmpty) distance,
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          parts.join(' · '),
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}