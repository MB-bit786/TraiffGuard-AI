import 'package:flutter/material.dart';

class TariffColors {
  TariffColors._();

  // Primaries
  static const Color navyDeep = Color(0xFF0A1628);
  static const Color navyMid = Color(0xFF112240);
  static const Color navySurface = Color(0xFF1A2F52);
  static const Color navyElevated = Color(0xFF1E3A63);

  // Accents
  static const Color greenVerified = Color(0xFF2ECC71);
  static const Color greenVerifiedSoft = Color(0xFF1A3D2B);
  static const Color greenVerifiedBorder = Color(0xFF27AE60);

  static const Color amberPending = Color(0xFFFFB300);
  static const Color amberPendingSoft = Color(0xFF3D2E00);
  static const Color amberPendingBorder = Color(0xFFFF8F00);

  static const Color crimsonRisk = Color(0xFFE53935);
  static const Color crimsonRiskSoft = Color(0xFF3D0A0A);
  static const Color crimsonRiskBorder = Color(0xFFC62828);

  // Text
  static const Color textPrimary = Color(0xFFECF0F1);
  static const Color textSecondary = Color(0xFF8FA3C0);
  static const Color textMuted = Color(0xFF4A6080);

  // Misc
  static const Color divider = Color(0xFF1E3A63);
  static const Color cardBorder = Color(0xFF1E3A63);
  static const Color onlineGlow = Color(0xFF00E676);
  static const Color inputBorder = Color(0xFF2A4A7A);
  static const Color inputFocusBorder = Color(0xFFFFB300);

  // Semantic Helpers
  static Color background(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
  
  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? navySurface 
        : Colors.white;
  }

  static Color appBar(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? navyMid 
        : const Color(0xFF1565C0);
  }

  static Color card(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? navySurface 
        : Colors.white;
  }

  static Color text(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? textPrimary 
        : Colors.black87;
  }

  static Color mutedText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? textMuted 
        : Colors.black54;
  }

  static Color border(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? cardBorder 
        : Colors.grey[300]!;
  }
}
