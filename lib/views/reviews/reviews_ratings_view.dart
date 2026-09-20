import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/widgets/header/header.dart';

import '../../controllers/reviews_ratings_controller.dart';
import '../../models/ride_model.dart';
import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text.dart';
import '../../utilis/app_text_styles.dart';
import '../../widgets/app_icon_button_widget.dart';

class ReviewsRatingsView extends GetView<ReviewsRatingsController> {
  const ReviewsRatingsView({super.key});

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              showDescription: true,
              description: AppText.reviewsRatingsSubtitle,
              responsive: responsive,
              title: AppText.reviews,
              subtitle: AppText.ratings,
              canPop: true,
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  );
                }

                final error = controller.errorMessage.value;
                if (error != null) {
                  return _ErrorState(
                    message: error,
                    onRetry: controller.retry,
                    responsive: responsive,
                  );
                }

                if (controller.reviews.isEmpty) {
                  return _EmptyState(responsive: responsive);
                }

                final rides = controller.filteredReviews;
                final itemCount = 2 + (rides.isEmpty ? 1 : rides.length);

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    responsive.w(4),
                    responsive.h(1),
                    responsive.w(4),
                    responsive.h(2),
                  ),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _SummaryCard(
                        average: controller.formattedAverage,
                        filledStars: controller.averageRating.round().clamp(
                          0,
                          5,
                        ),
                        reviewCount: controller.reviewCount,
                        starCounts: controller.starCounts,
                        responsive: responsive,
                      );
                    }

                    if (index == 1) {
                      return Padding(
                        padding: EdgeInsets.only(
                          top: responsive.h(2),
                          bottom: responsive.h(1.5),
                        ),
                        child: _StarFilterBar(
                          selected: controller.selectedFilter.value,
                          onChanged: controller.selectFilter,
                        ),
                      );
                    }

                    if (rides.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.only(top: responsive.h(6)),
                        child: Center(
                          child: Text(
                            'No reviews for this rating',
                            style: AppTextStyles.whiteSmall(context).copyWith(
                              color: AppColors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      );
                    }

                    final ride = rides[index - 2];
                    return _ReviewCard(
                      ride: ride,
                      dateLabel: _dateLabel(ride),
                      onTap: () => controller.openDetail(ride),
                      responsive: responsive,
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildHeader(BuildContext context, ResponsiveRepo responsive) {
  //   return Padding(
  //     padding: EdgeInsets.only(
  //       left: responsive.w(2),
  //       right: responsive.w(4),
  //       top: responsive.h(1),
  //       bottom: responsive.h(1),
  //     ),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         AppIconButtonWidget(
  //           icon: Icons.arrow_back,
  //           onPressed: () => Get.back(),
  //           backgroundColor: AppColors.primaryGreen,
  //           iconColor: AppColors.black,
  //           width: responsive.w(10),
  //           height: responsive.h(5),
  //           top: responsive.h(2),
  //           left: responsive.w(4),
  //           borderRadius: responsive.w(3),
  //         ),
  //         SizedBox(width: responsive.w(5)),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               RichText(
  //                 text: TextSpan(
  //                   children: [
  //                     TextSpan(
  //                       text: AppText.reviews,
  //                       style: AppTextStyles.large(
  //                         context,
  //                       ).copyWith(color: AppColors.white),
  //                     ),
  //                     TextSpan(
  //                       text: AppText.ratings,
  //                       style: AppTextStyles.large(
  //                         context,
  //                       ).copyWith(color: AppColors.primaryGreen),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               SizedBox(height: responsive.h(0.2)),
  //               Text(
  //                 AppText.reviewsRatingsSubtitle,
  //                 maxLines: 2,
  //                 overflow: TextOverflow.ellipsis,
  //                 style: AppTextStyles.small(context).copyWith(
  //                   fontSize: responsive.h(1.4),
  //                   color: AppColors.white.withValues(alpha: 0.55),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  String _dateLabel(RideModel ride) {
    final when = ride.ratedAt ?? ride.completedAt ?? ride.updatedAt;
    if (when == null) return '—';
    return _formatDate(when);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.average,
    required this.filledStars,
    required this.reviewCount,
    required this.starCounts,
    required this.responsive,
  });

  final String average;
  final int filledStars;
  final int reviewCount;
  final Map<int, int> starCounts;
  final ResponsiveRepo responsive;

  @override
  Widget build(BuildContext context) {
    final maxCount = starCounts.values.fold<int>(
      0,
      (current, value) => value > current ? value : current,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.w(4)),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(responsive.w(4)),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                average,
                style: AppTextStyles.large(context).copyWith(
                  color: AppColors.primaryGreen,
                  fontSize: responsive.h(4.2),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: responsive.w(3)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        final filled = index < filledStars;
                        return Padding(
                          padding: EdgeInsets.only(right: responsive.w(0.6)),
                          child: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: filled
                                ? AppColors.primaryGreen
                                : AppColors.white.withValues(alpha: 0.28),
                            size: responsive.w(5.2),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: responsive.h(0.4)),
                    Text(
                      reviewCount == 1 ? '1 review' : '$reviewCount reviews',
                      style: AppTextStyles.whiteSmall(context).copyWith(
                        color: AppColors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.h(2)),
          ...List.generate(5, (index) {
            final star = 5 - index;
            final count = starCounts[star] ?? 0;
            final fraction = maxCount == 0 ? 0.0 : count / maxCount;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == 4 ? 0 : responsive.h(0.7),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: responsive.w(6),
                    child: Text(
                      '$star',
                      style: AppTextStyles.whiteSmall(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    Icons.star_rounded,
                    color: AppColors.primaryGreen,
                    size: responsive.w(3.6),
                  ),
                  SizedBox(width: responsive.w(2)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: responsive.h(0.8),
                        backgroundColor: AppColors.white.withValues(
                          alpha: 0.08,
                        ),
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.w(2)),
                  SizedBox(
                    width: responsive.w(8),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.whiteSmall(context).copyWith(
                        color: AppColors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StarFilterBar extends StatelessWidget {
  const _StarFilterBar({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);
    final labels = <int, String>{
      0: 'All',
      5: '5 ★',
      4: '4 ★',
      3: '3 ★',
      2: '2 ★',
      1: '1 ★',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.entries.map((entry) {
          final isSelected = selected == entry.key;
          return Padding(
            padding: EdgeInsets.only(right: responsive.w(2)),
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: Container(
                height: responsive.h(4.4),
                padding: EdgeInsets.symmetric(horizontal: responsive.w(4)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  entry.value,
                  style: AppTextStyles.whiteSmall(context).copyWith(
                    color: isSelected ? AppColors.black : AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.ride,
    required this.dateLabel,
    required this.onTap,
    required this.responsive,
  });

  final RideModel ride;
  final String dateLabel;
  final VoidCallback onTap;
  final ResponsiveRepo responsive;

  @override
  Widget build(BuildContext context) {
    final passenger = ride.customerName.trim().isEmpty
        ? 'Passenger'
        : ride.customerName.trim();
    final initial = passenger.isEmpty ? 'P' : passenger[0].toUpperCase();
    final rating = ride.riderRating ?? 0;
    final pickup = ride.pickupLocation.trim().isEmpty
        ? 'Pickup'
        : ride.pickupLocation.trim();
    final dropoff = ride.dropoffLocation.trim().isEmpty
        ? 'Drop-off'
        : ride.dropoffLocation.trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: responsive.h(1.5)),
        padding: EdgeInsets.all(responsive.w(3.5)),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(responsive.w(4)),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.w(2.2),
                vertical: responsive.h(0.28),
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(responsive.w(1.5)),
              ),
              child: Text(
                ride.isFromReservation ? AppText.reservation : 'Ride',
                style: AppTextStyles.whiteSmall(context).copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: responsive.h(1.2),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            SizedBox(height: responsive.h(1)),
            Row(
              children: [
                Container(
                  width: responsive.w(11),
                  height: responsive.w(11),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryGreen,
                  ),
                  child: Text(
                    initial,
                    style: AppTextStyles.small(context).copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: responsive.h(2),
                    ),
                  ),
                ),
                SizedBox(width: responsive.w(3)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passenger,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.whiteMedium(context).copyWith(
                          fontSize: responsive.h(1.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: responsive.h(0.3)),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            final filled = index < rating;
                            return Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: filled
                                  ? AppColors.primaryGreen
                                  : AppColors.white.withValues(alpha: 0.28),
                              size: responsive.w(4.2),
                            );
                          }),
                          SizedBox(width: responsive.w(1.5)),
                          Text(
                            dateLabel,
                            style: AppTextStyles.whiteSmall(context).copyWith(
                              fontSize: responsive.h(1.35),
                              color: AppColors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.white.withValues(alpha: 0.35),
                  size: responsive.w(6),
                ),
              ],
            ),
            SizedBox(height: responsive.h(1.4)),
            Text(
              '$pickup  →  $dropoff',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.whiteSmall(
                context,
              ).copyWith(color: AppColors.white.withValues(alpha: 0.62)),
            ),
            if (ride.hasRiderReview) ...[
              SizedBox(height: responsive.h(1)),
              Text(
                ride.riderReview,
                style: AppTextStyles.whiteSmall(context).copyWith(height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.responsive});

  final ResponsiveRepo responsive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: responsive.w(10)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_outline_rounded,
              color: AppColors.white.withValues(alpha: 0.35),
              size: responsive.w(16),
            ),
            SizedBox(height: responsive.h(2)),
            Text('No ratings yet', style: AppTextStyles.whiteMedium(context)),
            SizedBox(height: responsive.h(0.8)),
            Text(
              'When passengers rate your completed rides, they will show up here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.whiteSmall(
                context,
              ).copyWith(color: AppColors.white.withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.responsive,
  });

  final String message;
  final VoidCallback onRetry;
  final ResponsiveRepo responsive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: responsive.w(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.whiteSmall(context),
            ),
            SizedBox(height: responsive.h(2)),
            TextButton(
              onPressed: onRetry,
              child: Text(
                AppText.retry,
                style: AppTextStyles.small(context).copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
