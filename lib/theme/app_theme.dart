import 'package:flutter/material.dart';

class AppColors {
  // Brand Gradients
  static const storageGradient = LinearGradient(
    colors: [Color(0xFF5B3FE8), Color(0xFF7B3CE2), Color(0xFFB03BE3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const buttonGradient = LinearGradient(
    colors: [Color(0xFF5F43E8), Color(0xFF833EE4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const userBubbleGradient = LinearGradient(
    colors: [Color(0xFF4338CA), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Storage segments
  static const photosColor = Color(0xFFFBBF24); // Amber / Yellow
  static const docsColor = Color(0xFFEC4899);   // Pink / Magenta
  static const appsColor = Color(0xFF8B5CF6);   // Purple
  static const systemColor = Color(0xFFC084FC); // Lavender

  // File badges
  static const pdfColor = Color(0xFFEF4444);
  static const docColor = Color(0xFF2563EB);
  static const xlsColor = Color(0xFF10B981);
  static const pptColor = Color(0xFF8B5CF6);
  static const imgColor = Color(0xFF10B981);
  static const apkColor = Color(0xFF10B981);

  // Success green
  static const successGreen = Color(0xFF10B981);
  static const accentBlue = Color(0xFF3B82F6);
  static const accentPurple = Color(0xFF6366F1);
}

class AppTheme {
  static ThemeData light() {
    const primary = Color(0xFF6046E8);
    const scaffoldBg = Color(0xFFF7F8FC);
    const cardBg = Color(0xFFFFFFFF);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: Color(0xFF7A3DE2),
        surface: cardBg,
        surfaceContainerHighest: Color(0xFFF1F3F9),
        onSurface: Color(0xFF111827),
        onSurfaceVariant: Color(0xFF6B7280),
        outline: Color(0xFFE5E7EB),
        outlineVariant: Color(0xFFF3F4F6),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: Color(0xFF111827),
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: Color(0xFF111827),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: Color(0xFF111827),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF111827),
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: Color(0xFF6B7280),
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: Color(0xFF9CA3AF),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xFF111827),
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: Color(0xFF111827)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF1F3F9),
        thickness: 1,
      ),
    );
  }

  static ThemeData dark() {
    const primary = Color(0xFF7C5CF8);
    const scaffoldBg = Color(0xFF0C0E17);
    const cardBg = Color(0xFF151824);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: Color(0xFF9333EA),
        surface: cardBg,
        surfaceContainerHighest: Color(0xFF1E2235),
        onSurface: Color(0xFFF9FAFB),
        onSurfaceVariant: Color(0xFF9CA3AF),
        outline: Color(0xFF262C40),
        outlineVariant: Color(0xFF1C2030),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: Color(0xFFF9FAFB),
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: Color(0xFFF9FAFB),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: Color(0xFFF9FAFB),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF9FAFB),
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFFF9FAFB),
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: Color(0xFF9CA3AF),
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: Color(0xFF6B7280),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xFFF9FAFB),
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: Color(0xFFF9FAFB)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF22283A),
        thickness: 1,
      ),
    );
  }
}
