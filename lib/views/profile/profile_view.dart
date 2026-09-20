import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/controllers/auth_controller.dart';
import 'package:ngtowncardriver/controllers/dashboard_controller.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/services/firestore_service.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';
import 'package:ngtowncardriver/utilis/firestore_paths.dart';
import 'package:ngtowncardriver/widgets/app_icon_button_widget.dart';
import 'package:ngtowncardriver/widgets/app_snackbar_widget.dart';
import 'package:ngtowncardriver/widgets/constants/menu_item.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  static const Color _mutedGrey = Color(0xFFB8B8B8);

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _usernameController;

  final FirestoreService _firestore = FirestoreService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = Get.find<AuthController>();
    final authEmail = auth.currentUser?.email?.trim() ?? '';

    var initialName = '';
    var initialEmail = authEmail;
    if (Get.isRegistered<DashboardController>()) {
      final dashboard = Get.find<DashboardController>();
      if (dashboard.profileName.value.isNotEmpty &&
          dashboard.profileName.value != 'Driver') {
        initialName = dashboard.profileName.value;
      }
      if (dashboard.profileEmail.value.isNotEmpty) {
        initialEmail = dashboard.profileEmail.value;
      }
    }

    _nameController = TextEditingController(text: initialName);
    _phoneController = TextEditingController();
    _emailController = TextEditingController(text: initialEmail);
    _usernameController = TextEditingController(text: initialName);

    _loadDriverProfile();
  }

  Future<void> _loadDriverProfile() async {
    final auth = Get.find<AuthController>();
    final authEmail = auth.currentUser?.email?.trim() ?? '';
    final uid = auth.uid;
    if (uid == null) return;

    try {
      final driver = await _firestore.fetchDriver(uid);
      if (!mounted || driver == null) return;

      final name = driver.fullName.trim();
      final email = driver.email.trim().isNotEmpty
          ? driver.email.trim()
          : authEmail;
      final phone = driver.phone.trim();

      // TextEditingControllers update without setState.
      if (name.isNotEmpty) {
        _nameController.text = name;
        _usernameController.text = name;
      }
      if (email.isNotEmpty) _emailController.text = email;
      if (phone.isNotEmpty) _phoneController.text = phone;
    } catch (_) {
      // Keep auth email / empty name if Firestore read fails.
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final fullName = _nameController.text.trim();
    if (fullName.isEmpty) {
      AppSnackbar.error(
        title: 'Save failed',
        message: 'Enter your full name.',
      );
      return;
    }

    final auth = Get.find<AuthController>();
    final uid = auth.uid;
    if (uid == null) {
      AppSnackbar.error(
        title: 'Save failed',
        message: 'You are not signed in.',
      );
      return;
    }

    final parts = fullName.split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    setState(() => _isSaving = true);

    try {
      await _firestore.updateDriverFields(uid, {
        DriverFields.firstName: firstName,
        DriverFields.lastName: lastName,
        DriverFields.email: email,
        DriverFields.phone: phone,
      });

      await auth.currentUser?.updateDisplayName(fullName);

      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().refreshProfileDisplay(
          fullName: fullName,
          email: email,
        );
      }

      if (!mounted) return;

      _usernameController.text = fullName;

      AppSnackbar.success(
        title: 'Profile updated',
        message: 'Your changes have been saved.',
      );
    } catch (_) {
      AppSnackbar.error(
        title: 'Save failed',
        message: 'Could not save your profile. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =====================================================
              // HEADER: circular back + Edit Profile title
              // =====================================================
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppIconButtonWidget(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.pop(context),
                        backgroundColor: AppColors.primaryGreen,
                        iconColor: AppColors.black,
                        width: responsive.w(10),
                        height: responsive.h(5),
                        borderRadius: responsive.w(3),
                      ),
                    ),
                    Text(
                      'Edit Profile',
                      style: AppTextStyles.whiteMedium(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // =====================================================
              // AVATAR + CAMERA BADGE
              // =====================================================
              Center(
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF3A3A3A),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.white,
                          size: 56,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: GestureDetector(
                          onTap: () {
                            // TODO: Pick profile photo
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: AppColors.dashboardAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                             Icons.check,
                              color: AppColors.black,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // =====================================================
              // EDIT FIELDS CARD
              // =====================================================
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _editRow(
                      context: context,
                      label: 'Full name',
                      controller: _nameController,
                    ),
                    _rowDivider(),
                    _editRow(
                      context: context,
                      label: 'Phone number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    _rowDivider(),
                    _editRow(
                      context: context,
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _rowDivider(),
                    _editRow(
                      context: context,
                      label: 'Username',
                      controller: _usernameController,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =====================================================
              // SAVE CHANGES
              // =====================================================
              GestureDetector(
                onTap: _isSaving ? null : _saveProfile,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.dashboardAccent,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  alignment: Alignment.center,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.black,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: AppTextStyles.whiteSmall(context).copyWith(
                            color: AppColors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 30),

              // =====================================================
              // HISTORY
              // =====================================================

              // =====================================================
              // LEGAL
              // =====================================================
              // Text(
              //   'Legal',
              //   style: AppTextStyles.whiteMedium(
              //     context,
              //   ).copyWith(color: AppColors.primaryGreen),
              // ),

              // const SizedBox(height: 10),

              // _menuItem(
              //   context: context,
              //   title: 'Terms of Service',
              //   icon: Icons.description_outlined,
              //   onTap: () {
              //     // TODO: Terms of Service
              //   },
              // ),

              // _menuItem(
              //   context: context,
              //   title: 'Privacy Policy',
              //   icon: Icons.privacy_tip_outlined,
              //   onTap: () {
              //     // TODO: Privacy Policy
              //   },
              // ),

              // const SizedBox(height: 20),

              // // =====================================================
              // // ACCOUNT
              // // =====================================================
              // Text(
              //   'Account',
              //   style: AppTextStyles.whiteMedium(
              //     context,
              //   ).copyWith(color: AppColors.primaryGreen),
              // ),

              // const SizedBox(height: 10),

              // // DELETE ACCOUNT
              // _menuItem(
              //   context: context,
              //   title: 'Delete Account',
              //   icon: Icons.delete_outline,
              //   iconColor: AppColors.primaryRed,
              //   textColor: AppColors.primaryRed,
              //   onTap: () {
              //     _showDeleteDialog(context);
              //   },
              // ),

              // LOGOUT
              MenuItem(
                context: context,
                title: 'Logout',
                icon: Icons.logout,
                iconColor: AppColors.primaryRed,
                textColor: AppColors.primaryRed,
                onTap: () {
                  _showLogoutDialog(context);
                },
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }



  Widget _editRow({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.whiteSmall(
              context,
            ).copyWith(color: _mutedGrey, fontSize: 14),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              style: AppTextStyles.whiteSmall(
                context,
              ).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
              cursorColor: AppColors.primaryGreen,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.white.withValues(alpha: 0.08),
    );
  }

 


  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.inputBackground,
          title: Text('Logout', style: AppTextStyles.whiteMedium(context)),
          content: Text(
            'Are you sure you want to logout?',
            style: AppTextStyles.whiteSmall(context),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel', style: AppTextStyles.whiteSmall(context)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Get.find<AuthController>().signOut();
                // TODO: Logout
              },
              child: Text(
                'Logout',
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
}
