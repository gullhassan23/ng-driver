import 'package:flutter/material.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/widgets/auth_rich_text_widget.dart';

class AuthText extends StatelessWidget {
  final String title;
  final String text;
  final VoidCallback onTap;

  const AuthText({
    super.key,
    required this.title,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return SizedBox(
      width: double.infinity,
      child: AuthRichTextWidget(
        normalText: title,
        highlightedText: text,
        normalTextColor: AppColors.white,
        highlightedGradient: AppColors.gradientOrange,
        textAlign: TextAlign.center,
        padding: EdgeInsets.only(
          top: responsive.h(3),
          left: responsive.w(8),
          right: responsive.w(8),
        ),
        onHighlightedTap: onTap,
      ),
    );
  }
}
