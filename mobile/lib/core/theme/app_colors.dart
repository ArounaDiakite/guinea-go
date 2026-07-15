import 'package:flutter/material.dart';

/// Guinea Go brand palette.
///
/// Built around three West African-rooted hues instead of a default
/// Material blue: a warm terracotta (laterite roads, movement, the
/// energy of departure), a deep emerald (Fouta Djallon highlands,
/// trust, arrival/confirmation) and a savane gold used sparingly for
/// ratings, badges and highlights. Neutrals are warm off-whites/
/// charcoals rather than cold grays, to keep the whole palette feeling
/// coherent rather than "brand color on top of generic gray UI".
class AppColors {
  AppColors._();

  // Primary - "Terracotta Route"
  static const Color primary = Color(0xFFE15A2B);
  static const Color primaryDark = Color(0xFFC24A20);
  static const Color primaryLight = Color(0xFFFDEBE2);

  // Secondary - "Fouta Emerald"
  static const Color secondary = Color(0xFF0E7C5A);
  static const Color secondaryDark = Color(0xFF0B6248);
  static const Color secondaryLight = Color(0xFFE1F5EC);

  // Accent - "Savane Gold" (ratings, badges, highlights - sparingly)
  static const Color accent = Color(0xFFF0A83C);
  static const Color accentDark = Color(0xFFD68F26);
  static const Color accentLight = Color(0xFFFDF1DD);

  // Neutrals - warm, not cold gray
  static const Color background = Color(0xFFFBF8F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF2ECE4);
  static const Color border = Color(0xFFE9E1D8);

  static const Color textPrimary = Color(0xFF241C15);
  static const Color textSecondary = Color(0xFF6E6055);
  static const Color textHint = Color(0xFFA69A8E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  // Semantic - error is a distinct crimson, never confusable with the
  // terracotta primary; success/warning intentionally reuse secondary/
  // accent so status colors stay inside the brand palette.
  static const Color success = secondary;
  static const Color warning = accent;
  static const Color error = Color(0xFFD64545);
  static const Color errorLight = Color(0xFFFBE7E5);
  static const Color info = Color(0xFF3E7C93);
  static const Color infoLight = Color(0xFFE4F0F4);
}
