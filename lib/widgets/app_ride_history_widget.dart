import 'package:flutter/material.dart';
import 'package:ngtowncardriver/utilis/app_colors.dart';
import 'package:ngtowncardriver/utilis/app_text.dart';
import 'package:ngtowncardriver/utilis/app_text_styles.dart';

import '../responsiveness/responsive_repo.dart';

class AppRideHistoryCardWidget extends StatelessWidget {
  final String? pickupLocation;
  final String? dropOffLocation;
  final List<String>? stopLocations;

  final String? date;
  final String? time;

  final String? fare;
  final String? distance;
  final String? duration;

  final String? status;
  final bool? isCancelled;

  final VoidCallback? onTap;

  const AppRideHistoryCardWidget({
    super.key,
    this.pickupLocation,
    this.dropOffLocation,
    this.stopLocations,
    this.date,
    this.time,
    this.fare,
    this.distance,
    this.duration,
    this.status,
    this.isCancelled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    final bool cancelled = isCancelled ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: responsive.h(1.5)),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(responsive.w(4)),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _buildSideIndicator(context, cancelled),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.w(3),
                    vertical: responsive.h(1.4),
                  ),
                  child: Column(
                    children: [
                      _buildRideContent(context, cancelled),

                      SizedBox(height: responsive.h(1)),

                      _buildDateTime(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideIndicator(BuildContext context, bool cancelled) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    return Container(
      width: responsive.w(1.1),
      decoration: BoxDecoration(
        color: cancelled ? AppColors.primaryRed : AppColors.darkGreen,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(responsive.w(4)),
          bottomLeft: Radius.circular(responsive.w(4)),
        ),
      ),
    );
  }

  Widget _buildRideContent(BuildContext context, bool cancelled) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLocationIcons(context),

        SizedBox(width: responsive.w(2.5)),

        Expanded(flex: 6, child: _buildLocations(context)),

        SizedBox(width: responsive.w(2)),

        Container(
          width: 1,
          height: responsive.h(9),
          color: AppColors.white.withValues(alpha: 0.10),
        ),

        SizedBox(width: responsive.w(3)),

        Expanded(flex: 4, child: _buildDetails(context, cancelled)),

        SizedBox(width: responsive.w(1)),

        Padding(
          padding: EdgeInsets.only(top: responsive.h(5)),
          child: Icon(
            Icons.chevron_right,
            color: AppColors.progressInactive,
            size: responsive.w(5),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationIcons(BuildContext context) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);
    final double iconSize = responsive.w(6.5);
    final stops = stopLocations ?? const <String>[];

    return SizedBox(
      width: iconSize,
      child: Column(
        children: [
          Image.asset(
            'assets/images/location.webp',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          ),
          for (var i = 0; i < stops.length; i++) ...[
            Container(
              height: responsive.h(1.2),
              width: 1,
              color: AppColors.progressInactive,
            ),
            Image.asset(
              'assets/images/stop.png',
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            ),
          ],
          Container(
            height: responsive.h(2),
            width: 1,
            color: AppColors.progressInactive,
          ),
          Image.asset(
            'assets/images/flag.webp',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _buildLocations(BuildContext context) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);
    final stops = stopLocations ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppText.pickup,
          style: AppTextStyles.whiteSmall(context).copyWith(
            fontSize: responsive.h(1.55),
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w500,
          ),
        ),

        SizedBox(height: responsive.h(0.2)),

        Text(
          pickupLocation ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.whiteSmall(
            context,
          ).copyWith(fontSize: responsive.h(1.55), color: AppColors.white),
        ),

        for (var i = 0; i < stops.length; i++) ...[
          SizedBox(height: responsive.h(0.8)),
          Text(
            'Stop ${i + 1}',
            style: AppTextStyles.whiteSmall(context).copyWith(
              fontSize: responsive.h(1.55),
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: responsive.h(0.2)),
          Text(
            stops[i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.whiteSmall(
              context,
            ).copyWith(fontSize: responsive.h(1.55), color: AppColors.white),
          ),
        ],

        SizedBox(height: responsive.h(1.2)),

        Text(
          AppText.dropOff,
          style: AppTextStyles.whiteSmall(context).copyWith(
            fontSize: responsive.h(1.55),
            color: AppColors.primaryRed,
            fontWeight: FontWeight.w500,
          ),
        ),

        SizedBox(height: responsive.h(0.2)),

        Text(
          dropOffLocation ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.whiteSmall(
            context,
          ).copyWith(fontSize: responsive.h(1.55), color: AppColors.white),
        ),
      ],
    );
  }

  Widget _buildDetails(BuildContext context, bool cancelled) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: _buildStatus(context, cancelled),
        ),

        SizedBox(height: responsive.h(1.2)),

        Text(
          fare ?? '${AppText.dollar}0',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.whiteMedium(
            context,
          ).copyWith(fontSize: responsive.h(1.8), fontWeight: FontWeight.w600),
        ),

        SizedBox(height: responsive.h(0.7)),

        _buildInfoRow(
          context,
          icon: Icons.route_outlined,
          value: distance ?? '0 ${AppText.km}',
        ),

        SizedBox(height: responsive.h(0.5)),

        _buildInfoRow(
          context,
          icon: Icons.access_time_outlined,
          value: duration ?? '0 ${AppText.min}',
        ),
      ],
    );
  }

  Widget _buildStatus(BuildContext context, bool cancelled) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.w(2),
        vertical: responsive.h(0.35),
      ),
      decoration: BoxDecoration(
        color: cancelled ? AppColors.primaryRed : AppColors.darkGreen,
        borderRadius: BorderRadius.circular(responsive.w(5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            cancelled ? Icons.close : Icons.check,
            color: AppColors.white,
            size: responsive.w(3),
          ),

          SizedBox(width: responsive.w(0.8)),

          Text(
            status ?? (cancelled ? AppText.cancelled : AppText.completed),
            style: AppTextStyles.whiteSmall(context).copyWith(
              fontSize: responsive.h(1.25),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String value,
  }) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    return Row(
      children: [
        Icon(icon, size: responsive.w(3.5), color: AppColors.progressInactive),

        SizedBox(width: responsive.w(1.2)),

        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.whiteSmall(context).copyWith(
              fontSize: responsive.h(1.35),
              color: AppColors.progressInactive,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTime(BuildContext context) {
    final ResponsiveRepo responsive = ResponsiveRepo(context);

    return Row(
      children: [
        Icon(
          Icons.calendar_month_outlined,
          size: responsive.w(3.5),
          color: AppColors.progressInactive,
        ),

        SizedBox(width: responsive.w(1.5)),

        Flexible(
          child: Text(
            date ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.whiteSmall(context).copyWith(
              fontSize: responsive.h(1.25),
              color: AppColors.progressInactive,
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsive.w(1.5)),
          child: Text(
            '•',
            style: AppTextStyles.whiteSmall(context).copyWith(
              fontSize: responsive.h(1.25),
              color: AppColors.progressInactive,
            ),
          ),
        ),

        Flexible(
          child: Text(
            time ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.whiteSmall(context).copyWith(
              fontSize: responsive.h(1.25),
              color: AppColors.progressInactive,
            ),
          ),
        ),
      ],
    );
  }
}
