import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Rich modern dark palette
  static const Color bgDark = Color(0xFF0A0F1D);
  static const Color surfaceDark = Color(0xFF131B2E);
  static const Color surfaceElevated = Color(0xFF1E293B);
  static const Color surfaceCard = Color(0xFF172033);
  static const Color border = Color(0xFF2E3D5B);
  static const Color borderLight = Color(0xFF38496E);

  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryGradientStart = Color(0xFF2563EB);
  static const Color primaryGradientEnd = Color(0xFF4F46E5);

  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFF34D399);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFBBF24);
  static const Color rose = Color(0xFFEF4444);
  static const Color roseLight = Color(0xFFF87171);
  static const Color indigo = Color(0xFF6366F1);
  static const Color purple = Color(0xFF8B5CF6);

  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDim = Color(0xFF64748B);

  static ThemeData get darkTheme {
    final base = ThemeData(
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primary,
      dividerColor: border,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: emerald,
        surface: surfaceDark,
        error: rose,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textMain,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDark.withValues(alpha: 0.85),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textMain,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textMain,
          side: const BorderSide(color: borderLight),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
