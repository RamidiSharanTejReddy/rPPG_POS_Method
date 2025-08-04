import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF0033A1);
  static const Color secondaryBlue = Color(0xFF2B74FF);
  static const Color accentPink = Color(0xFFFF6B8B);
  static const Color cogniBlue = Color(0xFF0033A1);
  static const Color heartPink = Color(0xFFFF6B8B);
  static const Color background = Color(0xFFF5F7FA);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, secondaryBlue],
  );

  static const LinearGradient heartGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heartPink, Color(0xFFFF96AB)],
  );

  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w300,
    letterSpacing: 1.2,
    color: Colors.white,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w300,
    color: primaryBlue,
  );
}
