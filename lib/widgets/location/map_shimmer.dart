import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Full-area shimmer placeholder used when Google Map cannot load.
class MapShimmer extends StatelessWidget {
  const MapShimmer({super.key});

  static const Color _land = Color(0xFF242F3E);
  static const Color _base = Color(0xFF2A3544);
  static const Color _highlight = Color(0xFF3D4A5C);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _land,
      child: Shimmer.fromColors(
        baseColor: _base,
        highlightColor: _highlight,
        period: const Duration(milliseconds: 1400),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: _land),
            Positioned(
              top: 120,
              left: 0,
              right: 40,
              child: _bar(height: 10, radius: 4),
            ),
            Positioned(
              top: 200,
              left: 48,
              right: 0,
              child: _bar(height: 10, radius: 4),
            ),
            Positioned(
              top: 280,
              left: 0,
              right: 80,
              child: _bar(height: 10, radius: 4),
            ),
            Positioned(
              top: 160,
              left: 72,
              child: _bar(width: 10, height: 180, radius: 4),
            ),
            Positioned(
              top: 240,
              right: 64,
              child: _bar(width: 10, height: 160, radius: 4),
            ),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _base,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white24,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white38,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bar({
    double? width,
    double height = 10,
    double radius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
