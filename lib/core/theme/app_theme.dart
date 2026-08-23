import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colori Premium per un'esperienza "Ensemble Analytics"
  static const Color primaryColor = Color(0xFF6C63FF); // Viola moderno / tech
  static const Color accentColor = Color(0xFFFF6584); // Rosa scuro / Rosso per l'azione e per i numeri "caldi"
  static const Color backgroundColor = Color(0xFF0F172A); // Slate scuro profondo per lo sfondo
  static const Color surfaceColor = Color(0xFF1E293B); // Slate leggermente più chiaro per card
  static const Color textPrimary = Color(0xFFF8FAFC); // Bianco sporco per il testo principale
  static const Color textSecondary = Color(0xFF94A3B8); // Grigio per il testo secondario
  static const Color goldPro = Color(0xFFFFD700); // Colore oro per elementi Pro / Premium

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        background: backgroundColor,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme.copyWith(
          displayLarge: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          displayMedium: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          bodyLarge: const TextStyle(color: textPrimary),
          bodyMedium: const TextStyle(color: textSecondary),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: const CardThemeData(
        color: surfaceColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
