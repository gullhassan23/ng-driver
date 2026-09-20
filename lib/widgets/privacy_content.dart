import 'package:flutter/material.dart';
import 'package:ngtowncardriver/config/app_config.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text.dart';

import 'package:url_launcher/url_launcher.dart';

class PrivacyContent extends StatefulWidget {
  const PrivacyContent({super.key});

  @override
  State<PrivacyContent> createState() => _PrivacyContentState();
}

class _PrivacyContentState extends State<PrivacyContent> {
  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _gradientLink(String text, VoidCallback onTap, TextStyle style) {
    return GestureDetector(
      onTap: onTap,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) =>
            AppColors.gradientOrange.createShader(bounds),
        child: Text(
          text,
          style: style.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);
    final normalStyle = TextStyle(
      color: AppColors.white,
      fontSize: responsive.h(1.7),
      fontWeight: FontWeight.w400,
    );
    final linkStyle = TextStyle(
      fontSize: responsive.h(1.7),
      fontWeight: FontWeight.w500,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.w(8)),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${AppText.policyContent} ', style: normalStyle),
            _gradientLink(
              AppText.term.trim(),
              () => _openUrl(AppConfig.termsAndConditionsUrl),
              linkStyle,
            ),
            Text(' ${AppText.and}', style: normalStyle),
            _gradientLink(
              AppText.privacyPolicy,
              () => _openUrl(AppConfig.privacyPolicyUrl),
              linkStyle,
            ),
          ],
        ),
      ),
    );
  }
}
