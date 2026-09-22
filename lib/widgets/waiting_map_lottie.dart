import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../utilis/app_colors.dart';

/// Full-screen waiting map animation that is torn down as soon as this
/// route is no longer current, so it cannot paint over the dashboard
/// during / after a back transition.
class WaitingMapLottie extends StatefulWidget {
  const WaitingMapLottie({super.key});

  @override
  State<WaitingMapLottie> createState() => _WaitingMapLottieState();
}

class _WaitingMapLottieState extends State<WaitingMapLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _routeAnimation;
  bool _show = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (!identical(animation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_onRouteStatus);
      _routeAnimation = animation;
      _routeAnimation?.addStatusListener(_onRouteStatus);
      if (animation != null &&
          (animation.status == AnimationStatus.reverse ||
              animation.status == AnimationStatus.dismissed)) {
        _show = false;
        _controller.stop();
      }
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      _hide();
    }
  }

  void _hide() {
    if (!_show) return;
    _controller.stop();
    _show = false;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hide =
        !_show || !(ModalRoute.of(context)?.isCurrent ?? true);
    if (hide) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return const SizedBox.expand(
        child: ColoredBox(color: AppColors.dashboardBackground),
      );
    }

    return SizedBox.expand(
      child: ClipRect(
        child: Lottie.asset(
          'assets/lottie/map_lottie.json',
          controller: _controller,
          onLoaded: (composition) {
            if (!_show || !mounted) return;
            _controller
              ..duration = composition.duration
              ..repeat();
          },
          fit: BoxFit.cover,
          addRepaintBoundary: true,
        ),
      ),
    );
  }
}
