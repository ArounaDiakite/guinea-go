import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Two-typeface pairing instead of a single default font, so the
/// title/body/caption hierarchy comes from real typographic contrast,
/// not just size:
/// - Poppins (geometric, warm, has personality) for headings/titles.
/// - Inter (neutral, optimized for legibility at small sizes) for
///   body copy, labels and captions.
///
/// Both are bundled locally (assets/fonts/, declared in pubspec.yaml)
/// rather than fetched at runtime via google_fonts - this market can't
/// assume reliable connectivity for a CDN font fetch on first launch,
/// and a bundled font keeps widget tests deterministic too.
class AppTypography {
  AppTypography._();

  static TextTheme get textTheme => TextTheme(
        // Hero / splash titles
        displayLarge: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 32,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        // Screen titles
        headlineMedium: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        // Section headers
        titleLarge: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        // Card titles, list item titles
        titleMedium: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        titleSmall: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        // Primary body text
        bodyLarge: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        // Secondary body text
        bodyMedium: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        // Captions, hints, timestamps
        bodySmall: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        // Button labels
        labelLarge: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: AppColors.textOnPrimary,
        ),
        labelMedium: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        labelSmall: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: AppColors.textHint,
        ),
      );
}
