import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/new_reservation_request_controller.dart';
import '../../models/reservation_model.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text_styles.dart';
import '../../widgets/app_icon_button_widget.dart';
import '../../widgets/buttons/app_button_widget.dart';
import '../../widgets/reservation/reservation_customer_card.dart';
import '../../widgets/reservation/reservation_detail_card.dart';
import '../../widgets/reservation/reservation_trip_card.dart';

class NewReservationRequestView
    extends GetView<NewReservationRequestController> {
  const NewReservationRequestView({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);
    final reservation = controller.reservation;

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, responsive),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.w(4),
                  vertical: responsive.h(1),
                ),
                child: Column(
                  children: [
                    AppReservationCustomerCardWidget(reservation: reservation),
                    SizedBox(height: responsive.h(2)),
                    AppReservationTripCardWidget(reservation: reservation),
                    SizedBox(height: responsive.h(2)),
                    AppReservationDetailsCardWidget(reservation: reservation),
                    SizedBox(height: responsive.h(2)),
                  ],
                ),
              ),
            ),
            _buildActions(context, responsive),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ResponsiveRepo responsive) {
    return Padding(
      padding: EdgeInsets.only(
        left: responsive.w(4),
        right: responsive.w(4),
        top: responsive.h(1),
        bottom: responsive.h(1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconButtonWidget(
            icon: Icons.arrow_back,
            onPressed: () => Get.back(),
            backgroundColor: AppColors.primaryGreen,
            iconColor: AppColors.black,
            width: responsive.w(10),
            height: responsive.h(5),
            top: responsive.h(2),
            left: responsive.w(4),
            borderRadius: responsive.w(3),
          ),
          SizedBox(width: responsive.w(2.5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    maxLines: 1,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Reservation ',
                          style: AppTextStyles.whiteMedium(context).copyWith(
                            color: AppColors.white,
                            fontSize: responsive.h(2.4),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'Request',
                          style: AppTextStyles.whiteMedium(context).copyWith(
                            color: AppColors.primaryGreen,
                            fontSize: responsive.h(2.4),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: responsive.h(0.3)),
                Text(
                  'A customer has booked a ride. Please accept or decline.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small(context).copyWith(
                    fontSize: responsive.h(1.4),
                    color: AppColors.white.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, ResponsiveRepo responsive) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.w(4),
        responsive.h(1),
        responsive.w(4),
        responsive.h(1.5),
      ),
      child: Obx(() {
        final action = controller.submittingAction.value;
        final accepting = action == ReservationSubmitAction.accept;
        final declining = action == ReservationSubmitAction.decline;
        final busy = accepting || declining;
        const declineColor = Color(0xFFFF3B4A);

        return Row(
          children: [
            Expanded(
              child: AppButtonWidget(
                text: 'Decline',
                onPressed: busy ? null : controller.decline,
                backgroundColor: AppColors.black,
                disabledBackgroundColor: Colors.grey.shade800,
                foregroundColor: AppColors.white,
                borderColor: declineColor,
                borderWidth: 1.2,
                borderRadius: responsive.w(3),
                showTrailingArrow: false,
                child: declining
                    ? _buildButtonLoader(
                        context,
                        responsive,
                        label: 'Declining…',
                        color: declineColor,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.close,
                            color: declineColor,
                            size: responsive.w(5),
                          ),
                          SizedBox(width: responsive.w(2)),
                          Text(
                            'Decline',
                            style: AppTextStyles.small(context).copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(width: responsive.w(3)),
            Expanded(
              child: AppButtonWidget(
                text: 'Accept',
                onPressed: busy ? null : controller.accept,
                backgroundColor: AppColors.dashboardAccent,
                disabledBackgroundColor:
                    AppColors.dashboardAccent.withValues(alpha: 0.55),
                foregroundColor: AppColors.black,
                borderRadius: responsive.w(3),
                showTrailingArrow: false,
                child: accepting
                    ? _buildButtonLoader(
                        context,
                        responsive,
                        label: 'Accepting…',
                        color: AppColors.black,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check,
                            color: AppColors.black,
                            size: responsive.w(5),
                          ),
                          SizedBox(width: responsive.w(2)),
                          Text(
                            'Accept',
                            style: AppTextStyles.small(context).copyWith(
                              color: AppColors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildButtonLoader(
    BuildContext context,
    ResponsiveRepo responsive, {
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: responsive.w(4.5),
          width: responsive.w(4.5),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            strokeCap: StrokeCap.round,
            color: color,
          ),
        ),
        SizedBox(width: responsive.w(2.5)),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.small(context).copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}


void openNewReservationRequest(ReservationModel reservation) {
  Get.to(
    () => const NewReservationRequestView(),
    binding: BindingsBuilder(() {
      Get.put(NewReservationRequestController(reservation: reservation));
    }),
  );
}
