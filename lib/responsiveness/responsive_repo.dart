import 'package:flutter/material.dart';

class ResponsiveRepo {
  final BuildContext context;

  ResponsiveRepo(this.context);

  // Screen Width
  double get width => MediaQuery.of(context).size.width;

  // Screen Height
  double get height => MediaQuery.of(context).size.height;

  // Responsive Width
  double w(double value) {
    return width * (value / 100);
  }

  // Responsive Height
  double h(double value) {
    return height * (value / 100);
  }

  // Responsive Font Size
  double font(double value) {
    return width * (value / 100);
  }

  // Device Type
  bool get isMobile => width < 600;

  bool get isTablet => width >= 600 && width < 1024;

  bool get isDesktop => width >= 1024;
}