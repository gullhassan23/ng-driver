import 'package:flutter/material.dart';
import 'package:ngtowncardriver/models/reservation_model.dart';
import 'package:ngtowncardriver/responsiveness/responsive_repo.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

class AppReservationCustomerCardWidget extends StatelessWidget {
  final ReservationModel reservation;

  const AppReservationCustomerCardWidget({
    super.key,
    required this.reservation,
  });

  @override
  Widget build(BuildContext context) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);
    final BorderRadius radius = BorderRadius.circular(responsive.w(4));
    final double accentWidth = responsive.w(1);

    final String name = reservation.fullName.isNotEmpty
        ? reservation.fullName
        : '—';

    final String phone = reservation.phone.trim().isNotEmpty
        ? reservation.phone
        : '—';
    final String email = reservation.email.trim().isNotEmpty
        ? reservation.email
        : '—';
    final String createdAt = reservation.displayCreatedAt;
    final String createdAtTime = reservation.displayCreatedAtTime;
    final String initials = _getInitials(name);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: radius,
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.12)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.w(3.5) + accentWidth,
                responsive.w(3.5),
                responsive.w(3.5),
                responsive.w(3.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: responsive.w(13),
                    height: responsive.w(13),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryGreen,
                          AppColors.primaryGreen.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: AppColors.white,
                        fontFamily: 'Poppins',
                        fontSize: responsive.h(2),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.w(2.5)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.whiteMedium(context).copyWith(
                            fontSize: responsive.h(1.8),
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: responsive.h(0.7)),
                        _contactLine(
                          context: context,
                          responsive: responsive,
                          icon: Icons.phone_outlined,
                          text: phone,
                          maxLines: 1,
                        ),
                        SizedBox(height: responsive.h(0.45)),
                        _contactLine(
                          context: context,
                          responsive: responsive,
                          icon: Icons.email_outlined,
                          text: email,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: responsive.w(1.5)),
                  Container(
                    width: 1,
                    height: responsive.h(8.5),
                    color: AppColors.white.withValues(alpha: 0.12),
                  ),
                  SizedBox(width: responsive.w(1.8)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.white.withValues(alpha: 0.75),
                        size: responsive.w(4),
                      ),
                      SizedBox(height: responsive.h(0.4)),
                      Text(
                        'Created At',
                        maxLines: 1,
                        style: AppTextStyles.small(context).copyWith(
                          fontSize: responsive.h(1.25),
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      SizedBox(height: responsive.h(0.25)),
                      Text(
                        createdAt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.small(context).copyWith(
                          fontSize: responsive.h(1.25),
                          color: AppColors.white,
                        ),
                      ),
                      Text(
                        createdAtTime == '—' ? '—' : 'at $createdAtTime',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.small(context).copyWith(
                          fontSize: responsive.h(1.25),
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: accentWidth,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactLine({
    required BuildContext context,
    required ResponsiveRepo responsive,
    required IconData icon,
    required String text,
    int maxLines = 1,
  }) {
    final double iconSize = responsive.w(3.6);
    final double fontSize = responsive.h(1.3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: responsive.h(0.12)),
          child: Icon(
            icon,
            color: AppColors.white.withValues(alpha: 0.75),
            size: iconSize,
          ),
        ),
        SizedBox(width: responsive.w(1.2)),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.small(context).copyWith(
              fontSize: fontSize,
              height: 1.25,
              color: AppColors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');

    if (parts.isEmpty || name.trim().isEmpty || name.trim() == '—') {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
