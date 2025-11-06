import 'package:flutter/material.dart';

/// Unified Design System for Student Pages
/// Based on StudentProfilePage design
class StudentTheme {
  // === COLORS ===

  /// Primary brand color - Deep Purple
  static const Color primaryColor = Color(0xFF422F5D);

  /// Secondary accent color - Orange
  static const Color secondaryColor = Color(0xFFF99D46);

  /// Accent color - Pink
  static const Color accentColor = Color(0xFFD64483);

  /// Page background color - Light grey
  static const Color backgroundColor = Color(0xFFF8F9FA);

  /// Main text color - Dark grey
  static const Color textColor = Color(0xFF1E1E1E);

  /// Card background color - White
  static const Color cardColor = Color(0xFFFFFFFF);

  /// Surface color - Light grey (for subtle backgrounds)
  static const Color surfaceColor = Color(0xFFF1F3F5);

  /// Divider color
  static const Color dividerColor = Color(0xFFE9ECEF);

  // === TEXT STYLES ===

  /// Large page title (26-28px)
  static const TextStyle pageTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textColor,
    height: 1.2,
  );

  /// Section title (20-22px)
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textColor,
  );

  /// Card title (18-20px)
  static const TextStyle cardTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textColor,
    height: 1.2,
  );

  /// Subtitle (16-18px)
  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textColor,
  );

  /// Body text (14-15px)
  static const TextStyle bodyText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: textColor,
    height: 1.5,
  );

  /// Caption text (12-13px)
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Color(0xFF6C757D),
  );

  /// Label text (small, grey)
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Color(0xFF6C757D),
  );

  // === SPACING ===

  /// Extra small spacing (4px)
  static const double spaceXS = 4;

  /// Small spacing (8px)
  static const double spaceSM = 8;

  /// Medium spacing (12px)
  static const double spaceMD = 12;

  /// Large spacing (16px)
  static const double spaceLG = 16;

  /// Extra large spacing (20px)
  static const double spaceXL = 20;

  /// Extra extra large spacing (24px)
  static const double spaceXXL = 24;

  /// Huge spacing (32px)
  static const double spaceHuge = 32;

  // === BORDER RADIUS ===

  /// Small radius (8px)
  static const double radiusSM = 8;

  /// Medium radius (12px)
  static const double radiusMD = 12;

  /// Large radius (16px)
  static const double radiusLG = 16;

  /// Extra large radius (20px)
  static const double radiusXL = 20;

  /// Round radius (24px+)
  static const double radiusRound = 24;

  // === CARD DECORATIONS ===

  /// Standard card decoration (white background, subtle border)
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(radiusLG),
    border: Border.all(
      color: const Color(0xFFE9ECEF),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  /// Elevated card decoration (more prominent shadow)
  static BoxDecoration elevatedCardDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(radiusXL),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  /// Surface decoration (subtle background)
  static BoxDecoration surfaceDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(radiusMD),
    border: Border.all(
      color: dividerColor,
      width: 1,
    ),
  );

  /// Gradient decoration (secondary to accent)
  static BoxDecoration gradientDecoration = BoxDecoration(
    gradient: const LinearGradient(
      colors: [secondaryColor, accentColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radiusLG),
  );

  // === BUTTON STYLES ===

  /// Primary button style
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMD),
    ),
    elevation: 0,
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  );

  /// Secondary button style (outlined)
  static ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: const BorderSide(color: primaryColor, width: 1.5),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMD),
    ),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  );

  /// Gradient button decoration
  static BoxDecoration gradientButtonDecoration = BoxDecoration(
    gradient: const LinearGradient(
      colors: [secondaryColor, accentColor],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    borderRadius: BorderRadius.circular(radiusMD),
  );

  // === CHIP/BADGE STYLES ===

  /// Primary chip decoration
  static BoxDecoration primaryChipDecoration = BoxDecoration(
    color: primaryColor.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(radiusSM),
    border: Border.all(
      color: primaryColor.withValues(alpha: 0.2),
    ),
  );

  /// Secondary chip decoration
  static BoxDecoration secondaryChipDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(radiusSM),
    border: Border.all(color: dividerColor),
  );

  /// Info chip decoration (for location, mode, etc)
  static BoxDecoration infoChipDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(radiusSM),
    border: Border.all(color: dividerColor),
  );

  // === HELPER METHODS ===

  /// Create a color with opacity
  static Color withOpacity(Color color, double opacity) {
    final double normalized = opacity.clamp(0.0, 1.0);
    return color.withValues(alpha: normalized);
  }

  /// Get text style with custom color
  static TextStyle textStyleWithColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Icon box decoration (for info tiles)
  static BoxDecoration iconBoxDecoration = BoxDecoration(
    color: primaryColor.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(radiusMD),
  );

  /// Success color
  static const Color successColor = Color(0xFF28A745);

  /// Warning color
  static const Color warningColor = Color(0xFFFFC107);

  /// Error color
  static const Color errorColor = Color(0xFFDC3545);

  /// Info color
  static const Color infoColor = Color(0xFF17A2B8);
}
