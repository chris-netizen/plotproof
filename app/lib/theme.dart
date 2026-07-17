/// PlotProof design system.
///
/// One place for colour, type and component styling so the whole app
/// reads as a single, trustworthy, "land-registry-grade" product.
/// Direction: light, clean, generous whitespace, one strong green accent,
/// with loud semantic states for the two moments that matter — an
/// all-clear plot (green) and a conflicting plot (red).
library theme;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand — a refined, official forest green (trust + "verified").
  static const brand = Color(0xFF0F5A34);
  static const brandBright = Color(0xFF157A46);
  static const brandTint = Color(0xFFE7F3EC); // soft green surface

  // Neutrals.
  static const background = Color(0xFFF5F7F4); // very light green-grey
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF10231A); // near-black, green-tinted
  static const inkSoft = Color(0xFF5B6B61); // secondary text
  static const border = Color(0xFFE2E8E2);

  // Semantic states.
  static const success = Color(0xFF15803D);
  static const successBg = Color(0xFFDCF5E4);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFDE7E7);
  static const dangerBorder = Color(0xFFF2B8B8);
  static const warning = Color(0xFFB45309);
  static const warningBg = Color(0xFFFBF0D9);
}

/// Rounded-corner radii used across the app.
class AppRadii {
  static const card = 18.0;
  static const control = 14.0;
  static const pill = 999.0;
}

ThemeData buildPlotProofTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    primary: AppColors.brand,
    surface: AppColors.surface,
    // ignore: deprecated_member_use
    background: AppColors.background,
    error: AppColors.danger,
  );

  final baseText = GoogleFonts.interTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,

    textTheme: baseText.copyWith(
      displaySmall: baseText.displaySmall?.copyWith(
          fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5),
      headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5),
      headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.3),
      titleLarge: baseText.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
      titleMedium: baseText.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink),
      bodyLarge: baseText.bodyLarge?.copyWith(color: AppColors.ink, height: 1.4),
      bodyMedium:
          baseText.bodyMedium?.copyWith(color: AppColors.inkSoft, height: 1.45),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.ink,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control)),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.border),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.brandTint,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.brand
                : AppColors.inkSoft,
          )),
    ),

    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.brandTint,
      side: BorderSide.none,
    ),
  );
}

/// A soft drop shadow for cards that need slight lift (hero cards).
const kSoftShadow = [
  BoxShadow(
    color: Color(0x14101828),
    blurRadius: 24,
    offset: Offset(0, 8),
  ),
];
