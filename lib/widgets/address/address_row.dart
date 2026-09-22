import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';

class AddressRow extends StatelessWidget {
  const AddressRow({super.key, required this.asset, required this.text});

  final String asset;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(asset, width: 26, height: 26, fit: BoxFit.contain),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}