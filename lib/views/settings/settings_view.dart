import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/config/app_config.dart';
import 'package:ngtowncardriver/controllers/auth_controller.dart';
import 'package:ngtowncardriver/controllers/dashboard_controller.dart';
import 'package:ngtowncardriver/routes/app_routes.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  static const Color _mutedGrey = Color(0xFFB8B8B8);

  DashboardController get _dashboard => Get.find<DashboardController>();

  Future<void> _openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.inputBackground,
          title: Text(
            'Logout',
            style: AppTextStyles.whiteMedium(dialogContext),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: AppTextStyles.whiteSmall(dialogContext),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: AppTextStyles.whiteSmall(dialogContext),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Get.find<AuthController>().signOut();
              },
              child: Text(
                'Logout',
                style: AppTextStyles.whiteSmall(
                  dialogContext,
                ).copyWith(color: AppColors.primaryRed),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Settings',
                style: AppTextStyles.large(
                  context,
                ).copyWith(color: AppColors.primaryGreen),
              ),
            ),
            const SizedBox(height: 28),

            _settingsCard(children: [_profileTile(context)]),
            const SizedBox(height: 14),

            // _settingsCard(
            //   children: [
            //     Obx(() {
            //       final auth = Get.find<AuthController>();
            //       return _switchTile(
            //         context: context,
            //         icon: Icons.notifications_off_outlined,
            //         title: 'Pause notifications',
            //         value: auth.notificationsPaused.value,
            //         onChanged: (value) {
            //           auth.notificationsPaused.value = value;
            //         },
            //       );
            //     }),
            //   ],
            // ),
            const SizedBox(height: 14),

            _settingsCard(
              children: [
                _tile(
                  context: context,
                  icon: Icons.info_outline,
                  title: 'Terms of service',
                  onTap: () => _openUrl(AppConfig.termsAndConditionsUrl),
                ),
                _tile(
                  context: context,
                  icon: Icons.info_outline,
                  title: 'User policy',
                  onTap: () => _openUrl(AppConfig.privacyPolicyUrl),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _settingsCard(
              children: [
                _tile(
                  context: context,
                  icon: Icons.badge_outlined,
                  title: 'Driver Details',
                  onTap: () => Get.toNamed(AppRoutes.driverDetails),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _settingsCard(
              children: [
                _tile(
                  context: context,
                  icon: Icons.settings_outlined,
                  title: 'General Settings',
                  iconColor: AppColors.white,
                  textColor: AppColors.white,
                  onTap: () {
                    final auth = Get.find<AuthController>();
                    auth.clearDeleteAccountForm();
                    auth.isDeletingAccount.value = false;
                    Get.toNamed(AppRoutes.deleteacc);
                  },
                ),
                _versionTile(context),
              ],
            ),
            const SizedBox(height: 28),

            // GestureDetector(
            //   onTap: () => _showLogoutDialog(context),
            //   child: Container(
            //     width: double.infinity,
            //     height: 54,
            //     decoration: BoxDecoration(
            //       color: AppColors.white,
            //       borderRadius: BorderRadius.circular(28),
            //     ),
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: [
            //         Icon(Icons.logout, color: AppColors.primaryRed, size: 20),
            //         const SizedBox(width: 10),
            //         Text(
            //           'Log Out',
            //           style: AppTextStyles.whiteSmall(context).copyWith(
            //             color: AppColors.primaryRed,
            //             fontWeight: FontWeight.w600,
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _profileTile(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3A3A3A),
              ),
              child: const Icon(Icons.person, color: AppColors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Obx(() {
                final name = _dashboard.profileName.value;
                final email = _dashboard.profileEmail.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.whiteSmall(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: AppTextStyles.whiteSmall(
                          context,
                        ).copyWith(color: _mutedGrey, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                );
              }),
            ),
            const Icon(Icons.chevron_right, color: _mutedGrey, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _versionTile(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        final build = snapshot.data?.buildNumber;
        final value = version == null
            ? '—'
            : (build == null || build.isEmpty)
            ? version
            : '$version ($build)';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.white, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'App Version',
                  style: AppTextStyles.whiteSmall(
                    context,
                  ).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                ),
              ),
              Text(
                value,
                style: AppTextStyles.whiteSmall(
                  context,
                ).copyWith(color: _mutedGrey, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.white, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.whiteSmall(context).copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: textColor,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: _mutedGrey, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.white, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.whiteSmall(
                context,
              ).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryGreen,
            activeTrackColor: AppColors.primaryGreen.withValues(alpha: 0.45),
            inactiveThumbColor: AppColors.white,
            inactiveTrackColor: const Color(0xFF555555),
          ),
        ],
      ),
    );
  }
}
