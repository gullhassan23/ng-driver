import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/controllers/auth_controller.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';
import 'package:ngtowncardriver/widgets/app_blur_dialog.dart';
import 'package:ngtowncardriver/widgets/app_icon_button_widget.dart';
import 'package:ngtowncardriver/widgets/app_snackbar_widget.dart';
import 'package:ngtowncardriver/widgets/app_text_field_widget.dart';

class DeleteAccSection extends GetView<AuthController> {
  const DeleteAccSection({super.key});

  static const Color _mutedGrey = Color(0xFFB8B8B8);

  Future<void> _onDeletePressed(BuildContext context) async {
    if (controller.isDeletingAccount.value) return;

    if (controller.deleteAccountPassword.text.trim().isEmpty) {
      AppSnackbar.error(
        title: 'Password required',
        message: 'Enter your password to confirm account deletion.',
      );
      return;
    }

    if (!controller.deleteAccountConfirmed.value) {
      AppSnackbar.error(
        title: 'Confirmation required',
        message: 'Please confirm that you understand this cannot be undone.',
      );
      return;
    }

    final shouldDelete = await _showConfirmDialog(context);
    if (shouldDelete != true) return;

    await controller.deleteAccount();
  }

  Future<bool?> _showConfirmDialog(BuildContext context) {
    return showAppBlurDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.inputBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Account?',
            style: AppTextStyles.whiteMedium(context),
          ),
          content: Text(
            'This action will permanently delete your driver account and associated data. This cannot be undone.',
            style: AppTextStyles.whiteSmall(
              context,
            ).copyWith(color: _mutedGrey, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: AppTextStyles.whiteSmall(context)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete Account',
                style: AppTextStyles.whiteSmall(
                  context,
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
    return Scaffold(
      
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _header(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _warningHero(context),
                    const SizedBox(height: 28),
                    _consequencesCard(context),
                    const SizedBox(height: 16),
                    _passwordCard(context),
                    const SizedBox(height: 16),
                    _confirmRow(context),
                    const SizedBox(height: 28),
                    _deleteButton(context),
                    const SizedBox(height: 14),
                    _keepAccountButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Obx(() {
              final deleting = controller.isDeletingAccount.value;
              return AppIconButtonWidget(
                icon: Icons.arrow_back,
                onPressed: deleting ? null : () => Get.back(),
                backgroundColor: AppColors.primaryGreen,
                iconColor: AppColors.black,
                width: responsive.w(10),
                height: responsive.h(5),
                borderRadius: responsive.w(3),
              );
            }),
          ),
          Text(
            'Delete Account',
            style: AppTextStyles.whiteMedium(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _warningHero(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryGreen,
            // color: AppColors.primaryRed.withValues(alpha: 0.14),
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            color: AppColors.black,
            size: 42,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          "We're sorry to see you go",
          textAlign: TextAlign.center,
          style: AppTextStyles.whiteMedium(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Deleting your driver account is permanent. You will lose access to rides, reservations, and profile data.',
          textAlign: TextAlign.center,
          style: AppTextStyles.whiteSmall(
            context,
          ).copyWith(color: _mutedGrey, height: 1.45, fontSize: 13),
        ),
      ],
    );
  }

  Widget _consequencesCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You will lose',
            style: AppTextStyles.whiteSmall(
              context,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          _consequenceRow(
            context,
            icon: Icons.history,
            title: 'Ride history',
            subtitle: 'Completed trips and earnings records',
          ),
          _consequenceRow(
            context,
            icon: Icons.event_busy_outlined,
            title: 'Reservations',
            subtitle: 'Pending and confirmed bookings',
          ),
          _consequenceRow(
            context,
            icon: Icons.badge_outlined,
            title: 'Driver profile',
            subtitle: 'Name, vehicle, and account details',
          ),
        ],
      ),
    );
  }

  Widget _consequenceRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              // color: AppColors.primaryRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.black,
              //  color: AppColors.primaryRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.whiteSmall(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.whiteSmall(
                    context,
                  ).copyWith(color: _mutedGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm with password',
            style: AppTextStyles.whiteSmall(
              context,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your current password to delete this account.',
            style: AppTextStyles.whiteSmall(
              context,
            ).copyWith(color: _mutedGrey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final deleting = controller.isDeletingAccount.value;
            final obscure = controller.obscureDeletePassword.value;
            return AppTextFieldWidget(
              hintText: 'Password',
              controller: controller.deleteAccountPassword,
              keyboardType: TextInputType.visiblePassword,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              borderRadius: 16,
              fillColor: const Color(0xFF3A3A3A),
              enabled: !deleting,
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white54,
                ),
                onPressed: deleting
                    ? null
                    : () => controller.obscureDeletePassword.toggle(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _confirmRow(BuildContext context) {
    return Obx(() {
      final confirmed = controller.deleteAccountConfirmed.value;
      final deleting = controller.isDeletingAccount.value;
      return GestureDetector(
        onTap: deleting
            ? null
            : () => controller.deleteAccountConfirmed.toggle(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: confirmed ? AppColors.primaryRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: confirmed ? AppColors.primaryRed : _mutedGrey,
                    width: 1.6,
                  ),
                ),
                child: confirmed
                    ? const Icon(Icons.check, size: 15, color: AppColors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'I understand this action cannot be undone.',
                  style: AppTextStyles.whiteSmall(
                    context,
                  ).copyWith(fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _deleteButton(BuildContext context) {
    return Obx(() {
      final deleting = controller.isDeletingAccount.value;
      return GestureDetector(
        onTap: deleting ? null : () => _onDeletePressed(context),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(28),
          ),
          alignment: Alignment.center,
          child: deleting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      color: AppColors.black,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Delete my account',
                      style: AppTextStyles.whiteSmall(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      );
    });
  }

  Widget _keepAccountButton(BuildContext context) {
    return Obx(() {
      final deleting = controller.isDeletingAccount.value;
      return GestureDetector(
        onTap: deleting ? null : () => Get.back(),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          alignment: Alignment.center,
          child: Text(
            'Keep my account',
            style: AppTextStyles.whiteSmall(context).copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      );
    });
  }
}
