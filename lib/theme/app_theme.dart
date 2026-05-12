import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // New Olive Dark Theme Colors
  static const Color background = Color(0xFF1A1C14);
  static const Color panelBackground = Color(0xFF2A2C22);
  static const Color accent = Color(0xFFD4C462);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9E9E9E);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        surface: panelBackground,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.outfit(color: textPrimary),
        bodyMedium: GoogleFonts.outfit(color: textSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: panelBackground,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
      ),
    );
  }
}
