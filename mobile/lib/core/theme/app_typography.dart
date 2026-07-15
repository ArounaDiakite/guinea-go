import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Two-typeface pairing instead of a single default font, so the
/// title/body/caption hierarchy comes from real typographic contrast,
/// not just size:
/// - Poppins (geometric, warm, has personality) for headings/titles.
/// - Inter (neutral, optimized for legibility at small sizes) for
///   body copy, labels and captions.
class AppTypography {
  AppTypography._();

  static TextTheme get textTheme => TextTheme(
        // Hero / splash titles
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        // Screen titles
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        // Section headers
        titleLarge: GoogleFonts.poppins(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        // Card titles, list item titles
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        // Primary body text
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        // Secondary body text
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        // Captions, hints, timestamps
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        // Button labels
        labelLarge: GoogleFonts.inter(
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: AppColors.textOnPrimary,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: AppColors.textHint,
        ),
      );
}
