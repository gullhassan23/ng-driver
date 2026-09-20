import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/controllers/auth_controller.dart';
import 'package:ngtowncardriver/models/driver_information_model.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/services/firestore_service.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';
import 'package:ngtowncardriver/widgets/app_icon_button_widget.dart';

class DriverDetailsView extends StatefulWidget {
  const DriverDetailsView({super.key});

  @override
  State<DriverDetailsView> createState() => _DriverDetailsViewState();
}

class _DriverDetailsViewState extends State<DriverDetailsView> {
  static const Color _mutedGrey = Color(0xFFB8B8B8);

  final FirestoreService _firestore = FirestoreService();

  bool _isLoading = true;
  String? _errorMessage;
  DriverInformationModel? _info;

  @override
  void initState() {
    super.initState();
    _loadDriverInformation();
  }

  Future<void> _loadDriverInformation() async {
    final uid = Get.find<AuthController>().uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'You are not signed in.';
      });
      return;
    }

    try {
      final info = await _firestore.fetchDriverInformation(uid);
      if (!mounted) return;
      setState(() {
        _info = info;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load driver details.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
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
                      'Driver Details',
                      style: AppTextStyles.whiteMedium(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: AppTextStyles.whiteSmall(
              context,
            ).copyWith(color: _mutedGrey, fontSize: 15),
          ),
        ),
      );
    }

    final info = _info;
    if (info == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No driver details found',
            textAlign: TextAlign.center,
            style: AppTextStyles.whiteSmall(
              context,
            ).copyWith(color: _mutedGrey, fontSize: 15),
          ),
        ),
      );
    }

    final rows = <(String, String)>[
      ('CNIC', info.cnic),
      ('License number', info.licenseNumber),
      ('Vehicle type', info.vehicleType),
      ('Vehicle make', info.vehicleMake),
      ('Vehicle model', info.vehicleModel),
      ('Vehicle color', info.vehicleColor),
      ('Registration', info.vehicleRegistration),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(22),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) _rowDivider(),
              _detailRow(
                context: context,
                label: rows[i].$1,
                value: rows[i].$2.trim().isEmpty ? '—' : rows[i].$2.trim(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required BuildContext context,
    required String label,
    required String value,
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
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.whiteSmall(
                context,
              ).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
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
}
