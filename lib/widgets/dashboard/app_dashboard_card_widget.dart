import 'package:flutter/material.dart';

import '../../responsiveness/responsive_repo.dart';
import '../../utilis/app_colors.dart';
import '../../utilis/app_text_styles.dart';

class AppDashboardCardWidget extends StatelessWidget {
  // User
  final String? userName;

  // Price
  final String? price;

  // Distance / Time
  final String? distance;
  final String? time;

  // Route
  final String? routeTitle;
  final String? routeSubtitle;

  // Icons
  final IconData? locationIcon;
  final IconData? timeIcon;

  // Colors
  final Color? startColor;
  final Color? endColor;
  final Color? textColor;
  final Color? secondaryTextColor;
  final Color? iconColor;

  // Size
  final double? width;
  final double? height;

  // Margin
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  // Card
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;

  // Actions
  final VoidCallback? onTap;
  final VoidCallback? onSwipe;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  /// Stable key for [Dismissible] so stream rebuilds do not remount mid-swipe.
  final Key? dismissibleKey;

  // Swipe hint
  final bool showSwipeHint;

  const AppDashboardCardWidget({
    super.key,

    this.userName,
    this.price,

    this.distance,
    this.time,

    this.routeTitle,
    this.routeSubtitle,

    this.locationIcon,
    this.timeIcon,

    this.startColor,
    this.endColor,
    this.textColor,
    this.secondaryTextColor,
    this.iconColor,

    this.width,
    this.height,

    this.top,
    this.left,
    this.right,
    this.bottom,

    this.borderRadius,
    this.padding,

    this.onTap,
    this.onSwipe,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.dismissibleKey,

    // Default true
    this.showSwipeHint = true,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveRepo(context);

    final Color mainTextColor =
        textColor ?? AppColors.white;

    final Color secondaryColor =
        secondaryTextColor ?? AppColors.white;

    final Color iconsColor =
        iconColor ?? AppColors.white;

    final BorderRadius radius = BorderRadius.circular(
      borderRadius ?? responsive.w(4),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: top ?? 0,
        left: left ?? 0,
        right: right ?? 0,
        bottom: bottom ?? 0,
      ),

      child: Stack(
        clipBehavior: Clip.none,
        children: [

          // ==========================================
          // GREEN SWIPE HINT
          // ==========================================

          if (showSwipeHint)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Container(
                width: responsive.w(6),

                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,

                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                      responsive.w(4),
                    ),
                    bottomLeft: Radius.circular(
                      responsive.w(4),
                    ),
                  ),
                ),
              ),
            ),

          // ==========================================
          // ACTUAL CARD
          // ==========================================

          Padding(
            padding: EdgeInsets.only(
              right: showSwipeHint
                  ? responsive.w(12)
                  : 0,
            ),

            child: Dismissible(
              key: dismissibleKey ?? UniqueKey(),

              direction: DismissDirection.horizontal,

              dismissThresholds: const {
                DismissDirection.startToEnd: 0.30,
                DismissDirection.endToStart: 0.30,
              },

              onDismissed: (direction) {
                if (direction == DismissDirection.startToEnd) {
                  (onSwipeRight ?? onSwipe)?.call();
                } else if (direction == DismissDirection.endToStart) {
                  (onSwipeLeft ?? onSwipe)?.call();
                } else {
                  onSwipe?.call();
                }
              },

              // ========================================
              // SWIPE BACKGROUND - RIGHT (cancel)
              // ========================================

              background: Container(
                decoration: BoxDecoration(
                  color: AppColors.secondaryRed,
                  borderRadius: radius,
                ),

                alignment: Alignment.centerLeft,

                padding: EdgeInsets.only(
                  left: responsive.w(5),
                ),

                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.white,
                  size: responsive.w(6),
                ),
              ),

              // ========================================
              // SWIPE BACKGROUND - LEFT (complete)
              // ========================================

              secondaryBackground: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: radius,
                ),

                alignment: Alignment.centerRight,

                padding: EdgeInsets.only(
                  right: responsive.w(5),
                ),

                child: Icon(
                  Icons.check_rounded,
                  color: AppColors.white,
                  size: responsive.w(6),
                ),
              ),

              // ========================================
              // CARD
              // ========================================

              child: GestureDetector(
                onTap: onTap,

                child: Container(
                  width: width ?? double.infinity,
                  height: height,

                  padding: padding ??
                      EdgeInsets.symmetric(
                        horizontal: responsive.w(5),
                        vertical: responsive.h(2),
                      ),

                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        startColor ??
                            AppColors.secondaryRed,
                        endColor ??
                            const Color(0xFF9E161C),
                      ],
                    ),

                    borderRadius: radius,
                  ),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [

                      // ==================================
                      // USER NAME + PRICE
                      // ==================================

                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [

                          if (userName != null)
                            Expanded(
                              child: Text(
                                userName!,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style:
                                AppTextStyles.medium(
                                  context,
                                ).copyWith(
                                  color: mainTextColor,
                                  fontWeight:
                                  FontWeight.w700,
                                ),
                              ),
                            ),

                          if (price != null)
                            Text(
                              price!,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style:
                              AppTextStyles.medium(
                                context,
                              ).copyWith(
                                color: mainTextColor,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                        ],
                      ),

                      // ==================================
                      // DISTANCE + TIME
                      // ==================================

                      if (distance != null ||
                          time != null)
                        Padding(
                          padding: EdgeInsets.only(
                            top: responsive.h(1),
                          ),

                          child: Row(
                            children: [

                              if (distance != null)
                                Row(
                                  mainAxisSize:
                                  MainAxisSize.min,
                                  children: [

                                    Icon(
                                      locationIcon ??
                                          Icons
                                              .location_on_outlined,
                                      color: iconsColor,
                                      size:
                                      responsive.w(3.5),
                                    ),

                                    SizedBox(
                                      width:
                                      responsive.w(1),
                                    ),

                                    Text(
                                      distance!,
                                      style:
                                      AppTextStyles
                                          .small(
                                        context,
                                      ).copyWith(
                                        color:
                                        secondaryColor,
                                        fontWeight:
                                        FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),

                              if (time != null) ...[
                                SizedBox(
                                  width:
                                  responsive.w(4),
                                ),

                                Row(
                                  mainAxisSize:
                                  MainAxisSize.min,
                                  children: [

                                    Icon(
                                      timeIcon ??
                                          Icons
                                              .access_time_rounded,
                                      color: iconsColor,
                                      size:
                                      responsive.w(3.5),
                                    ),

                                    SizedBox(
                                      width:
                                      responsive.w(1),
                                    ),

                                    Text(
                                      time!,
                                      style:
                                      AppTextStyles
                                          .small(
                                        context,
                                      ).copyWith(
                                        color:
                                        secondaryColor,
                                        fontWeight:
                                        FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                      // ==================================
                      // ROUTE TITLE
                      // ==================================

                      if (routeTitle != null)
                        Padding(
                          padding: EdgeInsets.only(
                            top: responsive.h(1),
                          ),

                          child: Text(
                            routeTitle!,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style:
                            AppTextStyles.medium(
                              context,
                            ).copyWith(
                              color: mainTextColor,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ),

                      // ==================================
                      // ROUTE SUBTITLE
                      // ==================================

                      if (routeSubtitle != null)
                        Padding(
                          padding: EdgeInsets.only(
                            top: responsive.h(0.4),
                          ),

                          child: Text(
                            routeSubtitle!,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style:
                            AppTextStyles.small(
                              context,
                            ).copyWith(
                              color: secondaryColor,
                              fontWeight:
                              FontWeight.w400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
