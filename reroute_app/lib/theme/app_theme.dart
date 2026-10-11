import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Clean, professional, minimal light palette (Calm Tech / Slate & Indigo)
  static const Color bgLight = Color(0xFFF8FAFC);          // Slate 50 background
  static const Color surfaceWhite = Color(0xFFFFFFFF);     // Pure white surface
  static const Color surfaceCard = Color(0xFFFFFFFF);      // Clean card surface
  static const Color surfaceElevated = Color(0xFFF1F5F9);  // Slate 100 soft highlight
  static const Color surfaceSubtle = Color(0xFFF8FAFC);    // Subtlest backdrop

  // Clean borders & dividers
  static const Color border = Color(0xFFE2E8F0);           // Slate 200 border
  static const Color borderLight = Color(0xFFCBD5E1);      // Slate 300 crisp border
  static const Color borderFocus = Color(0xFF2563EB);      // Active focus border

  // Refined Primary & Accents
  static const Color primary = Color(0xFF2563EB);          // Royal Blue 600
  static const Color primaryHover = Color(0xFF1D4ED8);     // Deeper Blue 700
  static const Color primaryLight = Color(0xFF3B82F6);     // Bright Blue 500
  static const Color primarySoft = Color(0xFFEFF6FF);      // Blue 50 soft tint
  static const Color primaryGradientStart = Color(0xFF2563EB);
  static const Color primaryGradientEnd = Color(0xFF4F46E5);

  // Status & Semantic Colors (Refined & calibrated for light background)
  static const Color emerald = Color(0xFF059669);          // Emerald 600
  static const Color emeraldLight = Color(0xFF10B981);     // Emerald 500
  static const Color emeraldSoft = Color(0xFFECFDF5);      // Soft green background

  static const Color amber = Color(0xFFD97706);            // Amber 600
  static const Color amberLight = Color(0xFFF59E0B);       // Amber 500
  static const Color amberSoft = Color(0xFFFFFBEB);        // Soft amber background

  static const Color rose = Color(0xFFDC2626);             // Rose 600
  static const Color roseLight = Color(0xFFEF4444);        // Rose 500
  static const Color roseSoft = Color(0xFFFEF2F2);         // Soft red background

  static const Color indigo = Color(0xFF4F46E5);           // Indigo 600
  static const Color indigoSoft = Color(0xFFEEF2FF);       // Soft indigo background
  static const Color purple = Color(0xFF7C3AED);           // Violet 600
  static const Color purpleSoft = Color(0xFFF5F3FF);       // Soft purple background

  // Modern crisp typography colors (High legibility on white)
  static const Color textMain = Color(0xFF0F172A);          // Slate 900
  static const Color textSecondary = Color(0xFF334155);     // Slate 700
  static const Color textMuted = Color(0xFF64748B);         // Slate 500
  static const Color textDim = Color(0xFF94A3B8);           // Slate 400

  // Standard shadow configurations for minimal depth
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get shadowCard => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  // Professional minimal light theme definition
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: bgLight,
      primaryColor: primary,
      dividerColor: border,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: emerald,
        surface: surfaceWhite,
        error: rose,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textMain,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.06),
        centerTitle: false,
        iconTheme: const IconThemeData(color: textSecondary),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textMain,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textSecondary,
          backgroundColor: surfaceWhite,
          side: const BorderSide(color: border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: rose, width: 1),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        hintStyle: const TextStyle(color: textDim, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textMain,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Backward compatibility alias for darkTheme so nothing breaks during migration
  static ThemeData get darkTheme => lightTheme;
}
