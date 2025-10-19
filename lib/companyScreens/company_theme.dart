import 'package:flutter/material.dart';

class CompanyColors {
  static const Color primary = Color(0xFF422F5D);
  static const Color secondary = Color(0xFFD64483);
  static const Color accent = Color(0xFFF99D46);
  static const Color background = Color(0xFFF7F4F0);
  static const Color surface = Color(0xFFFEFEFE);
  static const Color muted = Color(0xFF5F6368);

  static const Gradient heroGradient = LinearGradient(
    colors: [Color(0xFF422F5D), Color(0xFFD64483)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class CompanySpacing {
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20));
  static const double cardElevation = 4.0;

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1400) {
      return const EdgeInsets.symmetric(horizontal: 180, vertical: 32);
    }
    if (width >= 1100) {
      return const EdgeInsets.symmetric(horizontal: 140, vertical: 30);
    }
    if (width >= 900) {
      return const EdgeInsets.symmetric(horizontal: 96, vertical: 28);
    }
    if (width >= 600) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    }
    return const EdgeInsets.symmetric(horizontal: 20, vertical: 20);
  }

  static double maxContentWidth(double availableWidth) {
    if (availableWidth >= 1400) return 1080;
    if (availableWidth >= 1100) return 960;
    if (availableWidth >= 900) return 840;
    if (availableWidth >= 600) return 640;
    return availableWidth;
  }

  static double responsiveGap(double width) {
    if (width >= 900) return 24;
    if (width >= 600) return 20;
    return 16;
  }
}

class CompanyDecorations {
  static const BoxDecoration pageBackground = BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFFF8F5FF), Color(0xFFFDF7F9)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}
